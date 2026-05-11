use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::time::Instant;

use rhwp::DocumentCore;

struct Config {
    output_dir: PathBuf,
    runs: usize,
    inputs: Vec<PathBuf>,
}

struct Measurement {
    file_name: String,
    file_path: String,
    file_bytes: u64,
    run: usize,
    status: String,
    error: String,
    page_count: u32,
    data_read_seconds: f64,
    open_seconds: f64,
    svg_seconds: f64,
    svg_bytes: usize,
    pdf_seconds: f64,
    pdf_bytes: usize,
    total_seconds: f64,
    output_path: String,
}

fn main() {
    let config = match parse_args(env::args().skip(1).collect()) {
        Ok(config) => config,
        Err(message) => {
            eprintln!("{message}");
            std::process::exit(2);
        }
    };

    if let Err(error) = fs::create_dir_all(&config.output_dir) {
        eprintln!("failed to create output directory: {error}");
        std::process::exit(1);
    }

    let mut measurements = Vec::new();
    for run in 1..=config.runs {
        for input in &config.inputs {
            let measurement = measure(input, &config.output_dir, run);
            println!("{}", measurement.to_tsv());
            measurements.push(measurement);
        }
    }

    if let Err(error) = write_outputs(&config.output_dir, &measurements) {
        eprintln!("failed to write benchmark outputs: {error}");
        std::process::exit(1);
    }
}

fn parse_args(args: Vec<String>) -> Result<Config, String> {
    if args.len() < 2 {
        return Err(usage());
    }

    let output_dir = PathBuf::from(&args[0]);
    let mut runs = 3usize;
    let mut inputs = Vec::new();
    let mut index = 1;

    while index < args.len() {
        match args[index].as_str() {
            "--runs" => {
                index += 1;
                if index >= args.len() {
                    return Err("missing value for --runs".to_string());
                }
                runs = args[index]
                    .parse::<usize>()
                    .map_err(|_| "invalid --runs value".to_string())?;
                if runs == 0 {
                    return Err("--runs must be greater than 0".to_string());
                }
            }
            "--help" | "-h" => return Err(usage()),
            value if value.starts_with("--") => {
                return Err(format!("unknown option: {value}"));
            }
            value => inputs.push(PathBuf::from(value)),
        }
        index += 1;
    }

    if inputs.is_empty() {
        return Err("missing input files".to_string());
    }

    Ok(Config { output_dir, runs, inputs })
}

fn usage() -> String {
    "usage: svg_pdf_benchmark <output-dir> [--runs N] <hwp-or-hwpx> [...]".to_string()
}

fn measure(input: &Path, output_dir: &Path, run: usize) -> Measurement {
    let start_total = Instant::now();
    let file_name = input
        .file_name()
        .and_then(|name| name.to_str())
        .unwrap_or("input")
        .to_string();
    let file_path = input.display().to_string();
    let file_bytes = fs::metadata(input).map(|metadata| metadata.len()).unwrap_or(0);

    match measure_ok(input, output_dir, run) {
        Ok(mut measurement) => {
            measurement.total_seconds = start_total.elapsed().as_secs_f64();
            measurement
        }
        Err(error) => Measurement {
            file_name,
            file_path,
            file_bytes,
            run,
            status: "FAIL".to_string(),
            error,
            page_count: 0,
            data_read_seconds: 0.0,
            open_seconds: 0.0,
            svg_seconds: 0.0,
            svg_bytes: 0,
            pdf_seconds: 0.0,
            pdf_bytes: 0,
            total_seconds: start_total.elapsed().as_secs_f64(),
            output_path: String::new(),
        },
    }
}

