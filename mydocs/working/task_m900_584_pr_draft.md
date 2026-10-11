네 bundle을 0.2.3 / build 21로 맞추고 release workflow의 직전 공개 버전·rhwp 기준을 v0.2.2·v0.8.7로 정렬합니다. 앞서 devel에 반영된 Mac 글꼴 연결을 출시할 수 있도록, 기존 글꼴 목록에서 선택하는 안내와 v0.2.3 릴리즈 노트를 준비합니다.

## 변경

- Mac 설치 글꼴과 별도 보관 복사본의 사용 방법, 원본·권한·지원 범위와 Windows 후속을 구분합니다.
- 과거 릴리즈 본문은 보존하고 최신 안내만 정규화합니다. README·Homebrew는 실제 public v0.2.2 제공 상태를 유지합니다.
- 새 DMG 미공개/draft 상태에서 Pages 배포를 건너뛰는 기존 asset gate를 유지합니다. Swift·Studio·core pin·FFI·renderer 동작은 변경하지 않습니다.

## 검증

- Rust 양 target portable, core/Studio receipt, render-tree golden 및 공유 Swift 경계 통과.
- unsigned Debug·universal Release, 네 bundle 0.2.3/21·양 architecture, Release endpoint 및 Legal 일치 통과.
- 세 문서 native render smoke, 55개 release/Pages helper fixture, 본문·YAML/shell·246개 HTML local link/anchor·과거 본문 보존 통과.
- 홈·업데이트·Mac 안내·새 노트의 1280/390/320px 및 키보드 확인. 새 public appcast v0.2.2 bytes 보존.
- 개발 앱·내부 Updater 등록과 불필요한 이번 빌드 cache 정리. /Applications 설치본 v0.2.2/20·strict seal 유지.

상세 검증은 `mydocs/working/task_m900_584_stage2.md`와 `mydocs/report/task_m900_584_report.md`에 포함합니다.

## 다음 단계

이 PR은 소스 준비 범위입니다. 최종 signed/notarized DMG, ARM/Intel 최초 설치·재설치, 실제 Mac 글꼴·저장/복구 및 실제 Sparkle 업데이트는 미실행입니다. 병합 후 각각의 승인 gate에서 확인합니다. #480/#525 한계와 Windows #566·추가 최적화 #581 이슈는 유지하며 #584 이슈를 자동으로 닫지 않습니다.

Refs #584
