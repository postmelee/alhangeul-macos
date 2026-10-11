#!/usr/bin/env python3
"""실제 CoreText scan을 사용하는 unsigned 격리 성능 측정. 설치/등록/서명 없음."""
import argparse
import collections
import hashlib
import json
import math
import platform
import shutil
import statistics
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD_FLAGS = ["ALHANGEUL_FONT_EXTENSION_PROBE"]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def distribution(values):
    if not values:
        return {"count": 0}
    values = sorted(values)
    result = {"count": len(values), "minimum": values[0], "median": statistics.median(values), "maximum": values[-1]}
    if len(values) >= 10:
        result["p90"] = values[math.ceil(0.9 * len(values)) - 1]
    return result


def summarize(results):
    groups = collections.defaultdict(list)
    for result in results:
        for row in result["samples"]:
            key = (result["mode"], result["installedEnabled"], row["scenario"], row["file"] if row["scenario"] not in ("many-serial", "many-concurrent", "many-max10") else "many", row["phase"], row.get("cache"))
            groups[key].append(row)
    summary = []
    for key, rows in sorted(groups.items(), key=lambda pair: str(pair[0])):
        valid = [r for r in rows if r["status"] == "success"]
        totals = [(r["end"] - r["start"]) / 1_000_000 for r in valid]
        snapshots, ratios, scans, metadata, metadata_ratios = [], [], [], [], []
        for row, total in zip(valid, totals):
            durations = [(s["end"] - s["start"]) / 1_000_000 for s in row["spans"] if s["kind"] == "snapshotCall" and s["success"]]
            snapshots.extend(durations)
            internal = [(s["end"] - s["start"]) / 1_000_000 for s in row["spans"] if s["kind"] == "metadata" and s["success"]]
            metadata.extend(internal)
            if len(internal) == 1 and 0 < internal[0] <= total:
                metadata_ratios.append(internal[0] / total)
            if len(durations) == 1 and 0 < durations[0] <= total:
                ratios.append(durations[0] / total)
            scans.extend((s["end"] - s["start"]) / 1_000_000 for s in row["spans"] if s["kind"] == "scan")
        summary.append({"mode": key[0], "installedEnabled": key[1], "scenario": key[2], "file": key[3], "phase": key[4], "cache": key[5],
                        "statuses": dict(collections.Counter(r["status"] for r in rows)), "fallbackCount": sum(bool(r.get("fallback")) for r in rows),
                        "totalMs": distribution(totals), "snapshotCallMs": distribution(snapshots), "scanMs": distribution(scans),
                        "metadataMs": distribution(metadata), "metadataFraction": distribution(metadata_ratios),
                        "snapshotCallFraction": distribution(ratios), "scanCount": sum(s["kind"] == "scan" for r in rows for s in r["spans"]),
                        "readCount": sum(s["kind"] == "read" for r in rows for s in r["spans"]),
                        "readBytes": sum(s["bytes"] for r in rows for s in r["spans"] if s["kind"] == "read" and s["success"]),
                        "readFailures": sum(s["kind"] == "read" and not s["success"] for r in rows for s in r["spans"]),
                        "releaseCount": sum(s["kind"] == "release" for r in rows for s in r["spans"]),
                        "note": "snapshotCall includes actor entry wait; differs from internal metadataMs"})
    return summary


