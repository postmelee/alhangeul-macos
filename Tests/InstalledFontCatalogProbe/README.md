# 설치 글꼴 catalog·권한 지속 검증 — Task #565 Stage 4

실제 `InstalledFontCatalogService`와 `InstalledFontSystem`을 사용하는 격리된 sandbox 앱이다. 테스트 사용자에게 허용받은 로컬 코드 서명 인증서가 필요하다. 제품 배포·공증이나 영구 시스템 글꼴 설치를 수행하지 않는다.

```bash
PROBE_SIGN_ID='승인된 로컬 인증서 이름' scripts/probe-installed-font-catalog.sh
```

공용 설치 `NanumSquareR`, `NanumSquareB`가 있어야 한다. 없으면 실패하며 자동 설치하지 않는다. 설정과 목록은 probe 자체 컨테이너의 Application Support/InstalledFontCatalogProbe에 저장한다. 같은 명령을 반복하면 사용 설정을 복원하고 공용 글꼴 두 face의 실제 bytes·검증 SHA-256·sfntIndex를 확인한다.

## 지속 권한 대조

```bash
PROBE_SIGN_ID='승인된 로컬 인증서 이름' scripts/probe-installed-font-catalog.sh --choose
```

실행 전 사용자에게 `build.noindex/task565-stage4/installed-font-permission-fixture` 폴더의 지속 읽기 허용을 받는다. NSOpenPanel에서 **이 폴더만** 선택한다. 저장소의 자체 테스트 글꼴 1개를 복사한 폴더이며 실제 사용자 Fonts를 선택하지 않는다. 출력의 `outsideReadableBeforeSelection: false`와 `bookmarkRead: true`로 선택 전 거부/선택 후 읽기를 구분한다.

이후 `--choose` 없이 다시 실행해 `restoredEnabled: true`, `bookmarkCount: 1`, `bookmarkRead: true`, `grantIssues: 0`을 확인한다. 같은 bundle ID와 서명 기준을 유지한다. 접근한 자체 fixture는 프로세스 범위로만 CoreText에 등록하고 작업 종료 시 해제한다. 영구 등록하지 않는다.

probe는 App Sandbox, user-selected.read-only, bookmarks.app-scope entitlement를 사용한다. 사용 설정·읽기 권한 검증이며 renderer/설정 UI/확장 통합 검증은 아니다. JSON 결과는 probe 자체 컨테이너에 기록되고 stdout에도 출력된다. 원본 경로·bookmark bytes는 stdout에 출력하지 않는다.

자체 fixture 폴더와 probe 컨테이너는 재현을 위해 유지한다. 일반 사용자의 글꼴·한컴 앱·제품 설정 저장소를 변경하지 않는다.
