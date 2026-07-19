#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "scripts" / "preview_renderer_baseline_manifest.json"
DEFAULT_RESOURCE_DIR = ROOT / "Sources" / "HostApp" / "Resources" / "rhwp-studio"
HARNESS = ROOT / "scripts" / "preview-visual-diff-harness.sh"
POLICY_CHOICES = {"coreGraphicsOnly", "skiaOptIn"}


@dataclass(frozen=True)
class SamplePage:
    sample_id: str
    path: Path
    repo_path: str
    file_name: str
    category: str
    page: int
    known_risk: list[str]
    threshold: dict[str, Any]
    notes: str


@dataclass
class RunResult:
    policy: str
    page: int
    output_dir: Path
    inputs: list[Path]
    exit_code: int | None


def main() -> int:
    args = parse_args()
    manifest_path = resolve_repo_path(args.manifest)
    manifest = load_manifest(manifest_path)
    validate_manifest(manifest, manifest_path)

    policies = parse_policy_pair(args.policy_pair, manifest)
    page_mode = args.page_mode or default_page_mode(args.suite, manifest)
    sample_pages = select_sample_pages(manifest, args.suite, page_mode)

    if args.validate_only:
        print_validation_summary(manifest, sample_pages, policies, page_mode)
        return 0

    if args.output_dir is None:
        raise SystemExit("error: output-dir is required unless --validate-only is used")

    output_dir = resolve_output_path(args.output_dir)
    runs = build_runs(output_dir, policies, sample_pages)
    write_plan(output_dir, manifest_path, manifest, args.suite, page_mode, policies, sample_pages, runs)

    if args.dry_run:
        write_summary(output_dir, manifest, args.suite, page_mode, policies, sample_pages, runs, {})
        print(f"dry-run: runs={len(runs)} samples={len({s.sample_id for s in sample_pages})}")
        return 0

    exit_codes: list[int] = []
    for run in runs:
        code = execute_run(run, args)
        run.exit_code = code
        exit_codes.append(code)

    parsed = parse_run_summaries(runs)
    write_summary(output_dir, manifest, args.suite, page_mode, policies, sample_pages, runs, parsed)
    return 1 if any(code != 0 for code in exit_codes) else 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run manifest-based CoreGraphics/Skia preview visual baseline suites.",
    )
    parser.add_argument("output_dir", nargs="?", help="Output directory for baseline artifacts.")
    parser.add_argument("--suite", choices=["quick", "extended", "all"], default="quick")
    parser.add_argument("--manifest", default=str(DEFAULT_MANIFEST))
    parser.add_argument("--page-mode", choices=["first", "manifest"])
    parser.add_argument("--policy-pair", default=None, help="Comma-separated pair, default from manifest.")
    parser.add_argument("--viewport", default="1400x1800")
    parser.add_argument("--settle-ms", default="120")
    parser.add_argument("--resource-dir", default=str(DEFAULT_RESOURCE_DIR))
    parser.add_argument("--dry-run", action="store_true", help="Validate and write a run plan without invoking the harness.")
    parser.add_argument("--validate-only", action="store_true", help="Validate manifest and selected samples, then exit.")
    return parser.parse_args()


def resolve_repo_path(value: str) -> Path:
    path = Path(value)
    if not path.is_absolute():
        path = ROOT / path
    return path


def resolve_output_path(value: str) -> Path:
    path = Path(value)
    if not path.is_absolute():
        path = ROOT / path
    return path


