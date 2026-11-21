# Task #612 Stage 1 — 회귀 자산과 경로 선정

## 단계 목적
원본과 기준 PDF를 고정하고 현재 공개 API로 가능한 개선 경로를 결정한다.

## 산출물
samples/issue7406의 HWP(78,336 bytes), PDF(330,163 bytes), 출처·해시 README. upstream v0.9.0 기준의 render tree/CG PNG와 Skia policy baseline을 build.noindex/task612에 보관했다.

## 본문 변경 정도 / 본문 무손실 여부
원본 파일의 bytes를 그대로 복사했다. HWP/PDF SHA-256은 이슈 기록과 일치한다. 본앱 정상 표시는 사용자 확인을 따른다.

## 검증 결과
- smoke-quicklook-skia-policy.sh: resolver OK, CG/Skia decode/Skia direct 모두 생성 성공. CG 28,528 bytes, Skia decode 63,928 bytes, Skia direct 63,469 bytes.
- render-debug-compare.sh: tree/core SVG/native PNG 생성 성공. RawSvg에 g/line/rect/text 벡터 요소 확인.
- core 내부 rasterize_svg_fragment_to_png는 비공개이며 현재 공개 FFI는 페이지 단위다.

## 잔여 위험
Skia 성공은 PDF 시각 동등성의 증명이 아니다. 주변 캡션과 글꼴의 차이를 Stage 3에서 확인한다. 개체 단위 FFI는 이번 수정에 추가하지 않는다.

## 다음 단계 영향
유한한 bbox와 제한된 벡터 XML을 가진 RawSvg 페이지에만 공개 Skia PNG 경로를 사용한다. 일반 페이지·단일 래스터 조각·부적합 입력은 CoreGraphics를 유지한다.

## 승인
PR까지 진행하라는 작업지시자의 명시 승인에 따라 Stage 2로 진행한다.
