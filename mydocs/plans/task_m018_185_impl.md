# Task M018 #185 구현계획서

수행계획서: `mydocs/plans/task_m018_185.md`

각 단계 완료 후 `task-stage-report` 절차로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #185 GitHub Release/Pages 업데이트 본문 템플릿과 생성 스크립트 고도화
- 마일스톤: M018 (`v0.1.1`)
- 브랜치: `local/task185`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 기준 브랜치: `devel-webview`
- 선행 상태: #183, #184, #199 반영 여부는 Stage 1에서 `devel-webview` 기준으로 재확인하고, 실제 delta 수집 시 현재 브랜치 기준으로 기록한다.
- 주 대상: release note generator, Pages 업데이트 문서, README 최신 릴리즈 요약, `mydocs/release/` 장기 기록, 배포 매뉴얼
- 목표: GitHub Release, Pages, README, release detail 문서가 같은 version/DMG/SHA256/provenance 기준을 쓰고, #188 public release 실행 전에 delta 기반 검증 체크리스트 초안을 제공한다.

## 구현 원칙

- GitHub Release 게시, release asset upload, Sparkle appcast 게시, Homebrew tap 배포는 수행하지 않는다.
- `docs/updates/v0.1.0.html`의 현재 양식과 디자인을 유지한다. 새 `v0.1.1` 페이지는 같은 header, hero, action buttons, `updates-content`, `updates-section`, footer 구조를 재사용하고 사이트 스타일 개편을 하지 않는다.
- `docs/updates/index.html`은 최신 항목과 최신 DMG 링크만 필요한 범위에서 갱신한다.
- GitHub Release 본문은 운영 정보가 누락되지 않도록 더 상세하게 만들되, Pages 페이지는 공개 사용자 안내용으로 간결하게 유지한다.
- `README.md`는 제품 개요와 현재 작업 축, 최신 공개 릴리즈 1개 요약으로 좁히고 과거 릴리즈 상세는 `mydocs/release/`로 넘긴다.
- `mydocs/release/v<version>.md`는 장기 기록 문서로 두며, PR별 검증과 release candidate 검증의 경계를 명확히 기록한다.
- `release_distribution_guide.md`는 버전 중립적인 절차와 현재도 유효한 배포 정책만 남긴다. `v0.1`, `v0.1.0`, 특정 날짜, 특정 release cycle 결정은 릴리즈별 기록 또는 기술 문서로 분리한다.
- Team ID, signing identity 표시명, notary profile name처럼 비밀은 아니지만 환경 의존적인 운영 식별자는 매뉴얼 본문이 아니라 `mydocs/tech/release_environment.md` 같은 환경 스냅샷 문서로 분리한다.
- `troubleshootings/`는 실패 사례, 검증 함정, 재발 방지 절차처럼 문제 해결 성격이 분명한 내용에만 사용한다. 일반 release policy나 버전별 release decision record를 troubleshooting으로 옮기지 않는다.
- release delta 자동화는 public release 승인 장치가 아니라 초안 생성/검증 보조 도구로 취급한다.
- 실제 `v0.1.1` public DMG SHA256은 #188에서 확정되므로 이번 단계의 후보 문서에는 placeholder 또는 #188 handoff 표시를 명확히 둔다.
- 새 스크립트는 shell 기반 기존 `scripts/ci/` 스타일을 우선하고, 외부 패키지 의존성을 추가하지 않는다.

## Stage 1. 릴리즈 communication 표면과 정보 소유 경계 확정

### 목표

현재 release communication 표면을 조사하고, GitHub Release, Pages, README, `mydocs/release/`가 각각 어떤 정보를 소유할지 확정한다.

### 작업

