# Task M900 #601 최종 보고 — v0.2.4 공개와 배포 수용

v0.2.4 / build 22를 2026-11-11 08:01:40 KST 공개했다. 공식 rhwp v0.9.0, 편집 오류 복구, HFT 대응 글꼴 공급·굵기 출력을 통합한 동일 서명·공증 DMG다. 실제 v0.2.3 → v0.2.4 Sparkle 다운로드·설치·자동 재실행, HWP·HWPX 화면과 Finder, Homebrew 업데이트·제거·신규 설치를 확인했다.

작업지시자가 “검색은 #587로 남기고 대체 근거 수용·#601 종료”를 승인했다. 실제 Mac 본문 검색은 미확인으로 유지하고, 양 아키텍처 VM 검색과 설치 importer의 본문 추출을 대체 근거로 수용한다. TXT는 8.9초에 검색됐으므로 이전 TXT 미검색 환경과 같은 원인으로 단정하지 않는다. 검색 원인과 필요한 수정은 [#587](https://github.com/postmelee/alhangeul-macos/issues/587)에서 계속한다.

## 검증과 출처

- 제품 태그 소스 `41d9c77473e30cabe5f00a0179652658e55aa0ce`, 공식 엔진 `c9095c5f67632e6721e800ccc7fb43ea49d26682`.
- 공개 DMG SHA-256 `58868d2e1a2d85cdb7958e7ca470525fd4bcc7eb456342e5418ba4af9046a749`, 351,264,277 bytes. 인증 없는 신규 다운로드·체크섬·공증 검사와 기존 앱 공개키의 Sparkle 서명 검증 통과.
- [양 VM 최초 설치·재설치](https://github.com/postmelee/alhangeul-macos/actions/runs/42749186623), [정식 공개·Pages](https://github.com/postmelee/alhangeul-macos/actions/runs/42919440881) 성공. VM 재설치는 `maintained`이며 미검색 상태 복구를 입증하지 않는다.
- 실제 Sparkle 자동 재실행 PID 53322 → 53906, 0.2.4/22·rhwp v0.9.0. 기본 모드 확장 smoke와 두 형식의 문서·Quick Look·썸네일 확인.
- [Homebrew PR #5](https://github.com/postmelee/homebrew-tap/pull/5), style·audit·upgrade·uninstall·신규 install 및 첫 실행 확인. 네 bundle의 버전·universal·strict seal·Gatekeeper·staple 통과. 최종 앱과 receipt는 0.2.4.
- 최근 문서와 시험 설정을 복원하고 실제 업데이트 유지보수 기록은 보존했다. 기존 복구본과 기본 파일 연결을 유지했다.

[릴리스 상세 기록](../release/v0.2.4.md)과 [공개 후 증거 요약](assets/task_m900_601/postpublish.json)에 실제 실행 범위와 실패·미확인 결과를 구분했다. 최소 macOS 12·Intel 실기기 GUI는 미실행이다. 오래된 검증 앱 내부의 Sparkle Updater 등록 두 건은 macOS의 -10814로 해제되지 않았으며 공식 Finder 제공자와 구분했다.

## 공개 안내 정리

[PR #608](https://github.com/postmelee/alhangeul-macos/pull/608)에 Cask mirror, README, Pages Homebrew 안내, 릴리스 기록과 수용 판단을 모았다. Pages 조립에서 공개 appcast 바이트를 보존했고 문서 링크·본문 템플릿·공백 검사를 통과했다. 제품 소스·태그·DMG는 추가 변경하지 않았다. devel·main 병합, 공개 Pages와 appcast 보존 확인 후 이슈를 종료한다.
