# PR 처리 가이드

## 목적

이 문서는 `alhangeul-macos` 저장소의 내부 task PR 생성 규칙과 외부 기여자 PR 검토 절차를 정리한다.

브랜치 흐름과 merge 전략은 [`git_workflow_guide.md`](git_workflow_guide.md)를 따른다. 제품 `devel`과 native `native-viewer-editor`의 역할 판단은 [`branch_strategy_webview_native.md`](../tech/branch_strategy_webview_native.md)를 기준으로 한다.

## 범위

- 내부 task PR 본문 작성 규칙
- 외부 기여 PR 검토
- 리뷰 기록 문서 작성 규칙
- 검토 완료 후 아카이브 절차

## 기본 원칙

- 내부 task PR 본문은 `.github/pull_request_template.md`를 따른다.
- 내부 task PR 본문은 최종 결과 보고서의 짧은 압축본으로 작성한다.
- PR 본문에는 실제 실행한 검증만 적는다.
- 현재 PR이 직접 수행하는 issue는 `대상 타스크`에 적는다.
- `관련 이슈`는 선행, 후속, Epic, upstream, 참고 PR/issue처럼 PR 이해에 필요한 맥락을 적는다.
- 외부 기여 PR은 코드 변경과 문서 변경을 함께 검토한다.
- 외부 PR 검토 결과는 `mydocs/pr/` 문서 흐름으로 관리한다.
- 검토 문서는 재현 가능해야 하며, 실행한 검증 명령/결과를 포함한다.

## 내부 task PR 작성 규칙

내부 task PR은 `local/task{번호}`에서 작업한 내용을 `publish/task{번호}`로 push한 뒤 작업 범위에 맞는 통합 브랜치 대상으로 생성한다. 첫 공개 배포, WKWebView-backed viewer/editor, Finder/Quick Look, PDF/공유/저장, Spotlight/mdimporter, 변환, 배포, 문서는 `devel`, Swift native viewer/editor는 `native-viewer-editor`를 쓴다.

PR 본문은 `.github/pull_request_template.md`를 기준으로 작성한다.

### 섹션 구성

내부 task PR에는 다음 섹션을 둔다.

- `요약`
- `변경 내역`
- `핵심 리뷰 포인트`
- `검증`
- `스크린샷`
- `관련 이슈`
- `후속 이슈 제안`
- `남은 리스크`

`핵심 리뷰 포인트`, `스크린샷`, `후속 이슈 제안`은 필요한 경우만 유지한다. 해당하지 않으면 삭제하거나 `없음` 한 줄로 정리한다.

### 섹션별 작성 기준

`요약`:

- 최대 4개 bullet로 압축한다.
- 대상 타스크, 변경 이유, 변경 내용, 리뷰어가 먼저 볼 지점을 적는다.
- 현재 PR이 직접 수행하는 issue는 `대상 타스크`에 적는다.

`변경 내역`:

- Stage 기반 작업은 Stage당 1줄로 적는다.
- Stage 제목은 단계 보고서로 링크하고, 옆의 짧은 commit SHA는 commit URL로 링크한다.
- 예: `**[Stage 1](stage-url)** ([0cdbae0](commit-url)): 한 줄 요약`
- 주요 파일/영역 표는 최대 5행만 남긴다.
- 수행 계획서, 구현 계획서, 최종 보고서는 `작업 문서` 항목으로 짧게 묶는다.
- 작업 문서 링크는 PR head commit SHA 기준 GitHub blob URL을 사용하고, raw URL 대신 `[파일명](URL)` 형식으로 표시한다.

`핵심 리뷰 포인트`:

- 리뷰어가 먼저 판단해야 하는 ABI, 스키마, 렌더링 계약, 알고리즘 분기, 호환성 판단이 있을 때만 유지한다.
- 최대 3개만 적고, 코드 블록은 각 20줄 이하로 제한한다.

`검증`:

- 실제 실행한 명령과 수동 확인만 적는다.
- 실행하지 않은 항목은 삭제한다.
- 수동 확인은 어떤 화면이나 파일에서 확인했는지 짧게 적는다.

`스크린샷`:

- UI, Finder, Quick Look, Thumbnail, renderer 결과처럼 시각적 변경사항이 있을 때만 유지한다.
- 시각 변경이 있으면 Before/After 표를 사용한다.
- 실제 이미지나 산출물 없이 형식만 채우지 않는다.

`관련 이슈`:

