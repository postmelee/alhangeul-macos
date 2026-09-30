#!/usr/bin/env python3
"""checkout의 native/Studio provenance에서 README 포함 버전 배지를 갱신한다."""

import argparse
import html
import json
from pathlib import Path
import re
import sys
import tomllib
from urllib.parse import quote

START = "  <!-- bundled-rhwp-badges:start -->"
END = "  <!-- bundled-rhwp-badges:end -->"


def provenance(repo, kind, tag, commit):
    if not isinstance(repo, str) or not re.fullmatch(r"https://github\.com/[\w.-]+/[\w.-]+(?:\.git)?", repo):
        raise ValueError("GitHub source repository가 필요합니다")
    if not isinstance(commit, str) or not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("resolved commit 40자 SHA가 필요합니다")
    if kind == "release-tag":
        if not isinstance(tag, str) or not re.fullmatch(r"v\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?", tag):
            raise ValueError("release-tag pin에 유효한 release tag가 필요합니다")
        ref = tag
    elif kind == "commit":
        ref = commit[:12]
    else:
        raise ValueError(f"지원하지 않는 ref kind: {kind}")
    return repo.removesuffix(".git"), kind, ref, commit


def badge(label, source):
    repo, kind, ref, commit = source
    url = f"{repo}/releases/tag/{quote(ref, safe='')}" if kind == "release-tag" else f"{repo}/commit/{commit}"
    # Shields 정적 배지에서 '-'는 '--'로 이스케이프한다.
    encoded = [quote(part.replace("-", "--"), safe="") for part in (label, ref)]
    image = f"https://img.shields.io/badge/{encoded[0]}-{encoded[1]}-blue"
    alt = html.escape(f"{label}: {ref}", quote=True)
    return f'  <a href="{html.escape(url, quote=True)}" title="포함된 rhwp commit: {commit}"><img src="{image}" alt="{alt}" /></a>'


def expected_readme(root):
    core = tomllib.loads((root / "rhwp-core.lock").read_text())
    studio = json.loads((root / "Sources/HostApp/Resources/rhwp-studio/manifest.json").read_text())
    native = provenance(core["rhwp_repo"], core["rhwp_ref_kind"], core.get("rhwp_release_tag"), core["rhwp_commit"])
    viewer = provenance(studio["source_repository"], studio["source_ref_kind"], studio.get("source_release_tag"), studio["source_resolved_commit"])
    lines = [badge("bundled rhwp", native)] if native == viewer else [
        badge("bundled rhwp native", native), badge("bundled rhwp Studio", viewer)]
    readme = (root / "README.md").read_text()
    if readme.count(START) != 1 or readme.count(END) != 1 or readme.index(START) > readme.index(END):
        raise ValueError("README 배지 영역이 없거나 중복/역순입니다")
    before, after_start = readme.split(START)
    _, after = after_start.split(END)
    return readme, before + START + "\n" + "\n".join(lines) + "\n" + END + after


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--check", action="store_true", help="파일 수정 없이 오래된 표시·링크 검사")
    args = parser.parse_args()
    try:
        current, expected = expected_readme(args.root)
        if args.check and current != expected:
            raise ValueError("README 포함 rhwp 배지가 provenance와 다릅니다. helper를 실행하세요")
        if not args.check and current != expected:
            (args.root / "README.md").write_text(expected)
        print("README 포함 rhwp 배지: OK")
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