def load_manifest(path: Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise SystemExit(f"error: missing manifest: {path}") from None
    except json.JSONDecodeError as error:
        raise SystemExit(f"error: invalid JSON manifest: {path}: {error}") from None


def validate_manifest(manifest: dict[str, Any], manifest_path: Path) -> None:
    samples = manifest.get("samples")
    if not isinstance(samples, list) or not samples:
        raise SystemExit(f"error: manifest has no samples: {manifest_path}")

    seen_ids: set[str] = set()
    missing: list[str] = []
    for index, sample in enumerate(samples):
        if not isinstance(sample, dict):
            raise SystemExit(f"error: sample #{index + 1} must be an object")
        sample_id = required_string(sample, "id", index)
        if sample_id in seen_ids:
            raise SystemExit(f"error: duplicate sample id: {sample_id}")
        seen_ids.add(sample_id)
        repo_path = required_string(sample, "path", index)
        if not (ROOT / repo_path).is_file():
            missing.append(repo_path)
        required_string(sample, "category", index)
        required_string_list(sample, "suite", index)
        pages = sample.get("pages")
        if not isinstance(pages, list) or not pages or any(not isinstance(p, int) or p < 1 for p in pages):
            raise SystemExit(f"error: sample {sample_id} must have positive integer pages")
        required_string_list(sample, "surfaces", index)
        if not isinstance(sample.get("knownRisk", []), list):
            raise SystemExit(f"error: sample {sample_id} knownRisk must be an array")
        if not isinstance(sample.get("threshold", {}), dict):
            raise SystemExit(f"error: sample {sample_id} threshold must be an object")

    if missing:
        raise SystemExit("error: missing samples: " + ", ".join(missing))


def required_string(sample: dict[str, Any], key: str, index: int) -> str:
    value = sample.get(key)
    if not isinstance(value, str) or not value:
        raise SystemExit(f"error: sample #{index + 1} missing string field {key}")
    return value


def required_string_list(sample: dict[str, Any], key: str, index: int) -> list[str]:
    value = sample.get(key)
    if not isinstance(value, list) or not value or any(not isinstance(item, str) for item in value):
        raise SystemExit(f"error: sample #{index + 1} missing string array field {key}")
    return value


def parse_policy_pair(value: str | None, manifest: dict[str, Any]) -> list[str]:
    raw = value
    if raw is None:
        pair = manifest.get("policyPair")
        if not isinstance(pair, list):
            raise SystemExit("error: manifest policyPair must be an array")
        policies = [str(item) for item in pair]
    else:
        policies = [part.strip() for part in raw.split(",") if part.strip()]

    if len(policies) != 2:
        raise SystemExit("error: --policy-pair must contain exactly two policies")
    unknown = [policy for policy in policies if policy not in POLICY_CHOICES]
    if unknown:
        raise SystemExit("error: unknown policy in pair: " + ", ".join(unknown))
    if policies[0] == policies[1]:
        raise SystemExit("error: --policy-pair must contain two different policies")
    return policies


def default_page_mode(suite: str, manifest: dict[str, Any]) -> str:
    if suite == "all":
        return "manifest"
    suites = manifest.get("suites", {})
    suite_info = suites.get(suite, {}) if isinstance(suites, dict) else {}
    mode = suite_info.get("defaultPageMode", "first") if isinstance(suite_info, dict) else "first"
    if mode not in {"first", "manifest"}:
        raise SystemExit(f"error: invalid defaultPageMode for suite {suite}: {mode}")
    return mode


def select_sample_pages(manifest: dict[str, Any], suite: str, page_mode: str) -> list[SamplePage]:
    selected: list[SamplePage] = []
    for sample in manifest["samples"]:
        sample_suites = sample["suite"]
        if suite != "all" and suite not in sample_suites:
            continue
        pages = sample["pages"][:1] if page_mode == "first" else sample["pages"]
        repo_path = sample["path"]
        path = ROOT / repo_path
        for page in pages:
            selected.append(
                SamplePage(
                    sample_id=sample["id"],
                    path=path,
                    repo_path=repo_path,
                    file_name=path.name,
                    category=sample["category"],
                    page=int(page),
                    known_risk=[str(item) for item in sample.get("knownRisk", [])],
                    threshold=dict(sample.get("threshold", {})),
                    notes=str(sample.get("notes", "")),
                )
            )
    if not selected:
        raise SystemExit(f"error: suite selected no samples: {suite}")
    return selected


def build_runs(output_dir: Path, policies: list[str], sample_pages: list[SamplePage]) -> list[RunResult]:
    runs: list[RunResult] = []
    pages = sorted({sample.page for sample in sample_pages})
    for policy in policies:
        for page in pages:
            inputs = [sample.path for sample in sample_pages if sample.page == page]
            if not inputs:
                continue
            runs.append(
                RunResult(
                    policy=policy,
                    page=page,
                    output_dir=output_dir / "runs" / policy / f"page-{page}",
                    inputs=inputs,
                    exit_code=None,
                )
            )
    return runs


def write_plan(
    output_dir: Path,
    manifest_path: Path,
    manifest: dict[str, Any],
    suite: str,
    page_mode: str,
    policies: list[str],
    sample_pages: list[SamplePage],
    runs: list[RunResult],
) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    plan = {
        "label": manifest.get("label"),
        "version": manifest.get("version"),
        "suite": suite,
        "pageMode": page_mode,
        "manifest": str(manifest_path),
        "policyPair": policies,
        "samplePages": [
            {
                "id": sample.sample_id,
                "path": sample.repo_path,
                "category": sample.category,
                "page": sample.page,
                "knownRisk": sample.known_risk,
            }
            for sample in sample_pages
        ],
        "runs": [
            {
                "policy": run.policy,
                "page": run.page,
                "outputDir": str(run.output_dir),
                "inputs": [str(path.relative_to(ROOT)) for path in run.inputs],
            }
            for run in runs
        ],
    }
    (output_dir / "run-plan.json").write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def execute_run(run: RunResult, args: argparse.Namespace) -> int:
    run.output_dir.mkdir(parents=True, exist_ok=True)
    resource_dir = resolve_repo_path(args.resource_dir)
    cmd = [
        str(HARNESS),
        str(run.output_dir),
        "--page",
        str(run.page),
        "--policy",
        run.policy,
        "--viewport",
        args.viewport,
        "--settle-ms",
        str(args.settle_ms),
        "--resource-dir",
        str(resource_dir),
        *[str(path) for path in run.inputs],
    ]
    print("+ " + " ".join(shell_quote(part) for part in cmd), flush=True)
    return subprocess.run(cmd, cwd=ROOT).returncode


def shell_quote(value: str) -> str:
    if not value or any(ch.isspace() or ch in "'\"$`\\|" for ch in value):
        return "'" + value.replace("'", "'\"'\"'") + "'"
    return value


def parse_run_summaries(runs: list[RunResult]) -> dict[tuple[str, int, str], dict[str, str]]:
    parsed: dict[tuple[str, int, str], dict[str, str]] = {}
    for run in runs:
        summary = run.output_dir / "summary.md"
        if not summary.is_file():
            continue
        for row in parse_summary_rows(summary):
            file_name = normalize_name(row.get("File", ""))
            parsed[(run.policy, run.page, file_name)] = row
    return parsed


def parse_summary_rows(path: Path) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    headers: list[str] | None = None
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        if cells and cells[0] == "File" and "Status" in cells:
            headers = cells
            continue
        if headers is None:
            continue
        if cells and set(cells[0]) <= {"-"}:
            continue
        if len(cells) < len(headers):
            continue
        rows.append(dict(zip(headers, cells)))
    return rows


def normalize_name(value: str) -> str:
    return unicodedata.normalize("NFC", value)


def write_summary(
    output_dir: Path,
    manifest: dict[str, Any],
    suite: str,
    page_mode: str,
    policies: list[str],
    sample_pages: list[SamplePage],
    runs: list[RunResult],
    parsed: dict[tuple[str, int, str], dict[str, str]],
) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    first_policy, second_policy = policies
    lines: list[str] = []
    lines.append("# Preview Renderer Baseline")
    lines.append("")
    lines.append(f"Label: {manifest.get('label', '-')}")
    lines.append(f"Suite: {suite}")
    lines.append(f"PageMode: {page_mode}")
    lines.append(f"PolicyPair: {first_policy},{second_policy}")
    lines.append(f"Samples: {len({sample.sample_id for sample in sample_pages})}")
    lines.append(f"SamplePages: {len(sample_pages)}")
    lines.append("")
    lines.append("## Runs")
    lines.append("")
    lines.append("| Policy | Page | ExitCode | Inputs | Summary |")
    lines.append("|--------|------|----------|--------|---------|")
    for run in runs:
        rel_summary = relative_link(output_dir, run.output_dir / "summary.md")
        exit_code = "-" if run.exit_code is None else str(run.exit_code)
        lines.append(
            markdown_row(
                [
                    run.policy,
                    str(run.page),
                    exit_code,
                    str(len(run.inputs)),
                    f"[summary]({rel_summary})" if (run.output_dir / "summary.md").is_file() else "-",
                ]
            )
        )
    lines.append("")
    lines.append("## Pair Summary")
    lines.append("")
    lines.append(
        "| ID | Category | Page | KnownRisk | "
        + f"{first_policy}Status | {first_policy}StudioCapture | {first_policy}ChangedPercent | {first_policy}MeanRGBDelta | {first_policy}NativeMs | {first_policy}Backend | "
        + f"{second_policy}Status | {second_policy}StudioCapture | {second_policy}ChangedPercent | {second_policy}MeanRGBDelta | {second_policy}NativeMs | {second_policy}Backend | "
        + "SkiaMinusCGChangedPercent | NativeSizeDriftPx | Triage | Artifacts |"
    )
    lines.append(
        "|----|----------|------|-----------|"
        "----------|-------------|----------------|-------------|----------|-------|"
        "----------|-------------|----------------|-------------|----------|-------|"
        "--------------------------|-------------------|--------|-----------|"
    )
    for sample in sample_pages:
        first = parsed.get((first_policy, sample.page, normalize_name(sample.file_name)), {})
        second = parsed.get((second_policy, sample.page, normalize_name(sample.file_name)), {})
        cg_changed = percent_value(first.get("ChangedPercent"))
        skia_changed = percent_value(second.get("ChangedPercent"))
        delta = numeric_delta(skia_changed, cg_changed)
        size_drift = native_size_drift(first.get("NativeSize"), second.get("NativeSize"))
        triage = triage_status(sample, first, second, delta)
        artifacts = artifact_links(output_dir, policies, sample.page)
        lines.append(
            markdown_row(
                [
                    sample.sample_id,
                    sample.category,
                    str(sample.page),
                    ",".join(sample.known_risk) or "-",
                    status_cell(first),
                    first.get("StudioCapture", "-"),
                    first.get("ChangedPercent", "-"),
                    first.get("MeanRGBDelta", "-"),
                    first.get("NativeMs", "-"),
                    first.get("NativeBackend", "-"),
                    status_cell(second),
                    second.get("StudioCapture", "-"),
                    second.get("ChangedPercent", "-"),
                    second.get("MeanRGBDelta", "-"),
                    second.get("NativeMs", "-"),
                    second.get("NativeBackend", "-"),
                    format_delta(delta),
                    "-" if size_drift is None else str(size_drift),
                    triage,
                    artifacts,
                ]
            )
        )
    (output_dir / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def status_cell(row: dict[str, str]) -> str:
    return row.get("Status", "MISSING") if row else "MISSING"


def percent_value(value: str | None) -> float | None:
    if not value or value == "-":
        return None
    try:
        return float(value.rstrip("%"))
    except ValueError:
        return None


def numeric_delta(left: float | None, right: float | None) -> float | None:
    if left is None or right is None:
        return None
    return left - right


def native_size_drift(first: str | None, second: str | None) -> int | None:
    first_size = parse_size(first)
    second_size = parse_size(second)
    if first_size is None or second_size is None:
        return None
    return max(abs(first_size[0] - second_size[0]), abs(first_size[1] - second_size[1]))


def parse_size(value: str | None) -> tuple[int, int] | None:
    if not value or "x" not in value:
        return None
    left, right = value.split("x", 1)
    try:
        return int(left), int(right)
    except ValueError:
        return None


def triage_status(sample: SamplePage, first: dict[str, str], second: dict[str, str], delta: float | None) -> str:
    if not first or not second:
        return "missing"
    if first.get("Status") != "OK" or second.get("Status") != "OK":
        return "failure"
    threshold = sample.threshold
    max_delta = float(threshold.get("maxSkiaMinusCGChangedPercentWarn", 5.0))
    max_changed = float(threshold.get("maxChangedPercentWarn", 10.0))
    skia_changed = percent_value(second.get("ChangedPercent"))
    if delta is not None and delta > max_delta:
        return "warn:skia-delta"
    if skia_changed is not None and skia_changed > max_changed:
        return "warn:skia-changed"
    if sample.known_risk:
        return "known-risk"
    return "ok"


def format_delta(value: float | None) -> str:
    if value is None:
        return "-"
    return f"{value:+.4f}pp"


def artifact_links(output_dir: Path, policies: list[str], page: int) -> str:
    links = []
    for policy in policies:
        summary = output_dir / "runs" / policy / f"page-{page}" / "summary.md"
        links.append(f"{policy}=[summary]({relative_link(output_dir, summary)})")
    return ", ".join(links)


def relative_link(base: Path, target: Path) -> str:
    try:
        return target.relative_to(base).as_posix()
    except ValueError:
        return target.as_posix()


def markdown_row(cells: list[str]) -> str:
    return "| " + " | ".join(markdown_cell(cell) for cell in cells) + " |"


def markdown_cell(value: Any) -> str:
    return str(value).replace("|", "/")


def print_validation_summary(
    manifest: dict[str, Any],
    sample_pages: list[SamplePage],
    policies: list[str],
    page_mode: str,
) -> None:
    print(f"label={manifest.get('label')}")
    print(f"policies={','.join(policies)}")
    print(f"pageMode={page_mode}")
    print(f"samples={len({sample.sample_id for sample in sample_pages})}")
    print(f"samplePages={len(sample_pages)}")


if __name__ == "__main__":
    sys.exit(main())
