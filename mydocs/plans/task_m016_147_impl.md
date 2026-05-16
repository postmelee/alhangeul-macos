# Task M016 #147 구현계획서

수행계획서: `mydocs/plans/task_m016_147.md`

각 단계 완료 후 `task-stage-report` 절차로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #147 third-party font/license 및 bundled rhwp-studio 자산 고지 정리
- 마일스톤: M016 (`v0.1 출시 전 보강`)
- 브랜치: `local/task147`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 주 대상: `THIRD_PARTY_LICENSES.md`, `README.md`, `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md`, `mydocs/tech/font_fallback_strategy.md`
- 기준 provenance: `rhwp-core.lock`, `Sources/HostApp/Resources/rhwp-studio/manifest.json`
- 목표: v0.1 artifact에 포함되는 `rhwp` core/Rust bridge 산출물, bundled `rhwp-studio` asset, bundled WOFF2 font의 attribution과 proprietary font 비포함 정책을 release 사용자가 확인할 수 있는 문서 흐름으로 정리한다.

## 구현 원칙

- 고지의 중심 문서는 루트 `THIRD_PARTY_LICENSES.md`로 둔다.
- `FONTS.md`는 bundled font별 license/source 세부 목록의 진실 원천으로 유지한다.
- `rhwp-core.lock`과 `rhwp-studio/manifest.json`은 기계 판독 가능한 provenance 기준으로 유지하고, 문서에는 요약과 위치를 연결한다.
- README에는 license/provenance의 진입점만 둔다. 동일한 긴 font/license 표를 중복 복제하지 않는다.
- proprietary 한컴/HY/HCR/Microsoft font 파일은 저장소와 release artifact에 포함하지 않는다는 정책을 명시한다.
- 새 font 파일 추가, core pin 변경, signing/notarization/package 산출물 생성은 하지 않는다.
- 문서 변경은 한국어로 작성하고, 기존 문서의 책임 범위를 유지한다.

## Stage 1. release artifact provenance inventory 확인

### 목표

- 현재 저장소에 포함된 `rhwp` core provenance, `rhwp-studio` asset snapshot, bundled font 목록, existing license 고지의 실제 상태를 확인한다.
- license 문서 보강 전에 실제 resource tree와 문서 목록 사이의 불일치 후보를 분리한다.

### 작업

- `rhwp-core.lock`의 repository, ref kind, release tag, commit, artifact hash/size를 확인한다.
- `Sources/HostApp/Resources/rhwp-studio/manifest.json`의 repository, release tag, resolved commit, entrypoint hash를 확인한다.
- `Sources/HostApp/Resources/rhwp-studio/fonts`의 WOFF2 목록과 `FONTS.md`의 font 표가 맞는지 대조한다.
- proprietary font 후보 이름이 실제 resource tree에 포함되지 않았는지 확인한다.
- `THIRD_PARTY_LICENSES.md`, README, `mydocs/tech/font_fallback_strategy.md`의 현재 고지 수준을 조사한다.
- Stage 1 보고서에 inventory 결과와 Stage 2 문서 설계에서 보강할 항목을 기록한다.

### 예상 변경 파일

- `mydocs/working/task_m016_147_stage1.md`

### 검증

```bash
git status --short --branch
sed -n '1,180p' rhwp-core.lock
sed -n '1,220p' Sources/HostApp/Resources/rhwp-studio/manifest.json
find Sources/HostApp/Resources/rhwp-studio/fonts -maxdepth 1 -name '*.woff2' -type f | sort
find Sources/HostApp/Resources/rhwp-studio/fonts -maxdepth 1 -type f | sort
rg -n "hamchob|hamchod|h2hdrm|hygprm|hygtre|hymjre|ArialW05|Calibri|MalgunGothic|Wingdings|Webdings" Sources/HostApp/Resources/rhwp-studio/fonts
rg -n "rhwp-studio|font|license|LICENSE|proprietary|WOFF2|rhwp-core.lock|manifest.json" README.md THIRD_PARTY_LICENSES.md Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md mydocs/tech/font_fallback_strategy.md
git diff --check
```

### 완료 기준

- release artifact에 포함되는 asset/font 범위와 provenance 기준 파일이 보고서에 정리된다.
- proprietary font가 resource tree에 포함되지 않는지 확인된다.
- Stage 2에서 고지 구조로 옮길 누락 항목이 확정된다.

### 커밋 메시지

```text
Task #147 Stage 1: license provenance inventory 정리
```

## Stage 2. license/attribution 문서 구조 설계

### 목표

- `THIRD_PARTY_LICENSES.md`, README, `FONTS.md`, font fallback 문서의 책임 경계를 확정한다.
- `rhwp`, `rhwp-studio`, bundled font, generated Rust/Swift bridge 산출물의 attribution 수준을 정한다.

### 작업

- Stage 1 inventory를 기준으로 문서별 소유 정보를 표로 정리한다.
- `THIRD_PARTY_LICENSES.md`에 들어갈 섹션 구조를 설계한다.
- README에는 어떤 위치에 license/provenance 진입점을 둘지 정한다.
- `FONTS.md`에는 font별 목록과 proprietary font 비포함 정책을 어느 수준까지 보강할지 정한다.
- `font_fallback_strategy.md`에는 native fallback 정책과 license 고지 위치 연결만 둘지 검토한다.
- Stage 2 보고서에 실제 Stage 3-4 문서 변경안을 기록한다.

### 예상 변경 파일

- `mydocs/working/task_m016_147_stage2.md`

