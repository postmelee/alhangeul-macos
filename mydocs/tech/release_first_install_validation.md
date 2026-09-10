# 릴리스 최초 설치 검증 설계

## 목적과 책임

릴리스 후보를 빌드한 VM과 설치를 시험하는 VM을 분리한다. GitHub-hosted macOS의 각 job은 새 VM이지만 개발 도구와 자동화 설정이 포함된 이미지다. 따라서 결과 명칭은 `새 GitHub-hosted VM 최초 설치`이며 순정 사용자 OS/실제 사용자 GUI 검증을 모두 대체하지 않는다.

자동화 구축은 #518, Spotlight 최초 설치 수용은 #513, v0.2.0 기능·출시 판단은 #337, 공개 배포 실행은 별도 릴리스 작업이 소유한다.

## 흐름

환경 조사 → 후보 출처 검증 → DMG 다운로드/hash 검사 → 서명·공증 검사 → 설치 전 TXT/HWP/HWPX corpus 준비 → 정상 복사/첫 실행 → 실제 자동 검색 → 앱 종료 후 검색 → 변경/삭제 → 정리 → 결과 기록.

빌드/fixture 생성은 설치 job 밖에서 수행한다. 최초 검색 이후 metadata 진단과 lifecycle을 수행하고 첫 실행 상태를 별도 보존한다. 기존 smoke의 `replace-app`은 수동 등록과 timestamp 보정을 포함하므로 일반 최초 설치 또는 Sparkle 업데이트 검증에 사용하지 않는다.

## 입력과 신뢰 경계

후보는 같은 저장소의 성공한 release-publish.yml 실행에서 만들어진 artifact만 허용한다. 실행 ID, artifact ID, 정확한 40자리 소스 SHA, 64자리 DMG SHA256, 버전, 빌드 번호를 필수로 받는다. API가 반환한 실행·artifact 연결과 head SHA를 대조한다. 만료 artifact, 임의 URL, 다른 저장소, PR/fork 산출물을 허용하지 않는다. 입력 문자열을 shell 코드에 직접 보간하지 않는다.

검증 harness의 SHA와 후보의 SHA는 별도로 기록한다. 후보 코드나 artifact 안의 스크립트를 실행하지 않고 신뢰한 harness로 검사한다. DMG/서명 검증 후에만 후보 앱을 실행한다. ZIP 상대 경로·symlink·크기 한도를 검사하고 읽기 전용으로 mount한다. 인증 토큰은 다운로드 단계에만 전달하고 앱 실행 환경에 전달하지 않는다.

## 판정

- ENVIRONMENT_READY: GUI 사용자, 기존 importer 부재 및 TXT 자동 검색 전제가 확인됨. 후보 검증은 미실행이며 release_eligible=false.
- ENVIRONMENT_UNAVAILABLE: 색인/GUI/기존 설치 조건 부적합. 설치 성공 아님.
- CANDIDATE_FAILED: 출처/hash/서명/공증/설치/검색 등 후보 검증 실패. 원인 분석 전 제품 결함으로 단정하지 않음.
- HARNESS_ERROR: API/명령/결과/정리 문제. 후보 성공 아님.
- PASS: 후보·최초/종료 후 검색·lifecycle·정리 필수 항목이 모두 통과한 해당 DMG의 자동화 범위 결과.

러너 조사 workflow의 성공은 측정 완료만 뜻한다. 결과 JSON의 release_eligible는 언제나 false다. 후보 workflow에서는 PASS 외 상태를 nonzero로 처리한다. 임의 강제 색인 활성화·등록·재색인·앱 재실행으로 실패를 덮지 않는다. 상태와 명령별 경과 시간, 실패 원문, 이미지 버전, runner arch, source/harness SHA, DMG hash를 저장한다.

## 배포와 결과 유효성

같은 소스라도 재서명·재공증·재패키징한 파일은 다른 후보다. 공개할 DMG SHA256과 검증 결과 SHA256이 일치해야 한다. 현재 publish workflow는 실행마다 다시 빌드하므로 draft PASS를 다음 public 실행에 그대로 재사용할 수 없다. 실제 공개 흐름에 gate를 연결할 때는 검증된 bytes 승격 또는 공개 직전 새 산출물의 재검증을 먼저 구현해야 한다. 이 작업만으로 기존 publish 경로에 자동 차단이 설치되었다고 주장하지 않는다.

유효한 자동 검사 결과 외에도 실제 Spotlight 화면, Finder/Quick Look/Thumbnail, Gatekeeper 다운로드 경험, 공개 Sparkle 업데이트, 최소 OS 검증 공백과 출시 승인을 별도로 기록한다. 기본 CI에는 signing credential을 주입하지 않는다.

## 근거

- [GitHub-hosted VM lifecycle](https://docs.github.com/en/actions/how-tos/manage-runners/github-hosted-runners/use-github-hosted-runners)
- [지원 러너 및 제한](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
- [Apple importer 최초 실행/재색인](https://developer.apple.com/library/archive/documentation/Carbon/Conceptual/MDImporters/Concepts/Troubleshooting.html)
