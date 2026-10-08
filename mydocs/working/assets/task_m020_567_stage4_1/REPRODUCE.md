# #567 Stage 4.1 재현

저장소 루트에서 실행한다. SDK/Xcode·Node·로그인한 macOS GUI와 기존 generated XCFramework가 필요하다. 설치 원본·사용자 앱 설정은 변경하지 않는다.

```bash
scripts/profile-installed-font-startup.sh
scripts/test-font-library.sh
python3 scripts/probe-studio-font-integration.py --changes --interactive \
  --output-dir build.noindex/task567/stage4-1-reproduction
FONT_SETTINGS_PROBE_OUT="$PWD/build.noindex/task567/stage4-1-ui-reproduction" \
  scripts/probe-installed-font-ui.sh
python3 scripts/smoke-studio-document-lifecycle.py \
  --fixture samples/re-font-dotum-empty-hancom.hwp
scripts/verify-rhwp-studio-assets.sh \
  --upstream-dir build.noindex/task567/stage3-2/upstream-v087
scripts/check-no-appkit.sh
```

시작 조사 CLI는 Swift `-O`로 실제 CoreText metadata·catalog·provider를 사용한다. 새 UUID 저장소에 5개 새 프로세스를 실행하고 JSON/집계를 기록한다. 전체 GUI launch·OS cold·signed sandbox 시험이 아니며 사용자 경로/이름/bytes는 집계 결과에 넣지 않는다. 사용 꺼짐 상태의 시작 준비와 최초 활성화 요청을 재현한다.

WK probe는 같은 제품 설정·서비스·Coordinator·Studio와 승인된 고운바탕 전용 복사본을 사용한다. 필요한 다운로드/라이선스·격리 파일 변경의 범위는 [Stage 4 재현](../task_m020_567_stage4/REPRODUCE.md)을 따른다. 원본 제거/읽기 거부·관리 복사본·재실행과 렌더링은 가상 28개 화면 시험과 별개다. 화면 캡처 helper는 macOS 14.4 이상이 필요하며 제품 최소 target은 macOS 12다.

28개 UI probe는 가상 목록으로 실제 설정 View를 확인한다. 감지 개수를 펼쳐 검색·family/권한 안내를 확인하고 긴 목록을 스크롤한다. 다시 접고 “글꼴 가져오기…”를 눌러 source 선택 sheet가 한 번에 열리는지 확인한다. 해당 화면 확인만으로 실제 글꼴 공급이나 OS 설치 성공을 주장하지 않는다. 이번 Cua 조작에서는 source 탐색이나 폴더 권한 제출은 하지 않았다.

실행 중인 앱의 경로를 재사용하여 실행 파일을 덮어쓰지 않는다. native smoke 중 다른 앱 창을 조작하지 않고 최종 raw log와 cleanup 결과를 확인한다. 직접 조작 앱은 창을 닫으면 종료하고 소유 경로만 등록 해제한다. 오래된 사용자 앱·개발 확장이나 전역 cache는 변경하지 않는다.

보존 파일은 현재 소스 SHA256, 시작 집계·5개 프로세스 결과, 최종 회귀·실제 PNG, 세 번의 WK 중간 실패와 lifecycle 첫 실패를 포함한다. `checksums.json`은 자신을 제외한 이 폴더의 증거 SHA256이다. 늦은 닫힘 보정 전의 실패와 최종 성공을 구분하여 읽는다.
