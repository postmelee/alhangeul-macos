# Task M900 #520 Stage 1 — 릴리스 기준

v0.1.11..41efb1770ae7a464c9cf766fe001c2da79a95823 의 first-parent 병합 15개와 각 PR 본문을 대조했다. #502 는 직전 릴리스 종료 기록이며 사용자 신규 기능에서 제외한다. #503–#506 은 core 검증/decoder/golden/통합 gate, #507–#512 및 #514–#515 는 Spotlight, #517 은 새 문서 저장·Word/HTML 내보내기, #519 는 최초 설치 자동화다. 미병합 #462 는 제외한다.

준비 버전은 0.2.0/18, core/Studio는 v0.8.6/f1f9c6ae58344ee9368996d3543f76b9345cf227 유지다. 준비 PR 이후 main/tag의 최종 SHA를 확정한다. 현재 공개는 0.1.11/17이며 signed candidate는 아직 없다.

기존 release-publish는 draft 이후 official 실행에서 재빌드하고 `--clobber`로 자산을 교체한다. 이를 draft 생성과 검증 결과를 확인하는 승격으로 분리해야 한다. Pages docs 배포 gate도 인증 API의 draft 자산을 공개 파일처럼 인정하므로 draft/prerelease를 명시적으로 거부하도록 보완한다.

#518 의 최종 환경 조사 run 34453172987 은 두 macOS 15 아키텍처에서 ENVIRONMENT_READY다. 이는 서명된 v0.2.0 앱 설치 통과 증거가 아니다. 자동 설치·로컬 GUI·공개 후 Sparkle 검증과 #513 / #337 / #520 종료 판단은 남는다.
