#!/usr/bin/env python3
"""격리 Spotlight smoke. 단계별 실행 후 실패 여부와 관계없이 cleanup을 실행한다."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
LSREGISTER = "/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"
PLUGIN = "Contents/Library/Spotlight/Alhangeul.mdimporter"
EXTENSIONS = ["AlhangeulPreview.appex", "AlhangeulThumbnail.appex"]
IDS = ["com.postmelee.alhangeul.QLExtension", "com.postmelee.alhangeul.ThumbnailExtension"]
CONTROL = "SpotlightEnvironmentControlOnly"


def run(args, log=None, check=True, timeout=30):
    result = subprocess.run([str(a) for a in args], capture_output=True, text=True, timeout=timeout)
    if log:
        Path(log).write_text(result.stdout + result.stderr)
    if check and result.returncode:
        raise RuntimeError(f"command failed ({result.returncode}): {args[0]}; see {log}")
    return result.stdout + result.stderr


def record(state, label, result="PASS", **details):
    state["results"].append({"case": label, "result": result, **details})
    print(f"{result}: {label}", flush=True)


def save(path, state):
    path.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n")


def fingerprint(app):
    return {str(path.relative_to(app)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in [app / "Contents/Info.plist", app / "Contents/MacOS/Alhangeul"]}


def providers():
    result = {}
    for identifier in IDS:
        output = run(["pluginkit", "-m", "-A", "-D", "-vv", "-i", identifier])
        # UUID/timestamp는 다시 등록할 때 달라질 수 있다. 선택 표시와 실제 경로를 비교한다.
        entries = []
        status = ""
        for line in output.splitlines():
            if identifier + "(" in line:
                status = line.strip()
            if "Path = " in line:
                entries.append((status, line.split("Path = ", 1)[1]))
        result[identifier] = sorted(entries)
    return result


def query(state, token):
    if not re.fullmatch(r"[A-Za-z0-9]+", token):
        raise ValueError("query token must be alphanumeric")
    output = run(["mdfind", "-onlyin", state["files"], f'kMDItemTextContent == "*{token}*"cd'])
    return sorted(line for line in output.splitlines() if line.startswith(state["files"] + "/"))


def expect_paths(state, token, names, label, timeout=60):
    expected = sorted(str(Path(state["files"]) / name) for name in names)
    deadline = time.monotonic() + timeout
    while True:
        actual = query(state, token)
        if actual == expected:
            state["results"].append({"case": label, "query": token, "paths": actual, "result": "PASS"})
            print(f"PASS: {label} ({len(actual)} files)", flush=True)
            return
        if time.monotonic() >= deadline:
            state["results"].append({"case": label, "expected": expected, "actual": actual, "result": "FAIL"})
            raise RuntimeError(f"Spotlight query timeout: {label}")
        time.sleep(2)


def prepare(args):
    if args.state.exists():
        raise ValueError("state already exists; use cleanup or a new state path")
    if not args.app or not args.fixtures:
        raise ValueError("prepare requires --app and --fixtures")
    app = args.app.resolve()
    fixtures = args.fixtures.resolve()
    manifest = json.loads((fixtures / "manifest.json").read_text())
    if manifest["token"] != args.token or not manifest["replacement"].isalnum():
        raise ValueError("fixture manifest/token mismatch")
    if args.token in manifest["replacement"] or manifest["replacement"] in args.token:
        raise ValueError("original and replacement query tokens must not overlap")
    run([sys.executable, ROOT / "scripts/ci/check-spotlight-bundle.py", "--app", app])
    if not re.fullmatch(r"[A-Za-z0-9]+", args.token):
        raise ValueError("invalid token")
    key = uuid.uuid4().hex[:12]
    workspace = Path.home() / "Documents" / ("AlhangeulSpotlightSmoke-" + key)
    install_root = Path.home() / "Applications" / ("AlhangeulSpotlightSmoke-" + key)
    evidence = args.state.parent / ("evidence-" + key)
    evidence.mkdir(parents=True)
    state = {"id": key, "source_app": str(app), "fixtures": str(fixtures), "workspace": str(workspace),
             "files": str(workspace / "Files"), "install_root": str(install_root),
             "install_app": str(install_root / "Alhangeul.app"), "evidence": str(evidence),
             "token": args.token, "replacement": manifest["replacement"],
             "results": [], "phase": "preparing", "original_apps": {},
             "providers_before": providers()}
    for existing in [Path("/Applications/Alhangeul.app"), Path.home() / "Applications/Alhangeul.app"]:
        if existing.is_dir():
            state["original_apps"][str(existing)] = fingerprint(existing)
    save(args.state, state)
    index = run(["mdutil", "-s", "/"], evidence / "index-before.txt")
    if "Indexing enabled" not in index:
        raise RuntimeError("root indexing is not enabled; no system setting was changed")
    run(["mdimport", "-L"], evidence / "importers-before.txt")
    state["fixture_hashes"] = {str(p.relative_to(fixtures)): hashlib.sha256(p.read_bytes()).hexdigest()
                              for p in fixtures.rglob("*") if p.is_file()}
    workspace.mkdir()
    (workspace / ".spotlight-smoke-owner").write_text(key)
    shutil.copytree(fixtures / "initial", workspace / "Files")
    run(["mdimport", "-i", workspace / "Files"], evidence / "baseline-import.txt")
    # 0건만으로 색인 환경 정상이라고 결론 내리지 않는다. index 단계의 txt 양성 대조가 필수다.
    state["before_install_paths"] = query(state, args.token)
    state["phase"] = "prepared"
    save(args.state, state)
    print(json.dumps({"files": state["files"], "install_app": state["install_app"]}, ensure_ascii=False))


def owned_locations(state):
    for key, parent in [("install_root", Path.home() / "Applications"), ("workspace", Path.home() / "Documents")]:
        owned = Path(state[key])
        if owned.parent != parent or owned.name != "AlhangeulSpotlightSmoke-" + state["id"]:
            raise ValueError("path is outside the exact owned test location")
        if owned.is_symlink() or (owned.exists() and (owned / ".spotlight-smoke-owner").read_text() != state["id"]):
            raise ValueError("ownership marker mismatch or symlink")
    if Path(state["install_app"]) != Path(state["install_root"]) / "Alhangeul.app":
        raise ValueError("unexpected app path")
    if Path(state["install_app"]).is_symlink():
        raise ValueError("test app must not be a symlink")
    if Path(state["files"]) != Path(state["workspace"]) / "Files" or Path(state["files"]).is_symlink():
        raise ValueError("unexpected corpus path")


def discover(state, label, timeout=60):
    expected = str(Path(state["install_app"]) / PLUGIN)
    deadline = time.monotonic() + timeout
    while True:
        found = expected in run(["mdimport", "-L"], Path(state["evidence"]) / (label + ".txt"))
        if found or time.monotonic() >= deadline:
            record(state, label, "PASS" if found else "MISS", importer=expected)
            return found
        time.sleep(2)


def install(state):
    root = Path(state["install_root"])
    root.mkdir()
    (root / ".spotlight-smoke-owner").write_text(state["id"])
    run(["ditto", state["source_app"], state["install_app"]], timeout=60)
    run(["codesign", "--verify", "--deep", "--strict", state["install_app"]])
    run([LSREGISTER, "-f", state["install_app"]])
    state["phase"] = "installed"
    discover(state, "discovery-before-first-launch")


def launch(state):
    # NSArgumentDomain은 이 프로세스에만 적용된다. 사용자 defaults를 쓰지 않는다.
    run(["open", "-n", "-a", state["install_app"], "--args",
         "-alhangeul.analytics.enabled.v1", "NO", "-SUEnableAutomaticChecks", "NO"])
    record(state, "first-launch-requested")
    discover(state, "discovery-after-first-launch")


def stop_candidate(state):
    executable = str(Path(state["install_app"]) / "Contents/MacOS/Alhangeul")
    # 번들 ID/프로세스 이름만으로 다른 설치본까지 종료하지 않는다.
    def pids():
        found = []
        for line in run(["ps", "-axo", "pid=,command="]).splitlines():
            fields = line.strip().split(maxsplit=1)
            if len(fields) == 2 and (fields[1] == executable or fields[1].startswith(executable + " ")):
                found.append(int(fields[0]))
        return found
    for pid in pids():
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
    deadline = time.monotonic() + 10
    while pids():
        if time.monotonic() >= deadline:
            raise RuntimeError("candidate app is still running; no bundle was removed")
        time.sleep(0.2)
    record(state, "candidate-app-not-running")


def restore_corpus(state):
    fixtures, files = Path(state["fixtures"]) / "initial", Path(state["files"])
    for source in fixtures.iterdir():
        destination = files / source.name
        if destination.is_symlink():
            raise ValueError("corpus destination must not be a symlink")
        shutil.copyfile(source, destination)
    record(state, "restored-synthetic-corpus")


def developer_register(state):
    # Xcode 개발 등록과 같은 비교 시험이다. 일반 설치/공증 배포 성공으로 기록하지 않는다.
    os.utime(Path(state["install_app"]) / PLUGIN, None)
    os.utime(state["install_app"], None)
    run([LSREGISTER, "-f", "-R", "-trusted", state["install_app"]])
    if not discover(state, "development-registration"):
        raise RuntimeError("development importer is not discoverable")
    state["development_registration"] = True


def metadata_test(state, path, label):
    evidence = Path(state["evidence"])
    log = evidence / (label + "-mdimport.txt")
    output = evidence / (label + "-metadata.plist")
    # -o는 기존 파일에 append한다. 재실행 때 dictionary 두 개가 이어지지 않게 비운다.
    output.unlink(missing_ok=True)
    trace = run(["mdimport", "-t", "-d3", "-o", output, path], log)
    expected = str(Path(state["install_app"]) / PLUGIN)
    if expected not in trace:
        raise RuntimeError(f"actual importer path is not the isolated app: {label}; see {log}")
    if not output.exists():
        raise RuntimeError(f"mdimport did not produce metadata: {label}")
    # 현재 mdimport -o는 OpenStep plist를 쓴다. Python plistlib의 XML/binary parser로 읽지 않는다.
    return json.loads(run(["plutil", "-convert", "json", "-o", "-", output]))


def verify(state):
    files = Path(state["files"])
    evidence = Path(state["evidence"])
    token = state["token"]
    for name in ["document-a.hwp", "document-b.hwpx", "document-c.hwp"]:
        data = metadata_test(state, files / name, "initial-" + name)
        if token not in data.get("kMDItemTextContent", ""):
            raise RuntimeError(f"mdimport text missing: {name}")
        record(state, "metadata-" + name, content_type=data.get("kMDItemContentType"),
               utf8_bytes=len(data["kMDItemTextContent"].encode("utf-8")))
    state["phase"] = "extracted"


def index(state):
    files = Path(state["files"])
    evidence = Path(state["evidence"])
    run(["mdimport", "-i", files], evidence / "initial-index.txt")
    try:
        expect_paths(state, CONTROL, ["index-control.txt"], "environment-text-control")
    except RuntimeError:
        state["index_environment"] = "unavailable"
        run(["mdutil", "-s", files], evidence / "corpus-index-state.txt", check=False)
        raise RuntimeError("plain-text control is not searchable; system indexing environment unavailable")
    state["index_environment"] = "available"
    expect_paths(state, state["token"], ["document-a.hwp", "document-b.hwpx", "document-c.hwp"], "body-only-search")
    state["phase"] = "searchable"


def lifecycle(state, extraction_only=False):
    files, fixtures = Path(state["files"]), Path(state["fixtures"])
    token, replacement = state["token"], state["replacement"]
    def search(term, names, label):
        if extraction_only:
            record(state, label, "MISS", reason="explicit extraction-only run; actual index not tested")
        else:
            expect_paths(state, term, names, label)

    def replace(variant, destination, label, needle=None):
        # 원래 정상 본문을 먼저 복원해 stale-text 제거를 검증한다.
        shutil.copyfile(fixtures / "initial" / destination, files / destination)
        run(["mdimport", "-i", files / destination])
        if not extraction_only:
            expect_paths(state, token, [destination], label + "-restored")
        shutil.copyfile(fixtures / "variants" / variant, files / destination)
        data = metadata_test(state, files / destination, label)
        body = data.get("kMDItemTextContent")
        if needle is None and body not in [None, "<null>", ""]:
            raise RuntimeError(f"stale/protected body returned: {label}")
        if needle is not None and (not isinstance(body, str) or needle not in body or token in body):
            raise RuntimeError(f"changed body mismatch: {label}")
        record(state, label + "-metadata")
        run(["mdimport", "-i", files / destination])
        search(token, [], label + "-old-word-removed")
        if needle:
            search(needle, [destination], label + "-new-word")
        (files / destination).unlink()

    # 사례마다 문서 하나로 판정한다. 원래 합성 문서는 fixture에 보존한다.
    for name in ["document-a.hwp", "document-b.hwpx", "document-c.hwp", "control.hwpx"]:
        (files / name).unlink(missing_ok=True)
    search(token, [], "deleted-original-documents")
    replace("modified.hwp", "document-a.hwp", "modified", replacement)
    for variant in ["protected.hwpx", "empty.hwpx"]:
        replace(variant, "document-b.hwpx", variant.split(".")[0])
    for variant in ["invalid.hwp", "drm.hwp", "distribution.hwp", "large.hwp"]:
        replace(variant, "document-a.hwp", variant.split(".")[0])
    shutil.copyfile(fixtures / "variants/truncated.hwpx", files / "document-b.hwpx")
    data = metadata_test(state, files / "document-b.hwpx", "truncated")
    body = data.get("kMDItemTextContent", "")
    if not body or len(body.encode("utf-8")) > 1024 * 1024 or len(body) >= 400_000:
        raise RuntimeError("truncated UTF-8 output limit mismatch")
    record(state, "truncated-metadata", utf8_bytes=len(body.encode("utf-8")))
    (files / "document-b.hwpx").unlink()
    search(token, [], "deleted-final-documents")
    state["phase"] = "lifecycle-extraction-only" if extraction_only else "lifecycle-verified"


def replace_app(state):
    stop_candidate(state)
    app = Path(state["install_app"])
    for extension in EXTENSIONS:
        run(["pluginkit", "-r", app / "Contents/PlugIns" / extension], check=False)
    run([LSREGISTER, "-u", app], check=False)
    previous = (app / PLUGIN).stat().st_mtime_ns
    shutil.rmtree(app)
    run(["ditto", state["source_app"], app], timeout=60)
    os.utime(app / PLUGIN, None)
    os.utime(app, None)
    run(["codesign", "--verify", "--deep", "--strict", app])
    run([LSREGISTER, "-f", app])
    launch(state)
    record(state, "local-app-replacement", old_timestamp_ns=previous,
           new_timestamp_ns=(app / PLUGIN).stat().st_mtime_ns)
    # 소스 zip과 동일 버전의 로컬 교체다. 공개 Sparkle 업데이트가 아니다.
    state["phase"] = "replaced"


def cleanup(state):
    app = Path(state["install_app"])
    root = Path(state["install_root"])
    workspace = Path(state["workspace"])
    stop_candidate(state)
    if app.exists():
        for extension in EXTENSIONS:
            run(["pluginkit", "-r", app / "Contents/PlugIns" / extension], check=False)
        run([LSREGISTER, "-u", app], check=False)
        run(["qlmanage", "-r", "cache"], Path(state["evidence"]) / "quicklook-cache-cleanup.txt")
    if root.exists():
        shutil.rmtree(root)
    if workspace.exists():
        shutil.rmtree(workspace)
    for path, original in state["original_apps"].items():
        if fingerprint(Path(path)) != original:
            raise RuntimeError(f"original app changed: {path}")
    after = providers()
    before = json.loads(json.dumps(state["providers_before"]))
    if json.loads(json.dumps(after)) != before:
        raise RuntimeError("original extension provider set was not restored")
    if str(app / PLUGIN) in run(["mdimport", "-L"], Path(state["evidence"]) / "importers-cleanup.txt"):
        raise RuntimeError("test importer registration remains")
    if state.get("index_environment") == "available":
        expect_paths(state, state["token"], [], "cleanup-index")
    else:
        record(state, "cleanup-index", "MISS", reason="index environment unavailable")
    record(state, "cleanup-original-apps-providers")
    state["phase"] = "cleaned"
    print("PASS: owned files removed; original app hashes and provider selections preserved", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=["prepare", "install", "launch", "developer-register", "verify",
                                          "index", "lifecycle", "replace-app", "restore-corpus", "stop-app",
                                          "cleanup", "status"])
    parser.add_argument("--state", type=Path, required=True)
    parser.add_argument("--app", type=Path)
    parser.add_argument("--fixtures", type=Path)
    parser.add_argument("--token", default="AlhangeulSpotlightProbe")
    parser.add_argument("--extraction-only", action="store_true",
                        help="lifecycle의 실제 색인 검증을 MISS로 남기고 metadata만 검증")
    args = parser.parse_args()
    args.state = args.state.resolve()
    if args.phase == "prepare":
        prepare(args)
        return
    state = json.loads(args.state.read_text())
    try:
        if args.phase != "status":
            owned_locations(state)
        if state["phase"] == "cleaned" and args.phase not in ["cleanup", "status"]:
            raise ValueError("run was cleaned; prepare a new state")
        if args.phase == "status":
            print(json.dumps(state, ensure_ascii=False, indent=2))
        elif args.phase == "install":
            if state["phase"] != "prepared": raise ValueError("prepare required")
            install(state)
        elif args.phase == "verify":
            if state["phase"] in ["preparing", "prepared", "cleaned"]: raise ValueError("install required")
            verify(state)
        elif args.phase == "index":
            if state["phase"] != "extracted": raise ValueError("verify required")
            index(state)
        elif args.phase == "launch":
            launch(state)
        elif args.phase == "developer-register":
            developer_register(state)
        elif args.phase == "lifecycle":
            if not args.extraction_only and state["phase"] != "searchable": raise ValueError("index required")
            lifecycle(state, args.extraction_only)
        elif args.phase == "replace-app":
            replace_app(state)
        elif args.phase == "restore-corpus":
            restore_corpus(state)
        elif args.phase == "stop-app":
            stop_candidate(state)
        elif args.phase == "cleanup":
            cleanup(state)
    finally:
        save(args.state, state)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)
