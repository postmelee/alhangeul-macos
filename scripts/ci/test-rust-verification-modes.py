#!/usr/bin/env python3
"""격리된 fake toolchain으로 build CLI의 검증 경계를 검사한다. 실제 빌드 검증은 별도다."""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
HEADER = b"void rhwp_open(void);\n// width_pt height_pt\n"
ARCHIVE = b"reference archive\n"
COMMIT = "a" * 40
MOCK = r'''#!/usr/bin/env python3
import os, pathlib, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
if name == 'rustup':
    print('aarch64-apple-darwin\nx86_64-apple-darwin')
elif name == 'cbindgen':
    pathlib.Path(args[args.index('--output') + 1]).write_bytes(pathlib.Path(os.environ['FIXTURE_HEADER']).read_bytes())
elif name == 'xcrun' and '-output' in args:
    pathlib.Path(args[args.index('-output') + 1]).write_text(os.environ.get('FIXTURE_ARCHIVE', 'reference archive\n'))
elif name == 'xcodebuild':
    pathlib.Path(args[args.index('-output') + 1]).mkdir(parents=True)
elif name == 'stat':
    print(pathlib.Path(args[-1]).stat().st_size)
'''


def run_case(name, flags, expected, needle, *, archive=None, legacy=None, mutation=None):
    with tempfile.TemporaryDirectory(prefix="rhwp-verify-test-") as tmp:
        root = Path(tmp)
        for directory in ("scripts", "RustBridge", "bin"):
            (root / directory).mkdir()
        shutil.copy2(ROOT / "scripts/build-rust-macos.sh", root / "scripts/build-rust-macos.sh")
        (root / "RustBridge/Cargo.toml").write_text('[dependencies]\nrhwp = { git = "https://github.com/edwardkim/rhwp.git", tag = "v1.2.3", features = ["native-skia"] }\n')
        (root / "RustBridge/Cargo.lock").write_text(f'[[package]]\nname = "rhwp"\nsource = "git+https://github.com/edwardkim/rhwp.git?tag=v1.2.3#{COMMIT}"\n')
        (root / "rhwp-ffi-symbols.txt").write_text("rhwp_open\n")
        (root / "header").write_bytes(HEADER)
        lock = f'lock_version = 2\nrhwp_repo = "https://github.com/edwardkim/rhwp.git"\nrhwp_ref_kind = "release-tag"\nrhwp_release_tag = "v1.2.3"\nrhwp_commit = "{COMMIT}"\nrhwp_enabled_features = "native-skia"\n'
        for path, data in (("Frameworks/universal/librhwp.a", ARCHIVE), ("Frameworks/generated_rhwp.h", HEADER)):
            lock += f'\n[[artifacts]]\npath = "{path}"\nsha256 = "{hashlib.sha256(data).hexdigest()}"\nsize = {len(data)}\n'
        (root / "rhwp-core.lock").write_text(lock)
        for tool in ("cargo", "rustup", "cbindgen", "xcrun", "xcodebuild", "stat"):
            mock = root / "bin" / tool
            mock.write_text(MOCK)
            mock.chmod(0o755)
        if mutation:
            mutation(root)
        before = (root / "rhwp-core.lock").read_bytes()
        env = dict(os.environ, PATH=f"{root / 'bin'}:{os.environ['PATH']}", FIXTURE_HEADER=str(root / "header"))
        env.pop("ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY", None)
        if archive is not None:
            env["FIXTURE_ARCHIVE"] = archive
        if legacy is not None:
            env["ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY"] = legacy
        result = subprocess.run(["bash", str(root / "scripts/build-rust-macos.sh"), *flags], env=env, capture_output=True, text=True)
        output = result.stdout + result.stderr
        assert (result.returncode == 0) == expected, f"{name}: unexpected exit {result.returncode}\n{output}"
        assert needle in output, f"{name}: missing {needle!r}\n{output}"
        assert before == (root / "rhwp-core.lock").read_bytes(), f"{name}: verification rewrote lock"
        print(f"PASS: {name}")


def replace(path, old, new):
    return lambda root: (root / path).write_text((root / path).read_text().replace(old, new))


run_case("portable matching", ["--verify-portable"], True, "Verified (portable)")
run_case("portable archive drift", ["--verify-portable"], True, "comparison excluded", archive="different bytes")
run_case("strict matching", ["--verify-strict"], True, "Verified (strict)")
run_case("strict archive drift", ["--verify-strict"], False, "strict staticlib reference mismatch", archive="different bytes")
run_case("legacy remains strict", ["--verify-lock"], False, "strict staticlib reference mismatch", archive="different bytes")
run_case("legacy skip compatibility", ["--verify-lock"], True, "Verified (portable)", archive="different bytes", legacy="1")
run_case("strict cannot be weakened", ["--verify-strict"], False, "conflicts with legacy", legacy="1")
run_case("invalid env", ["--verify-portable"], False, "must be 0 or 1", legacy="true")
run_case("mutually exclusive modes", ["--verify-strict", "--verify-portable"], False, "exactly one")
run_case("update cannot accompany verify", ["--update-lock", "--verify-portable"], False, "exactly one")
run_case("unknown flag", ["--verify-typo"], False, "unknown option")
run_case("portable enforces commit", ["--verify-portable"], False, "core commit differs", mutation=replace("RustBridge/Cargo.lock", COMMIT, "b" * 40))
run_case("portable enforces features", ["--verify-portable"], False, "enabled features differ", mutation=replace("RustBridge/Cargo.toml", "native-skia", "other"))
run_case("portable enforces header", ["--verify-portable"], False, "generated header ABI artifact mismatch", mutation=replace("header", "void", "int"))
run_case("header failure precedes archive drift", ["--verify-strict"], False, "generated header ABI artifact mismatch", archive="different bytes", mutation=replace("header", "void", "int"))
run_case("portable enforces FFI symbols", ["--verify-portable"], False, "generated FFI symbol set differs", mutation=replace("header", "rhwp_open", "rhwp_changed"))
run_case("portable requires archive metadata", ["--verify-portable"], False, "missing or invalid lock metadata", mutation=replace("rhwp-core.lock", hashlib.sha256(ARCHIVE).hexdigest(), "bad"))
run_case("build only remains available", [], True, "Done:", archive="different bytes")
print("Rust verification mode fixtures passed (18 cases).")
