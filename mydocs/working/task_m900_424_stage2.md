# Task M900 #424 Stage 2 완료보고서

## 단계 목적

`v0.1.7` 이후 포함 PR을 실제 사용자 영향 기준으로 분류하고, `v0.1.8 (14)` / `rhwp v0.7.18` release communication을 README, Pages와 내부 release record에 일관되게 반영한다.

## 산출물

### 사용자-facing 문서

- `README.md`
  - 최신 릴리스 요약을 `v0.1.8`, `rhwp v0.7.18`, HOP UTI 호환 기준으로 갱신
- `docs/index.html`
  - Pages 홈 다운로드와 FAQ의 최신 DMG 기준을 `v0.1.8`로 갱신
- `docs/updates/index.html`
  - header/본문 다운로드 CTA와 첫 릴리스 항목을 `v0.1.8`로 갱신
- `docs/updates/v0.1.8.html`
  - 사용자용 변경 요약, rhwp 변화, 앱 변화, 한계와 설치 안내 추가
- `docs/updates/v0.1.0.html` ~ `docs/updates/v0.1.7.html`
  - 최신 릴리스 고지를 `v0.1.8`로 갱신

### 내부 release record

- `mydocs/release/index.md`
  - `v0.1.8` 후보 추가, `v0.1.7`을 공개 완료로 보정
- `mydocs/release/v0.1.7.md`
  - public release 상태, public DMG SHA256과 현재 Homebrew 미반영 상태를 live 결과로 보정
- `mydocs/release/v0.1.8.md`
  - release identity, 14개 포함 merge PR과 Task #424 판정, GitHub Release body 후보, 검증·배포 gate, known limitations 기록
- `mydocs/plans/task_m900_424_impl.md`
  - Stage 2 실제 소유 파일인 Pages 홈, 이전 버전 고지와 v0.1.7 상태 보정을 명시

### 검증 전용 ignored 산출물

- `build.noindex/release/pr-analysis-0.1.8.md`
- `build.noindex/release/delta-checklist-0.1.8.md`
- `build.noindex/release/release-notes-0.1.8.md`

위 `build.noindex/` 파일은 commit하지 않는다. release note의 SHA256은 형식 검증용 placeholder이며 public 값이 아니다.

## 본문 변경 정도 / 본문 무손실 여부

- 앱, extension, RustBridge, core/studio asset, renderer와 release workflow source는 Stage 2에서 변경하지 않았다.
- README는 기존 “최신 공개 릴리즈” 블록의 버전, 설명과 링크만 교체했다.
- Pages 홈과 updates index는 최신 다운로드/릴리스 링크만 교체하고 기존 섹션, 스타일과 script를 보존했다.
- v0.1.0~v0.1.6 release page는 기존 notice의 최신 버전·링크만 `v0.1.8`로 교체했다. v0.1.7 page는 같은 표준 notice를 새로 추가했고 기존 release 본문은 변경하지 않았다.
- v0.1.8 page는 기존 update page의 header, action, section과 footer 구조를 재사용했다. 모바일 provenance hash overflow를 막기 위해 hash 내부에 `<wbr>` 한 개만 추가했다.
- v0.1.7 record는 상단 최종 상태와 별도 완료 보정만 추가했다. 당시 Stage 3/4 rehearsal·gate 기록은 역사 기록으로 무손실 보존했다.
- 공개 요약에는 #420 core/studio, #417 HOP UTI와 #384 웹 문의 경로만 반영했다. Skia internal opt-in, verification-only 작업, external image C ABI와 v0.7.19 조사 결과는 사용자 기능으로 올리지 않았다.

## 검증 결과

### Live release 기준

2026-07-19 GitHub live 조회 결과:

| 항목 | 결과 |
|------|------|
| 알한글 v0.1.7 | non-draft, non-prerelease, `2026-06-24T21:37:20Z` 공개 |
| v0.1.7 DMG | 156,747,415 bytes, SHA256 `332208ff6f68c78a49d0fc60b895eeabb41d4996dad38fde158fa1935ab4b09d` |
| rhwp v0.7.18 | public stable, target `93862a4e16df59834ebce46d91e948cd739208e9` |
| rhwp v0.7.19 | public stable, upstream latest |
| edwardkim/rhwp#2396 | OPEN |

### 포함 PR 분석

`v0.1.7..HEAD` first-parent merge PR 14개를 확인했다.

```text
#384 #395 #397 #399 #400 #401 #402
#403 #405 #414 #416 #417 #420 #423
```

`scripts/ci/write-release-pr-analysis.sh`가 생성한 14개 PR 초안을 `scripts/validate-github-body.sh`로 검증했다. release owner 판정 결과는 다음과 같다.

