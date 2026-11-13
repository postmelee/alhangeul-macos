# Task #612 Stage 3 — 통합 검증과 PR 준비

## 단계 목적
실제 확장 공급 코드와 Release 빌드를 검증하고 독립 PDF 기준과 비교한다.

## 산출물
[최종 보고서](../report/task_m020_612_report.md), before/after/reference 이미지와 영역별 수치, CI 회귀 실행 연결.

## 본문 변경 정도 / 본문 무손실 여부
HWP/PDF 원본 해시는 유지했다. 차트·축·범례·캡션이 존재하지만 캡션 굵기와 글꼴, 일부 기준선은 기준 PDF와 다르다.

## 검증 결과
- 최종 회귀 runner와 Poppler 비교 PASS: 막대 0 → 6개(기준 6), 녹색 면적 25,703px(기준 25,560px).
- 확장 PNG/PDF 공급, 거부 fallback, stale, 9쪽 PDF의 페이지별 선택 PASS.
- Release HostApp/확장 빌드 PASS(148.190초), check-no-appkit / 기본 render smoke / 명시적 policy smoke PASS.
- 기존 CoreGraphics 진단 PNG는 변경 전후 byte 동일. bash -n / git diff --check PASS.
- 새 설치 후보의 Finder smoke, 최소 OS와 Intel runtime은 미실행. 설치 제공자는 /Applications/Alhangeul.app이다.

## 잔여 위험
기준 PDF와 글꼴 동등성을 보증하지 않는다. 제한 밖 SVG는 기존 fallback을 유지한다. 등록 hygiene의 기존 휴지통 앱 경고는 별도 환경 문제로 기록한다.

## 다음 단계 영향 및 승인
PR 생성까지의 명시 승인에 따라 최종 보고와 publish/task612 → devel PR을 게시한다. 병합·배포는 범위 밖이다.
