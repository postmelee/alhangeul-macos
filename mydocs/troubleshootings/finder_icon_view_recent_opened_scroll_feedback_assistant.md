# Finder 최근 사용일 그룹 스크롤 버벅임 `Feedback Assistant` 제출 정리

## 작성 목적

2026년 4월 24일 기준으로 확인한 Finder 스크롤 버벅임 재현 조건과, Apple `Feedback Assistant`에 바로 제출할 수 있는 내용을 한 문서에 정리한다.

이 문서는 다음 상황을 전제로 한다.

- Finder `아이콘 보기`
- `최근 사용일(Date Last Opened)` 기준 정렬 또는 그룹
- `어제`, `이전 7일`, `더 이전 날짜` 같은 그룹 섹션이 생김
- 세로 스크롤과 가로 스크롤이 동시에 가능한 2축 레이아웃

## 현재 판단

현재까지의 결론은 다음과 같다.

1. 이 현상은 `.hwp` / `.hwpx`가 많은 폴더에서 더 눈에 띌 수는 있다.
2. 하지만 `.hwp` / `.hwpx`가 전혀 없는 `Desktop` 폴더에서도 같은 보기 모드에서 같은 현상이 재현됐다.
3. 우리 앱의 thumbnail extension은 `hwp` / `hwpx` UTI에만 등록되어 있으므로, HWP가 없는 폴더에서는 호출될 수 없다.
4. 따라서 근본 원인은 우리 앱 extension이 아니라 Finder의 `아이콘 보기 + 최근 사용일 그룹 + 2축 스크롤` 조합일 가능성이 높다.

즉, 이 문서의 목적은 앱 버그 신고가 아니라 macOS/Finder 동작 버그를 Apple에 전달하는 것이다.

## 제출 경로

가능하면 `Feedback Assistant`로 제출한다.

