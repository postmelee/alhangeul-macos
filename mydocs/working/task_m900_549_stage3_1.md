# Task M900 #549 Stage 3.1 — Pages 실제 배포 생략 원인 보정

main PR #550 병합 후 [34930122727](https://github.com/postmelee/alhangeul-macos/actions/runs/34930122727)은 전체 conclusion이 success였지만 `Deploy GitHub Pages`는 skipped였다. 실제 공개 HTML byte 대조가 실패해 이를 발견했다. v0.2.0 페이지 헤더가 미공개 v0.2.1 DMG를 가리켰고, 공개 asset gate가 배포를 차단했다. 첫 workflow를 실제 배포 성공으로 수용하지 않는다.

v0.2.0 헤더의 URL·접근성 이름을 해당 공개 버전으로 고쳤다. 같은 잘못된 floating latest 패턴이 있던 v0.1.11 헤더도 자기 버전의 고정 URL로 바꿨다. 이전 버전 페이지의 최신 이동 배너는 0.2.2를 유지한다. v0.2.1 draft와 tag/assets는 변경하지 않았다.

보정 후 docs 전체 DMG 버전을 GitHub Release API의 draft/prerelease/asset uploaded 상태와 대조해 모두 통과했다. [자산 gate 결과](../report/assets/task_m900_549/pages-asset-gate.json), 버전 배너 check·diff check·Pages artifact/appcast byte 보존 PASS. 배너 helper는 aside만 검사하여 헤더 URL 문제를 잡지 못하므로 실제 asset gate와 공개 HTML 확인을 함께 사용한다.

최초 종료 PR 병합 이후에 발견된 배포 차단이어서 같은 #549 의 후속 main PR 하나로 보정한다. 이미 열린 #551 main → devel 인계에는 이 변경도 포함한다. 최종 수용은 새 workflow의 deploy job 성공 및 실제 공개 HTML·appcast byte 일치로 판단하며, 완료 결과는 #549 에 기록한다.
