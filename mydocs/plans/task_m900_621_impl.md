# Task M900 #621 구현계획서

[수행계획](task_m900_621.md) · [릴리즈 이슈 #621](https://github.com/postmelee/alhangeul-macos/issues/621)

## 1단계 — 후보 소스 및 실행 검증

v0.9.1 공식 SHA `981ce66b4183b13c1a3b5907e04a8969c8c42034`를 Cargo·core lock·Studio receipt·manifest와 대조한다. #620과 동기화 후보의 정확한 head에서 성공한 CI, 변경 경로 및 디스크 기록을 확인한다. Polaris HWP, Slack OLE 원본 HWP/HWPX, 별도 참조 PDF, 공개 HWP/HWPX 대조군을 사용한다. Slack 파일과 파생 결과는 T7의 비공개 폴더에 유지한다.

## 2단계 — 서명·공증 후보 및 설치 검증

4개 bundle의 버전과 빌드를 0.2.5/23으로 맞추고, `main`과 `devel`의 콘텐츠와 버전·업스트림 provenance를 검사한다. signed draft DMG를 생성하고 소스·빌드 실행·artifact ID·SHA-256을 고정한다. 실제 Mac에서 문서 첫 표시, 글꼴 준비, 전환·취소, 재열기, 저장·PDF·인쇄와 Finder 확장을 확인한다. ARM 및 Intel VM별 최초 설치·본문 검색·재설치를 동일 DMG에서 확인한다. 설치 이력과 검증 환경을 구분한다.

## 3단계 — 공개·실제 업데이트·후속

Threads 자동 수집 진단을 재실행해 승격의 별도 선행 조건을 확인한다. 검증한 bytes를 공개 승격하고, 공개 DMG와 checksum, appcast, v0.2.4에서의 실제 Sparkle 재실행, Homebrew 설치·업그레이드를 확인한다. 외부 제보 #595, #597, #614는 원래 재현 절차와 기대 동작을 새 공개 설치본에서 확인할 수 있는 범위로 검사한다. 확인한 항목만 근거에 따라 닫고 남은 제보에는 결과와 후속을 기록한다.
