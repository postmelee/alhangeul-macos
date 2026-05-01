# Copilot Code Review Instructions

Write pull request review comments in Korean. Prioritize correctness, runtime regressions, FFI and memory safety, architecture boundary violations, build and release reproducibility, and missing verification. Do not leave praise, broad summaries, or style-only comments unless they expose a concrete maintenance or correctness risk. Every review comment should be actionable and tied to changed lines.

Repository context:
- This repository builds a macOS HWP/HWPX preview and viewer app. It owns HostApp viewer, Quick Look preview extension, Finder Thumbnail extension, Swift bridge code, RustBridge C ABI, packaging policy, and related documentation.
- `project.yml` is the source of truth for Xcode configuration. Flag direct manual edits to `AlhangeulMac.xcodeproj` unless the PR clearly regenerates it from `xcodegen generate`.
- `Frameworks/Rhwp.xcframework`, `Frameworks/generated_rhwp.h`, `Frameworks/module.modulemap`, and `Frameworks/universal/librhwp.a` are generated from `RustBridge/` and scripts. If generated artifacts, `rhwp-core.lock`, `RustBridge/Cargo.lock`, or `rhwp-ffi-symbols.txt` change, check provenance, ABI symbols, and artifact hash consistency.

Architecture rules:
- `Sources/RhwpCoreBridge` must not import or depend on AppKit/UIKit and must not own UI state. It should stay limited to FFI wrappers, render tree decoding, and CoreGraphics/CoreText rendering.
- UI, Finder, Quick Look, Thumbnail, sandbox, and presentation behavior belongs in `Sources/HostApp`, `Sources/QLExtension`, `Sources/ThumbnailExtension`, or `Sources/Shared` as appropriate.
- Swift/Rust FFI changes must defend null pointers, pointer/length consistency, string/byte deallocation via `rhwp_free_string` and `rhwp_free_bytes`, and document handle lifetime via `rhwp_open` and `rhwp_close`.
- Rust core dependency must be pinned by release tag plus resolved commit for Stable, or by resolved commit `rev` for Demo/Preview. Flag branch or floating refs, local path overrides, and mismatches between `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, and `rhwp-core.lock`.

Rendering and extension checks:
- For render tree or renderer changes, check `RenderTree.swift` decoder compatibility, 1-indexed `bin_data_id`, transforms, clipping, CoreText coordinate conversions, and image/text style handling.
- Quick Look and Thumbnail code should keep conservative memory behavior, file-size fallback behavior, sandbox-safe failure paths, and thumbnail cache correctness.
- HostApp viewer code should keep document opening, security-scoped URLs, page cache, page selection, and zoom state separated in the store/view layers.

Workflow and verification:
- PRs normally target `devel`, come from `publish/taskN`, and are backed by a GitHub Issue and Korean task documents under `mydocs/`.
- PR descriptions should use `.github/pull_request_template.md`, separate the direct target task from contextual related issues, link each Stage summary to its report and commit, and list only verification that was actually run.
- When a change touches RustBridge, core dependency, FFI, or generated bridge artifacts, expect `./scripts/build-rust-macos.sh` or `--verify-lock`, `./scripts/check-no-appkit.sh`, `xcodegen generate`, and HostApp `xcodebuild` as applicable.
- When rendering behavior changes, expect `./scripts/validate-stage3-render.sh`; for visual differences or renderer bug fixes, expect `./scripts/render-debug-compare.sh` on relevant samples.
- Do not request release, signing, notarization, or Homebrew Cask work unless the PR is explicitly about distribution.