def main():
    driver_source = Path(__file__).read_bytes()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--suite", choices=["snapshot", "consumers", "transitions", "guards", "signature", "attributes", "collections", "all"], default="all")
    parser.add_argument("--binary", type=Path, help="동일 source receipt의 기존 격리 binary 재사용")
    parser.add_argument("--optimization", choices=["none", "speed"], default="none", help="기존 비최적화 비교와 -O 비교를 분리")
    parser.add_argument("--repetitions", type=int, choices=range(1, 4), help="부분 진단용 반복 수")
    args = parser.parse_args()
    out = args.output.resolve()
    if out.exists() or not out.is_relative_to(ROOT / "build.noindex/task580"):
        raise SystemExit("build.noindex/task580 아래 새 실행 경로가 필요합니다")
    out.mkdir(parents=True)
    (out / "driver-source.py").write_bytes(driver_source)
    inputs = out / "inputs"
    inputs.mkdir()
    audit = json.loads((ROOT / "Tests/ExtensionFontPerformanceProbe/fixtures.json").read_text())
    for entry in audit["originalFonts"]["verifiedFiles"]:
        original = ROOT / entry["path"]
        if digest(original) != entry["sha256"]:
            raise SystemExit("OFL 원본 hash 불일치")
        shutil.copy2(original, inputs / original.name)
    for entry, name in zip(audit["fixtures"], ["single.hwp", "single.hwpx", "two.hwpx"]):
        original = ROOT / entry["path"]
        if digest(original) != entry["sha256"]:
            raise SystemExit("문서 원본 hash 불일치")
        shutil.copy2(original, inputs / name)
    for index in range(10):
        shutil.copy2(inputs / "single.hwpx", inputs / f"many-{index}.hwpx")
    sources = sorted((ROOT / "Sources/RhwpCoreBridge").glob("*.swift"))
    sources += sorted((ROOT / "Sources/Shared/FontLibrary").glob("*.swift"))
    sources += sorted((ROOT / "Sources/Shared/NativeFonts").glob("*.swift"))
    sources += [ROOT / f"Sources/Shared/{name}.swift" for name in ["HwpPageImageRenderer", "HwpNativePageCompositor", "HwpPreviewPDFRenderer", "HwpPreviewPNGRenderer", "HwpExternalImageResolver"]]
    sources += [ROOT / "Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift"]
    sources += sorted((ROOT / "Tests/ExtensionFontPerformanceProbe").glob("*.swift"))
    source_hashes = {str(p.relative_to(ROOT)): digest(p) for p in sources}
    source_hashes["Tests/ExtensionFontPerformanceProbe/fixtures.json"] = digest(ROOT / "Tests/ExtensionFontPerformanceProbe/fixtures.json")
    source_hashes["Frameworks/universal/librhwp.a"] = digest(ROOT / "Frameworks/universal/librhwp.a")
    source_hashes["Frameworks/generated_rhwp.h"] = digest(ROOT / "Frameworks/generated_rhwp.h")
    if args.binary:
        binary = args.binary.resolve()
        if not binary.is_relative_to(ROOT / "build.noindex/task580"):
            raise SystemExit("다른 경로의 binary는 재사용하지 않습니다")
        receipt = json.loads((binary.parent / "receipt.json").read_text())
        if receipt["sources"] != source_hashes or receipt["binarySHA256"] != digest(binary) or receipt.get("buildFlags") != BUILD_FLAGS or receipt.get("optimization", "none") != args.optimization:
            raise SystemExit("binary/source receipt 불일치")
    else:
        build = out / "build"
        build.mkdir()
        binary = build / "font-performance"
        cmd = ["swiftc", "-parse-as-library", "-D", "ALHANGEUL_FONT_EXTENSION_PROBE", "-target", platform.machine() + "-apple-macosx12.0", "-module-cache-path", str(build / "modules"), "-I", str(ROOT / "Frameworks/modulemap")]
        if args.optimization == "speed":
            cmd += ["-O"]
        cmd += list(map(str, sources)) + ["-L", str(ROOT / "Frameworks/universal"), "-lrhwp"]
        for framework in ["JavaScriptCore", "CoreText", "CoreGraphics", "ImageIO", "Foundation", "CoreServices", "ApplicationServices", "Security", "Metal", "QuartzCore", "IOSurface", "OpenGL"]:
            cmd += ["-framework", framework]
        cmd += ["-lc++", "-lz", "-liconv", "-o", str(binary)]
        with (build / "compile.log").open("w") as log:
            subprocess.run(cmd, cwd=ROOT, stdout=log, stderr=log, check=True)
        if any(digest(ROOT / name) != expected for name, expected in source_hashes.items()):
            raise SystemExit("compile 중 source/fixture/native 변경으로 측정 거부")
        (build / "receipt.json").write_text(json.dumps({"sources": source_hashes, "binarySHA256": digest(binary), "buildFlags": BUILD_FLAGS, "optimization": args.optimization}, indent=2) + "\n")
    modes = ["snapshot", "consumers", "transitions", "guards"] if args.suite == "all" else [args.suite]
    results = []
    for mode in modes:
        for enabled in ["off", "on"]:
            for repetition in range(args.repetitions or (3 if mode == "snapshot" else 2 if mode == "consumers" else 1)):
                name = f"{mode}-{enabled}-{repetition}"
                run = out / name
                run.mkdir()
                print("RUN", name, flush=True)
                with (run / "runtime.log").open("w") as log:
                    subprocess.run([str(binary), str(inputs), str(run), mode, enabled, str(repetition)], stdout=log, stderr=log, check=True, timeout=600)
                results.append(json.loads((run / "result.json").read_text()))
                (out / "summary.json").write_text(json.dumps(summarize(results), indent=2) + "\n")
    if any(digest(ROOT / name) != expected for name, expected in source_hashes.items()):
        raise SystemExit("실행 중 source/fixture/native 변경으로 측정 거부")
    receipt = {"sourceCommit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
               "uncommittedSources": source_hashes, "platform": platform.platform(), "architecture": platform.machine(),
               "coreLockSHA256": digest(ROOT / "rhwp-core.lock"), "inputs": {p.name: digest(p) for p in inputs.iterdir()},
               "binary": str(binary.relative_to(ROOT)), "scope": "unsigned direct real CoreText environment, private store; not signed Finder",
               "buildFlags": BUILD_FLAGS, "optimization": args.optimization,
               "driverSHA256": hashlib.sha256(driver_source).hexdigest(),
               "runs": len(results), "samples": sum(len(r["samples"]) for r in results), "installedOSFontsModified": False}
    (out / "run-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print("PASS", receipt["runs"], "runs", receipt["samples"], "samples", out / "summary.json", flush=True)


if __name__ == "__main__":
    main()
