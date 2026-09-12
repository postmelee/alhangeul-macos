# Task M020 #341 Stage 5 — CI 기본 도구 호환성 수정

## 원인과 변경

리뷰 보완의 NDEBUG 음성 검사는 정상적으로 본문 단어 부재를 거부했지만, macOS CI runner에 rg가 없어 결과 확인 단계가 실패했다. 제품 importer 실패가 아닌 검사 스크립트 의존성 누락이었다. 외부 설치가 필요 없는 `/usr/bin/grep -Eq`로 바꿔 같은 실패 패턴을 대조한다.

## 검증

- `PATH=/usr/bin:/bin:/usr/sbin:/sbin scripts/verify-spotlight-importer.sh build.noindex/spotlight-work/package/release/Alhangeul.app`: PASS — 기존 Release 개발 패키지 callback 11개 + NDEBUG 양성/음성 2개.
- `bash -n scripts/verify-spotlight-importer.sh`, `git diff --check`: PASS.
- 제품 소스·ABI·core pin·시스템 등록 변경 없음. 새 PR head CI는 push 후 확인한다.

## 인계

#341 수정 커밋을 #342 → #343 → #513 순서로 통합한다. CI 성공 확인 후 #507 → #508 → #509 → #510 → #511 → #512 → #514 순서로 병합한다. #514 조사 범위의 병합은 최초 설치 해결을 뜻하지 않으며 #513 및 상위 #337 이슈는 열린 상태를 유지한다.
