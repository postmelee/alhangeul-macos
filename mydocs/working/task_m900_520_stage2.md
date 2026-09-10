# Task M900 #520 Stage 2 — 동일 DMG 승격

## 변경 결과

release-publish를 새 stable draft 생성으로 제한하고 기존 Release의 upload/clobber 및 public/appcast 경로를 제거했다. release-promote는 같은 tag SHA/version/build와 원본 후보 artifact, 양 macOS 15 runner의 최신 validation attempt를 대조한다. PASS 요약 외에도 최초 실행·앱 종료 후 본문 검색 및 33개 lifecycle/cleanup 원본 결과가 필요하다.

Release의 DMG와 checksum을 실제 다운로드하여 검증한 hash와 비교한다. Sparkle/Pages 준비 후 회차·tag·asset ID/메타데이터/bytes를 재확인하고 `release edit`만 수행한다. 공개된 동일 자산의 재실행은 Pages 복구를 허용하며 더 최신 버전으로부터의 downgrade를 거부한다. builder와의 후보별 잠금, docs-only Pages와의 전체 실행 잠금을 적용한다. Pages docs gate는 인증 API에 노출되는 draft/prerelease를 거부한다.

## 검증

- `PYTHONDONTWRITEBYTECODE=1 python3 scripts/ci/test-release-promotion.py`: 11 tests PASS. 잘못된 run/회차/후보/아키텍처, 누락 증거, checksum/재빌드, archive 경로, 자산 교체와 공개 직전 rerun, 공개 후 동일 자산 재시도, 실제 Pages jq predicate를 검사했다.
- `PYTHONDONTWRITEBYTECODE=1 python3 scripts/ci/test-release-install-smoke.py`: 기존 11 tests PASS.
- `actionlint .github/workflows/*.yml`: PASS.
- 실제 GitHub Release 변이·서명·공증·Pages/Sparkle 게시: 미실행. 이 단계는 자동화 구현/회귀이며 공개 수용 증거가 아니다.

## 다음 단계

4개 bundle 0.2.0/18, 사용자 문구와 포함 PR 분석을 준비하고 CI·리뷰용 PR을 생성한다. #520 은 전체 배포가 끝날 때까지 열어 둔다.
