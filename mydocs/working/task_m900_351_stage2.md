# Task M900 #351 Stage 2 완료 보고서

## 단계 목표

`v0.1.5` public release 후보의 사용자-facing release communication과 내부 release record를 `rhwp v0.7.15` 기준으로 정리했다. `devel`에 남아 있던 `v0.1.4` 후보 상태 기록은 public 완료 결과와 충돌하지 않도록 보정했다.

## 변경 요약

| 파일 | 변경 |
|------|------|
| `README.md` | 최신 공개 릴리즈 요약을 `v0.1.5`, `rhwp v0.7.15`, build `11` 기준으로 갱신 |
| `docs/index.html` | 홈 화면 다운로드 버튼과 FAQ의 최신 DMG 문구를 `v0.1.5`로 갱신 |
| `docs/updates/v0.1.5.html` | Pages 사용자용 릴리즈 노트 신규 작성 |
| `docs/updates/index.html` | 최신 DMG 링크와 릴리즈 노트 목록에 `v0.1.5` 추가 |
| `docs/updates/v0.1.0.html` ~ `docs/updates/v0.1.4.html` | 이전 릴리즈 안내 배너가 최신 `v0.1.5` 페이지를 가리키도록 자동 정규화 |
| `mydocs/release/index.md` | `v0.1.5` 후보 항목 추가, `v0.1.4` 상태를 공개 완료로 보정 |
| `mydocs/release/v0.1.4.md` | `main`의 public 완료 기록 기준으로 release record 보정 |
| `mydocs/release/v0.1.5.md` | release decision record, GitHub Release body 후보, 검증 gate, 후속 항목 신규 작성 |

## Release body 후보

`mydocs/release/v0.1.5.md`에 GitHub Release 본문 후보를 다음 구조로 작성했다.

- `변경 요약`: `rhwp v0.7.15` 반영, 수식/미주 흐름, HWPX 저장 호환성, 문단 정보 UI, `0.1.5 (11)` universal DMG 기준
- `포함된 rhwp 변화`: core/studio tag와 commit, 수식 TAC/커서 이동/미주 수식, HWPX picture/diagonal border/field ordering, `rhwp-studio` 문단 정보 UI
- `알한글 앱 변화`: source metadata, workflow default, About provenance, README/Pages/release index 정렬, public publish 단계의 checksum 검증 보류

upstream browser extension 보안 강화는 같은 `rhwp v0.7.15` package에 포함된 변화로만 기록했다. 알한글 macOS 앱의 신규 브라우저 확장 권한이나 네트워크 기능으로 오해되지 않도록 Pages와 release record에 제한 문구를 함께 넣었다.

## 검증 결과

| 명령 | 결과 |
|------|------|
| `scripts/ci/write-release-delta-checklist.sh v0.1.4 HEAD build.noindex/release/delta-checklist-0.1.5.md` | 통과 |
| `scripts/ci/write-release-notes.sh 0.1.5 <64hex> build.noindex/release/release-notes-0.1.5.md` | 통과 |
| `scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.5.md` | 통과 |
| `scripts/ci/update-release-version-notices.sh --updates-dir docs/updates --check` | 통과 |
| `rg -n "v0\\.1\\.5|0\\.1\\.5|v0\\.7\\.15|변경 요약|포함된 rhwp 변화|알한글 앱 변화|alhangeul-macos-0\\.1\\.5\\.dmg" ...` | 통과 |
| `rg -n "최신 버전 v0\\.1\\.5|href=\"\\./v0\\.1\\.5\\.html\"" docs/updates/v0.1.0.html ... docs/updates/v0.1.4.html` | 통과 |
| `git diff --check` | 통과 |

`write-release-notes.sh` 최초 dry-run은 SHA256 자리표시자 길이 입력 오류로 실패했고, 64자리 hex 자리표시자로 즉시 재실행해 통과했다. 이는 source 변경이나 release helper 결함이 아니라 검증 명령 입력값 문제다.

## 산출물

- `docs/updates/v0.1.5.html`
- `mydocs/release/v0.1.5.md`
- `mydocs/working/task_m900_351_stage2.md`
- 검증 dry-run 산출물:
  - `build.noindex/release/delta-checklist-0.1.5.md`
  - `build.noindex/release/release-notes-0.1.5.md`

`build.noindex/` 산출물은 git에 포함하지 않는다.

## 후속 단계로 넘길 항목

- Stage 3에서 `v0.1.4..HEAD` delta checklist를 Stage 2 commit 포함 상태로 다시 생성한다.
- Stage 3에서 source preflight, Debug/Release build, release package, local/rehearsal DMG 검증을 수행한다.
- public DMG SHA256, Sparkle EdDSA signature, notarization 결과, Homebrew Cask digest는 Stage 4/5 public publish 이후에만 기록한다.
- `Casks/alhangeul.rb`는 public DMG SHA256 확정 전에는 변경하지 않는다.

## 다음 승인 요청

Stage 3: Source Preflight와 Rehearsal 진행 승인을 요청한다.
