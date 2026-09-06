#!/usr/bin/env python3
"""실제 pinned producer와 Swift consumer의 golden 계약. Python 3.11 이상."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from urllib.parse import parse_qs, urlsplit

try:
    import tomllib
except ImportError:
    sys.exit("ERROR: render tree golden requires Python 3.11 or later")

ROOT = Path(__file__).resolve().parents[2]
SAMPLE = Path("samples/basic/request.hwp")
GOLDEN = Path("scripts/ci/fixtures/render-tree/request-page0.json")
PAGE = 0


class ContractError(Exception):
    pass


def canonical(value):
    # Python integers retain all usize bits; no field, array or numeric rounding normalization.
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2, allow_nan=False) + "\n").encode()


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read_json(data):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ContractError("duplicate JSON key")
            result[key] = value
        return result
    return json.loads(data, object_pairs_hook=unique)


def provenance(root):
    with (root / "rhwp-core.lock").open("rb") as stream:
        lock = tomllib.load(stream)
    with (root / "RustBridge/Cargo.lock").open("rb") as stream:
        cargo = tomllib.load(stream)
    with (root / "RustBridge/Cargo.toml").open("rb") as stream:
        dependency = tomllib.load(stream)["dependencies"]["rhwp"]
    if lock.get("lock_version") != 2 or lock.get("rhwp_ref_kind") not in ("release-tag", "commit"):
        raise ContractError("golden requires a v2 release-tag or resolved commit lock")
    commit = lock["rhwp_commit"]
    if not re.fullmatch("[0-9a-f]{40}", commit):
        raise ContractError("invalid resolved core commit")
    packages = [p for p in cargo["package"] if p["name"] == "rhwp"]
    if len(packages) != 1:
        raise ContractError("Cargo.lock must contain exactly one rhwp package")
    source = packages[0].get("source", "")
    url = urlsplit(source.removeprefix("git+"))
    repo = source.removeprefix("git+").split("?", 1)[0].split("#", 1)[0]
    query = parse_qs(url.query)
    expected_repo = lock["rhwp_repo"].rstrip("/")
    if repo.rstrip("/") != expected_repo or dependency.get("git", "").rstrip("/") != expected_repo or url.fragment != commit:
        raise ContractError("core source/Cargo provenance mismatch")
    kind = lock["rhwp_ref_kind"]
    if kind == "release-tag":
        tag = lock["rhwp_release_tag"]
        if not tag or query.get("tag") != [tag] or dependency.get("tag") != tag:
            raise ContractError("core release tag/Cargo mismatch")
    else:
        tag = None
        revision = dependency.get("rev")
        if not revision or query.get("rev") != [revision]:
            raise ContractError("core revision/Cargo mismatch")
    features = dependency.get("features", [])
    if ",".join(features) != lock["rhwp_enabled_features"]:
        raise ContractError("core enabled features/Cargo mismatch")
    return {
        "recipe_version": 1,
        "core": {"repo": expected_repo, "ref_kind": kind, "release_tag": tag,
                 "commit": commit, "enabled_features": features},
        "sample": {"path": SAMPLE.as_posix(), "sha256": digest((root / SAMPLE).read_bytes()), "page": PAGE},
    }


def produce(root):
    version = subprocess.check_output(["rustc", "-vV"], text=True)
    host = next(line.removeprefix("host: ") for line in version.splitlines() if line.startswith("host: "))
    if host not in ("aarch64-apple-darwin", "x86_64-apple-darwin"):
        raise ContractError("native golden producer supports macOS arm64/x86_64 only")
    output = subprocess.check_output([
        "cargo", "run", "--release", "--locked", "--manifest-path", str(root / "RustBridge/Cargo.toml"),
        "--target", host, "--example", "render_tree_golden", "--", str(root / SAMPLE), str(PAGE),
    ], cwd=root)
    return read_json(output)


def consume(root, trees):
    # Intentionally compile the Foundation-only model in isolation; update this input list if its types move.
    build_root = root / "build.noindex"
    build_root.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="render-tree-contract-", dir=build_root) as directory:
        work = Path(directory)
        binary = work / "decode"
        subprocess.run(["swiftc", "-parse-as-library", "-module-cache-path", str(work / "module-cache"),
                        str(root / "Sources/RhwpCoreBridge/RenderTree.swift"),
                        str(root / "scripts/ci/render_tree_golden_check.swift"), "-o", str(binary)], check=True)
        files = []
        for index, tree in enumerate(trees):
            path = work / f"tree-{index}.json"
            path.write_bytes(canonical(tree))
            files.append(str(path))
        subprocess.run([str(binary), *files], check=True)


def run_contract(mode, root, golden, *, producer=produce, consumer=consume):
    metadata = provenance(root)
    tracked = None
    if mode == "verify":
        if not golden.is_file():
            raise ContractError("missing golden; run the explicit writer after a reviewed core update")
        tracked = read_json(golden.read_bytes())
        tracked_metadata = dict(tracked["metadata"])
        recorded_hash = tracked_metadata.pop("tree_sha256")
        if tracked_metadata != metadata:
            raise ContractError("stale golden provenance/sample/recipe; verifier does not update files")
        # This hash diagnoses edited tree data before rebuilding the producer; final file bytes remain authoritative.
        if recorded_hash != digest(canonical(tracked["tree"])):
            # Decode corrupted known payloads before reporting hash drift, preserving useful diagnostics.
            consumer(root, [tracked["tree"]])
            raise ContractError("stale golden tree hash; verifier does not update files")
    current = producer(root)
    consumer(root, [current] if tracked is None else [tracked["tree"], current])
    metadata["tree_sha256"] = digest(canonical(current))
    expected = canonical({"metadata": metadata, "tree": current})
    if mode == "verify":
        if golden.read_bytes() != expected:
            raise ContractError("stale golden producer output; verifier does not update files")
        print("OK: pinned producer, golden provenance and Swift decoder contract match")
        return
    if mode != "update":
        raise ContractError("unknown golden mode")
    # One atomic file holds both metadata and tree; failed build/decode leaves the old golden intact.
    golden.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=golden.parent, prefix=".golden-", delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(expected)
        temporary.chmod(0o644)
        os.replace(temporary, golden)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    print("OK: wrote producer-backed render tree golden")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("update", "verify"))
    parser.add_argument("--golden", type=Path, default=ROOT / GOLDEN, help="explicit golden destination/input")
    args = parser.parse_args()
    try:
        run_contract(args.mode, ROOT, args.golden)
    except (ContractError, OSError, ValueError, KeyError, TypeError, StopIteration, subprocess.CalledProcessError) as error:
        print(f"ERROR: render tree golden: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