- 앱: Spotlight에서 `Feedback Assistant` 실행
- URL 스킴: `applefeedback://`
- 웹: [feedbackassistant.apple.com](https://feedbackassistant.apple.com)
- 안내 문서: [Apple Developer - Feedback Assistant](https://developer.apple.com/feedback-assistant/)

`Feedback Assistant`를 쓸 수 없는 경우에는 일반 피드백 폼을 대안으로 쓸 수 있다.

- [Apple Product Feedback - macOS](https://www.apple.com/feedback/macos/)

단, 일반 피드백 폼보다 `Feedback Assistant`가 더 적합하다.

- macOS 앱에서 제출하면 진단 정보 수집이 더 용이하다.
- Apple이 후속 질문이나 추가 로그 요청을 같은 리포트에서 이어갈 수 있다.

## 제출 전 준비물

권장 첨부물은 아래와 같다.

1. 문제 재현 화면 녹화 1개
2. grouped icon layout이 보이는 Finder 스크린샷 1장 이상
3. 문제가 잘 드러나는 폴더 경로 예시
4. 가능하면 비교 자료
   - 같은 폴더에서 다른 정렬 기준일 때는 정상이라는 영상
   - `.hwp`가 없는 폴더에서도 재현된다는 영상

가능하면 아래 정보도 같이 적는다.

- macOS 버전과 build 번호
- 사용 기기 모델
- 트랙패드 또는 마우스 사용 여부
- 외부 모니터 사용 여부

## `Feedback Assistant` 입력 가이드

권장 시작 토픽은 `macOS`이다.

가능하면 영역은 Finder 또는 Files/Windowing 계열로 고른다. 정확한 세부 카테고리 이름은 시점에 따라 달라질 수 있으므로, `Finder`와 가장 가까운 항목을 고르면 된다.

한 리포트에는 한 이슈만 적는다.

- 이번 리포트의 범위:
  - Finder grouped icon view에서의 스크롤 관성/정지 문제
- 넣지 말아야 할 내용:
  - HWP 썸네일 품질 개선
  - Quick Look extension 구현 세부
  - 우리 앱 아키텍처 변경 요청

## 복붙용 제출 초안

### 제목

`Finder icon view grouped by Date Last Opened stops inertial scrolling in bidirectional layout`

### 요약

Finder에서 `아이콘 보기`를 사용하고 `Date Last Opened`로 그룹 또는 정렬하면, 세로/가로 스크롤이 모두 가능한 grouped icon layout에서 관성 스크롤이 자연스럽게 이어지지 않고 즉시 멈추는 현상이 발생한다. 경우에 따라 다음 클릭이나 추가 입력이 들어오면, 멈춰 있던 스크롤이 뒤늦게 다시 진행되는 것처럼 보인다.

### 재현 절차

1. Finder에서 항목 수가 충분히 많은 폴더를 연다.
2. 보기 방식을 `아이콘 보기`로 바꾼다.
3. `정렬` 또는 `그룹` 기준을 `Date Last Opened`로 맞춘다.
4. `Yesterday`, `Previous 7 Days` 같은 그룹 섹션이 보이고, 세로/가로 스크롤이 모두 가능한 상태를 만든다.
5. 트랙패드 또는 마우스로 빠르게 스크롤한다.

### 실제 결과

- 관성 스크롤이 자연스럽게 감속되지 않고 바로 멈춘다.
- 경우에 따라 다음 클릭 또는 추가 입력이 들어오면, 멈춰 있던 스크롤이 뒤늦게 다시 진행되는 것처럼 보인다.
- 같은 폴더라도 다른 보기/정렬 조합에서는 덜 두드러지거나 재현되지 않는다.

### 기대 결과

- grouped icon layout에서도 일반적인 Finder 관성 스크롤이 유지되어야 한다.
- 추가 클릭 없이 스크롤 감속과 화면 갱신이 자연스럽게 이어져야 한다.

### 추가 관찰

- 이 문제는 특정 서드파티 Quick Look Thumbnail extension이 없어도 재현된다.
- `.hwp` / `.hwpx` 파일이 전혀 없는 `Desktop` 폴더에서도 같은 보기 모드에서 동일 증상이 확인됐다.
- 따라서 특정 문서 포맷 extension 하나의 문제라기보다, Finder의 `아이콘 보기 + Date Last Opened 그룹 + 2축 스크롤` 조합에서 발생하는 UI/스크롤 처리 문제로 보인다.

### 영향

- 많은 파일을 가진 폴더에서 탐색 경험이 눈에 띄게 저하된다.
- 스크롤이 끊기고 입력 반응이 어색해 Finder가 잠깐 멈춘 것처럼 느껴진다.

## 한국어 초안

제목:

`Finder 아이콘 보기에서 최근 사용일 그룹 정렬 시 2축 스크롤 관성이 끊기고 클릭 후 다시 진행됨`

본문:

Finder에서 `아이콘 보기`를 사용하고 `최근 사용일(Date Last Opened)`로 그룹 또는 정렬하면, 세로 스크롤과 가로 스크롤이 모두 가능한 grouped icon layout에서 스크롤 관성이 부드럽게 이어지지 않고 즉시 멈추는 현상이 발생합니다. 경우에 따라 다음 클릭이나 추가 입력이 들어오면, 멈춰 있던 스크롤이 뒤늦게 다시 진행되는 것처럼 보입니다.

재현 절차는 다음과 같습니다.

1. Finder에서 항목 수가 충분히 많은 폴더를 엽니다.
2. 보기 방식을 `아이콘 보기`로 바꿉니다.
3. `정렬` 또는 `그룹` 기준을 `최근 사용일(Date Last Opened)`로 설정합니다.
4. `어제`, `이전 7일`, `더 이전 날짜` 같은 그룹 섹션이 보이고, 세로/가로 스크롤이 모두 가능한 상태를 만듭니다.
5. 트랙패드 또는 마우스로 빠르게 스크롤합니다.

실제 결과:

- 관성 스크롤이 자연스럽게 감속되지 않고 바로 멈춥니다.
- 경우에 따라 다음 클릭 또는 추가 입력이 들어오면, 멈춰 있던 스크롤이 뒤늦게 다시 진행되는 것처럼 보입니다.
- 같은 폴더라도 다른 보기/정렬 조합에서는 덜 두드러지거나 재현되지 않습니다.

기대 결과:

- grouped icon layout에서도 일반적인 Finder 관성 스크롤이 유지되어야 합니다.
- 추가 클릭 없이 스크롤 감속과 화면 갱신이 자연스럽게 이어져야 합니다.

추가 관찰:

- 이 문제는 특정 서드파티 Quick Look Thumbnail extension이 없어도 재현됩니다.
- `.hwp` / `.hwpx` 파일이 전혀 없는 `Desktop` 폴더에서도 같은 보기 모드에서 동일 증상이 확인됐습니다.
- 따라서 특정 문서 포맷 extension 하나의 문제라기보다, Finder의 `아이콘 보기 + 최근 사용일 그룹 + 2축 스크롤` 조합에서 발생하는 UI/스크롤 처리 문제로 보입니다.

## 제출 후 처리

리포트를 제출하면 `Feedback Assistant ID`가 발급된다. 이후 보완 자료는 같은 리포트에 이어서 넣는다.

- 추가 정보: 화면 녹화, 스크린샷, 비교 영상
- 추가 설명: 어떤 폴더에서 재현됐는지, 어떤 정렬/그룹에서만 재현되는지

업데이트 방법 안내:

- [Update or close submitted feedback in Feedback Assistant on Mac](https://support.apple.com/guide/feedback-assistant/update-or-close-submitted-feedback-fbacc24e7d22/mac)

## 참고 링크

- [Apple Developer - Feedback Assistant](https://developer.apple.com/feedback-assistant/)
- [Feedback Assistant User Guide for Mac](https://support.apple.com/en-lamr/guide/feedback-assistant/welcome/mac)
- [Create new feedback in Feedback Assistant on Mac](https://support.apple.com/en-lamr/guide/feedback-assistant/fbad45b5bb25/mac)
- [Feedback - macOS - Apple](https://www.apple.com/feedback/macos/)
- [Finder에서 항목 정렬 및 배치](https://support.apple.com/sr-rs/guide/mac-help/mchlp1745/mac)
- [Finder에서 항목을 빠르게 보는 방법](https://support.apple.com/en-lamr/guide/mac-help/mh11493/mac)
