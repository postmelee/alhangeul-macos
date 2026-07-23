# Issue #430 Stage 1 완료 보고서

## 단계 목적

GitHub Pages 홈의 승인된 철학 섹션 시안과 현재 문서 구조를 대조하고, 기존 docs-only Pages 배포 경계를 확인해 구현·검증·PR·배포 단계를 실행 가능한 구현계획으로 확정한다.

## 산출물

- `mydocs/plans/task_m010_430_impl.md` 신규 작성
  - 233줄
  - 구현 원칙과 사전 조사 결과 기록
  - Stage 1부터 Stage 5까지 대상, 작업, 검증, 완료 조건과 예상 커밋 정의
  - footer 무손실, public appcast 보존, `main` 승격 별도 승인 지점 명시
- `mydocs/working/task_m010_430_stage1.md` 신규 작성
  - Stage 1 조사·검증 결과와 다음 단계 승인 요청 기록

## 본문 변경 정도 / 본문 무손실 여부

Stage 1에서는 `docs/` 소스를 수정하지 않았다. 다음 명령의 종료 코드 `0`으로 작업 브랜치의 `docs/`가 `HEAD`와 동일함을 확인했다.

```text
$ git diff --quiet HEAD -- docs; echo $?
0
```

승인 시안 stash의 대상 파일은 다음 두 개뿐이다.

```text
docs/index.html
docs/styles.css
```

현행 footer 원문은 홈, 업데이트, 문의/제보 페이지에 모두 유지되어 있다.

```text
docs/index.html:251: Mac을 위한 HWP/HWPX 문서 미리보기 및 편집 앱입니다. 한글 파일이 더 이상 낯선 파일로 남지 않도록 만듭니다.
docs/updates/index.html:130: Mac을 위한 HWP/HWPX 문서 미리보기 및 편집 앱입니다. 한글 파일이 더 이상 낯선 파일로 남지 않도록 만듭니다.
docs/feedback/index.html:113: Mac을 위한 HWP/HWPX 문서 미리보기 및 편집 앱입니다. 한글 파일이 더 이상 낯선 파일로 남지 않도록 만듭니다.
```

따라서 Stage 1의 Pages 본문과 footer는 무손실이며, Stage 2에서도 승인 시안의 두 파일만 선택 적용하도록 범위를 고정했다.

## 검증 결과

구현계획의 단계와 핵심 배포 경계를 검색했다.

```text
$ rg -n "Stage 1|Stage 2|Stage 3|Stage 4|Stage 5|footer|appcast|main" mydocs/plans/task_m010_430_impl.md
Stage 1~5 제목 확인
footer 무손실 확인 항목 확인
public appcast 보존 항목 확인
main 승격 별도 승인 항목 확인
```

docs-only Pages workflow의 실행·artifact 보존 조건을 확인했다.

```text
.github/workflows/pages-docs-deploy.yml:6:    branches:
.github/workflows/pages-docs-deploy.yml:7:      - main
.github/workflows/pages-docs-deploy.yml:9:      - "docs/**"
.github/workflows/pages-docs-deploy.yml:34:          if [ "$GITHUB_REF" != "refs/heads/main" ]; then
.github/workflows/pages-docs-deploy.yml:144:      - name: Fetch current public appcast
.github/workflows/pages-docs-deploy.yml:181:          scripts/ci/prepare-pages-artifact.sh \
.github/workflows/pages-docs-deploy.yml:189:          xmllint --noout "$pages_artifact_dir/appcast.xml"
```

현재 원격 통합·배포 브랜치 차이는 다음과 같다.

```text
$ git rev-list --left-right --count origin/main...origin/devel
1    4
```

`origin/main` 전용 커밋 1개와 `origin/devel` 전용 커밋 4개가 있어 Task #430 PR을 `devel`에 merge하는 것만으로는 공개 배포 범위가 확정되지 않는다. Stage 5 진입 전 당시 차이를 다시 제시하고 `main` 승격 경로를 별도 승인받도록 구현계획에 반영했다.

문서 형식 검사는 통과했다.

```text
$ git diff --check -- mydocs/plans/task_m010_430_impl.md mydocs/working/task_m010_430_stage1.md
(출력 없음, 성공)
```

## 잔여 위험

- 보존된 시안은 stash이므로 Stage 2에서 전체 적용하면 의도하지 않은 파일 상태가 섞일 수 있다. 두 대상 파일의 승인 diff만 선택 적용해야 한다.
- 긴 한국어 제목의 실제 줄바꿈과 대칭 여백은 CSS 정적 검사만으로 확정할 수 없다. Stage 3에서 데스크톱·모바일 시각 검증이 필요하다.
- docs-only workflow는 공개 appcast 네트워크 다운로드와 XML 검증에 의존하므로 배포 시 외부 상태에 따라 중단될 수 있다.
- `main`과 `devel`의 차이는 이후 커밋에 따라 달라질 수 있다. 배포 직전 재확인이 필요하다.

## 다음 단계 영향

Stage 2에서는 `stash@{0}`을 전체 복원하지 않고 승인된 `docs/index.html`, `docs/styles.css` 변경만 반영한다. Open Graph 문구, 철학 섹션 위치·문장·강조·반응형 크기·대칭 여백을 구현한 뒤 footer 원문과 다른 Pages 문서가 변경되지 않았음을 확인한다.

Stage 2는 소스 변경 단계이므로 이 보고서 검토와 작업지시자 승인을 받은 뒤에만 진행한다.

## 승인 요청

구현계획서 `mydocs/plans/task_m010_430_impl.md`와 이 Stage 1 결과를 기준으로 Stage 2 `승인된 철학 섹션과 Open Graph 설명 구현`에 진입할지 승인 요청한다.
