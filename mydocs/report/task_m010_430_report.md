# Issue #430 최종 결과 보고서

## 작업 요약

- 이슈: [#430](https://github.com/postmelee/alhangeul-macos/issues/430)
- 마일스톤: M010 / v0.1
- 통합 대상: `devel`
- 작업 브랜치: `local/task430`
- 단계 수: Stage 1 구현 경계 확정, Stage 2 HTML/CSS 구현, Stage 3 시각·artifact 검증, Stage 4 최종 보고와 PR 게시
- 배포 단계: PR merge 이후 Stage 5 `main` 승격과 public Pages 배포 별도 승인 대기

GitHub Pages 홈의 FAQ 다음이자 footer 직전 위치에 프로젝트의 문서 접근 철학을 독립 섹션으로 추가했다. 긴 제목은 기본 400 굵기로 두고 `문서 접근`과 `특정 프로그램 구매 여부`만 기존 섹션 헤더와 같은 600 굵기로 강조했으며, `문서 접근`에는 기존 파란색 accent를 적용했다.

링크 공유용 Open Graph 설명은 `Mac에서 HWP/HWPX를 미리보고 편집하고 공유하는 오픈소스 앱입니다.`로 간결하게 변경했다. footer 문구와 다른 Pages 문서, 앱 소스, Pages workflow와 Sparkle appcast는 변경하지 않았다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `docs/index.html` | Open Graph 설명 변경, FAQ 뒤·footer 앞에 철학 섹션 markup 추가, stylesheet cache query 갱신 |
| `docs/styles.css` | 철학 섹션의 경계선·폭·제목/설명 위계·강조·반응형 크기·대칭 여백 추가 |
| `mydocs/orders/20260721.md` | #430 등록과 Stage 4 완료 처리 |
| `mydocs/plans/task_m010_430.md` | 작업 범위, 설계 방향, 검증과 배포 승인 gate를 담은 수행계획 작성 |
| `mydocs/plans/task_m010_430_impl.md` | Stage 1~5 대상·작업·검증·완료 조건을 담은 구현계획 작성 |
| `mydocs/working/task_m010_430_stage1.md` | 승인 시안, footer 무손실과 docs-only 배포 경계 조사 기록 |
| `mydocs/working/task_m010_430_stage2.md` | Open Graph 설명·철학 섹션 구현과 정적 검증 기록 |
| `mydocs/working/task_m010_430_stage3.md` | 데스크톱·모바일 시각 검증과 Pages artifact/appcast 보존 검증 기록 |
| `mydocs/report/task_m010_430_report.md` | 최종 변경·검증·잔여 위험과 후속 승인 사항 정리 |

## 변경 전·후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| 본문 독립 철학 섹션 | 0개 | 1개, FAQ 다음·footer 직전 |
| 철학 제목 강조 | 해당 없음 | 기본 400, 핵심 구절 2개 600 |
| 철학 제목 크기 | 해당 없음 | 데스크톱 40px / 태블릿 38px / 모바일 32px |
| 철학 섹션 위아래 여백 | 해당 없음 | 데스크톱 `clamp(88px, 10vh, 120px)` / 모바일 68px 대칭 |
| 구현 파일 | 0개 | HTML/CSS 2개 |
| 구현 파일 diff | 해당 없음 | `docs/index.html` +13/-2, `docs/styles.css` +61/-0 |
| 반응형 자동 확인 | 미확인 | 1440×1000, 390×844 두 viewport |
| 가로 overflow | 미확인 | 두 viewport 모두 0px |
| 브라우저 warning/error | 미확인 | 0건 |
| Pages artifact appcast | 미확인 | 공개 원본과 SHA-256 일치 |

## 검증 결과

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| Open Graph 설명 단축 | OK | 승인 문구가 `docs/index.html`과 생성 artifact 홈에 존재 |
| 철학 섹션 위치 | OK | DOM에서 FAQ 다음, footer 직전이며 접근 가능한 level 2 heading으로 확인 |
| 제목 문구와 강조 범위 | OK | `문서 접근`, `특정 프로그램 구매 여부`만 600; 전자에만 accent 적용 |
| 기존 헤더와 제목 크기 일치 | OK | 1440px에서 철학/FAQ 40px, 390px에서 철학/FAQ 32px |
| 위아래 여백 대칭 | OK | 1440px에서 100px/100px, 390px에서 68px/68px |
| 모바일 줄바꿈과 overflow | OK | 제목 2줄, 설명 3줄, 가로 overflow 0px |
| reveal 동작 | OK | 섹션 `is-revealed`, 두 항목 opacity 1, identity transform |
| footer 무손실 | OK | 홈·업데이트·문의/제보 페이지에 기존 제품 설명 유지 |
| JavaScript 문법 | OK | `node --check docs/script.js` 통과 |
| 업데이트 문구 정합성 | OK | latest v0.1.8 기준 검사 통과 |
| 공개 appcast XML | OK | `xmllint --noout` 통과, 최신 item `Alhangeul v0.1.8` 확인 |
| Pages artifact 구성 | OK | 홈·업데이트 페이지·appcast 존재 및 artifact appcast XML 유효 |
| appcast 무손실 보존 | OK | 공개 원본과 artifact SHA-256 `fd1c25bb...14af4` 일치 |
| Git 변경 형식 | OK | `git diff --check -- docs mydocs` 통과 |
| 통합 브랜치 기준 | OK | `origin/devel`이 `local/task430`의 조상, 차이 0/4 |

## 실행한 검증 명령

```bash
rg -n "og:description|philosophy-section|philosophy-title|philosophy-highlight|philosophy-emphasis" docs/index.html docs/styles.css
rg -n "한글 파일이 더 이상 낯선 파일로 남지 않도록 만듭니다" docs/index.html docs/updates/index.html docs/feedback/index.html
node --check docs/script.js
scripts/ci/update-release-version-notices.sh --updates-dir docs/updates --check
xmllint --noout /tmp/task430-public-appcast.xml
scripts/ci/prepare-pages-artifact.sh --docs-dir docs --appcast /tmp/task430-public-appcast.xml --output-dir build.noindex/task430-pages-artifact
test -f build.noindex/task430-pages-artifact/index.html
test -f build.noindex/task430-pages-artifact/updates/index.html
xmllint --noout build.noindex/task430-pages-artifact/appcast.xml
cmp -s /tmp/task430-public-appcast.xml build.noindex/task430-pages-artifact/appcast.xml
git diff --check -- docs mydocs
git merge-base --is-ancestor origin/devel local/task430
git rev-list --left-right --count origin/devel...local/task430
```

수동·브라우저 확인:

- 로컬 서버 `http://127.0.0.1:8080/#philosophy-title`에서 데스크톱·모바일 렌더링 확인
- FAQ, 철학 섹션과 footer의 시각적 연결 확인
- 제목 강조, 한국어 줄바꿈, 설명 폭과 대칭 여백 확인
- 브라우저 콘솔 warning/error 0건 확인

## 잔여 위험과 후속 작업

- 이 보고서 시점에는 `devel` 대상 PR, PR CI와 merge가 아직 완료되지 않았다. 리뷰와 merge는 작업지시자 승인이 필요하다.
- Task #430의 public Pages 배포는 PR merge 뒤 Stage 5에서 수행한다. 이 보고서 작성 시점의 `origin/main...origin/devel` 차이는 `1 / 4`이므로 `main` 승격 포함 범위를 다시 확인하고 별도 승인받아야 한다.
- 실제 docs-only workflow는 공개 appcast 다운로드, GitHub Pages 권한과 배포 환경에 의존한다. 실패 시 stale repository appcast로 대체하지 않고 안전하게 중단하는 기존 정책을 유지한다.
- workflow 성공 직후에는 CDN 캐시로 공개 HTML/CSS 반영이 잠시 지연될 수 있다.
- 새 앱 버전, release tag, DMG, appcast 항목, Homebrew Cask와 workflow 자체는 이 작업에서 변경하지 않는다.

## 작업지시자 승인 요청

Task #430의 구현과 PR 전 검증을 완료했다. `publish/task430` 브랜치를 게시하고 `devel` 대상 Open PR을 생성한 뒤 리뷰와 merge 승인을 요청한다.

PR merge 이후에는 최신 `origin/main...origin/devel` 포함 범위를 제시하고 Stage 5 `main` 승격과 public Pages 배포 승인을 별도로 요청한다.
