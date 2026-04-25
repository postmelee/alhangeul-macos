# PR 처리 가이드

## 목적

이 문서는 `alhangeul-macos` 저장소의 내부 task PR 생성 규칙과 외부 기여자 PR 검토 절차를 정리한다.

브랜치 흐름과 merge 전략은 `AGENTS.md`의 `Git 워크플로우`를 따른다.

## 범위

- 내부 task PR 본문 작성 규칙
- 외부 기여 PR 검토
- 리뷰 기록 문서 작성 규칙
- 검토 완료 후 아카이브 절차

## 기본 원칙

- 내부 task PR 본문은 `.github/pull_request_template.md`를 따른다.
- 내부 task PR 본문은 최종 결과 보고서의 압축본으로 작성한다.
- PR 본문에는 실제 실행한 검증만 적는다.
- 관련 이슈는 merge 시 닫아도 되는 경우에만 `Closes #번호`로 적는다.
- 외부 기여 PR은 코드 변경과 문서 변경을 함께 검토한다.
- 외부 PR 검토 결과는 `mydocs/pr/` 문서 흐름으로 관리한다.
- 검토 문서는 재현 가능해야 하며, 실행한 검증 명령/결과를 포함한다.

## 내부 task PR 작성 규칙

내부 task PR은 `local/task{번호}`에서 작업한 내용을 `publish/task{번호}`로 push한 뒤 `devel` 대상으로 생성한다.

PR 본문은 `.github/pull_request_template.md`를 기준으로 작성한다. 템플릿은 `edwardkim/rhwp`의 기본 PR 템플릿을 참고하되, 이 저장소의 하이퍼-워터폴 산출물과 연결되도록 확장한 형식이다.

### 필수 섹션

내부 task PR에는 다음 섹션을 둔다.

- `요약`
- `변경 내역`
- `검증`
- `문서`
- `관련 이슈`
- `남은 리스크`

`스크린샷`은 UI, Finder, Quick Look, Thumbnail 표시처럼 시각 확인이 필요한 변경에서만 유지한다. 해당하지 않으면 삭제한다.

### 섹션별 작성 기준

`요약`:

- 이 PR이 해결하는 문제와 핵심 변경을 간결하게 적는다.
- 최종 결과 보고서가 있는 경우, 보고서의 결론을 2~5개 bullet로 압축한다.

`변경 내역`:

- stage 기반 작업은 stage 기준으로 적는다.
- stage 커밋이 이미 존재하면 가능한 한 commit 링크나 짧은 SHA를 함께 적는다.
- 작은 작업은 stage 대신 파일/기능 단위로 적을 수 있다.

`검증`:

- 실제 실행한 명령만 체크한다.
- 실행하지 않은 항목은 삭제하거나 미체크 상태로 둔다.
- 수동 확인은 어떤 화면이나 파일에서 확인했는지 짧게 적는다.

`문서`:

- 수행 계획서, 구현 계획서, 단계별 완료 보고서, 최종 결과 보고서를 적는다.
- troubleshooting, feedback, manual 문서가 있으면 함께 적는다.
- 문서 링크는 PR head commit SHA 기준 GitHub blob URL을 사용하고, raw URL 대신 `[파일명](URL)` 형식으로 표시한다.

`관련 이슈`:

- merge 시 해당 issue를 닫아도 되는 PR은 `Closes #번호`를 사용한다.
- 아직 issue를 닫으면 안 되는 경우에는 `Related #번호` 또는 `Refs #번호`를 사용한다.
- draft PR 단계에서 자동 종료가 부담스러우면 `Refs #번호`로 시작하고, ready 전환 전에 `Closes #번호`로 바꾼다.

`남은 리스크`:

- 검증 한계, 후속 task 후보, 운영상 주의사항을 적는다.
- 없으면 `없음`으로 적는다.

### PR 본문과 최종 보고서의 관계

최종 결과 보고서는 장기 보관 문서이고, PR 본문은 리뷰 화면에서 빠르게 읽는 요약본이다.

- 최종 결과 보고서:
  - 전체 맥락, 단계별 결과, 검증 로그, 남은 리스크를 자세히 기록한다.
- PR 본문:
  - 리뷰어가 merge 판단에 필요한 내용만 압축한다.
  - 상세 내용은 `문서` 섹션에서 최종 보고서와 단계 보고서를 참조한다.

### 작성 예시

