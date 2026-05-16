# Issue #144 Stage 4 보고서

## 단계 목적

Stage 2-3 구현이 실제 macOS 앱 실행 환경에서 toolbar 활성 상태를 바꾸는지 확인한다. Debug HostApp 빌드, Finder drag/drop, native open 경로를 smoke 검증하고 접근성 트리 기준으로 toolbar 상태를 기록한다.

## 산출물

- `mydocs/working/task_m010_144_stage4.md`
  - Stage 4 smoke 검증 보고서
- 앱 소스 변경 없음
- 문서 외 변경 없음

## 본문 변경 정도 / 본문 무손실 여부

- 코드 본문 변경: 없음
- 리소스 본문 변경: 없음
- 검증 보고서만 추가

## 검증 환경

- 앱: `build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app`
- 샘플:
  - drag/drop: `samples/exam_social.hwp`
  - native open: `samples/exam_science.hwp`
- 창 배치:
  - Finder와 알한글 앱 창을 나란히 배치
  - Finder 선택 파일을 CGEvent 좌표 drag로 viewer 영역에 drop
- 접근성 확인:
  - Computer Use accessibility tree와 screenshot 기반 확인

## 검증 결과

### Debug build

실행 명령:

```bash
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과:

```text
** BUILD SUCCEEDED ** [0.354 sec]
```

빌드 중 CoreSimulatorService와 `~/Library/Logs/CoreSimulator` 접근 경고가 출력되었지만 macOS HostApp build는 성공했다.

### 빈 앱 baseline

Debug 앱을 빈 상태로 실행한 직후 접근성 트리에서 titlebar toolbar baseline을 확인했다.

결과:

- `공유`: disabled
- `Finder에서 보기`: disabled
- `PDF로 내보내기`: disabled
- viewer status: `HWP 파일을 선택해주세요.`

이 상태는 문서가 없는 초기 상태로 정상이다.

### Finder drag/drop smoke

`samples/exam_social.hwp`를 Finder에서 선택하고 알한글 viewer 영역으로 drag/drop했다. 첫 번째 Computer Use drag는 창 내부 좌표 제한으로 drop이 들어가지 않았고, 이후 실제 화면 좌표 CGEvent drag로 재시도했다.

확인된 접근성 트리:

```text
URL: alhangeul-studio://app/index.html?url=alhangeul-document://current?revision%3D1&filename=exam_social.hwp
status: exam_social.hwp — 4페이지
```

toolbar 결과:

- `공유`: enabled
- `PDF로 내보내기`: enabled
- `Finder에서 보기`: disabled

판정:

- 원래 버그였던 `공유`와 `PDF로 내보내기` 비활성 상태는 해결됨
- JS `File` 기반 drag/drop은 원본 filesystem URL이 없으므로 `Finder에서 보기` disabled 유지가 Stage 1-3 정책과 일치함

### native open 회귀 smoke

상대 app path를 사용한 첫 명령은 `Unable to find application named ...`로 실패했고, 절대 app path로 다시 실행했다.

성공 명령:

```bash
open -a /Users/melee/Documents/projects/rhwp-mac/build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app /Users/melee/Documents/projects/rhwp-mac/samples/exam_science.hwp
```

확인된 접근성 트리:

```text
URL: alhangeul-studio://app/index.html?url=alhangeul-document://current?revision%3D1&filename=exam_science.hwp
status: exam_science.hwp — 4페이지
```

toolbar 결과:

- `공유`: enabled
- `Finder에서 보기`: enabled
- `PDF로 내보내기`: enabled

판정:

- source URL을 보유한 native open 경로에서는 세 toolbar item이 모두 활성화됨
- 최근 문서 기록을 깨뜨리는 직접 증거는 발견되지 않음. native open은 `sourceDocument`를 보유하므로 기존 최근 문서 기록 경로를 그대로 사용한다.

## 잔여 위험

- HWPX drag/drop smoke는 이번 단계에서 별도로 실행하지 않았다. Stage 5 또는 최종 검증에서 HWPX는 toolbar 상태와 저장 제한 정책만 추가 확인하는 것이 좋다.
- `Finder에서 보기`는 drag/drop 경로에서 의도적으로 disabled다. 사용자가 Finder에서 끌어온 파일의 원본 선택까지 기대한다면 AppKit `NSDraggingDestination` 기반 URL 확보를 후속 설계로 분리해야 한다.
- PDF export와 share payload 생성의 실제 완료까지는 클릭 실행하지 않았다. 이번 smoke의 목적은 toolbar 활성 상태 회귀 확인이며, payload export 자체는 기존 bridge 기능에 의존한다.

## 다음 단계 영향

Stage 5에서 다음을 정리한다.

- 오늘할일 상태 갱신
- 최종 보고서 준비
- 필요 시 HWPX 추가 smoke 여부 결정
- PR 전 전체 검증 명령과 잔여 리스크 정리

## 승인 요청

Stage 4 앱 실행 및 smoke 검증을 완료했다. Stage 5 문서 정리와 최종 보고 준비로 진입하려면 작업지시자 승인이 필요하다.