- 공개 주요 요약: #420, #417
- 보조 웹 변경: #384
- 공개 기능에서 제외: #395, #397, #399, #400, #401, #402, #403, #405, #414, #416, #423
- release transport 예정: Task #424 PR

`scripts/ci/write-release-delta-checklist.sh v0.1.7 HEAD`도 성공해 HostApp, Quick Look, Thumbnail, core/studio, Pages와 release metadata 영향 path를 확인했다.

### Release helper

다음 명령이 통과했다.

```text
scripts/ci/write-release-notes.sh 0.1.8 <placeholder-sha256> ...
scripts/ci/check-release-notes-template.sh ...
scripts/validate-github-body.sh ...
scripts/ci/update-release-version-notices.sh --updates-dir docs/updates --check
```

결과:

```text
Release note template check passed
Release version notices are up to date for latest v0.1.8
```

생성된 GitHub Release body는 다음 구조를 포함한다.

- `이번 버전의 주요 변경 사항`
- `변경 요약`, `포함된 rhwp 변화`, `알한글 앱 변화`
- 다운로드, 지원 환경, 첫 실행, 업데이트, Homebrew
- 알려진 제한 사항
- 릴리즈 요약 PR, 해결된 Issue, 참고/연관 Issue
- 상세 기록과 release metadata

### Pages browser QA

로컬 정적 서버에서 `v0.1.8.html`, `/updates/`와 Pages 홈을 확인했다.

| viewport/페이지 | 결과 |
|-----------------|------|
| 1440x900 v0.1.8 | `scrollWidth=innerWidth=1440`, 6개 section, header/main 겹침 없음 |
| 390x844 v0.1.8 | `scrollWidth=innerWidth=390`, overflow element 0, action 3개 표시 |
| 390x844 updates index | header/본문 DMG 링크 모두 v0.1.8, 첫 항목 v0.1.8, page overflow 없음 |
| 390x844 Pages home | download link v0.1.8, `scrollWidth=clientWidth=390` |

세 페이지 모두 browser console error/warning이 없었다. v0.1.8 모바일 최초 검사에서 provenance commit inline code 한 개가 40px 넘는 것을 확인해 `<wbr>`로 보정했고, 재검사에서 overflow element 0을 확인했다.

### 정적 diff

- `scripts/validate-github-body.sh mydocs/release/v0.1.8.md`: 통과
- v0.1.0~v0.1.7의 latest notice가 모두 v0.1.8을 가리킴
- latest v0.1.8 page에는 이전 버전 notice 없음
- README, Pages와 release record에서 `v0.1.8`, `v0.7.18`, HOP, DMG 경로 확인
- `git diff --check`: 통과

## 잔여 위험

- Stage 2 문서의 v0.1.8 GitHub Release/DMG URL은 후보 경로다. official stable publish 전에는 실제 asset이 없으며 Pages는 `main` 반영과 release workflow gate 전에는 공개하지 않는다.
- 자동 PR 분석과 delta checklist의 candidate는 Stage 2 시작 시 `be406ef...`다. Task #424 Stage 2 이후 commit과 최종 `devel -> main` candidate는 Stage 3/4에서 다시 생성해야 한다.
- release body의 SHA256은 placeholder로만 검증했다. public DMG SHA256은 Stage 5 official publish 후 기록한다.
- `rhwp v0.7.19`가 upstream latest이므로 Publish workflow는 `require_latest_rhwp=false` 실행별 예외 승인 없이는 실패한다.
- HOP exact UTI와 custom scheme Host RPC는 source/report 근거만 있다. signed/notarized draft DMG에서 둘 다 통과하기 전 official publish를 승인할 수 없다.
- external linked image, Skia default, Intel 실기기와 Sparkle v0.1.7 -> v0.1.8 update는 아직 완료로 기록하지 않았다.
- repository Cask는 현재 v0.1.6이다. public v0.1.8 DMG URL/SHA256 확정 전에는 갱신하지 않는다.

## 다음 단계 영향

Stage 3은 현재 release communication을 입력으로 source preflight와 rehearsal을 수행한다.

1. `rhwp v0.7.18` lock/studio, FFI와 no-AppKit boundary를 검증한다.
2. Xcode project를 재생성하고 HostApp Debug build와 native render smoke를 실행한다.
3. Release package의 app/extension version, universal slice와 legal asset을 확인한다.
4. release helper PR analysis, delta와 release body를 Stage 2 commit이 포함된 HEAD에서 재생성한다.
5. 별도 승인 후에만 rehearsal DMG를 생성하고 checksum/layout을 검증한다.

## 승인 요청

Stage 2 release communication과 검증 결과를 승인하고, Stage 3 `Source Preflight와 Rehearsal` 진입을 요청한다. Stage 3 source preflight는 승인 범위에 포함하되 rehearsal DMG 생성은 결과 확인 후 별도 승인을 받는다.
