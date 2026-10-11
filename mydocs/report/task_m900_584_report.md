# Task M900 #584 부분 최종 보고 — v0.2.3 소스 준비

## 결론

**Stage 1 조사와 Stage 2 소스·사용자 안내 준비 완료 / 최종 DMG·설치·실제 업데이트·공개 수용 대기.** 이번 보고는 준비 PR을 위한 부분 인계이며 #584 전체 완료 보고가 아니다. v0.2.3 / 21의 네 bundle·release 입력을 맞추고 Mac 글꼴과 rhwp v0.8.7 안내 후보를 준비했다. 실제 public 앱·Pages·Sparkle·Homebrew는 여전히 v0.2.2다.

준비 [PR #585](https://github.com/postmelee/alhangeul-macos/pull/585)는 검증 이미지 보정 head `938b59b9`의 CI 4개 통과 후 `5146d91e`로 devel에 병합했다. 이후 [Stage 3](../working/task_m900_584_stage3.md)에서 [main PR #586](https://github.com/postmelee/alhangeul-macos/pull/586)의 통합 리뷰·CI 4개를 확인하고, **“main 병합·다음 실행 준비”** 승인으로 main `c9d59f93`에 병합했다. **“v0.2.3 태그 생성·push”** 승인으로 해당 실제 SHA에 tag를 생성·게시·검증했다. DMG workflow의 실행 입력·운영 이름 준비까지 완료했으며 실행 승인과 최종 DMG 수용은 대기다.

## 구현과 사용자 변화

설정에서 Mac 글꼴 사용을 켠 뒤 기존 시스템 글꼴 목록에서 선택하는 방법을 중심으로 릴리즈 노트·홈 FAQ·Mac 안내를 연결했다. 원본 참조와 별도 보관 복사본, 권한·지원 스타일·출력 실패 동작을 구분한다. 한컴 제거 후 모든 글꼴 유지·Windows ZIP 가져오기·모든 글꼴 및 한컴 배치 동일성을 약속하지 않는다.

rhwp v0.8.7과 Mac 글꼴 연결 코드는 앞선 PR에서 이미 devel에 반영했다. 이번 준비 PR은 해당 기능의 버전·workflow 기본값·출시 안내를 정렬한다. Swift 동작·Studio·core pin·FFI·renderer 선택을 추가로 바꾸지 않았다. 이전 15개 릴리즈의 본문·공개일·다운로드는 보존하고 최신 안내만 정규화했다. README는 실제 public v0.2.2를 유지하고 미공개 준비 상태를 명시한다.

## 검증 근거

Rust 양 target portable·core/Studio·producer golden/Swift decoder·unsigned Debug 및 universal Release·네 bundle 값/실행 파일 양 slice·Release endpoint·Legal·세 문서 native smoke를 통과했다. 재빌드한 header/staticlib SHA256·size는 기존 lock과 같다. release/Pages helper의 55개 fixture 검사, 본문/YAML/shell/HTML 링크·과거 본문 보존, 12개 desktop/mobile viewport와 키보드 동선도 통과했다.

새로 받은 public appcast를 XML로 읽고 v0.2.2 bytes/hash를 로컬 조립에 그대로 보존했다. v0.2.3 자산은 아직 404이며 기존 Pages asset gate가 조기 배포를 막는다. 생성 본문의 hash 검증에는 별도 synthetic fixture만 썼으며 실제 DMG hash로 기록하거나 게시하지 않았다.

- [Stage 1 보고](../working/task_m900_584_stage1.md), [Stage 2 보고](../working/task_m900_584_stage2.md).
- [Stage 2 증거](assets/task_m900_584/stage2/validation.json), [제품/arch 기록](assets/task_m900_584/stage2/built-products.json), [Pages 보호](assets/task_m900_584/stage2/pages-proof.json), [등록 정리](assets/task_m900_584/stage2/registration-cleanup.json), [공간 정리](assets/task_m900_584/stage2/storage-cleanup.json).
- [Mac 안내 화면](assets/task_m900_584/stage2/fonts-desktop.jpg), [새 노트 화면](assets/task_m900_584/stage2/release-desktop.jpg), [checksum](assets/task_m900_584/stage2/SHA256SUMS).

## 남은 수용과 위험

| 영역 | 상태 |
|------|------|
| 준비 PR | #585 devel 병합 완료. main #586 새 CI 4개 PASS·통합 리뷰 후 c9d59f93에 병합 완료 |
| 최종 provenance/DMG | source SHA c9d59f9300ef78b4cc6a3a8e17a10a3d766d01d4 및 v0.2.3 tag 게시·검증 완료. workflow 실행 별도 승인 대기, run/artifact/hash 미확정·공증 DMG 미생성 |
| ARM/Intel VM | 새 동일 DMG의 schema 3 최초 설치·재설치·cleanup 수용 대기 |
| 실제 Mac | 일반 최종 앱의 글꼴·문서·PDF·인쇄 취소·Finder·Spotlight 대기. #569 진단 앱 증거를 최종 DMG PASS로 대체하지 않음 |
| 저장·복구 | #480 기존 원본 보호는 유지, native 암호화 저장 미지원. #525 복구 후보 한계 별도 유지. 최종 앱에서 실제 결과·원본 보존을 판정 |
| 공개·업데이트 | 같은 DMG public 신규 다운로드·Pages/Sparkle·실제 v0.2.2→v0.2.3 업데이트·Cask 및 README 공개 상태 갱신 대기 |
| 독립 후속 | Windows #566·추가 현재성 비용 최적화 #581 OPEN. <300ms·무지연 실행을 완료 기준으로 다시 요구하지 않음 |

최소 macOS 12·Intel 실기기 GUI·실제 한컴 제거·물리 인쇄를 이번 unsigned 검증으로 수행했다고 주장하지 않는다. 새 원본 손상이나 보호 우회가 확인되면 공개를 차단한다.

## 준비 PR 결과와 다음 gate

`local/task584`의 준비 소스·문서·증거·부분 보고는 승인에 따라 `publish/task584`의 #585로 게시했다. source 준비 커밋 `ee453da2`, 보고 묶음 `39e3e131`, 이미지·checksum 보정 `938b59b9`를 포함해 최신 head의 CI 4개를 통과했고, 병합 승인에 따라 `5146d91e`로 devel에 반영했다. PR은 Refs #584 형식이며 #584는 계속 OPEN이다.

승인된 main PR 본문을 #586으로 게시하고 [통합 리뷰](../feedback/task_m900_584_pr586_review.md)와 CI 증거를 보존했다. 승인받은 main 병합 후 tree·content gate·네 bundle·공개 feed 유지와 실제 Pages deploy skip을 확인했다. 태그 생성도 별도로 승인받아 정확한 main SHA에 고정했고 [태그 증거](assets/task_m900_584/stage3/tag/tag-verification.json)를 보존했다. [DMG 준비안](../working/task_m900_584_release_execution.md)의 서명/공증 workflow, VM/실제 Mac 설치와 공개는 [구현계획](../plans/task_m900_584_impl.md)의 각각의 gate를 따른다. Stage 3 완료 또는 최종 릴리즈 성공으로 기록하지 않는다.
