# Task M900 #518 Stage 2 — 재사용 후보 검증 workflow

## 변경

`release-first-install.yml`에 수동 실행과 workflow_call을 제공했다. 같은 저장소의 성공한 Release Publish DMG 실행·artifact·소스 SHA를 확인하고 DMG SHA256/버전/빌드를 대조한다. fixture 생성 job과 arm64/Intel 설치 job을 분리했다. 설치 job은 Python 도구만 준비하고 앱을 빌드하지 않는다.

서명·공증·universal 검사 후 DMG 앱을 build.noindex 사본으로 보존하고 DMG를 해제한다. 설치 전 corpus 준비, 복사·첫 실행 한 번, 실제 검색·후보 선택, 앱 종료 후 검색, 수정·삭제 lifecycle과 소유 정리를 기존 smoke에 연결한다. 정상 설치 목적의 lsregister, 수동 mdimport 재색인, touch, 앱 교체는 실행하지 않는다. 종료 후 표준 cleanup의 소유 등록 해제는 설치 검증 이후 단계다.

토큰은 artifact 다운로드 단계에만 전달한다. 출처·입력·ZIP 경로·불완전 결과의 거짓 PASS를 11개 회귀로 확인했다. 최초/종료 후 state와 lifecycle·cleanup state를 별도로 기록한다. 실패 시에도 결과 artifact를 업로드하며 최종 verdict는 누락/실패를 거부한다.

## 검증

- `python3 scripts/ci/test-release-install-smoke.py`: 11 PASS.
- 기존 `test-spotlight-system-smoke.py`: 31 PASS.
- Python compileall, actionlint, git diff --check PASS.
- 후보 검증 workflow의 서명·공증 DMG end-to-end는 미실행이다. 이 작업은 signing/publish를 발동하지 않는다. 실제 릴리스 후보의 결과가 있어야 #513 수용 판정에 사용할 수 있다.