fn measure_ok(input: &Path, output_dir: &Path, run: usize) -> Result<Measurement, String> {
    let file_name = input
        .file_name()
        .and_then(|name| name.to_str())
        .unwrap_or("input")
        .to_string();
    let file_path = input.display().to_string();
    let file_bytes = fs::metadata(input).map_err(|error| error.to_string())?.len();

    let data_read_start = Instant::now();
    let data = fs::read(input).map_err(|error| error.to_string())?;
    let data_read_seconds = data_read_start.elapsed().as_secs_f64();

    let open_start = Instant::now();
    let document = DocumentCore::from_bytes(&data).map_err(|error| format!("{error:?}"))?;
    let open_seconds = open_start.elapsed().as_secs_f64();

    let page_count = document.page_count();
    let svg_start = Instant::now();
    let mut svg_pages = Vec::with_capacity(page_count as usize);
    let mut svg_bytes = 0usize;
    for page in 0..page_count {
        let svg = document
            .render_page_svg_native(page)
            .map_err(|error| format!("page {} SVG failed: {error:?}", page + 1))?;
        svg_bytes += svg.len();
        svg_pages.push(svg);
    }
    let svg_seconds = svg_start.elapsed().as_secs_f64();

    let pdf_start = Instant::now();
    let pdf_bytes = rhwp::renderer::pdf::svgs_to_pdf(&svg_pages).map_err(|error| error.to_string())?;
    let pdf_seconds = pdf_start.elapsed().as_secs_f64();

    let stem = input
        .file_stem()
        .and_then(|name| name.to_str())
        .unwrap_or("output");
    let output_path = output_dir.join(format!("{stem}-run{run}-svg-core.pdf"));
    fs::write(&output_path, &pdf_bytes).map_err(|error| error.to_string())?;

    Ok(Measurement {
        file_name,
        file_path,
        file_bytes,
        run,
        status: "OK".to_string(),
        error: String::new(),
        page_count,
        data_read_seconds,
        open_seconds,
        svg_seconds,
        svg_bytes,
        pdf_seconds,
        pdf_bytes: pdf_bytes.len(),
        total_seconds: 0.0,
        output_path: output_path.display().to_string(),
    })
}

fn write_outputs(output_dir: &Path, measurements: &[Measurement]) -> Result<(), String> {
    let mut tsv = String::new();
    tsv.push_str("file\tpath\trun\tstatus\tfile_bytes\tpages\tdata_read_s\topen_s\tsvg_s\tsvg_bytes\tpdf_s\tpdf_bytes\ttotal_s\toutput\terror\n");
    for measurement in measurements {
        tsv.push_str(&measurement.to_tsv());
        tsv.push('\n');
    }
    fs::write(output_dir.join("svg_pdf_measurements.tsv"), tsv).map_err(|error| error.to_string())?;

    let mut summary = String::new();
    summary.push_str("# rhwp SVG PDF Benchmark\n\n");
    summary.push_str("| File | Runs | Status | Pages | AvgTotalSeconds | MinTotalSeconds | MaxTotalSeconds | AvgPDFSeconds | AvgPDFBytes |\n");
    summary.push_str("|------|------|--------|-------|-----------------|-----------------|-----------------|---------------|-------------|\n");

    let mut files: Vec<&str> = measurements.iter().map(|measurement| measurement.file_name.as_str()).collect();
    files.sort_unstable();
    files.dedup();

    for file in files {
        let rows: Vec<&Measurement> = measurements
            .iter()
            .filter(|measurement| measurement.file_name == file && measurement.status == "OK")
            .collect();
        if rows.is_empty() {
            summary.push_str(&format!("| `{file}` | 0 | FAIL | - | - | - | - | - | - |\n"));
            continue;
        }

        let runs = rows.len();
        let pages = rows[0].page_count;
        let avg_total = average(rows.iter().map(|row| row.total_seconds));
        let min_total = rows.iter().map(|row| row.total_seconds).fold(f64::INFINITY, f64::min);
        let max_total = rows.iter().map(|row| row.total_seconds).fold(0.0, f64::max);
        let avg_pdf = average(rows.iter().map(|row| row.pdf_seconds));
        let avg_pdf_bytes = average(rows.iter().map(|row| row.pdf_bytes as f64));

        summary.push_str(&format!(
            "| `{file}` | {runs} | OK | {pages} | {:.6} | {:.6} | {:.6} | {:.6} | {:.0} |\n",
            avg_total, min_total, max_total, avg_pdf, avg_pdf_bytes
        ));
    }

    fs::write(output_dir.join("svg_pdf_summary.md"), summary).map_err(|error| error.to_string())
}

fn average(values: impl Iterator<Item = f64>) -> f64 {
    let mut total = 0.0;
    let mut count = 0usize;
    for value in values {
        total += value;
        count += 1;
    }
    if count == 0 {
        0.0
    } else {
        total / count as f64
    }
}

impl Measurement {
    fn to_tsv(&self) -> String {
        [
            self.file_name.clone(),
            self.file_path.clone(),
            self.run.to_string(),
            self.status.clone(),
            self.file_bytes.to_string(),
            self.page_count.to_string(),
            seconds(self.data_read_seconds),
            seconds(self.open_seconds),
            seconds(self.svg_seconds),
            self.svg_bytes.to_string(),
            seconds(self.pdf_seconds),
            self.pdf_bytes.to_string(),
            seconds(self.total_seconds),
            self.output_path.clone(),
            self.error.clone(),
        ]
        .join("\t")
    }
}

fn seconds(value: f64) -> String {
    format!("{value:.6}")
}
