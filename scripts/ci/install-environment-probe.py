#!/usr/bin/env python3
"""새 macOS VM의 설치 검증 전제를 측정한다. 시스템 설정을 변경하지 않는다."""
import argparse
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile
import time
import uuid


class Unavailable(RuntimeError):
    pass


def command(args, timeout=30):
    result = subprocess.run(args, text=True, capture_output=True, timeout=timeout)
    return {"argv": args, "returncode": result.returncode,
            "stdout": result.stdout, "stderr": result.stderr}


def probe(timeout=180):
    result = {"schema_version": 1, "status": "HARNESS_ERROR", "release_eligible": False,
              "os": platform.platform(), "architecture": platform.machine(),
              "image_os": os.environ.get("ImageOS"), "image_version": os.environ.get("ImageVersion"),
              "run_id": os.environ.get("GITHUB_RUN_ID"), "run_attempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
              "harness_sha": os.environ.get("GITHUB_SHA"), "commands": []}
    started = time.monotonic()
    root = None

    def read(args, seconds=30):
        entry = command(args, timeout=seconds)
        result["commands"].append(entry)
        if entry["returncode"]:
            raise Unavailable(f"명령 실패: {args[0]} ({entry['returncode']})")
        return entry["stdout"]

    try:
        if platform.system() != "Darwin":
            raise Unavailable("macOS 러너가 아님")
        catalog = read(["/usr/bin/mdimport", "-L"])
        lsregister = "/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"
        registrations = read([lsregister, "-dump"])
        if any(name in (catalog + registrations).lower() for name in
               ("alhangeul", "rhwp mac", "rhwp.app", "rhwp-mac.app")):
            raise Unavailable("기존 알한글/importer 등록이 있음")
        for path in [Path('/Applications/Alhangeul.app'), Path.home() / 'Applications/Alhangeul.app']:
            if path.exists():
                raise Unavailable("기존 알한글 설치본이 있음")
        read(["/bin/launchctl", "print", f"gui/{os.getuid()}"])
        result["gui_session_present"] = True
        documents = Path.home() / "Documents"
        documents.mkdir(exist_ok=True)
        root = Path(tempfile.mkdtemp(prefix="AlhangeulInstallProbe-", dir=documents))
        state = read(["/usr/bin/mdutil", "-s", str(root)])
        if "Indexing enabled" not in state:
            raise Unavailable("시험 문서 위치의 자동 색인이 활성 상태가 아님")
        token = "InstallEnvironment" + uuid.uuid4().hex
        control = root / "control.txt"
        control.write_text(token + '\n')
        until = time.monotonic() + timeout
        while time.monotonic() < until:
            hits = read(["/usr/bin/mdfind", "-onlyin", str(root),
                         f'kMDItemTextContent == "{token}"cd'], min(30, max(1, until-time.monotonic())))
            normalized = [p.removeprefix('/System/Volumes/Data') for p in hits.splitlines()]
            if str(control) in normalized:
                result["status"] = "ENVIRONMENT_READY"
                result["txt_automatic_search"] = True
                break
            time.sleep(min(2, max(0, until-time.monotonic())))
        else:
            read(["/usr/bin/mdls", str(control)])
            raise Unavailable(f"TXT 자동 검색이 {timeout}초 안에 확인되지 않음")
    except (Unavailable, subprocess.TimeoutExpired) as error:
        result.update(status="ENVIRONMENT_UNAVAILABLE", reason=str(error))
    except Exception as error:
        result.update(status="HARNESS_ERROR", reason=str(error))
    finally:
        if root is not None:
            try:
                shutil.rmtree(root)
                result["owned_files_removed"] = True
            except OSError as error:
                result.update(status="HARNESS_ERROR", cleanup_error=str(error))
        result["elapsed_seconds"] = round(time.monotonic()-started, 2)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--timeout', type=int, default=180, choices=range(1, 601), metavar='1..600')
    parser.add_argument('--assessment', action='store_true', help='측정 완료만 성공 처리. 설치 release_eligible는 항상 false')
    args = parser.parse_args()
    result = probe(args.timeout)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in result.items() if k != 'commands'}, ensure_ascii=False, indent=2))
    return 0 if result['status'] == 'ENVIRONMENT_READY' or (args.assessment and result['status'] == 'ENVIRONMENT_UNAVAILABLE') else 2


if __name__ == '__main__':
    raise SystemExit(main())