- `scripts/ci/write-release-notes.sh`의 현재 입력, 출력, provenance 수집 방식을 확인한다.
- `docs/updates/index.html`, `docs/updates/v0.1.0.html`, `docs/appcast.xml`의 현재 version/URL/본문 구조를 확인한다.
- `README.md`의 로드맵, 릴리즈/설치, known limitations 범위를 확인하고 최신 릴리즈 요약으로 줄일 위치를 정한다.
- `mydocs/manual/release_distribution_guide.md`의 GitHub Release, Sparkle appcast, Pages 다운로드 버튼, 릴리스 체크리스트 항목을 대조한다.
- 참고 자료인 `edwardkim/rhwp` `v0.7.10` 릴리즈 본문에서 참고할 구조만 정리하고, 알한글의 설치/첫 실행/provenance 우선순위에 맞게 변환한다.
- Stage 1 보고서에 정보 소유 경계와 이후 단계의 변경 원칙을 기록한다.

### 예상 변경 파일

- `mydocs/working/task_m018_185_stage1.md`

### 검증

```bash
git status --short --branch
bash -n scripts/ci/write-release-notes.sh
rg -n "Release|release|업데이트|appcast|SHA256|provenance|Quick Look|Thumbnail" README.md docs/updates docs/appcast.xml mydocs/manual/release_distribution_guide.md scripts/ci/write-release-notes.sh
git diff --check
```

### 완료 기준

- 각 표면의 정보 소유 경계가 Stage 1 보고서에 기록된다.
- Pages 페이지 디자인 유지 제약이 명시된다.
- Stage 2~4에서 구현할 산출물 범위가 확정된다.

### 커밋 메시지

```text
Task #185 Stage 1: 릴리즈 communication 기준 확정
```

## Stage 2. GitHub Release 본문 template과 필수 섹션 검증 구현

### 목표

`scripts/ci/write-release-notes.sh`가 #185 template 순서대로 GitHub Release 본문 후보를 생성하고, 필수 섹션 누락을 dry-run으로 확인할 수 있게 한다.

### 작업

- `write-release-notes.sh` 출력 구조를 다음 순서로 보강한다.
  - 사용자용 요약
  - 설치 방법
  - 설치 후 첫 실행과 Quick Look/Thumbnail 활성화 안내
  - 업데이트 확인 방법
  - 이번 버전의 주요 변경 사항
  - 다운로드 산출물과 SHA256
  - 포함된 `rhwp` core와 viewer asset provenance
  - 검증 결과
  - 릴리즈 delta 기반 추가 확인 항목
  - 알려진 제한 사항과 후속 이슈
  - Third Party notices
- 기존 version, SHA256, `rhwp-core.lock`, `rhwp-studio` manifest, third-party notice 파일 검증은 유지한다.
- 실제 smoke 결과와 실제 release delta는 #188에서 보정할 수 있도록 placeholder와 작성 지침을 명확히 넣는다.
- 필수 heading 검증을 script 내부 `--check-template` 옵션으로 추가할지, 별도 `scripts/ci/check-release-notes-template.sh`로 둘지 Stage 1 기준에 따라 결정한다.
- Stage 2 보고서에 생성 예시 경로와 누락 검증 결과를 기록한다.

### 예상 변경 파일

- `scripts/ci/write-release-notes.sh`
- `scripts/ci/check-release-notes-template.sh` (필요 시)
- `mydocs/working/task_m018_185_stage2.md`

### 검증

```bash
git status --short --branch
bash -n scripts/ci/write-release-notes.sh
scripts/ci/write-release-notes.sh 0.1.1 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef build.noindex/release/release-notes-0.1.1.md
rg -n "사용자용 요약|설치 방법|첫 실행|Quick Look|업데이트 확인|주요 변경|SHA256|provenance|검증 결과|릴리즈 delta|알려진 제한 사항|Third Party" build.noindex/release/release-notes-0.1.1.md
git diff --check
```

필수 섹션 검증 helper를 추가하면 다음도 수행한다.

```bash
bash -n scripts/ci/check-release-notes-template.sh
scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.1.md
```

### 완료 기준

- release note dry-run이 `v0.1.1` 후보 본문을 생성한다.
- 필수 섹션 누락 검증이 자동 또는 명령형 기준으로 가능하다.
- 생성 본문에 설치, 첫 실행, Sparkle, checksum, provenance, 검증, known limitations, third-party notices가 모두 포함된다.

### 커밋 메시지

