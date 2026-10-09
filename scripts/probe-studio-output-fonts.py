#!/usr/bin/env python3
"""Task #568 Stage 1: 제품 PDF renderer를 쓰는 격리 실험. 설치·인쇄·다운로드 없음."""
import argparse
import hashlib
import json
from pathlib import Path
import platform
import plistlib
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PIN = "1a76570e833917d15817415a53c09ad61ab3203f"
FONT_HASHES = {
    "GowunBatang-Regular.ttf": "466c593e7147412e748af4856d5ad14709b5a860bdf62b9c2546f2c5874e9849",
    "GowunBatang-Bold.ttf": "dbfcaa646e5831e7478524924f02906f550285a5050699b4e38c9950b3ec4b94",
    "OFL.txt": "49a57cc769fa9affd6eefb9070a61e3d3f6b757c97cafb15848bc6d1c81acc78",
}
SOURCES = [
    "Tests/StudioOutputFontProbe/main.swift",
    "Tests/StudioOutputFontProbe/job.swift",
    "Sources/HostApp/Services/MacFontDiscovery.swift",
    "Sources/HostApp/Services/RhwpStudioPagePDFRenderer.swift",
    "Sources/HostApp/Services/RhwpStudioPDFFontProvider.swift",
    "Sources/HostApp/Services/RhwpStudioPagePayload.swift",
    "Tests/HostAppTests/CGPDFFontResourceInspector.swift",
]
SOURCES += sorted(str(p.relative_to(ROOT)) for pattern in ["Sources/Shared/FontLibrary/*.swift", "Sources/HostApp/Services/InstalledFont*.swift", "Sources/HostApp/Services/RhwpStudioOutputFont*.swift"] for p in ROOT.glob(pattern))
SVG = '''<svg xmlns="http://www.w3.org/2000/svg" width="794" height="1123" viewBox="0 0 794 1123">
<rect width="794" height="1123" fill="white"/>
<text x="64" y="85" font-family="sans-serif" font-size="24" font-weight="700">Task 568 | PDF FONT PROBE</text>
<text x="64" y="120" font-family="sans-serif" font-size="15" fill="#666">Regular / Bold / Korean / ASCII / fallback</text>
<path d="M64 140H730" stroke="#ddd"/>
<text x="64" y="195" data-face="regular" font-family="Gowun Batang" font-size="28">한글 글꼴 확인 가나다 ABC 123</text>
<text x="64" y="245" data-face="bold" font-family="Gowun Batang" font-weight="700" font-size="28">한글 굵은 글꼴 가나다 ABC 123</text>
<text x="64" y="285" data-face="regular" font-family="고운바탕" font-size="18">고운 바탕 Regular / localized family</text>
<text x="64" y="320" data-face="bold" font-family="GowunBatang-Bold" font-weight="700" font-size="18">고운 바탕 Bold / PostScript face</text>
<path d="M64 352H730" stroke="#ddd"/>
<text x="64" y="400" font-family="바탕" font-size="26">내장 바탕 대조 한글 ABC 456</text>
<text x="64" y="445" font-family="돋움" font-weight="700" font-size="26">내장 돋움 대조 한글 ABC 789</text>
<text x="64" y="505" font-family="serif" font-size="23">자모 ㄱ ㄴ ㄷ / 수식 ∑ √ ∞ / 漢字</text>
<rect x="64" y="550" width="666" height="88" fill="none" stroke="#777"/>
<path d="M64 594H730M397 550V638" stroke="#aaa"/>
<text x="80" y="580" font-family="sans-serif" font-size="18">표와 geometry 확인</text>
<text x="413" y="580" font-family="sans-serif" font-size="18">1 / 1 page</text>
<text x="80" y="623" data-face="regular" font-family="Gowun Batang" font-size="18">한글 검색과 선택</text>
<text x="413" y="623" data-face="bold" font-family="Gowun Batang" font-weight="700" font-size="18">Bold font program</text>
<text x="64" y="1040" font-family="sans-serif" font-size="14" fill="#777">Synthetic SVG. Isolated prototype; product output is unchanged.</text>
</svg>'''

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def run(args, *, log=None, timeout=60):
    try:
        result = subprocess.run([str(a) for a in args], cwd=ROOT, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
    except subprocess.TimeoutExpired as error:
        captured = error.stdout or b""
        if isinstance(captured, bytes):
            captured = captured.decode("utf-8", errors="replace")
        if log:
            log.write_text(captured, encoding="utf-8")
        raise RuntimeError(f"{Path(str(args[0])).name} 시간 초과:\n{captured[-5000:]}") from error
    if log:
        log.write_text(result.stdout, encoding="utf-8")
    if result.returncode:
        raise RuntimeError(f"{Path(str(args[0])).name} 실패 ({result.returncode}):\n{result.stdout[-5000:]}")
    return result.stdout

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--upstream-dir", type=Path, required=True)
    parser.add_argument("--font-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--node", default="node")
    parser.add_argument("--stage2", action="store_true", help="제품 output job과 Noto 회귀를 검사")
    args = parser.parse_args()
    upstream, fonts, output = (p.resolve() for p in (args.upstream_dir, args.font_dir, args.output_dir))
    if not output.is_relative_to(ROOT / "build.noindex/task568") or output.exists():
        raise RuntimeError("새 build.noindex/task568/ 하위 경로가 필요합니다. 기존 산출물은 덮지 않습니다.")
    if platform.system() != "Darwin":
        raise RuntimeError("macOS의 실제 WKWebView·PDFKit이 필요합니다.")
    assert run(["git", "-C", upstream, "rev-parse", "HEAD"]).strip() == PIN
    provenance = json.loads((fonts / "provenance.json").read_text())
    assert provenance["commit"] == "c1eda9233c33ad7775b27efd794f931095cf6133"
    for entry in provenance["files"]:
        file = fonts / entry["file"]
        assert file.stat().st_size == entry["bytes"] and digest(file) == entry["sha256"], file.name
    assert all(digest(fonts / name) == expected for name, expected in FONT_HASHES.items())
    output.mkdir(parents=True)
    inputs = {name: digest(ROOT / name) for name in SOURCES}
    official_sources = ["rhwp-studio/src/core/local-fonts.ts", "rhwp-studio/src/core/host-font-provider.ts",
                        "rhwp-studio/src/core/host-font-requests.ts", "rhwp-studio/src/main.ts"]
    official_hashes = {name: digest(upstream / name) for name in official_sources}
    for name in official_sources:
        committed = run(["git", "-C", upstream, "show", "HEAD:" + name])
        assert hashlib.sha256(committed.encode()).hexdigest() == official_hashes[name], name
    (output / "sample.svg").write_text(SVG.replace("고운바탕", "Gowun Batang Regular").replace("localized family", "fullName") if args.stage2 else SVG, encoding="utf-8")
    app = output / "StudioOutputFontProbe.app"
    executable = app / "Contents/MacOS/StudioOutputFontProbe"
    executable.parent.mkdir(parents=True)
    with (app / "Contents/Info.plist").open("wb") as stream:
        plistlib.dump({"CFBundleIdentifier": "com.postmelee.alhangeul.OutputFontProbe." + hashlib.sha256(str(output).encode()).hexdigest()[:10],
            "CFBundleName": "StudioOutputFontProbe", "CFBundleExecutable": executable.name,
            "CFBundlePackageType": "APPL", "CFBundleVersion": "1", "LSMinimumSystemVersion": "12.0",
            "NSHighResolutionCapable": True, "LSUIElement": True}, stream)
    command = ["xcrun", "swiftc", "-parse-as-library", "-swift-version", "5",
               "-target", platform.machine() + "-apple-macosx12.0", "-module-cache-path", output / "module-cache",
               *[ROOT / name for name in SOURCES], "-o", executable,
               "-framework", "AppKit", "-framework", "WebKit", "-framework", "PDFKit", "-framework", "CoreText"]
    run(command, log=output / "compile.log", timeout=180)
    run(["codesign", "--force", "--sign", "-", app], log=output / "codesign.log")
    lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
    try:
        run([executable, ROOT, fonts, output / "metadata.json", "metadata"], log=output / "metadata.log")
        run([args.node, ROOT / "Tests/StudioOutputFontProbe/matcher.mjs", upstream, fonts, output, *(["--adapted"] if args.stage2 else [])],
            log=output / "matcher.log")
        metadata = json.loads((output / "metadata.json").read_text())
        reports = {}
        for mode in (["baseline", "job"] if args.stage2 else ["baseline", "naive", "custom", "missing", "wrong-token"]):
            directory = output / mode
            directory.mkdir()
            run([executable, ROOT, fonts, directory, mode], log=directory / "runtime.log")
            report = json.loads((directory / "result.json").read_text())
            reports[mode] = report
            if mode in ["missing", "wrong-token"]:
                assert report["status"] == "expected-rejection" and not (directory / "sample.pdf").exists()
                assert any(e["source"] == "rejected" for e in report["events"])
                continue
            pdf = directory / "sample.pdf"
            assert report["status"] == "rendered" and report["pages"] == 1 and report["matches"] >= 4
            fidelity = {}
            for field in ["text", "selectionText"]:
                fidelity[field] = "한글 글꼴 확인 가나다 ABC 123" in report[field]
                if mode in ["custom", "job"]:
                    assert fidelity[field] and "한글 굵은 글꼴 가나다 ABC 123" in report[field], field
                else:
                    # 기준선의 기존 공백 mapping 결함은 측정해 남긴다. exact 통과로 합산하지 않는다.
                    compact = report[field].replace(" ", "").replace("#", "")
                    assert "한글글꼴확인가나다ABC123" in compact, field
            fonts_text = run(["pdffonts", pdf], log=directory / "pdffonts.txt")
            run(["pdfinfo", pdf], log=directory / "pdfinfo.txt")
            run(["pdftotext", "-layout", pdf, directory / "text.txt"])
            extracted = (directory / "text.txt").read_text()
            fidelity["pdftotext"] = "한글 글꼴 확인 가나다 ABC 123" in extracted
            if mode in ["custom", "job"]:
                assert fidelity["pdftotext"] and "한글 굵은 글꼴 가나다 ABC 123" in extracted
            fidelity["notoControlExact"] = "내장 바탕 대조 한글 ABC 456" in extracted
            if args.stage2:
                assert all(fidelity.values()), fidelity
            report["textFidelity"] = fidelity
            (directory / "result.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            run(["pdftoppm", "-png", "-singlefile", "-scale-to", "1400", pdf, directory / "page"])
            if mode in ["custom", "job"]:
                for ps in ["GowunBatang-Regular", "GowunBatang-Bold"]:
                    rows = [line for line in fonts_text.splitlines() if ps in line]
                    assert rows and all(re.search(r"\s+yes\s+yes\s+(yes|no)\s+\d+\s+\d+$", line) for line in rows), ps
                    assert any(re.search(r"\s+yes\s+yes\s+yes\s+\d+\s+\d+$", line) for line in rows), ps
                assert report["sourceReads"] == 2 and report["residentBytes"] == 16_612_008
                if mode == "custom":
                    assert all("Noto" not in row["family"] for row in report["preparation"]["customComputed"])
                else:
                    assert report["releases"] == 1 and report["residentAfterClose"] == 0
            else:
                assert "Noto" in fonts_text
                if mode == "baseline":
                    assert "GowunBatang" not in fonts_text
                assert all(row["family"].startswith('"Noto') or any(f.startswith('"Noto') for f in row["descendantFamilies"])
                           for row in report["preparation"]["customComputed"][:5])
                assert report["sourceReads"] == (0 if mode == "baseline" else 2)
        assert inputs == {name: digest(ROOT / name) for name in SOURCES}
        assert official_hashes == {name: digest(upstream / name) for name in official_sources}
        receipt = {"status": "passed", "upstreamCommit": PIN, "swift": run(["xcrun", "swiftc", "--version"]).strip(),
            "os": platform.platform(), "productSources": inputs, "officialSources": official_hashes,
            "fontProvenance": provenance, "systemPresent": {f["postscriptName"]: f["systemPresent"] for f in metadata["faces"]},
            "nanumPresent": metadata["nanumPresent"], "modes": {mode: {
                k: result.get(k) for k in ["status", "sourceReads", "residentBytes", "pdfSHA256", "pages", "matches", "textFidelity"]
            } for mode, result in reports.items()}, "actualPrint": False, "sandbox": False,
            "adHocSigned": True, "OSFontRegistration": False}
        (output / "receipt.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"status": "passed", "output": str(output), "modes": receipt["modes"]}, ensure_ascii=False, indent=2))
    finally:
        # 이 probe의 고유 앱만 해제한다. Quick Look/Thumbnail과 다른 앱 등록에는 손대지 않는다.
        try:
            run([lsregister, "-u", app], log=output / "unregister.log")
        except RuntimeError as error:
            # UI 실행 전 실패한 앱은 등록되지 않았다. 해당 상태만 정상 정리로 허용한다.
            if "-10814" not in str(error):
                raise

if __name__ == "__main__":
    main()
