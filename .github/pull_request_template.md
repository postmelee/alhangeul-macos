## 요약

<!-- 최대 4개 bullet로 압축합니다.
- 대상 타스크는 무엇인가요?
- 왜 변경했나요?
- 무엇을 변경했나요?
- 리뷰어가 먼저 볼 지점은 무엇인가요?
-->

- 대상 타스크: #
- 왜:
- 무엇:
- 리뷰 포인트:

## PR base

<!--
제품/WKWebView/Finder/Quick Look/배포/문서/Skia 공통 기반 작업은 `devel`을 base로 둡니다.
HostApp native macOS shell, Skia viewport, Swift 편집 UI/오버레이 작업은 `native-viewer-editor`를 base로 둡니다.
`main`은 release PR 전용이며, 퇴역한 `devel-webview`는 PR base로 사용하지 않습니다.
-->

- base:

## 변경 내역

<!--
Stage 기반 작업이면 Stage당 1줄로 적습니다.
Stage 제목은 단계 보고서로, 짧은 커밋 SHA는 commit URL로 링크합니다.
예: **[Stage 1](stage-url)** ([0cdbae0](commit-url)): 한 줄 요약
-->

- **[Stage 1](stage-url)** ([0cdbae0](commit-url)):

<!-- 주요 파일/영역은 최대 5행만 남깁니다. 필요 없으면 표를 삭제합니다. -->

| 영역 | 변경 | 리뷰 포인트 |
|------|------|-------------|
|  |  |  |

<!--
작업 문서는 PR 생성 직전 `git rev-parse HEAD`로 확인한 PR head commit SHA 기준 GitHub blob URL을 사용합니다.
raw URL 대신 `[파일명](https://github.com/postmelee/alhangeul-macos/blob/{head_sha}/mydocs/...)` 형식으로 적습니다.
해당 없는 항목은 삭제합니다.
-->

- 수행 계획서: [task_m{milestone}_{issue}.md](https://github.com/postmelee/alhangeul-macos/blob/{head_sha}/mydocs/plans/task_m{milestone}_{issue}.md)
- 구현 계획서: [task_m{milestone}_{issue}_impl.md](https://github.com/postmelee/alhangeul-macos/blob/{head_sha}/mydocs/plans/task_m{milestone}_{issue}_impl.md)
- 최종 보고서: [task_m{milestone}_{issue}_report.md](https://github.com/postmelee/alhangeul-macos/blob/{head_sha}/mydocs/report/task_m{milestone}_{issue}_report.md)

## 핵심 리뷰 포인트

<!-- 필요한 경우만 유지합니다. 최대 3개, 코드 블록은 각 20줄 이하로 제한합니다. 해당 없으면 섹션을 삭제합니다. -->

-

## 검증

<!-- 어떻게 검증했나요? 실제 실행한 명령과 수동 확인만 남기고, 실행하지 않은 항목은 삭제합니다.

Finder/Quick Look/Thumbnail extension 관련 변경이면 아래 항목을 유지하고 채웁니다.
- Debug app이 아니라 Release package 또는 표준 smoke helper 설치본으로 Finder integration을 확인했나요?
- `pluginkit -mAvvv`의 active provider path가 기대 설치본 내부였나요?
- `scripts/check-extension-registration-hygiene.sh --check-only` 결과가 깨끗했나요?
- `build.noindex/` 또는 Xcode DerivedData 아래 개발 산출물 registration이 남지 않았나요?
- 수동 `lsregister`/`pluginkit` 등록을 했다면 같은 검증 안에서 unregister와 `qlmanage -r cache`까지 수행했나요?
-->

-

## 스크린샷

<!-- 시각적 변경사항이 있을 때만 유지합니다. 실제 이미지나 산출물 없이 형식만 채우지 않습니다. 해당 없으면 섹션을 삭제합니다. -->

| Before | After |
|--------|-------|
|  |  |

## 관련 이슈

<!-- 현재 PR의 대상 타스크가 아니라, PR 이해에 필요한 선행/후속/Epic/upstream/참고 이슈를 적습니다. 해당 없으면 "없음"으로 적습니다. -->

-

## 후속 이슈 제안

<!-- 아직 이슈가 없지만 분리할 후보를 적습니다. 없으면 "없음"으로 적습니다. -->

-

## 남은 리스크

<!-- 리뷰어가 알아야 할 검증 한계나 운영상 주의사항을 적습니다. 없으면 "없음"으로 적습니다. -->

-