```text
Task #185 Stage 2: GitHub Release 본문 template 보강
```

## Stage 3. Pages 업데이트 페이지와 README 최신 릴리즈 기준 정리

### 목표

현재 Pages 업데이트 페이지 디자인을 유지하면서 `v0.1.1` 후보 페이지와 index 갱신 기준을 마련하고, README를 최신 릴리즈 1개 요약 중심으로 정리한다.

### 작업

- `docs/updates/v0.1.1.html`을 현재 `docs/updates/v0.1.0.html`의 양식으로 작성한다.
- `v0.1.1.html`은 같은 CSS, header, hero, action button, `updates-section`, footer 구조를 유지한다.
- 페이지 본문은 사용자 관점의 요약, 주요 변경, 알려진 한계, 설치와 업데이트 안내를 중심으로 간결하게 둔다.
- 운영 상세인 긴 provenance, delta checklist, PR별 검증은 Pages에 길게 복제하지 않고 GitHub Release 또는 `mydocs/release/v0.1.1.md`로 연결한다.
- `docs/updates/index.html`에 `v0.1.1` 항목을 추가하고 최신 DMG 다운로드 링크를 `alhangeul-macos-0.1.1.dmg`로 갱신할 기준을 적용한다.
- `README.md`는 현재 작업 축과 최신 공개 릴리즈 1개 요약을 중심으로 줄이고, 상세 기록은 `mydocs/release/` 링크로 넘긴다.
- 실제 public DMG SHA256이 아직 확정되지 않은 항목은 #188 handoff로 표시한다.
- Stage 3 보고서에 디자인 유지 확인 결과와 변경된 링크를 기록한다.

### 예상 변경 파일

- `docs/updates/index.html`
- `docs/updates/v0.1.1.html`
- `README.md`
- `mydocs/working/task_m018_185_stage3.md`

### 검증

```bash
git status --short --branch
rg -n "v0\\.1\\.1|alhangeul-macos-0\\.1\\.1\\.dmg|Quick Look|Thumbnail|Sparkle|업데이트 확인" docs/updates README.md
rg -n "updates-hero|updates-content|updates-section|page-action-button|site-footer" docs/updates/v0.1.0.html docs/updates/v0.1.1.html
git diff --check
```

필요 시 로컬 정적 페이지를 브라우저로 열어 시각 회귀를 확인한다. 이 경우 현재 `v0.1.0` 페이지와 같은 레이아웃 흐름을 유지하는지만 확인하고 디자인 개편은 하지 않는다.

### 완료 기준

- `v0.1.1` Pages 후보가 `v0.1.0`의 양식과 디자인을 유지한다.
- `docs/updates/index.html` 최신 항목과 최신 DMG 링크 갱신 기준이 반영된다.
- README가 과거 릴리즈 상세를 누적하지 않는 방향으로 정리된다.
- Pages, README, release note 후보 사이의 version/DMG URL 안내가 충돌하지 않는다.

### 커밋 메시지

```text
Task #185 Stage 3: Pages와 README 릴리즈 기준 정리
```

## Stage 4. `mydocs/release/` 장기 기록과 delta 검증 체크리스트 기준 구현

### 목표

릴리즈별 장기 기록 문서 구조를 만들고, 이전 공개 릴리즈 대비 변경 delta를 release candidate 검증 입력으로 넘기는 기준을 마련한다. 동시에 `release_distribution_guide.md`에서 버전별 release decision record로 분리해야 할 정보를 식별한다.

### 작업

- `mydocs/release/index.md`를 만들고 릴리즈 목록, 최신 릴리즈, GitHub Release/Pages 링크 관리 기준을 작성한다.
- `mydocs/release/v0.1.1.md` 초안을 만들고 다음 항목을 포함한다.
  - 사용자용 요약
  - 직전 공개 릴리즈 대비 변경점
  - 연결된 Issue/PR
  - 기여자
  - 검증 결과와 #188에서 반복할 public smoke
  - 알려진 제한 사항과 후속 이슈
  - `rhwp` core와 viewer asset provenance
  - GitHub Release/Pages/Sparkle appcast 링크