### 검증

```bash
git status --short --branch
rg -n "^#|^##|rhwp|rhwp-studio|font|license|proprietary|WOFF2" THIRD_PARTY_LICENSES.md README.md Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md mydocs/tech/font_fallback_strategy.md
git diff --check
```

### 완료 기준

- 중복 고지를 줄이면서 release 사용자가 필요한 정보를 따라갈 수 있는 문서 구조가 확정된다.
- Stage 3에서 변경할 문서와 변경하지 않을 문서가 분리된다.
- legal 해석이 필요한 항목과 단순 attribution 항목이 보고서에서 분리된다.

### 커밋 메시지

```text
Task #147 Stage 2: license 고지 구조 설계
```

## Stage 3. third-party license와 font 고지 보강

### 목표

- 루트 `THIRD_PARTY_LICENSES.md`를 v0.1 release artifact 기준의 license/attribution 진입점으로 보강한다.
- bundled font 세부 목록과 proprietary font 비포함 정책을 필요한 문서에 일관되게 연결한다.

### 작업

- `THIRD_PARTY_LICENSES.md`에 `rhwp`, `rhwp-studio` bundled asset, Rust bridge/generated artifact, bundled font 섹션을 추가 또는 보강한다.
- `rhwp-studio` provenance는 `manifest.json`과 `rhwp-core.lock` 위치를 함께 연결하고, release tag/commit 기준을 적는다.
- bundled font는 `FONTS.md`를 상세 목록으로 연결하고, 오픈 라이선스 WOFF2만 포함한다는 원칙을 적는다.
- proprietary 한컴/HY/HCR/Microsoft font 파일이 포함되지 않는다는 정책을 명확히 적는다.
- 필요 시 `FONTS.md`의 도입부 또는 proprietary font 섹션 문구를 release artifact 기준으로 정리한다.
- 필요 시 `mydocs/tech/font_fallback_strategy.md`에 third-party license 고지 위치를 연결한다.
- Stage 3 보고서에 문서 변경 요약과 attribution 범위 판단을 기록한다.

### 예상 변경 파일

- `THIRD_PARTY_LICENSES.md`
- `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md` (필요 시)
- `mydocs/tech/font_fallback_strategy.md` (필요 시)
- `mydocs/working/task_m016_147_stage3.md`

### 검증

```bash
git status --short --branch
scripts/verify-rhwp-studio-assets.sh
find Sources/HostApp/Resources/rhwp-studio/fonts -maxdepth 1 -name '*.woff2' -type f | sort
rg -n "rhwp|rhwp-studio|release-tag|v0.7.9|0fb3e6758b8ad11d2f3c3849c83b914684e83863|WOFF2|SIL OFL|proprietary|한컴|HY|Microsoft|THIRD_PARTY_LICENSES" THIRD_PARTY_LICENSES.md Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md mydocs/tech/font_fallback_strategy.md
git diff --check
```

### 완료 기준

- `THIRD_PARTY_LICENSES.md`만 읽어도 bundled third-party 범위와 상세 provenance 위치를 알 수 있다.
- bundled font는 `FONTS.md`의 세부 표와 연결되고, proprietary font 비포함 정책이 명확하다.
- resource tree 검증과 문서 diff 검증이 통과한다.

### 커밋 메시지

```text
Task #147 Stage 3: third-party license와 font 고지 보강
```

## Stage 4. README 진입점, 최종 검증, 보고 정리

### 목표

- README 또는 release 사용자용 진입점에 third-party license/provenance 위치를 연결한다.
- 전체 문서 검증을 마치고 최종 보고서와 오늘할일을 정리한다.

### 작업

- README의 배포, provenance, license 관련 섹션 중 적절한 위치에 `THIRD_PARTY_LICENSES.md`, `rhwp-core.lock`, `rhwp-studio/manifest.json`, `FONTS.md` 연결을 추가한다.
- README에 같은 license 표를 중복하지 않고, release artifact 확인자가 따라갈 수 있는 짧은 문구로 제한한다.
- Stage 1-3 결과를 바탕으로 최종 검증 명령을 실행한다.
- Stage 4 보고서와 최종 결과보고서에 변경 파일, 검증 결과, 남은 리스크를 정리한다.
- `mydocs/orders/20260506.md`의 #147 행을 완료 상태로 갱신한다.

### 예상 변경 파일

- `README.md`
- `mydocs/working/task_m016_147_stage4.md`
- `mydocs/report/task_m016_147_report.md`
- `mydocs/orders/20260506.md`

### 검증

```bash
git status --short --branch
scripts/verify-rhwp-studio-assets.sh
find Sources/HostApp/Resources/rhwp-studio/fonts -maxdepth 1 -name '*.woff2' -type f | sort | wc -l
rg -n "Third Party|THIRD_PARTY_LICENSES|rhwp-core.lock|manifest.json|FONTS.md|rhwp-studio|WOFF2|proprietary" README.md THIRD_PARTY_LICENSES.md Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md mydocs/tech/font_fallback_strategy.md
git diff --check
```

### 완료 기준

- README에서 third-party license/provenance 문서로 접근할 수 있다.
- `THIRD_PARTY_LICENSES.md`, `FONTS.md`, font fallback 문서의 책임 경계가 일관된다.
- 최종 보고서와 오늘할일 완료 처리가 커밋된다.
- PR 게시 전 working tree가 clean 상태다.

### 커밋 메시지

```text
Task #147 Stage 4 + 최종 보고서: third-party license 고지 정리 완료
```
