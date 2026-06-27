# Task M040 #383 최종 보고서

## 작업 요약

- GitHub Issue: [#383](https://github.com/postmelee/alhangeul-macos/issues/383)
- 마일스톤: M040 (`v0.4`)
- 브랜치: `local/task383`
- 기준 브랜치: `devel`
- 단계 수: 4단계
  - Stage 1: 랜딩페이지 문의/제보 구조 구현
  - Stage 2: 반응형 브라우저 검증
  - Stage 3: 최종 보고와 PR 준비
  - Stage 4: PR 리뷰 피드백 반영과 별도 문의/제보 페이지 정리

비개발자나 GitHub 계정을 사용하지 않는 사용자가 알한글 사용 중 발견한 오류, 렌더링 차이, 설치 문제를 공식 이메일로 쉽게 제보할 수 있게 GitHub Pages 문서에 문의/제보 경로를 추가했다. 초기에는 홈 화면의 FAQ 아래 섹션으로 구성했지만, 리뷰와 시각 피드백을 반영해 `/feedback/` 별도 페이지로 분리하고 업데이트 페이지와 같은 헤더/푸터/콘텐츠 폭을 사용하도록 정리했다.

최종 UI는 상단에 `문의 / 제보` 제목과 안내 문구를 두고, 민감한 정보 안내 박스를 카드 위에 배치했다. 제보 경로는 이메일 카드와 GitHub Issue 카드로 나누며, 이메일 주소 복사 버튼과 `mailto:` CTA, GitHub 공식 mark를 포함한 Issue CTA를 제공한다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `docs/feedback/index.html` | 별도 문의/제보 페이지 추가, 이메일/GitHub Issue 카드, 민감한 정보 안내, `mailto:` 템플릿, GitHub Issue CTA 구성 |
| `docs/index.html` | 홈 헤더에 `문의/제보` 링크 추가, FAQ 오류 제보 답변을 GitHub Issue -> 이메일 -> rhwp upstream 순서로 분리 |
| `docs/updates/index.html` | 업데이트 페이지 헤더에 `문의/제보` 링크 추가 |
| `docs/styles.css` | feedback 페이지 hero/notice/card/button/copy 상태 스타일 추가, sticky header 유지, footer 하단 공백 회귀 수정 |
| `docs/script.js` | 이메일 주소 복사 버튼 동작과 clipboard fallback 추가 |
| `mydocs/orders/20260626.md` | #383 오늘할일 항목과 최종 PR 준비 상태 갱신 |
| `mydocs/plans/task_m040_383.md` | 수행계획서 작성 |
| `mydocs/plans/task_m040_383_impl.md` | 구현계획서 작성 |
| `mydocs/working/task_m040_383_stage1.md` | Stage 1 구조 구현 결과와 정적 검증 기록 |
| `mydocs/working/task_m040_383_stage2.md` | Stage 2 브라우저 반응형 검증 결과 기록 |
| `mydocs/working/task_m040_383_stage4.md` | Stage 4 리뷰/시각 피드백 반영 결과 기록 |
| `mydocs/report/task_m040_383_report.md` | 최종 결과와 검증 결과 정리 |

## 변경 전·후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| 헤더 문의/제보 링크 | 없음 | 홈/업데이트 헤더에 `/feedback/` 링크 추가 |
| 공식 이메일 제보 경로 | 랜딩페이지에 없음 | `alhangeul.feedback@gmail.com` 안내, 복사 버튼, `mailto:` 템플릿 추가 |
| GitHub Issue 안내 | FAQ 중심 | 별도 카드 CTA와 FAQ 답변에 유지 |
| 민감한 정보 안내 | 없음 | 카드 위 안내 박스로 주민등록번호/연락처/내부 문서 원본 공유 주의 추가 |
| 문의/제보 화면 위치 | 없음 | `/feedback/` 별도 페이지 |
| 카드형 제보 경로 | 없음 | 이메일/GitHub Issue 2열 카드, 모바일 1열 stack |
| FAQ 오류 제보 답변 | 단일 문단 | GitHub Issue, 이메일, rhwp upstream 순서로 문단 분리 |
| 반응형 검증 viewport | 없음 | desktop/mobile 브라우저 시각 검증과 overflow 확인 |
| 변경 통계 | 기준 `devel` | 12 files changed, 1208 insertions, 13 deletions |

주요 파일 line count:

```text
     261 docs/index.html
     122 docs/feedback/index.html
     133 docs/updates/index.html
    1726 docs/styles.css
     305 docs/script.js
      98 mydocs/plans/task_m040_383.md
     154 mydocs/plans/task_m040_383_impl.md
      89 mydocs/working/task_m040_383_stage1.md
     150 mydocs/working/task_m040_383_stage2.md
      58 mydocs/working/task_m040_383_stage4.md
```

## 검증 결과

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| 헤더에서 문의/제보 페이지로 이동 | OK | 홈/업데이트 헤더의 `문의/제보` 링크가 `/feedback/`로 연결됨 |
| 별도 문의/제보 페이지 제공 | OK | `docs/feedback/index.html` 추가, 로컬 서버에서 `/feedback/` 200 확인 |
| 이메일 제보 경로 제공 | OK | 이메일 주소 링크, `mailto:alhangeul.feedback@gmail.com` CTA, 복사 버튼 확인 |
| GitHub Issue 경로 제공 | OK | GitHub mark 포함 `GitHub Issue` CTA가 저장소 Issues로 연결됨 |
| 민감한 정보 안내 제공 | OK | 카드 위 안내 박스에 주민등록번호/연락처/내부 문서 원본 공유 주의 문구 반영 |
| 카드형 desktop/mobile layout | OK | desktop 2열, mobile 1열 stack 및 overflow 없음 확인 |
| FAQ 오류 제보 답변 순서 | OK | GitHub Issue -> 이메일 -> rhwp upstream 순서로 문단 분리 |
| sticky header 회귀 방지 | OK | `.site-header { position: sticky; top: 0; }` 유지 확인 |
| footer 하단 공백 회귀 수정 | OK | `body`/`main` flex layout 적용 후 large viewport에서 footer bottom gap 0 확인 |
| Pages artifact 포함 가능성 | OK | `prepare-pages-artifact.sh`가 `docs/` 전체를 복사하므로 `/feedback/index.html` 포함 |
| 정적 diff 검증 | OK | `git diff --check` 통과 |

실행한 주요 명령:

```bash
git diff --check
curl -I http://127.0.0.1:8767/feedback/
rg -n "문의 / 제보|feedback-privacy-note|feedback-card-grid|feedback-copy-button|GitHub Issue" docs/feedback/index.html docs/styles.css docs/script.js
git log --oneline devel..local/task383
git diff --stat devel..local/task383
scripts/ci/prepare-pages-artifact.sh --docs-dir docs --appcast build.noindex/task383/appcast.xml --output-dir build.noindex/task383/pages-artifact
test -f build.noindex/task383/pages-artifact/feedback/index.html
```

브라우저 시각 검증은 `docs/`를 로컬 정적 서버로 제공한 뒤 수행했다.

```bash
python3 -m http.server 8767 --bind 127.0.0.1 --directory docs
```

검증 URL:

```text
http://127.0.0.1:8767/feedback/
```

## GitHub Pages 배포 조건

`.github/workflows/pages-docs-deploy.yml` 기준으로 docs-only Pages 배포는 `main` 브랜치의 `docs/**` push 또는 수동 `workflow_dispatch`에서만 실행된다. 이번 작업 PR은 프로젝트 정책에 따라 `devel`을 base로 생성하므로, PR을 `devel`에 merge하는 것만으로 GitHub Pages 배포가 즉시 실행되지는 않는다.

이 변경이 이후 `main`으로 병합되어 `docs/**` 변경 push가 발생하면 docs-only Pages workflow가 실행되고, public `appcast.xml` 보존과 release asset gate를 통과한 뒤 GitHub Pages에 배포된다.

## 잔여 위험과 후속 작업

- `mailto:` 클릭은 외부 메일 앱을 여는 동작이므로 실제 메일 전송은 수행하지 않고 href 값과 CTA 노출로 검증했다.
- Browser 시각 검증은 로컬 Firefox/브라우저 기반이다. Safari/Chrome 사용자 환경별 세부 렌더 차이는 별도 확인하지 않았다.
- `docs/styles.css`에는 과거 홈 섹션용 feedback selector 일부가 남아 있다. 현재 `/feedback/` 페이지 동작에는 영향이 없지만, 이후 랜딩페이지 CSS 정리 작업에서 제거 후보로 볼 수 있다.
- 실제 GitHub Pages 배포는 `devel` merge 후가 아니라 `main` 반영 후 수행된다.

## 작업지시자 승인 요청

최종 보고서와 PR 게시 산출물 검토를 요청한다. PR 리뷰에서는 `/feedback/` 별도 페이지의 desktop/mobile 배치, 이메일 복사 버튼, `mailto:` 템플릿, Pages 배포 조건을 중점 확인하면 된다.
