# 설치 글꼴 설정 UI 확인

저장소 루트에서 `scripts/probe-installed-font-ui.sh`를 실행한다. 어두운 모드는 `scripts/probe-installed-font-ui.sh --dark`로 실행한다. 기존 테스트 창을 닫은 후 모드를 바꾼다.

- 제품과 같은 View/모델을 720×560 창에 표시한다. 기본 모드는 가상 family 28개 × Regular/Bold/Light 3종 = 84개 face다. 긴 이름/충돌/권한 부족/미지원도 포함하는 **주입한 테스트 메타데이터**이며 실제 설치 글꼴 목록이 아니다.
- 데이터는 `build.noindex/task565-stage5/ui-data`에만 저장한다. 앱의 실제 설정·사용자 글꼴은 변경하지 않는다.
- 사용 체크 → 새로고침 → 재실행 후 체크 복원, 보관함 열기 → Escape 닫기, 권한 폴더 선택창 → Escape 취소를 확인한다.
- 이 probe의 권한 저장은 의도적으로 미지원이다. 실제 선택 URL의 bookmark 저장/복구는 `InstalledFontCatalogProbe`의 signed sandbox 검증을 사용한다.
- macOS 12 대상으로 warnings-as-errors 컴파일하고 ad-hoc 서명/검증한다. 제품 sandbox와 macOS 12 실제 실행 검증을 대신하지 않는다.
- 최종 화면: `build.noindex/task565-stage5/screenshots/light.jpeg`, `dark.jpeg`.
- Finder 확장을 포함하지 않으며 시스템 글꼴 등록도 하지 않는다. 창의 닫기 버튼으로 종료한다.

## 실제 Mac 목록 확인

`scripts/probe-installed-font-ui.sh --live`는 실제 CoreText 활성 목록을 표시하고 설정은 `ui-data/installed-live`에 격리한다. 실제 글꼴 bytes 복사나 시스템 설치는 하지 않는다. 이 모드에서 사용자가 폴더 접근을 허용하면 해당 테스트 저장소에 읽기 bookmark를 저장하므로, 화면 확인만 할 때는 폴더 선택을 취소한다. 검색·family 펼치기·스크롤을 직접 확인할 수 있다.
