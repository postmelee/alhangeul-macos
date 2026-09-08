# Task M020 #341 Stage 4 — factory 및 callback 검증기 강화

## 변경

유효한 다른 UUID로 plist 두 항목을 함께 바꾸면 기존 소스 검증을 통과하던 문제를 막았다. FactoryID 소스의 16바이트와 plist UUID를 대조하고, 잘못된 바이트 개수와 ExportedSymbols의 함수명 불일치를 거부한다. 소스 형식이 바뀌어 파싱할 수 없어도 성공 처리하지 않는다.

C checker의 assert 안에 있던 QueryInterface·callback·Release 호출을 항상 실행되는 REQUIRE로 바꿨다. NDEBUG에서도 검증과 호출이 유지된다. verify 스크립트는 정상 검사 외에 NDEBUG checker의 양성 본문과 존재하지 않는 needle의 명시적 실패를 확인한다. build.noindex가 없는 단독 실행 경로도 생성하도록 보완했다.

## 검증

- `python3 scripts/ci/check-spotlight-bundle.py`: PASS.
- `python3 scripts/ci/test-spotlight-bundle.py`: PASS — 5 tests (다른 UUID, source drift·길이, export drift 포함).
- `scripts/verify-spotlight-importer.sh <기존 Release package>`: PASS — 기존 11개 callback 사례 및 NDEBUG 양성/음성 2개.
- `bash -n scripts/verify-spotlight-importer.sh`, `git diff --check`: PASS.

비교 실험에서 수정 전 NDEBUG checker는 없는 needle에도 PASS를 출력했다. 수정 후에는 CFStringFind 검사에서 실패하고 exit 1이므로 검증기 자체의 거짓 성공을 차단한다. 제품 importer 코드를 바꾸지 않아 기존 Release package를 재사용했고 앱/확장을 등록하지 않았다.

## 판단 사항

한국어 kMDItemKind, 파일명 기반 제목과 공개 서명 helper의 기존 preserve-metadata 정책은 이번 검증기 보완에서 바꾸지 않는다. 최초 설치 자동 발견 문제는 #513 소유다. 검증기 보완 성공을 공개 서명·공증 또는 최초 설치 성공으로 확대하지 않는다.
