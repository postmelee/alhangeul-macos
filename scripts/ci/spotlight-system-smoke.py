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
# Spotlight는 본문을 단어로 색인한다. 임의 연결어의 부분 문자열 검색을 가정하지 않는다.
KOREAN = "나비"
UPDATED_KOREAN = "바다"
TRUNCATED_KOREAN = "호랑이"
TRUNCATED = "TruncatedDocumentMarker"
OMITTED = "OmittedDocumentMarker"


def run(args, log=None, check=True, timeout=30):
    def output_text(stdout, stderr):
        # TimeoutExpired는 text=True에서도 캡처 결과를 bytes로 제공할 수 있다.
        def decode(value):
            return value.decode("utf-8", errors="replace") if isinstance(value, bytes) else (value or "")
        return decode(stdout) + decode(stderr)

    def failure(message, output):
        if log:
            Path(log).write_text(output)
        tail = "\n".join(output.splitlines()[-8:])[-2000:] or "(no output captured)"
        location = f"; log: {log}" if log else ""
        return RuntimeError(f"{message}{location}\n{tail}")

    try:
        result = subprocess.run([str(a) for a in args], capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired as error:
        raise failure(f"command timed out after {timeout}s: {args[0]}",
                      output_text(error.stdout, error.stderr)) from error
    output = output_text(result.stdout, result.stderr)
    if check and result.returncode:
        raise failure(f"command failed ({result.returncode}): {args[0]}", output)
    if log:
        Path(log).write_text(output)
    return output


def record(state, label, result="PASS", **details):
    state["results"].append({"case": label, "result": result, "observed_at": time.time(), **details})
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
    # 한글을 허용하되 Spotlight query의 따옴표/연산자는 허용하지 않는다.
    if not token or not token.isalnum():
        raise ValueError("query token must be Unicode alphanumeric")
    # Files 삭제 후에도 존재하는 Documents 범위에서 조회하고 소유 경로로 제한한다.
    scope = str(Path(state["files"]).parent.parent)
    output = run(["mdfind", "-onlyin", scope, f'kMDItemTextContent == "*{token}*"cd'])
    paths = set()
    for line in output.splitlines():
        if line.startswith("/System/Volumes/Data/Users/"):
            line = line.removeprefix("/System/Volumes/Data")
        if line.startswith(state["files"] + "/"):
            paths.add(line)
    return sorted(paths)


def expect_paths(state, token, names, label, timeout=60):
    expected = sorted(str(Path(state["files"]) / name) for name in names)
    deadline = time.monotonic() + timeout
    stable_since = None
    while True:
        actual = query(state, token)
        # 일시적인 빈 응답이나 색인 서비스 중단을 삭제 성공으로 오인하지 않는다.
        control_ok = bool(expected) or query(state, CONTROL) == [str(Path(state["files"]) / "index-control.txt")]
        now = time.monotonic()
        if actual == expected and control_ok:
            if stable_since is None:
                stable_since = now
        else:
            stable_since = None
        if stable_since is not None and (expected or now - stable_since >= 4):
            state["results"].append({"case": label, "query": token, "paths": actual, "result": "PASS"})
            print(f"PASS: {label} ({len(actual)} files)", flush=True)
            return
        if now >= deadline:
            state["results"].append({"case": label, "expected": expected, "actual": actual,
                                     "control_ok": control_ok, "result": "FAIL"})
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
    if args.install_layout == "direct":
        install_root = install_root.with_suffix(".app")
    evidence = args.state.parent / ("evidence-" + key)
    evidence.mkdir(parents=True)
    state = {"id": key, "source_app": str(app), "fixtures": str(fixtures), "workspace": str(workspace),
             "files": str(workspace / "Files"), "install_root": str(install_root),
             "install_app": str(install_root / "Alhangeul.app"), "evidence": str(evidence),
             "token": args.token, "replacement": manifest["replacement"],
             "results": [], "phase": "preparing", "original_apps": {},
             "providers_before": providers()}
    state["automatic"] = args.automatic
    state["source_bundle_dates_ns"] = {"app": app.stat().st_mtime_ns,
                                        "importer": (app / PLUGIN).stat().st_mtime_ns}
    state["source_app_hashes"] = fingerprint(app)
    state["source_importer_hashes"] = fingerprint(app / PLUGIN)
    state["install_layout"] = args.install_layout
    if args.install_layout == "direct":
        state["install_app"] = str(install_root)
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
    state["prepared_corpus"] = corpus_snapshot(state)
    if not state["automatic"]:
        run(["mdimport", "-i", workspace / "Files"], evidence / "baseline-import.txt")
    # 0건만으로 색인 환경 정상이라고 결론 내리지 않는다. index 단계의 txt 양성 대조가 필수다.
    state["before_install_paths"] = query(state, args.token)
    state["phase"] = "prepared"
    save(args.state, state)
    print(json.dumps({"files": state["files"], "install_app": state["install_app"]}, ensure_ascii=False))


def owned_locations(state):
    for key, parent in [("install_root", Path.home() / "Applications"), ("workspace", Path.home() / "Documents")]:
        owned = Path(state[key])
        direct = key == "install_root" and state.get("install_layout") == "direct"
        name = "AlhangeulSpotlightSmoke-" + state["id"] + (".app" if direct else "")
        if owned.parent != parent or owned.name != name:
            raise ValueError("path is outside the exact owned test location")
        if owned.is_symlink():
            raise ValueError("ownership marker mismatch or symlink")
        if owned.exists():
            if direct:
                identity = [owned.stat().st_dev, owned.stat().st_ino]
                if state.get("install_identity") != identity:
                    raise ValueError("direct app identity mismatch")
            elif (owned / ".spotlight-smoke-owner").read_text() != state["id"]:
                raise ValueError("ownership marker mismatch or symlink")
    expected_app = Path(state["install_root"])
    if state.get("install_layout") != "direct":
        expected_app /= "Alhangeul.app"
    if Path(state["install_app"]) != expected_app:
        raise ValueError("unexpected app path")
    if Path(state["install_app"]).is_symlink():
        raise ValueError("test app must not be a symlink")
    if Path(state["files"]) != Path(state["workspace"]) / "Files" or Path(state["files"]).is_symlink():
        raise ValueError("unexpected corpus path")


def discover(state, label, timeout=60):
    expected = str(Path(state["install_app"]) / PLUGIN)
    started = time.monotonic()
    deadline = started + timeout
    while True:
        found = expected in run(["mdimport", "-L"], Path(state["evidence"]) / (label + ".txt"))
        if found or time.monotonic() >= deadline:
            record(state, label, "PASS" if found else "MISS", importer=expected,
                   elapsed_seconds=round(time.monotonic() - started, 2))
            return found
        time.sleep(2)


def install(state):
    if state.get("automatic") and not state.get("pre_install_environment_verified"):
        raise ValueError("automatic install requires environment before installation")
    root = Path(state["install_root"])
    if state.get("install_layout") == "direct":
        if root.exists():
            raise ValueError("direct installation destination already exists")
    else:
        root.mkdir()
        (root / ".spotlight-smoke-owner").write_text(state["id"])
    copy_candidate(state)
    run(["codesign", "--verify", "--deep", "--strict", state["install_app"]])
    app = Path(state["install_app"])
    state["installed_bundle_dates_ns"] = {"app": app.stat().st_mtime_ns,
                                           "importer": (app / PLUGIN).stat().st_mtime_ns}
    for key, bundle in [("source_app_hashes", app), ("source_importer_hashes", app / PLUGIN)]:
        if key in state and fingerprint(bundle) != state[key]:
            raise RuntimeError("installed app/importer differs from prepared source")
    if (state.get("automatic") and "source_bundle_dates_ns" in state
            and state["installed_bundle_dates_ns"] != state["source_bundle_dates_ns"]):
        raise RuntimeError("automatic installation changed source bundle dates")
    if not state.get("automatic"):
        run([LSREGISTER, "-f", state["install_app"]])
    state["phase"] = "installed"
    state["installed_at"] = time.time()
    discover(state, "discovery-before-first-launch", timeout=0 if state.get("automatic") else 60)


def copy_candidate(state):
    # ditto는 기존 destination 디렉터리의 mtime을 보존한다. direct 앱을 미리
    # mkdir하면 복사 자체가 timestamp 비교를 오염시키므로 새 경로로 복사한다.
    app = Path(state["install_app"])
    try:
        run(["ditto", state["source_app"], app], timeout=60)
    finally:
        # 부분 복사 실패에서도 소유한 새 앱만 cleanup할 수 있게 식별값을 보존한다.
        if state.get("install_layout") == "direct" and app.is_dir() and not app.is_symlink():
            state["install_identity"] = [app.stat().st_dev, app.stat().st_ino]


def launch(state):
    # NSArgumentDomain은 이 프로세스에만 적용된다. 사용자 defaults를 쓰지 않는다.
    run(["open", "-n", "-a", state["install_app"], "--args",
         "-alhangeul.analytics.enabled.v1", "NO", "-SUEnableAutomaticChecks", "NO"])
    state["launch_count"] = state.get("launch_count", 0) + 1
    first = state["launch_count"] == 1
    record(state, "first-launch-requested" if first else "candidate-relaunch-requested",
           launch_number=state["launch_count"])
    discover(state, "discovery-after-first-launch" if first else "discovery-after-relaunch")


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


def unregister_app(app):
    for extension in EXTENSIONS:
        run(["pluginkit", "-r", app / "Contents/PlugIns" / extension], check=False)
    # 재귀 개발 등록은 Sparkle의 Updater.app도 등록한다. 소유 bundle 내부만 정리한다.
    for nested in sorted(app.rglob("*.app"), reverse=True):
        run([LSREGISTER, "-u", nested], check=False)
    run([LSREGISTER, "-u", app], check=False)


def developer_register(state):
    # Xcode 개발 등록과 같은 비교 시험이다. 일반 설치/공증 배포 성공으로 기록하지 않는다.
    os.utime(Path(state["install_app"]) / PLUGIN, None)
    os.utime(state["install_app"], None)
    run([LSREGISTER, "-f", "-R", "-trusted", state["install_app"]])
    if not discover(state, "development-registration"):
        raise RuntimeError("development importer is not discoverable")
    state["development_registration"] = True


def diagnostic_register(state):
    """변경 시각·재복사 없이 사전 일반 등록 한 조건만 비교한다."""
    if state.get("phase") != "installed" or state.get("launch_count", 0):
        raise ValueError("diagnostic registration requires an installed, never-launched candidate")
    state.setdefault("assisted_actions", []).append("diagnostic-register")
    run([LSREGISTER, "-f", state["install_app"]])
    record(state, "diagnostic-register-only")


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
    token = state["token"]
    for name in ["document-a.hwp", "document-b.hwpx", "document-c.hwp"]:
        data = metadata_test(state, files / name, "initial-" + name)
        if token not in data.get("kMDItemTextContent", ""):
            raise RuntimeError(f"mdimport text missing: {name}")
        record(state, "metadata-" + name, content_type=data.get("kMDItemContentType"),
               utf8_bytes=len(data["kMDItemTextContent"].encode("utf-8")))
    state["phase"] = "extracted"


def environment(state):
    files = Path(state["files"])
    evidence = Path(state["evidence"])
    if not state.get("automatic"):
        run(["mdimport", "-i", files / "index-control.txt"], evidence / "control-index.txt")
    try:
        expect_paths(state, CONTROL, ["index-control.txt"], "environment-text-control")
    except RuntimeError:
        state["index_environment"] = "unavailable"
        run(["mdutil", "-s", files], evidence / "corpus-index-state.txt", check=False)
        run(["mdutil", "-as"], evidence / "volumes-index-state.txt", check=False)
        run(["mdls", files / "index-control.txt"], evidence / "control-index-metadata.txt", check=False)
        raise RuntimeError("plain-text control is not searchable; system indexing environment unavailable")
    state["index_environment"] = "available"
    if state.get("automatic") and state.get("phase") == "prepared":
        expect_paths(state, state["token"], [], "pre-install-body-absent")
        state["before_install_paths"] = query(state, state["token"])
        state["pre_install_environment_verified"] = True


def index(state):
    environment(state)
    if not state.get("automatic"):
        run(["mdimport", "-i", state["files"]], Path(state["evidence"]) / "initial-index.txt")
    expect_paths(state, state["token"], ["document-a.hwp", "document-b.hwpx", "document-c.hwp"], "body-only-search")
    expect_paths(state, KOREAN, ["document-a.hwp", "document-b.hwpx"], "korean-body-only-search")
    state["phase"] = "searchable"


def automatic_search(state):
    """수동 재색인·등록 없는 최초 설치 판정. metadata 진단보다 실제 검색을 먼저 본다."""
    if not state.get("automatic") or state.get("assisted_actions"):
        raise ValueError("automatic search requires an unassisted automatic run")
    if state.get("launch_count") != 1 or state.get("before_install_paths"):
        raise ValueError("automatic search requires one launch and no pre-install body matches")
    if not state.get("prepared_corpus") or corpus_snapshot(state) != state["prepared_corpus"]:
        raise ValueError("automatic search requires unchanged pre-install corpus")
    if not discover(state, "automatic-discovery"):
        raise RuntimeError("automatic importer discovery failed")
    index(state)
    verify(state)
    record(state, "automatic-first-install-search")
    state["phase"] = "searchable"


def corpus_snapshot(state):
    """본문/수정 시각이 바뀐 문서를 설치 전부터 있던 문서로 오인하지 않는다."""
    return {path.name: [path.stat().st_size, path.stat().st_mtime_ns,
                        hashlib.sha256(path.read_bytes()).hexdigest()]
            for path in Path(state["files"]).iterdir() if path.is_file()}


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
            search(UPDATED_KOREAN, [destination], label + "-new-korean-word")
        (files / destination).unlink()
        if needle:
            search(needle, [], label + "-deleted-new-word")
            search(UPDATED_KOREAN, [], label + "-deleted-new-korean-word")

    # 사례마다 문서 하나로 판정한다. 원래 합성 문서는 fixture에 보존한다.
    for name in ["document-a.hwp", "document-b.hwpx", "document-c.hwp", "control.hwpx"]:
        (files / name).unlink(missing_ok=True)
    search(token, [], "deleted-original-documents")
    search(KOREAN, [], "deleted-original-korean-word")
    replace("modified.hwp", "document-a.hwp", "modified", replacement)
    for variant in ["protected.hwpx", "empty.hwpx"]:
        replace(variant, "document-b.hwpx", variant.split(".")[0])
    for variant in ["invalid.hwp", "drm.hwp", "distribution.hwp", "large.hwp"]:
        replace(variant, "document-a.hwp", variant.split(".")[0])
    shutil.copyfile(fixtures / "variants/truncated.hwpx", files / "document-b.hwpx")
    data = metadata_test(state, files / "document-b.hwpx", "truncated")
    body = data.get("kMDItemTextContent", "")
    if (not body or len(body.encode("utf-8")) > 1024 * 1024 or len(body) >= 400_000
            or TRUNCATED not in body or OMITTED in body):
        raise RuntimeError("truncated UTF-8 output limit mismatch")
    record(state, "truncated-metadata", utf8_bytes=len(body.encode("utf-8")))
    run(["mdimport", "-i", files / "document-b.hwpx"])
    search(TRUNCATED, ["document-b.hwpx"], "truncated-prefix-search")
    search(TRUNCATED_KOREAN, ["document-b.hwpx"], "truncated-korean-prefix-search")
    search(OMITTED, [], "truncated-tail-not-indexed")
    (files / "document-b.hwpx").unlink()
    search(TRUNCATED, [], "deleted-truncated-document")
    search(token, [], "deleted-final-documents")
    state["phase"] = "lifecycle-extraction-only" if extraction_only else "lifecycle-verified"


def replace_app(state):
    stop_candidate(state)
    app = Path(state["install_app"])
    unregister_app(app)
    previous = (app / PLUGIN).stat().st_mtime_ns
    shutil.rmtree(app)
    copy_candidate(state)
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
        unregister_app(app)
        run(["qlmanage", "-r", "cache"], Path(state["evidence"]) / "quicklook-cache-cleanup.txt")
    if root.exists():
        shutil.rmtree(root)
    state["phase"] = "cleanup-pending-index"
    if workspace.exists() and state.get("index_environment") == "available":
        # 대조 txt는 검색 제거 판정이 끝날 때까지 남긴다. 실패해도 소유 파일은 정리한다.
        try:
            for path in Path(state["files"]).iterdir():
                if path.name != "index-control.txt":
                    path.unlink()
            for token in [state["token"], state["replacement"], KOREAN, UPDATED_KOREAN, TRUNCATED, TRUNCATED_KOREAN, OMITTED]:
                expect_paths(state, token, [], "cleanup-index-" + token)
            state["cleanup_index_verified"] = True
        except RuntimeError as error:
            record(state, "cleanup-index", "FAIL", reason=str(error))
        finally:
            shutil.rmtree(workspace)
    elif workspace.exists():
        shutil.rmtree(workspace)
    for path, original in state["original_apps"].items():
        if fingerprint(Path(path)) != original:
            raise RuntimeError(f"original app changed: {path}")
    after = providers()
    before = json.loads(json.dumps(state["providers_before"]))
    if json.loads(json.dumps(after)) != before:
        raise RuntimeError("original extension provider set was not restored")
    record(state, "cleanup-original-apps-providers")
    state["phase"] = "cleanup-pending-index"
    if state.get("index_environment") != "available":
        record(state, "cleanup-index", "MISS", reason="index environment unavailable")
    deadline = time.monotonic() + 60
    while str(app / PLUGIN) in run(["mdimport", "-L"], Path(state["evidence"]) / "importers-cleanup.txt"):
        if time.monotonic() >= deadline:
            record(state, "cleanup-importer-catalog", "MISS", reason="deleted test bundle path still listed")
            raise RuntimeError("owned files removed and original apps/providers preserved, but importer catalog is stale")
        time.sleep(2)
    record(state, "cleanup-importer-catalog")
    if state.get("index_environment") == "available" and not state.get("cleanup_index_verified"):
        raise RuntimeError("owned files removed but index cleanup was not verified; a new smoke run is required")
    state["phase"] = "cleaned"
    print("PASS: owned files removed; original app hashes and provider selections preserved", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=["prepare", "install", "launch", "developer-register", "diagnostic-register", "verify",
                                          "environment", "index", "automatic-search", "lifecycle", "replace-app", "restore-corpus", "stop-app",
                                          "cleanup", "status"])
    parser.add_argument("--state", type=Path, required=True)
    parser.add_argument("--app", type=Path)
    parser.add_argument("--fixtures", type=Path)
    parser.add_argument("--token", default="AlhangeulSpotlightProbe")
    parser.add_argument("--automatic", action="store_true",
                        help="prepare에서 저장: 수동 lsregister/mdimport -i 없이 복사·첫 실행·자동 검색 비교")
    parser.add_argument("--install-layout", choices=["nested", "direct"], default="nested",
                        help="prepare에서 저장: 중첩 폴더 또는 Applications 바로 아래 고유 소유 앱 비교")
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
        if state["phase"] in ["cleaned", "cleanup-pending-index"] and args.phase not in ["cleanup", "status"]:
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
        elif args.phase == "environment":
            environment(state)
        elif args.phase == "automatic-search":
            automatic_search(state)
        elif args.phase == "launch":
            launch(state)
        elif args.phase == "developer-register":
            state.setdefault("assisted_actions", []).append(args.phase)
            developer_register(state)
        elif args.phase == "diagnostic-register":
            diagnostic_register(state)
        elif args.phase == "lifecycle":
            if not args.extraction_only and state["phase"] != "searchable": raise ValueError("index required")
            state.setdefault("assisted_actions", []).append(args.phase)
            lifecycle(state, args.extraction_only)
        elif args.phase == "replace-app":
            state.setdefault("assisted_actions", []).append(args.phase)
            replace_app(state)
        elif args.phase == "restore-corpus":
            state.setdefault("assisted_actions", []).append(args.phase)
            restore_corpus(state)
        elif args.phase == "stop-app":
            stop_candidate(state)
        elif args.phase == "cleanup":
            cleanup(state)
    except Exception as error:
        record(state, args.phase + "-failed", "FAIL", reason=str(error))
        raise
    finally:
        save(args.state, state)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)
