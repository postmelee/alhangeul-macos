# Task #182 Finder 영상 디자인 기준

## Style Prompt

현재 `docs/` 홍보 페이지의 세 번째 기능 섹션 중 Finder stage만 16:9 영상으로 추출한다. 상단 progress/checkpoint 박스는 최종 영상에서 제외하고, `.hwp 정보 잠김` badge와 중앙 알한글 설치 orb, 하단 `알한글 설치` 라벨을 유지한다. 새 비주얼 스타일을 만들지 않고 기존 웹페이지의 Finder 이미지, 색상, 타이포그래피, 설치 애니메이션 감각을 따른다.

## Colors

- Finder stage: `#151820`
- Install green: `#34c759`

## Typography

- System font stack: `-apple-system`, `BlinkMacSystemFont`, `SF Pro Display`, `Segoe UI`, `sans-serif`
- Korean text는 시스템 San Francisco/Apple SD Gothic Neo 렌더링을 따른다.

## What NOT to Do

- 새 landing-page hero처럼 과장된 장식 요소를 추가하지 않는다.
- 기존에 없는 purple/gradient/orb 배경을 추가하지 않는다.
- 원본 Finder 이미지를 흐리게 처리하거나 어둡게 덮어 가독성을 낮추지 않는다.
- 상단 progress/checkpoint 박스를 영상 안에 다시 넣지 않는다.
- `.hwp 정보 잠김` badge와 install orb 위치는 유지하되, 실제 페이지 축소 표시에서 읽히지 않으면 크기는 조정한다.
- `.hwp 정보 잠김` badge는 설치 전 상태가 멈춰 보이지 않도록 scale, glow, sheen을 사용해 진행감을 준다.
- 설치 진행 애니메이션은 ease-out 곡선을 사용해 초반에 빠르게 진행되고 끝에서 부드럽게 감속한다.
- 최종 출력은 1440x810이지만 캡처는 2x 스케일로 수행해 로고와 라벨의 선명도를 확보한다.