- `release_distribution_guide.md` 안의 `v0.1`, `v0.1.0`, 특정 날짜/credential 준비 상태, 특정 cycle 브랜치 기준, 특정 버전 명령 예시를 분류한다.
- 버전별 결정과 release 당시 판단은 `mydocs/release/v0.1.0.md` 또는 `mydocs/release/v0.1.1.md`로 옮긴다.
- Team ID, signing identity 표시명, keychain profile name처럼 현재 환경 식별자는 필요 시 `mydocs/tech/release_environment.md`로 옮긴다.
- Gatekeeper, notarization, Finder integration, appcast push 실패처럼 재발 방지 성격이 강한 내용만 `mydocs/troubleshootings/` 분리 후보로 판단한다. 현재 단계에서 실제 실패 사례가 없으면 새 troubleshooting 문서는 만들지 않는다.
- `mydocs/manual/document_structure_guide.md`에 `release/` 폴더 역할과 파일명 기준을 추가한다.
- `document_structure_guide.md`에 release environment 문서와 troubleshooting 분리 기준을 필요한 범위에서 보강한다.
- `previous public release tag -> current release candidate commit` 범위의 commit/file delta 수집 명령을 문서화한다.
- 필요하면 `scripts/ci/write-release-delta-checklist.sh` 같은 최소 helper를 추가해 file path 기반 영향 영역 초안을 만든다.
- 영향 영역은 최소 HostApp viewer, Quick Look preview, Finder thumbnail, 저장/다른 이름 저장, PDF/인쇄/공유, Sparkle/appcast/Pages, DMG/signing/notarization, Homebrew Cask, `rhwp` core/viewer provenance, 문서 전용 변경으로 분류한다.
- Stage 4 보고서에 자동 분류 한계, release owner 보정 지점, manual에서 분리할 정보 목록을 기록한다.

### 예상 변경 파일

- `mydocs/release/index.md`
- `mydocs/release/v0.1.0.md` (기존 v0.1.0 release decision record 분리가 필요하다고 판단될 때)
- `mydocs/release/v0.1.1.md`
- `mydocs/tech/release_environment.md` (비밀이 아닌 운영 환경 식별자를 분리할 때)
- `mydocs/manual/document_structure_guide.md`
- `scripts/ci/write-release-delta-checklist.sh` (필요 시)
- `mydocs/working/task_m018_185_stage4.md`

### 검증

```bash
git status --short --branch
git log --oneline v0.1.0..HEAD
git diff --name-only v0.1.0..HEAD
rg -n "release/|릴리즈|v0\\.1\\.0|v0\\.1\\.1|검증|provenance|GitHub Release|Pages|appcast|release_environment|troubleshootings" mydocs/release mydocs/tech mydocs/manual/document_structure_guide.md
git diff --check
```

delta helper를 추가하면 다음도 수행한다.

```bash
bash -n scripts/ci/write-release-delta-checklist.sh
scripts/ci/write-release-delta-checklist.sh v0.1.0 HEAD build.noindex/release/delta-checklist-0.1.1.md
rg -n "HostApp|Quick Look|Thumbnail|Sparkle|DMG|Homebrew|문서" build.noindex/release/delta-checklist-0.1.1.md
```

### 완료 기준

- `mydocs/release/`의 역할과 파일명 기준이 매뉴얼에 반영된다.
- `release_distribution_guide.md`에서 분리할 버전별/환경별 정보 목록이 Stage 4 보고서에 정리된다.
- `v0.1.1` 릴리즈 상세 문서 초안이 존재한다.
- 필요 시 `v0.1.0` 릴리즈 기록 또는 release environment 문서가 생성된다.
- troubleshooting 분리가 필요한 정보와 그렇지 않은 정보의 기준이 기록된다.
- delta 기반 검증 체크리스트 작성 기준 또는 helper가 준비된다.
- PR별 검증과 release candidate 검증의 경계가 명확하다.

### 커밋 메시지

```text
Task #185 Stage 4: 릴리즈 기록과 delta 검증 기준 추가
```