```md
## 요약

- RustBridge를 `wasm_api`에서 `DocumentCore` 직접 결합으로 전환
- Thumbnail embedded preview fast path 추가
- Finder small-size thumbnail 지원과 성능 경로 최적화

## 변경 내역

- **Stage 1** (`abc1234`): RustBridge의 core 결합 구조 정리
- **Stage 2** (`def5678`): Thumbnail fast path FFI 추가
- **Stage 3** (`789abcd`): Swift thumbnail 호출 경로 반영

## 검증

- [x] `./scripts/build-rust-macos.sh`
- [x] `./scripts/check-no-appkit.sh`
- [x] `xcodegen generate`
- [x] `xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build`
- [x] `git diff --check`

## 문서

- 수행 계획서: [task_m050_22.md](https://github.com/postmelee/alhangeul-macos/blob/{sha}/mydocs/plans/task_m050_22.md)
- 구현 계획서: [task_m050_22_impl.md](https://github.com/postmelee/alhangeul-macos/blob/{sha}/mydocs/plans/task_m050_22_impl.md)
- 최종 보고서: [task_m050_22_report.md](https://github.com/postmelee/alhangeul-macos/blob/{sha}/mydocs/report/task_m050_22_report.md)

## 관련 이슈

Closes #22

## 남은 리스크

- Finder grouped icon view 버벅임은 `.hwp`가 없는 폴더에서도 재현되어 Apple Feedback 대상이다.
```

### PR 생성 명령

기본 PR 생성은 `publish/task{번호}`를 원격에 push한 뒤 실행한다.

```bash
git checkout local/task24
git push origin local/task24:publish/task24
gh pr create \
  --base devel \
  --head publish/task24 \
  --draft \
  --title "Task #24: PR 템플릿과 PR 생성 규격 표준화" \
  --template .github/pull_request_template.md
```

`--template`은 템플릿을 시작 본문으로 사용한다. PR 생성 중 editor에서 내용을 채우거나, 생성 후 GitHub에서 본문을 정리한다.

최종 보고서와 단계 보고서를 바탕으로 PR 본문을 미리 완성한 경우에는 `--body-file`을 사용한다.

```bash
gh pr create \
  --base devel \
  --head publish/task24 \
  --draft \
  --title "Task #24: PR 템플릿과 PR 생성 규격 표준화" \
  --body-file /tmp/task24-pr-body.md
```

운영 기준은 다음과 같다.

- 초안 PR을 빠르게 만들 때: `--template .github/pull_request_template.md`
- 최종 보고서 기반으로 본문을 확정했을 때: `--body-file <작성한 PR 본문 파일>`
- `--fill`은 커밋 메시지만으로 본문을 만들기 때문에 이 저장소의 기본 방식으로 쓰지 않는다.
- `--body`에 긴 본문을 직접 넣는 방식은 재사용과 검토가 어렵기 때문에 피한다.

## 외부 기여 PR 검토 절차

외부 PR은 `mydocs/pr/` 문서 흐름으로 처리한다.

- 검토 문서: `pr_{번호}_review.md`
- 구현 계획서: `pr_{번호}_review_impl.md` (필요 시)
- 최종 보고서: `pr_{번호}_report.md`

절차:

1. PR 메타데이터 확인 (base/head, mergeable, CI, 연결 issue)
2. 코드/문서 변경 범위 확인
3. 필요한 검증 실행
4. `pr_{번호}_review.md`에 핵심 리스크와 수정 요청 정리
5. 필요 시 `pr_{번호}_review_impl.md`에 재검토 계획 정리
6. 최종 판단을 `pr_{번호}_report.md`로 기록
7. 처리 완료 문서를 `mydocs/pr/archives/`로 이동

## 머지 전 체크

- PR 대상 브랜치가 정책에 맞는지
- 리뷰 코멘트가 해결/미해결로 구분되어 있는지
- 필수 검증이 수행됐는지
- 승인/보류/반려 판단 근거가 문서에 남았는지

## 머지 후 체크

- 관련 issue 상태 확인 (auto close 또는 수동 close)
- merge 완료된 `publish/task{번호}` 원격 브랜치 삭제 여부 확인
- 다음 작업에 필요하지 않은 로컬 worktree, build 산출물, 설치 smoke test 산출물 정리
- 후속 작업이 있으면 신규 issue로 분리
- 검토 문서를 `mydocs/pr/archives/`로 이동
