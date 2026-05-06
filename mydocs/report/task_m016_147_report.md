# Task #147 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#147 third-party font/license 및 bundled rhwp-studio 자산 고지 정리](https://github.com/postmelee/alhangeul-macos/issues/147) |
| 마일스톤 | M016 / v0.1 출시 전 보강 |
| 기준 브랜치 | `devel-webview` |
| 작업 브랜치 | `local/task147` |
| 단계 수 | 4단계 |
| 결론 | v0.1 artifact 기준 third-party license/provenance 고지 구조를 정리하고, `rhwp`, bundled `rhwp-studio`, bundled WOFF2 font, proprietary font 비포함 정책을 release 사용자가 따라갈 수 있게 문서화했다. |

현재 앱 artifact 기준은 `rhwp-core.lock`과 `Sources/HostApp/Resources/rhwp-studio/manifest.json`의 `v0.7.9` / `0fb3e6758b8ad11d2f3c3849c83b914684e83863`이다. Stage 2에서 upstream 최신 `v0.7.10`을 확인했지만, 이번 작업은 core/asset pin 갱신이 아니라 현재 포함된 artifact 고지 정리로 범위를 유지했다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `THIRD_PARTY_LICENSES.md` | release artifact 기준 scope, `rhwp` core pin, Rust bridge generated artifacts, bundled `rhwp-studio` static assets, bundled WOFF2, proprietary font 비포함 정책을 추가했다. |
| `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md` | Alhangeul v0.1 bundle 기준 문구로 정리하고, `LatinModernMath-Regular.woff2`와 Happiness Sans 개별 파일명을 보강했다. |
| `mydocs/tech/font_fallback_strategy.md` | 사용자용 third-party 고지 위치를 `THIRD_PARTY_LICENSES.md`로 연결했다. |
| `README.md` | License 섹션에 `THIRD_PARTY_LICENSES.md`, `rhwp-core.lock`, `rhwp-studio/manifest.json`, `FONTS.md` 진입점을 추가했다. |
| `mydocs/orders/20260506.md` | #147 오늘할일 상태를 완료로 갱신했다. |
| `mydocs/plans/task_m016_147.md` | 수행계획서를 작성했다. |
| `mydocs/plans/task_m016_147_impl.md` | 4단계 구현계획서를 작성했다. |
| `mydocs/working/task_m016_147_stage1.md` | current artifact provenance와 bundled font inventory를 조사했다. |
| `mydocs/working/task_m016_147_stage2.md` | license/attribution 문서 구조와 upstream `v0.7.10` 확인 결과를 정리했다. |
| `mydocs/working/task_m016_147_stage3.md` | third-party/license font 고지 보강 결과와 검증을 기록했다. |
| `mydocs/working/task_m016_147_stage4.md` | README 진입점과 최종 검증 결과를 기록했다. |
| `mydocs/report/task_m016_147_report.md` | 최종 결과보고서를 작성했다. |

## 변경 전·후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| `THIRD_PARTY_LICENSES.md` | 10줄, `rhwp` MIT 고지만 존재 | 63줄, artifact scope/provenance/font 정책 포함 |
| `FONTS.md` | 77줄, `LatinModernMath-Regular.woff2` 직접 항목 없음 | 81줄, 실제 bundle 누락 항목과 Happiness Sans 파일명 보강 |
| `font_fallback_strategy.md` | 62줄, `FONTS.md`만 연결 | 62줄, `THIRD_PARTY_LICENSES.md` 사용자 고지 연결 추가 |
| `README.md` | 454줄, MIT license 링크만 존재 | 457줄, Third Party notices/provenance 링크 추가 |
| bundled WOFF2 파일 | 34개 | 34개, 파일 추가/삭제 없음 |

## 단계별 결과

| 단계 | 커밋 | 결과 |
|------|------|------|
| 계획 | `92603b2` | 수행계획서와 오늘할일 항목을 작성했다. |
| 구현계획 | `3ad2943` | 4단계 구현계획서를 작성했다. |
| Stage 1 | `17e77f6` | `rhwp-core.lock`, `rhwp-studio/manifest.json`, WOFF2 34개, proprietary font 비포함 상태를 조사했다. |
| Stage 2 | `733dcac` | 문서별 책임 경계를 설계하고 upstream `v0.7.10`은 현재 app artifact와 분리하기로 정리했다. |
| Stage 3 | `ebf87d0` | `THIRD_PARTY_LICENSES.md`, `FONTS.md`, `font_fallback_strategy.md`를 실제 보강했다. |
| Stage 4 | 이번 최종 보고 커밋 | README 진입점, 오늘할일 완료 처리, Stage 4 보고서와 최종 보고서를 정리했다. |

## 검증 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| `scripts/verify-rhwp-studio-assets.sh` | OK | bundled `rhwp-studio` asset 구조와 entrypoint 검증 |
| bundled WOFF2 count | OK | `find ... -name '*.woff2' ... | wc -l` 결과 34 |
| license/provenance keyword scan | OK | README, `THIRD_PARTY_LICENSES.md`, `FONTS.md`, `font_fallback_strategy.md`에서 핵심 링크와 정책 확인 |
| proprietary font file check | OK | Stage 1에서 proprietary 후보 파일명은 실제 resource tree에 없음 확인 |
| `git diff --check` | OK | whitespace error 없음 |

## 잔여 위험과 후속 작업

| 구분 | 내용 |
|------|------|
| core update | upstream `rhwp` 최신 release는 `v0.7.10`이다. 별도 core/asset pin update를 진행하면 `THIRD_PARTY_LICENSES.md`, README, `rhwp-core.lock`, `manifest.json`을 함께 갱신해야 한다. |
| transitive licenses | bundled `rhwp-studio` JS/CSS/WASM의 transitive npm dependency license manifest는 이번 범위에 포함하지 않았다. 필요하면 별도 dependency license manifest 작업으로 분리한다. |
| font redistribution | `FONTS.md`의 “무료 배포” font는 기존 표현을 유지했다. 법률 자문 수준의 재해석은 별도 검토가 필요하다. |
| PR 이후 | PR merge 후 issue close와 branch/worktree cleanup은 merge 확인 후 별도 cleanup 절차로 진행한다. |

## 작업지시자 승인 요청

Task #147의 third-party font/license와 bundled `rhwp-studio` 자산 고지 정리를 완료했다. 다음 단계는 `publish/task147` 브랜치 push와 `devel-webview` 대상 PR 생성 승인이다.
