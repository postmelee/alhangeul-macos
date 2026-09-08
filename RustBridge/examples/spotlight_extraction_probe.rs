//! Spotlight 경로 선택용 측정. 본문 대신 시간과 결과 길이만 출력한다.
use rhwp::{doclang, parser, DocumentCore};
use serde_json::json;
use std::{env, fs, time::Instant};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    for path in env::args().skip(1) {
        let data = fs::read(&path)?;
        let start = Instant::now();
        let parsed = parser::parse_document(&data);
        let parse_ms = start.elapsed().as_secs_f64() * 1000.0;
        let parse_ok = parsed.is_ok();
        drop(parsed);
        let start = Instant::now();
        let semantic = doclang::extract_semantic(&data, &doclang::ConvertOptions::default());
        let semantic_ms = start.elapsed().as_secs_f64() * 1000.0;
        let semantic_ok = semantic.is_ok();
        drop(semantic);
        let start = Instant::now();
        let core = DocumentCore::from_bytes(&data);
        let open_ms = start.elapsed().as_secs_f64() * 1000.0;
        let mut result = json!({"file": path, "input_bytes": data.len(),
            "parse_ok": parse_ok, "parse_ms": parse_ms,
            "semantic_ok": semantic_ok, "semantic_ms": semantic_ms,
            "layout_open_ok": core.is_ok(), "layout_open_ms": open_ms});
        if let Ok(core) = core {
            let start = Instant::now();
            let unicode: String = serde_json::from_str(&core.text_file_unicode_json())?;
            result["unicode_ms"] = json!(start.elapsed().as_secs_f64() * 1000.0);
            result["unicode_bytes"] = json!(unicode.len());
            let start = Instant::now();
            let mut page_bytes = 0;
            let mut page_errors = 0;
            for page in 0..core.page_count() {
                match core.extract_page_text_native(page) {
                    Ok(text) => page_bytes += text.len(),
                    Err(_) => page_errors += 1,
                }
            }
            result["pages"] = json!(core.page_count());
            result["page_text_ms"] = json!(start.elapsed().as_secs_f64() * 1000.0);
            result["page_text_bytes"] = json!(page_bytes);
            result["page_errors"] = json!(page_errors);
        }
        println!("{result}");
    }
    Ok(())
}