- 현재 PR의 대상 타스크가 아니라 PR 이해에 필요한 맥락 이슈를 적는다.
- 선행, 후속, Epic, upstream, 참고 PR/issue를 의미 라벨과 함께 적는다.
- 해당 없으면 `없음`으로 적는다.

`후속 이슈 제안`:

- 아직 이슈가 없지만 분리할 후보를 적는다.
- 없으면 `없음`으로 적는다.

`남은 리스크`:

- 검증 한계와 운영상 주의사항을 적는다.
- 없으면 `없음`으로 적는다.

### PR 본문과 최종 보고서의 관계

최종 결과 보고서는 장기 보관 문서이고, PR 본문은 리뷰 화면에서 빠르게 읽는 요약본이다.

- 최종 결과 보고서:
  - 전체 맥락, 단계별 결과, 검증 로그, 남은 리스크를 자세히 기록한다.
- PR 본문:
  - 리뷰어가 merge 판단에 필요한 내용만 압축한다.
  - 상세 내용은 `변경 내역`의 Stage 링크와 작업 문서 링크로 참조한다.

### 작성 예시

```md
## 요약

- 대상 타스크: #22
- 왜: Thumbnail 경로가 Rust core provenance와 분리되어 검증 재현성이 낮았음
- 무엇: RustBridge 결합과 Thumbnail fast path를 정리
- 리뷰 포인트: FFI symbol 변화와 Finder small-size thumbnail fallback

## 변경 내역

- **[Stage 1](https://github.com/postmelee/alhangeul-macos/blob/{sha}/mydocs/working/task_m050_22_stage1.md)** ([abc1234](https://github.com/postmelee/alhangeul-macos/commit/{stage1_sha})): RustBridge의 core 결합 구조 정리
- **[Stage 2](https://github.com/postmelee/alhangeul-macos/blob/{sha}/mydocs/working/task_m050_22_stage2.md)** ([def5678](https://github.com/postmelee/alhangeul-macos/commit/{stage2_sha})): Thumbnail fast path FFI 추가

| 영역 | 변경 | 리뷰 포인트 |
|------|------|-------------|
| `RustBridge/` | core 결합 구조 정리 | lock/provenance 일치 |
| `Sources/ThumbnailExtension` | fast path 호출 반영 | fallback 유지 |

- 수행 계획서: [task_m050_22.md](https://github.com/postmelee/alhangeul-macos/blob/{sha}/mydocs/plans/task_m050_22.md)
- 구현 계획서: [task_m050_22_impl.md](https://github.com/postmelee/alhangeul-macos/blob/{sha}/mydocs/plans/task_m050_22_impl.md)
- 최종 보고서: [task_m050_22_report.md](https://github.com/postmelee/alhangeul-macos/blob/{sha}/mydocs/report/task_m050_22_report.md)

## 검증

- `./scripts/build-rust-macos.sh`
- `./scripts/check-no-appkit.sh`
- `git diff --check`

## 관련 이슈

- 선행: #17
- 참고: edwardkim/rhwp#385

## 남은 리스크

- Finder grouped icon view 버벅임은 `.hwp`가 없는 폴더에서도 재현되어 Apple Feedback 대상이다.
```

### PR 생성 명령

기본 PR 생성은 `publish/task{번호}`를 원격에 push한 뒤 실행한다.

```bash
git checkout local/task24
BASE_BRANCH=devel # Swift native viewer/editor 작업이면 native-viewer-editor
git push origin local/task24:publish/task24
gh pr create \
  --base "$BASE_BRANCH" \
  --head publish/task24 \
  --title "Task #24: PR 템플릿과 PR 생성 규격 표준화" \
  --template .github/pull_request_template.md
```

`--template`은 PR 본문 작성의 출발점으로만 사용한다.

최종 보고서와 단계 보고서를 바탕으로 PR 본문을 완성한 경우에는 `--body-file`을 우선 사용한다.

```bash
BASE_BRANCH=devel # Swift native viewer/editor 작업이면 native-viewer-editor
gh pr create \
  --base "$BASE_BRANCH" \
  --head publish/task24 \
  --title "Task #24: PR 템플릿과 PR 생성 규격 표준화" \
  --body-file /tmp/task24-pr-body.md
```

운영 기준은 다음과 같다.

- 템플릿에서 본문을 시작할 때: `--template .github/pull_request_template.md`
- 최종 보고서 기반으로 본문을 확정했을 때: `--body-file <작성한 PR 본문 파일>` 우선
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
