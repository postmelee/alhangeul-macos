# Task M016 #147 Stage 4 보고서

## 단계 목적

README에서 third-party license/provenance 문서로 접근할 수 있는 진입점을 추가하고, Stage 1-3 결과를 바탕으로 최종 검증과 최종 보고서, 오늘할일 완료 처리를 정리한다.

## 산출물

| 파일 | 라인 수 | 요약 |
|------|---------|------|
| `README.md` | 457 | License 섹션에 `THIRD_PARTY_LICENSES.md`, `rhwp-core.lock`, `rhwp-studio/manifest.json`, `FONTS.md` 링크 추가 |
| `mydocs/orders/20260506.md` | 14 | #147 상태를 완료로 갱신 |
| `mydocs/working/task_m016_147_stage4.md` | 92 | Stage 4 변경 요약과 최종 검증 결과 |
| `mydocs/report/task_m016_147_report.md` | 75 | Task #147 최종 결과보고서 |

## 본문 변경 정도 / 본문 무손실 여부

README에는 긴 third-party license 표를 복제하지 않고 하단 License 섹션에 짧은 진입점만 추가했다. `THIRD_PARTY_LICENSES.md`, `FONTS.md`, `font_fallback_strategy.md`의 Stage 3 책임 경계는 유지했다.

오늘할일은 `#147` 행만 `진행중`에서 `완료`로 바꾸고 비고를 `완료: 14:51`로 갱신했다.

## 검증 결과

### 브랜치 상태

```text
$ git status --short --branch
## local/task147
 M README.md
 M mydocs/orders/20260506.md
```

### rhwp-studio asset 검증

```text
$ scripts/verify-rhwp-studio-assets.sh
OK: rhwp-studio assets verified at /Users/melee/Documents/projects/rhwp-mac/Sources/HostApp/Resources/rhwp-studio
```

### bundled WOFF2 수량

```text
$ find Sources/HostApp/Resources/rhwp-studio/fonts -maxdepth 1 -name '*.woff2' -type f | sort | wc -l
      34
```

### README/license/provenance 검색

```text
$ rg -n "Third Party|THIRD_PARTY_LICENSES|rhwp-core.lock|manifest.json|FONTS.md|rhwp-studio|WOFF2|proprietary" README.md THIRD_PARTY_LICENSES.md Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md mydocs/tech/font_fallback_strategy.md
```

핵심 match:

- `README.md`: License 섹션에서 `THIRD_PARTY_LICENSES.md`, `rhwp-core.lock`, `rhwp-studio manifest`, `FONTS.md` 링크 확인
- `THIRD_PARTY_LICENSES.md`: `Third Party Licenses`, `rhwp-core.lock`, `manifest.json`, `rhwp-studio`, WOFF2 34개, proprietary font 비포함 정책 확인
- `FONTS.md`: `rhwp-studio/fonts` WOFF2 목록과 proprietary font 비포함 정책 확인
- `font_fallback_strategy.md`: `THIRD_PARTY_LICENSES.md`와 `FONTS.md` 연결 확인

### whitespace 검증

```text
$ git diff --check
통과
```

### 작업 브랜치 커밋 목록

```text
$ git log --oneline devel-webview..local/task147
ebf87d0 Task #147 Stage 3: third-party license와 font 고지 보강
733dcac Task #147 Stage 2: license 고지 구조 설계
17e77f6 Task #147 Stage 1: license provenance inventory 정리
3ad2943 Task #147: 구현 계획서 작성
92603b2 Task #147: 수행 계획서 작성과 오늘할일 갱신
```

Stage 4 커밋은 이 보고서와 최종 보고서를 포함해 추가될 예정이다.

## 잔여 위험

- upstream `rhwp` 최신 release는 `v0.7.10`으로 확인되었지만, 현재 앱 artifact 고지는 실제 pin인 `v0.7.9` 기준이다. core/asset pin을 갱신하면 고지도 함께 갱신해야 한다.
- bundled `rhwp-studio` JS/CSS/WASM의 transitive npm dependency license inventory는 별도 manifest가 없어 이번 작업 범위에 포함하지 않았다.
- “무료 배포” font의 재배포 조건은 기존 문서 표현을 유지했으며, 법률 자문 수준으로 재해석하지 않았다.

## 다음 단계 영향

Stage 4 완료 후 PR 게시 전 승인 요청 단계로 넘어간다. 승인되면 `publish/task147` 원격 브랜치와 `devel-webview` 대상 PR을 준비한다.

## 승인 요청

Stage 4와 Task #147 최종 보고서 작성을 완료한다. 다음 단계는 PR 게시 승인이다.
