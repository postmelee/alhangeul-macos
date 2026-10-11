# 실제 Mac 글꼴·Studio sandbox 수용 — Task M020 #567 Stage 5

가상 활성 목록을 주입하지 않고 실제 `InstalledFontSystem`과 제품 catalog/provider/Coordinator/설정 View 및 정식 bundled Studio를 사용한다. 문서·설정·관리 저장소는 고유 bundle ID의 sandbox 컨테이너에 격리한다. 사용자 앱 설정·관리 App Group·원본 글꼴·실제 문서를 변경하지 않는다.

## 실행

해당 Mac에 활성 static `NanumSquareR`와 `NanumSquareB`가 있어야 한다. 이 도구는 글꼴을 다운로드하거나 OS에 설치하지 않는다. 사용자가 승인한 기존 로컬 코드 서명 인증서만 지정한다. 키체인 접근은 사용자가 허용하며 credential을 입력·저장하지 않는다.

```bash
python3 scripts/probe-studio-font-acceptance.py \
  --output-dir build.noindex/task567/stage5/example-acceptance \
  --sign-identity '<승인된 로컬 코드 서명 인증서>'
```

처음 결과는 `first/`, 같은 앱의 새 프로세스 결과는 `reopen/`에 복사된다. 새 output 경로는 새 bundle ID를 사용하므로 이전 실행의 설정을 삭제할 필요가 없다. 같은 경로를 다시 사용하면 이미 저장한 설정·문서를 복원하므로 신규 저장소 대조와 구분한다. `build-receipt.json`은 컴파일한 소스·Studio·native framework와 실행 파일 hash를 기록한다. `--skip-build`는 현재 파일·서명 기준이 영수증과 일치하는 경우만 허용한다. 실행 중인 앱의 경로에 다시 빌드하지 않는다.

직접 조작하려면 최초 명령에 `--interactive`를 추가하거나, 성공한 동일 경로에서 다음을 실행한다.

```bash
python3 scripts/probe-studio-font-acceptance.py \
  --output-dir build.noindex/task567/stage5/example-acceptance \
  --sign-identity '<앞서 지정한 동일 인증서>' \
  --skip-build --interactive-only
```

“알한글 — 실제 Mac 글꼴 설정 · sandbox 테스트” 창에서 실제 목록 펼치기·검색·사용 설정·다시 감지·가져오기를 조작할 수 있다. 문서 창에서는 상단 기존 글꼴 메뉴의 시스템 글꼴 범주를 사용한다. Studio 환경설정의 글꼴 설정 버튼은 같은 테스트 설정 창을 연다. 모든 창을 닫으면 helper가 소유한 앱 경로만 LaunchServices에서 해제한다. Quick Look/Thumbnail을 등록하거나 다른 앱 등록을 지우지 않는다.

## 검증 경계

- 실제 metadata 탐색·원본 읽기의 횟수/시간을 계측한다. font 경로·bookmark는 출력 JSON에 기록하지 않는다. 전체 목록 감지·menu family 개수와 실제 bytes/renderer 지원 성공을 구분한다. 모든 목록 항목의 파일을 선읽어 지원 여부를 증명하지 않는다.
- 동시 최초 준비 8회와 초기 활성화 호출을 같은 actor로 재현한다. OS 활성화 이벤트의 실제 전달 자체를 검증하는 앱이 아니다. CoreText 알림 감시는 이번 결정적 계측에서 끈다. 실제 원본은 필요한 읽기마다 제품 경로로 재검증하며 수동 재감지는 가능하다.
- 같은 face의 8개 요청 병합과 서로 다른 두 face의 동시 공급에는 150ms의 도착 정렬용 지연만 주입한다. 목록·bytes·파일 권한은 실제 환경이다. 출력 `readMS`는 이 지연을 제외하며 전체 helper 소요 시간에는 포함한다.
- fresh process의 준비와 문서 요청→ready, 정확한 face 준비를 구분한다. 확대/축소와 반복 표시의 추가 읽기를 확인한다. `launchToAcceptanceMS`에는 대기·직접 읽기 대조·스크린샷이 포함되므로 제품 시작 시간이나 OS font server cold benchmark로 사용하지 않는다.
- native HWPX 저장과 HWP로 다른 이름 저장은 제품 session guard·save bridge·payload 검사·실제 쓰기·완료 동기화를 사용한다. 저장 위치와 합성 문서의 변환 확인만 주입한다. 물리 NSSavePanel 조작이나 실제 IME 입력을 검증했다고 주장하지 않는다.
- 첫 저장 후 bundled WASM으로 HWP/HWPX 본문·원래 family·Regular/Bold·내부 alias 미유출을 검사한다. 새 프로세스에서는 실제 글꼴 재읽기·두 renderer·저장 문서 복원을 확인한다.
- App Sandbox, network.client, user-selected.read-write, bookmarks.app-scope를 사용한다. 테스트 관리 저장소는 private root이며 실제 제품 App Group의 배포 서명 수용을 대체하지 않는다. 기존 #565 bookmark 복원은 동일한 별도 앱·서명 기준에서 검증하며 이 앱으로 권한을 복사하지 않는다.
- 앱 자체 창만 `ScreenCaptureKit.currentProcess`로 촬영한다. 촬영은 macOS 14.4+가 필요하다. macOS 12 대상 컴파일 성공은 macOS 12/Intel 실제 실행·공증된 제품 수용의 증거가 아니다. 영구 OS 설치/삭제·다른 볼륨·한컴 앱 삭제와 #568 출력/Finder는 별도 범위다.
