# 정리 후 검증 환경 재구성

2026-09-25 사용자 승인에 따라 `build.noindex/task567/pr7405-validation` 실행 산출물과 worktree를 정리했다. 이 폴더의 소스·결과·PDF·PNG는 보존 자료다. 원본 보고서의 명령은 아래 준비 후 다시 실행할 수 있다.

1. 알한글 소스 `ef7d638794f82b71a71c75ef2029bf4eb3d463db`와 기존 native bridge 산출물, 승인된 `build.noindex/task567/fonts/gowun-batang` 시험 파일을 준비한다. 원본 시험 글꼴과 별도 `task567/upstream`은 정리하지 않았다.
2. 검증 루트를 원래 경로에 만들고, `upstream`에 **실제 검증 head `bf371e200cfbc343094b552169864ba6c9235a27`**의 detached worktree를 준비한다. sparse 경로는 `sparse-checkout.txt`를 따른다. 이후 병합된 `7978d00b...` 또는 merge `aeb9f489...`로 실행하면 별도 버전 검증이다.
3. `main.swift`, `build-probe.py`를 검증 루트에, `probe.ts`, `probe.html`, `vite.probe.config.ts`를 `upstream/rhwp-studio`에 복사한다.
4. `upstream/rhwp-studio`에서 해당 head의 lock 기준 `npm ci --ignore-scripts`로 의존성을 재설치한다. 보존한 `upstream-package*.json`은 대조용이다. 예전 `/private/tmp/rhwp-7403/rhwp-studio/node_modules` 심볼릭 링크는 필요하지 않다.
5. 다른 Cargo 작업과 충돌하지 않는지 확인하고 원본 보고서의 fresh WASM → Vite probe build → Swift build → probe 실행 순서를 따른다. 공유 `target/pr-review`는 삭제하거나 초기화하지 않는다.
6. GUI 로그인 상태의 macOS에서 실행한다. 결과는 실행별로 구분하여 원본 증거를 덮어쓰지 않는다. 끝나면 시험 앱만 LaunchServices에서 등록 해제한다.

원본 경로를 다르게 구성하면 보존된 Swift 실행기와 빌드 스크립트의 절대 경로를 새 시험용 복사본에서 맞춰야 한다. 이 재구성 절차 자체를 새 환경에서 다시 실행한 것은 아니다.
