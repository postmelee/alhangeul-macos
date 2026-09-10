# Task M900 #520 구현계획서

## Stage 1 — 릴리스 기준과 변경 분석

v0.1.11..devel 병합 PR의 본문/최종 보고서로 사용자 기능·운영 변경과 이전 릴리스 기록을 구분한다. 버전 0.2.0/빌드 18과 core v0.8.6을 준비 기준으로 삼고 실제 tag/candidate는 미확정으로 남긴다.

## Stage 2 — 검증 DMG 공개 승격

기존 release-publish를 draft 후보 생성으로 제한한다. 새로운 release-promote workflow는 이미 성공한 candidate run/artifact와 validation run/attempt 및 두 아키텍처 결과를 확인한다. 같은 tag SHA, DMG hash, version/build, 검증 결과 원본 snapshot/lifecycle/cleanup을 대조하고 기존 draft 자산 bytes가 같은지 재확인한다. 빌드·재서명·asset 재업로드 없이 draft를 공개하고 같은 DMG의 Sparkle 서명·Pages artifact를 배포한다. 모든 읽기/검증 뒤 공개 변경을 수행하고 실패 재실행에서 공개 DMG 교체를 하지 않는다.

## Stage 3 — 후보 준비 PR·회귀·인계

4개 bundle version/build, release 입력과 내부/사용자 문구를 준비한다. publish 전 광고가 발생하지 않도록 Pages 공개 타이밍을 검토한다. 후보/검증 증거 불일치·미실행·바뀐 draft 자산·이미 공개된 릴리스 처리 회귀, workflow actionlint, 버전/본문/링크 검사, 필요한 PR CI를 수행한다. 보고서와 준비 PR을 게시한다.

## Stage 4 — 후보 실제 검증 (준비 PR 이후)

리뷰·병합 후 최종 main/tag identity를 확정하고 공증 draft 및 새 VM 최초 설치를 실행한다. 기존 Mac GUI·Finder/Thumbnail과 설치본 보존/복원을 검증한다. #513 종료 조건을 보고한다. 이 단계 결과가 없으면 공개하지 않는다.

## Stage 5 — 승인된 공개와 종료

작업지시자의 최종 공개 승인 후 exact DMG를 승격하고 다운로드/Pages/appcast·실제 Sparkle 업데이트 후 검색·확장을 확인한다. 릴리스 기록과 #513 / #337 종료 판단, #520 완료 보고와 정리를 수행한다. 공개 부작용과 유효한 후보/검증 증거를 사전에 구체적으로 제시한다.
