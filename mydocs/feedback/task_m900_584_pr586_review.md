# Task M900 #584 PR #586 main 통합 리뷰

## 판단과 검토 범위

[PR #586](https://github.com/postmelee/alhangeul-macos/pull/586)의 main 통합을 막을 제품·배포 경계 문제를 발견하지 못했다. **통합 리뷰·필수 CI 4개 완료 / 승인된 main 병합 완료**다. exact head의 MERGEABLE/CLEAN을 병합 직전 다시 확인했고 **“main 병합·다음 실행 준비”** 승인으로 `c9d59f93`에 병합했다. 이 판단은 소스 준비 PR에 대한 것이며 최종 signed/notarized DMG와 실제 설치·업데이트 수용을 뜻하지 않는다.

- base main: `43b4e998b93032b62bcb0517fb9c894de3dc8ae1`.
- head devel: `5146d91e61e29959b45f6af68090cca4e9c3b97d`.
- 사용자 승인: **“main PR 게시·CI/리뷰 진행”**. 게시된 제목·본문·Open 상태·head/base가 승인안과 일치한다. PR을 task artifact로 연결했다.
- 이전 [PR #585](https://github.com/postmelee/alhangeul-macos/pull/585)의 exact head CI 4개 PASS와 같은 제품 tree를 운반한다. main 통합의 새 [run 38176121965](https://github.com/postmelee/alhangeul-macos/actions/runs/38176121965)는 별도로 확인한다.

792개 파일에는 Sources 89개·Tests 75개·mydocs 534개와 번들/스크립트/Pages 등이 포함된다. 전체 GitHub 파일 목록을 페이지별로 조회해 로컬 diff의 path 792개 및 변경 blob SHA 전부가 일치함을 검증했다. GitHub full diff는 300개 파일 상한으로 HTTP 406이므로 검토에는 정확한 base/head의 로컬 diff를 사용했다. 기존 기능 전체를 새로 구현하거나 모든 증거 파일의 줄을 전수 재검토한 것으로 주장하지 않는다.

## 검토 근거

| 영역 | 검토한 결과 |
|------|-------------|
| 통합 출처 | main은 source의 ancestor이며 content gate의 예상 통합 tree가 devel tree와 동일. 누락된 main 별도 content 없음 |
| 버전·의존성 | 네 bundle 0.2.3/21, Cargo release tag·lock·core build info·Studio manifest/adapter receipt v0.8.7의 같은 commit. branch/floating pin으로 변경하지 않음 |
| Release/Pages | release workflow의 버전·직전 ref·core 기준 정렬. immutable tag/draft·latest 확인·동일 파일 승격 계약 유지. Docs-only asset gate는 main/source byte 동일이며 새 DMG가 missing/draft이면 skip. public appcast 보존 경로 유지 |
| CI·패키징 | Rust/Studio 영향 path가 macOS/portable 검증을 켜며, font library·WebKit IPC·native matcher·PDF/인쇄 검증을 포함. 새 probe/test target은 SKIP_INSTALL=YES이고 HostApp 배포 dependency로 추가하지 않음 |
| 글꼴 공급·출력 | 원본 bytes/SHA/face·style 검증, metadata·font bytes 크기 상한과 호출 수명·결과 해제, 작업별 snapshot/currentness·취소/lease 해제 경계를 확인. PDF 준비 실패/명시 fallback·출력 취소 계약 유지 |
| 확장 | HostApp bookmark를 넘기지 않고 자체 목록/권한과 shared policy를 읽음. epoch/policy/generation 및 원본·manifest 검사를 남긴 metadata 재사용, worker 종료와 취소 대기를 구분하는 경계 확인 |
| 안내·완료 상태 | 기존 메뉴에서 선택·기본 OFF·원본/권한·지원 스타일·Windows 후속을 유지. #480 원본 보호/암호화 저장 미지원과 #525 복구 후보 한계, 최종 DMG 미검증을 명시. Refs #584이며 자동 close 없음 |

일반 TTF/OTF 중심 지원, TTC/가변/HFT/전체 complex shaping·한컴 삭제 후 모든 글꼴 보존·모든 시스템 글꼴·한컴 배치 동일성은 보장하지 않는다. 이는 새 결함 발견이 아니라 릴리즈 안내와 기존 수용 계약의 경계다. #569 진단 앱 및 #580 반복 준비 측정을 최종 공증 DMG PASS로 대신하지 않았다.

## CI 관측과 참고 사항

관측 시점은 [CI 기록](../report/assets/task_m900_584/stage3/main-pr/ci-observed.json)의 KST 시간을 따른다.

- Classify changed files: SUCCESS.
- Script syntax checks: SUCCESS.
- macOS validation: SUCCESS.
- Release helper checks: SUCCESS.

Copilot은 quota 때문에 리뷰하지 못했다. GitHub에 inline 지적/변경 요청은 없지만 이를 Copilot 검토 PASS로 계산하지 않는다. 이번 내용은 직접 수행한 통합 검토이며 공개 review/comment로 게시하지 않았다.

전체 main diff의 git diff --check에는 기존 #580 이슈 보정 문서 `mydocs/working/task_m020_580_issue_update.md:72`의 EOF 빈줄 하나가 남는다. 제품 동작과 무관한 형식 참고이며 릴리즈 통합 차단 결함으로 분류하지 않았다. 전체 diff의 이 검사는 PASS로 기록하지 않는다. Stage 3.1 준비 커밋의 변경 문서 검증과 구분한다.

## 증거와 다음 gate

- [게시 metadata](../report/assets/task_m900_584/stage3/main-pr/pr586.json), [792개 path/blob 대조](../report/assets/task_m900_584/stage3/main-pr/publication-proof.json), [exact head CI·병합 상태](../report/assets/task_m900_584/stage3/main-pr/merge-readiness.json), [checksum](../report/assets/task_m900_584/stage3/main-pr/SHA256SUMS).
- 전체 raw 파일 목록·exact local diff는 build.noindex/task584/stage3/main-pr에 보존한다. 제품 소스 추가 수정이나 광범위 로컬 rebuild는 하지 않았다.
- main 병합과 실제 source의 tag 생성·push는 [구현계획 §4](../plans/task_m900_584_impl.md)에 따라 각각 별도 승인받아 실행했다. [병합 증거](../report/assets/task_m900_584/stage3/main-merge/pr586-merged.json), [태그 검증](../report/assets/task_m900_584/stage3/tag/tag-verification.json)과 [DMG 준비안](../working/task_m900_584_release_execution.md)에 실제 source/tag를 기록했다. 서명/공증·VM/실제 Mac 설치·공개는 아직 미실행이며 #584는 OPEN을 유지한다.
