# Task #301 Stage 2 완료 보고서

## 단계

- Stage 2: Release Communication 작성
- 기준 version/build: `0.1.4` / `10`
- 기준 upstream: `rhwp v0.7.13`
- 기준 commit: `b3e16ef212af81ef37d973ddb86d6816d3804642`

## 수행 내용

- README의 최신 릴리즈 요약을 `v0.1.4`, `rhwp v0.7.13`, Sparkle `0.1.4 (10)` 기준으로 갱신했다.
- 사용자용 Pages 릴리즈 노트 `docs/updates/v0.1.4.html`을 추가했다.
- Pages 업데이트 목록 `docs/updates/index.html`에 `v0.1.4` 항목을 추가하고 최신 DMG 링크를 tag-fixed `v0.1.4` URL로 갱신했다.
- Pages 홈 `docs/index.html`의 다운로드 버튼과 FAQ의 최신 공식 DMG 설명을 `v0.1.4` 기준으로 갱신했다.
- 내부 릴리즈 인덱스 `mydocs/release/index.md`에 `v0.1.4` 후보를 추가하고, 직전 `v0.1.3` 상태를 공개 완료로 정리했다.
- 내부 release decision record `mydocs/release/v0.1.4.md`를 작성했다.

`docs/index.html`은 구현 계획서의 최초 Stage 2 파일 목록에는 없었지만, 사용자용 최신 다운로드 진입점이므로 release communication 표면에 포함해 같이 정렬했다.

## 검증

| 명령 | 결과 | 비고 |
|------|------|------|
| `scripts/ci/write-release-delta-checklist.sh v0.1.3 HEAD build.noindex/release/delta-checklist-0.1.4.md` | 통과 | Stage 3에서 최종 HEAD 기준 재실행 예정 |
| `scripts/ci/write-release-notes.sh 0.1.4 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef build.noindex/release/release-notes-0.1.4.md` | 통과 | placeholder SHA로 template 생성 검증 |
| `scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.4.md` | 통과 | 필수 release note heading 확인 |
| `rg -n "0\\.1\\.4|v0\\.1\\.4|v0\\.7\\.13|전체 요약|포함된 rhwp 변화|알한글 앱 변화|alhangeul-macos-0\\.1\\.4\\.dmg" README.md docs/index.html docs/updates mydocs/release/v0.1.4.md` | 통과 | v0.1.4 표면 확인 |
| `rg -n "v0\\.7\\.12|0\\.1\\.3 \\(9\\)|alhangeul-macos-0\\.1\\.3\\.dmg|releases/download/v0\\.1\\.3" README.md docs/index.html docs/updates/index.html docs/updates/v0.1.4.html mydocs/release/v0.1.4.md` | 통과 | `docs/updates/index.html`의 과거 v0.1.3 목록 설명 1건만 남음 |
| `git diff --check` | 통과 | whitespace error 없음 |

## 산출물

- `README.md`
- `docs/index.html`
- `docs/updates/index.html`
- `docs/updates/v0.1.4.html`
- `mydocs/release/index.md`
- `mydocs/release/v0.1.4.md`
- `mydocs/orders/20260531.md`

## 남은 작업

- Stage 3에서 source preflight와 local/rehearsal 검증을 수행한다.
- public DMG SHA256, notarization, Sparkle EdDSA signature, Pages public 확인, Homebrew Cask digest는 Stage 4 이후 실제 배포 산출물 기준으로만 기록한다.
