# Task M900 #618 4단계 중간 기록 — 자동 동기화 러너 저장 공간

2026-11-20 · [#618](https://github.com/postmelee/alhangeul-macos/issues/618) · 대상 `devel` `08ce865e2ac9bd495e4696f40f64da515140c302`

[자동 동기화 44696814904](https://github.com/postmelee/alhangeul-macos/actions/runs/44696814904)에서 Linux의 WASM/Studio 빌드와 자산 업로드가 통과했다. macOS 작업은 별도 upstream clone과 복원까지 진행한 뒤 `cargo generate-lockfile`이 같은 저장소의 Git pack을 별도로 받는 중 `No space left on device`로 실패했다. 실행에 파일 시스템 계측이 없어 당시 최대 사용량과 필요한 여유 공간의 정확한 수치는 알 수 없다.

- macOS에서 Cargo가 받은 release-tag 의존성을 metadata의 공식 저장소 URL·태그·SHA로 찾고 checkout HEAD도 대조한다. 객체를 공유하는 sparse checkout으로 원본 Studio 소스와 root `Cargo.lock`만 복원한다. 기존 Studio receipt, Cargo.lock, ABI, 렌더 트리 검증을 계속 실행한다.
- Linux 업로드 준비와 macOS 복원에서 작업 내 `pkg`와 `dist`를 이동해 중복 보관을 줄인다. 기존 Cargo 캐시와 사용자 파일을 정리하는 단계는 추가하지 않았다.
- Cargo Git DB·checkout·registry, 앱 체크아웃·Rust target·Frameworks, Studio 자산 사용량과 여유 공간을 CI 로그와 요약에 기록한다. 8 GiB(Cargo 의존성 해석 전), 4 GiB(Universal 빌드 전)는 조기 실패를 위한 최소값이다. 해당 값이 전체 빌드에 충분한지는 실제 러너 재실행에서 확인한다.

`actionlint`, `git diff --check`, Studio Node 회귀 34건과 Studio Cargo.lock fingerprint 검사가 통과했다. 작은 Cargo/Git fixture에서 workflow 복원 명령으로 객체 공유, sparse checkout, 자산 이동, 다른 태그 거부를 확인했다. 디스크 검사는 경계값 통과, 경계 미달과 해석 불가 값 거부를 확인했다. #594의 실험용 글꼴 대기 제한 스크립트는 공식 v0.9.0과 v0.9.1에서 이전 소스 패턴이 달라 중단한다. 두 태그의 정식 Studio 빌드 경로에서 이 실험용 스크립트는 호출되지 않는다.

다음 검증은 수정 브랜치의 workflow를 공식 `v0.9.1` (`981ce66b4183b13c1a3b5907e04a8969c8c42034`)으로 실행해 저장량·최저 여유 공간과 후보 PR을 확인하는 것이다. 원격 실행과 후보 게시, 생성된 후보의 실제 WKWebView·Finder 수용 검사는 아직 남아 있다. 현재 단계에서는 공개 릴리즈·core pin 변경을 진행하지 않았다.
