# Task M900 #618 4단계 중간 기록 — 자동 동기화 러너 저장 공간

2026-11-20 · [#618](https://github.com/postmelee/alhangeul-macos/issues/618) · 대상 `devel` `08ce865e2ac9bd495e4696f40f64da515140c302`

[자동 동기화 44696814904](https://github.com/postmelee/alhangeul-macos/actions/runs/44696814904)에서 Linux의 WASM/Studio 빌드와 자산 업로드가 통과했다. macOS 작업은 별도 upstream clone과 복원까지 진행한 뒤 `cargo generate-lockfile`이 같은 저장소의 Git pack을 별도로 받는 중 `No space left on device`로 실패했다. 실행에 파일 시스템 계측이 없어 당시 최대 사용량과 필요한 여유 공간의 정확한 수치는 알 수 없다.

- macOS에서 Cargo가 받은 release-tag 의존성을 metadata의 공식 저장소 URL·태그·SHA로 찾고 checkout HEAD도 대조한다. 객체를 공유하는 sparse checkout으로 원본 Studio 소스와 root `Cargo.lock`만 복원한다. 기존 Studio receipt, Cargo.lock, ABI, 렌더 트리 검증을 계속 실행한다.
- Linux 업로드 준비와 macOS 복원에서 작업 내 `pkg`와 `dist`를 이동해 중복 보관을 줄인다. 기존 Cargo 캐시와 사용자 파일을 정리하는 단계는 추가하지 않았다.
- Cargo Git DB·checkout·registry, 앱 체크아웃·Rust target·Frameworks, Studio 자산 사용량과 여유 공간을 CI 로그와 요약에 기록한다. 8 GiB(Cargo 의존성 해석 전), 4 GiB(Universal 빌드 전)는 조기 실패를 위한 최소값이다. 해당 값이 전체 빌드에 충분한지는 실제 러너 재실행에서 확인한다.

`actionlint`, `git diff --check`, Studio Node 회귀 34건과 Studio Cargo.lock fingerprint 검사가 통과했다. 작은 Cargo/Git fixture에서 workflow 복원 명령으로 객체 공유, sparse checkout, 자산 이동, 다른 태그 거부를 확인했다. 디스크 검사는 경계값 통과, 경계 미달과 해석 불가 값 거부를 확인했다. #594의 실험용 글꼴 대기 제한 스크립트는 공식 v0.9.0과 v0.9.1에서 이전 소스 패턴이 달라 중단한다. 두 태그의 정식 Studio 빌드 경로에서 이 실험용 스크립트는 호출되지 않는다.

다음 검증은 수정 브랜치의 workflow를 공식 `v0.9.1` (`981ce66b4183b13c1a3b5907e04a8969c8c42034`)으로 실행해 저장량·최저 여유 공간과 후보 PR을 확인하는 것이다. 원격 실행과 후보 게시, 생성된 후보의 실제 WKWebView·Finder 수용 검사는 아직 남아 있다. 현재 단계에서는 공개 릴리즈·core pin 변경을 진행하지 않았다.

[수정 workflow 실행 44748954259](https://github.com/postmelee/alhangeul-macos/actions/runs/44748954259)는 Linux와 macOS 세 작업이 모두 통과해 [동기화 후보 #622](https://github.com/postmelee/alhangeul-macos/pull/622)를 생성했다. macOS 가용 공간은 Cargo 해석 전 46,864,204KiB, 해석 후 25,970,196KiB, Universal 빌드 후 22,505,936KiB, 종료 시 22,229,280KiB였다. Studio 복원 뒤 다운로드 폴더 사용량은 0KiB였다. Cargo checkout과 Git DB는 hardlink 또는 공유 객체의 용량을 포함할 수 있어 `du` 값을 합산해 실제 파일 시스템 사용량으로 해석하지 않는다.

## 공식 v0.9.1 Studio PDF 출력 예비 검증 후속

공식 Studio의 portable 레이어 스키마 `1.35`는 보통의 굵은 textRun을 0.02 em SVG 획으로 출력한다. 앱의 변환은 `1.23`만 받았고, `1.35`에서 획이 남아 네이티브 PDF가 관리 글꼴의 해당 출력에 `unavailable`을 반환했다. 공식 v0.9.1 WASM에서 HWP/HWPX 입력의 style과 클러스터 원점을 대조했다. 검증한 `1.35`를 명시적으로 허용하고 기존 `1.23` 및 알 수 없는 스키마와 모호한 효과에 대한 검사를 유지한다.

현재 공식 동기화 CI의 동일 WASM으로 원본 소스 검사, TypeScript, Vite 및 receipt 대조를 통과했다. 네이티브 v0.9.0 라이브러리를 링크한 격리 WKWebView에서 고운바탕 Regular/Bold를 가져와 두 파일의 실제 PDF와 인쇄용 PDF를 생성했다. 정확한 PostScript 이름, 한글 검색·선택, 취소 및 글꼴 변경 때의 기존 문서 보존을 확인했다. 실제 인쇄 창은 정상 표시 후 취소했다. 최종 설치 후보의 native v0.9.1과 Finder 검증은 별도로 실행한다.

## 네이티브 매처 동기화

[후보 CI 44762597317](https://github.com/postmelee/alhangeul-macos/actions/runs/44762597317)은 Studio 자산 검증을 통과한 뒤 네이티브 매처의 기존 `c9095c5f` pin을 발견했다. 공식 v0.9.1의 원본 모듈 10개와 esbuild `0.25.12`로 Swift 매처와 receipt를 다시 생성하고 공식 checkout과 검증했다. 자동 동기화는 같은 sparse checkout에서 두 파일을 생성·검증하고 함께 stage한다. 자동 동기화 대상 판정도 매처 pin을 확인한다.

수정한 #622 head `b99c8672`에서 [네 CI 작업](https://github.com/postmelee/alhangeul-macos/actions/runs/44772183143)이 통과했고 `devel` `6c1c9177`에 병합했다. [병합 뒤 동기화 dry-run 44856141808](https://github.com/postmelee/alhangeul-macos/actions/runs/44856141808)은 대상 판정만 실행하고 새 후보를 만들지 않았다.

## 비공개 OLE 제보에서 확인한 공식 차트 호환 문제

공개 #613 회귀 문서는 통과했다. 별도 비공개 제보의 HWP/HWPX는 SVG 요소가 허용 범위였지만 공식 v0.9.1 Rust 차트 그룹이 붙인 네 메타데이터 속성 때문에 PNG와 PDF 모두 `rejected`로 돌아갔다. 공식 생성 소스와 대조한 네 속성만 정확한 차트 그룹과 알려진 값에서 허용했다. SVG 요소, 외부 참조, CSS, 파일 크기 제한은 기존 정책을 적용한다.

공개 합성 회귀에서는 차트 메타데이터를 허용하고 알 수 없는 버전·그룹·속성 및 음수 ID를 거부했다. 공개 차트의 막대·축·범례와 일반 문서·권한 거부 경로도 통과했다. 비공개 양쪽 원본은 수정 전 `coreGraphics/rejected`, 수정 뒤 PNG `skia/vector`와 PDF `vector`로 바뀌었고 두 PNG 바이트가 일치했다. 원본·출력은 비공개 검증 위치에만 저장했다. 실제 Finder 공급자의 수용은 서명 설치 후보에서 별도로 확인한다.