## Stage 5. 매뉴얼 통합, 최종 dry-run, #188 handoff 정리

### 목표

전체 산출물이 같은 release 기준을 쓰는지 검증하고, #188 public release 실행에서 반복할 확인 항목을 최종 보고서에 넘긴다.

### 작업

- `release_distribution_guide.md`의 GitHub Release, Pages 업데이트, Sparkle appcast, 릴리스 체크리스트 항목을 Stage 2~4 기준에 맞게 갱신한다.
- `release_distribution_guide.md`의 예시 명령과 산출물 경로는 가능한 한 `<version>` 기반으로 일반화한다.
- `release_distribution_guide.md`에 남기는 현재 정책과, `mydocs/release/` 또는 `mydocs/tech/release_environment.md`로 넘기는 역사/환경 정보의 경계를 최종 반영한다.
- `write-release-notes.sh` dry-run 결과, Pages 후보, README 최신 릴리즈 블록, `mydocs/release/v0.1.1.md`의 version/DMG URL/SHA256/provenance 표현을 대조한다.
- placeholder가 남는 항목은 #188에서 확정할 값인지 명확히 표시한다.
- 공개 URL 최종 확인 항목을 #188 handoff로 정리한다.
  - `https://postmelee.github.io/alhangeul-macos/updates/`
  - `https://postmelee.github.io/alhangeul-macos/updates/v0.1.1.html`
  - `https://postmelee.github.io/alhangeul-macos/appcast.xml`
- 오늘할일 상태를 완료로 갱신한다.
- 최종 결과보고서에 변경 내용, 검증 결과, 미수행 public release 항목, #188 handoff를 기록한다.

### 예상 변경 파일

- `mydocs/manual/release_distribution_guide.md`
- `mydocs/tech/release_environment.md` (Stage 4에서 만들지 않았지만 Stage 5 일반화 중 필요하다고 판단될 때)
- `mydocs/troubleshootings/*.md` (실패 사례/재발 방지 성격의 분리 대상이 실제로 있을 때만)
- `mydocs/orders/20260510.md`
- `mydocs/report/task_m018_185_report.md`

### 검증

```bash
git status --short --branch
bash -n scripts/ci/write-release-notes.sh
scripts/ci/write-release-notes.sh 0.1.1 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef build.noindex/release/release-notes-0.1.1.md
rg -n "v0\\.1\\.1|alhangeul-macos-0\\.1\\.1\\.dmg|SHA256|Quick Look|Thumbnail|Sparkle|provenance" build.noindex/release/release-notes-0.1.1.md docs/updates README.md mydocs/release mydocs/tech mydocs/manual/release_distribution_guide.md
rg -n "v0\\.1|0\\.1\\.0|Developer ID Application:|XH6JHKYXV8|alhangeul-notary" mydocs/manual/release_distribution_guide.md
git diff --check
```

delta helper를 추가한 경우 최종 반복:

```bash
scripts/ci/write-release-delta-checklist.sh v0.1.0 HEAD build.noindex/release/delta-checklist-0.1.1.md
```

### 완료 기준

- release note generator, Pages 후보, README 최신 릴리즈 블록, `mydocs/release/v0.1.1.md`, 배포 매뉴얼이 같은 기준을 따른다.
- `release_distribution_guide.md`가 버전 중립적인 절차와 현재 정책 중심으로 정리된다.
- 버전별 결정, 과거 release 판단, 환경 식별자는 `mydocs/release/` 또는 `mydocs/tech/`로 분리된다.
- troubleshooting 문서는 실제 실패 사례 또는 재발 방지 성격이 분명할 때만 생성된다.
- 현재 Pages 디자인 유지 조건이 지켜진다.
- #188에서 실제 public SHA256, GitHub Release 게시, Pages URL, appcast 공개 상태를 확인할 handoff가 정리된다.
- 최종 보고서와 오늘할일 갱신이 완료된다.
- PR 게시 준비 전 작업트리가 정리된다.

### 커밋 메시지

```text
Task #185 Stage 5: 릴리즈 template 최종 검증과 handoff 정리
```
