# Task #612 Stage 2 — 제한된 RawSvg 페이지 선택

## 단계 목적
공개 Skia PNG API로 허용된 벡터 RawSvg가 있는 Quick Look 페이지만 개선한다.

## 산출물
- HwpPageImageRenderer: quickLookAutomatic 정책, RawSvg XML/bbox/구조 예산, 선택 이유 진단.
- Preview PNG resolver/renderer: automatic 요청과 실제 출력 모드 분리.
- ExtensionFontRenderer: PNG/PDF 공급 경로에서 페이지별 정책 적용. 글꼴 공급 실패·stale 동작 보존.
- regression runner 및 독립 Poppler PDF 비교. PR CI에 연결하고 관련 스크립트 변경도 render smoke를 실행하도록 분류한다.

## 본문 변경 정도 / 본문 무손실 여부
문서 내용과 core/FFI/Thumbnail 기본 정책은 변경하지 않는다. 일반 페이지와 단일 래스터 RawSvg는 CoreGraphics를 유지한다. 선택된 벡터 페이지의 본문·캡션은 core Skia로 렌더되므로 글꼴 차이는 가능하다.

## 검증 결과
- test-quicklook-raw-svg.sh: 정책/실제 PNG/PDF/일반 페이지/명시적 CG/글꼴 거부/stale/9쪽 PDF 정책 PASS.
- malformed XML, 외부 href, entity/DTD, CSS, 과대 bytes/요소/깊이/조각 수, 비정상 bbox는 CoreGraphics 선택.
- 차트 녹색 픽셀 0 → 25,703, PNG 63,928 bytes. 기준 PDF 녹색 면적 대비 1.005594679, 막대 6개 검증 PASS.
- smoke-quicklook-skia-policy.sh: HWP 차트/KTX의 기존 명시 모드와 DEBUG resolver PASS.
- git diff --check / bash -n PASS.

## 잔여 위험
허용 목록 밖의 유효 SVG, 관리 글꼴 공급 실패 또는 Skia 실패는 기존 자리표시자로 남을 수 있다. 내부 resvg는 core의 폰트 fallback을 사용하므로 모든 글꼴의 시각 동일성을 주장하지 않는다.

## 다음 단계 영향
수집한 before/after/reference를 직접 대조하고 Release 빌드·기본 smoke·등록 정리 결과를 최종 보고에 연결한다.

## 승인
PR 생성까지의 명시 승인에 따라 Stage 3으로 진행한다.
