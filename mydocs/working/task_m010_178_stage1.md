# Issue #178 Stage 1 완료 보고서

## 단계 목적

두 번째 `app-intro` 섹션의 상단 진입 여백, 철학 설명 위계, 스크린샷 크기를 좁은 범위에서 보강했다.

이번 단계는 구현계획서의 Stage 1에 따라 `docs/index.html`과 `docs/styles.css`만 수정했다. 브라우저 실측과 반응형 추가 보정은 Stage 2에서 진행한다.

## 산출물

| 파일 | 라인 수 | 요약 |
|------|---------|------|
| `docs/index.html` | 334 | 철학 설명을 단일 회색 단락에서 두 문장 구조의 `.app-intro-philosophy` 블록으로 변경 |
| `docs/styles.css` | 1774 | 두 번째 섹션 상단 정렬, 내부 gap, 철학 설명 hairline 영역, 스크린샷/기능 요약 폭 확대, 모바일 override 보정 |
| `mydocs/working/task_m010_178_stage1.md` | 신규 | Stage 1 완료 보고서 |

## 변경 내용

- `.app-intro-section`의 `min-height: 100svh`와 중앙 정렬 효과를 제거하고 상단 진입 리듬에 맞게 padding을 재조정했다.
- 리드 문구 `HWP/HWPX 문서를 Mac에서 빠르게 확인하고, 편집하고, 공유하세요.`는 그대로 유지했다.
- 철학 설명은 다음 두 문장 구조로 재구성했다.
  - `문서 접근은 특정 프로그램 구매 여부에 묶이면 안 됩니다.`
  - `알한글은 한글을 설치하기 어려운 Mac에서도 필요한 HWP/HWPX 문서를 확인하고 제출할 수 있게 만드는 오픈소스 도구입니다.`
- 철학 설명 영역에 얇은 top/bottom hairline을 적용하고, 첫 문장은 본문보다 강하게, 두 번째 문장은 muted 설명으로 보이게 했다.
- `og-main.png` 스크린샷 컨테이너 폭을 데스크톱 기준 `960px`에서 `1160px`까지 키울 수 있게 조정했다.
- 스크린샷 확대에 맞춰 기능 요약 4개 항목의 전체 폭과 gap도 확장했다.
- tablet/mobile override에서 스크린샷 폭, 철학 설명 padding, 모바일 type scale을 새 구조에 맞게 보정했다.

## 본문 무손실 여부

요청받은 리드 문구는 변경하지 않았다.

```text
docs/index.html:88:            HWP/HWPX 문서를 Mac에서 빠르게 확인하고, 편집하고, 공유하세요.
```

철학 설명은 작업지시자의 요청에 맞춰 표현 방식과 문장을 재작성했다.

## 검증 결과

실행한 명령:

```bash
rg -n "문서 접근은 특정 프로그램 구매 여부|app-intro-philosophy|app-intro-media|app-intro-capabilities" docs/index.html docs/styles.css
git diff --check -- docs/index.html docs/styles.css mydocs/working/task_m010_178_stage1.md
rg -n "HWP/HWPX 문서를 Mac에서 빠르게 확인하고, 편집하고, 공유하세요\\." docs/index.html
wc -l docs/index.html docs/styles.css
git diff --stat -- docs/index.html docs/styles.css
```

주요 출력:

```text
docs/index.html:91:            <p class="app-intro-principle">문서 접근은 특정 프로그램 구매 여부에 묶이면 안 됩니다.</p>
docs/styles.css:338:.app-intro-philosophy {
docs/styles.css:365:.app-intro-media {
docs/styles.css:384:.app-intro-capabilities {
docs/index.html:88:            HWP/HWPX 문서를 Mac에서 빠르게 확인하고, 편집하고, 공유하세요.
     334 docs/index.html
    1774 docs/styles.css
    2108 total
 docs/index.html |  8 ++++----
 docs/styles.css | 61 ++++++++++++++++++++++++++++++++++++++++++---------------
 2 files changed, 49 insertions(+), 20 deletions(-)
```

`git diff --check`는 출력 없이 통과했다.

## 잔여 위험

- 실제 브라우저에서 스크린샷 확대 후 세로 길이가 의도보다 길게 느껴질 수 있다.
- 작은 모바일 폭에서 철학 설명 두 번째 문장의 줄바꿈이 많아질 수 있다.
- `min-height` 제거로 두 번째 섹션과 다음 Feature 섹션 사이의 체감 리듬은 브라우저에서 다시 확인해야 한다.

## 다음 단계 영향

Stage 2에서 로컬 브라우저를 열어 데스크톱과 모바일 폭을 확인하고, 필요하면 spacing과 responsive 값을 추가 보정한다. `docs/script.js`는 이번 단계에서 변경하지 않았으나, reveal timing이 시각적으로 어색하지 않은지 Stage 2에서 확인한다.

## 승인 요청

Stage 1 산출물 기준으로 Stage 2 `브라우저 시각 검증과 반응형 보정`을 진행할지 승인 요청한다.
