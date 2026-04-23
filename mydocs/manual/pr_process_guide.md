# PR 처리 가이드

## 목적

이 문서는 `alhangeul-macos` 저장소의 PR 처리 절차를 정리한다. `AGENTS.md`에는 강제 규칙만 유지하고, 상세 단계는 이 문서를 참조한다.

## 범위

- 앱/bridge/문서 변경 PR
- 외부 기여 PR 검토
- PR 본문 작성 규칙
- 머지 전 검증과 머지 후 정리

## 기본 원칙

- 앱/bridge/문서 변경 PR 대상은 `postmelee/alhangeul-macos`의 `devel`이다.
- upstream `edwardkim/rhwp`에는 이 저장소 작업 PR을 만들지 않는다.
- PR은 최종 보고서 작성 후 생성한다.
- PR 본문은 최종 보고서를 기반으로 상세 작성한다.

## 앱/bridge/문서 PR 절차

1. 작업 완료 후 `git status`로 미커밋 파일 확인
2. 최종 보고서(`mydocs/report/task_{issue}_report.md`) 작성
3. 브랜치 push

```bash
git push -u origin local/task{issue}
```

4. draft PR 생성

```bash
gh pr create \
  --repo postmelee/alhangeul-macos \
  --base devel \
  --head local/task{issue} \
  --draft \
  --title "Issue #{issue}: 제목"
```

5. PR 본문 검토 후 필요 시 수정

```bash
gh pr edit <번호> --body-file <파일경로>
```

## PR 본문 필수 항목

- `Closes #{issue}`
- 작업 배경
- 주요 변경 내용
- 검증 명령과 결과
- 수동 확인 필요 항목
- 남은 리스크 또는 후속 작업

## 외부 기여 PR 검토 절차

외부 PR은 `mydocs/pr/` 문서 흐름으로 처리한다.

- 검토 문서: `pr_{번호}_review.md`
- 구현 계획서: `pr_{번호}_review_impl.md` (필요 시)
- 최종 보고서: `pr_{번호}_report.md`

절차:

1. PR 메타데이터 확인 (base/head, mergeable, CI)
2. 코드/문서 변경 범위 확인
3. 필요한 검증 실행
4. 리뷰 의견 작성
5. 처리 완료 문서를 `mydocs/pr/archives/`로 이동

## 머지 전 체크

- 대상 브랜치가 `devel`인지
- `Closes #{issue}`가 포함됐는지
- 작업 범위와 무관한 변경이 없는지
- 필수 검증이 수행됐는지
- 문서(`plans`, `working`, `report`, `orders`)가 누락되지 않았는지

## 머지 후 체크

- issue 상태 확인 (auto close 또는 수동 close)
- 다음 작업 브랜치 시작 전 `origin/devel` 동기화
- 필요 시 `mydocs/orders/` 상태 업데이트
