# 릴리스 후보 최초 설치 자동 검증

## 목적과 적용 범위

이미 서명·공증된 DMG를 새 GitHub-hosted macOS VM에 설치하고, 요청 기록을 유지한 같은 버전 제거·재설치까지 실제 Spotlight 본문 검색을 확인한다. 빌드와 설치 job을 분리하며 결과는 해당 DMG SHA256에만 유효하다. runner 이미지는 개발 도구가 포함된 환경이므로 순정 macOS, 실제 Spotlight GUI, Finder/Quick Look/Thumbnail 또는 Sparkle 업데이트 성공으로 확대하지 않는다.

workflow는 공개 서명·공증을 발급하거나 tag/Release/Pages/appcast를 변경하지 않는다. 실제 후보 실행은 릴리스 담당자가 승인한 배포 전 검증 단계에서 수행한다.

## 새 러너 환경 조사

`Install environment assessment`는 관련 코드가 바뀐 publish/task 브랜치와 PR에서 자동 실행되며 수동 실행도 제공한다. 임의 사용자 폴더의 `mdutil -s`는 unknown을 반환할 수 있으므로 볼륨 목록과 실제 TXT 검색으로 판단한다. 기존 알한글 등록 부재·GUI 세션·TXT 자동 검색 및 소유 파일 정리를 기록한다.

환경 조사 job 성공은 측정 완료만 뜻한다. JSON의 ENVIRONMENT_READY도 후보 설치를 검사하지 않았으므로 `release_eligible=false`다. ENVIRONMENT_UNAVAILABLE은 조사 artifact를 확인하고 환경 원인을 분석한다. 시스템 설정을 변경하지 않으며 최초 실패를 성공 기록으로 덮지 않는다.

## 후보 준비와 실행

1. 별도 승인된 `Release Publish DMG`의 draft 실행이 완료된 후 실행 ID, head SHA, `alhangeul-macos-<version>-public-dmg` artifact ID와 DMG SHA256을 확보한다. artifact는 14일 뒤 만료되므로 검증은 보존 기간 안에 수행한다.
2. 공개 승격용 검증은 후보의 `v<version>` tag에서 실행한다. 후보 고정 후 검증 도구 보완이 필요하면 검토·병합된 `main`에서 `--ref main`과 기존 후보 입력으로 새 실행을 만든다. 아래 출처 계약을 모두 만족해야 하며 임의 PR ref나 reusable 호출 결과는 승격 입력으로 사용하지 않는다. 수동 dispatch는 workflow가 기본 브랜치에 등록된 이후 가능하다.
3. 실행 예시의 값을 실제 후보 값으로 바꾼다. 임의 URL, PR 산출물, 다른 저장소 artifact는 받지 않는다.

```bash
gh workflow run release-first-install.yml --ref v<version> \
  -f source_run_id=<release-publish-run-id> \
  -f source_artifact_id=<public-dmg-artifact-id> \
  -f source_sha=<40자리-후보-SHA> \
  -f dmg_sha256=<64자리-DMG-SHA256> \
  -f expected_version=<version> \
  -f expected_build=<build>
```

다른 workflow에서는 `uses: ./.github/workflows/release-first-install.yml`과 동일한 6개 `with` 입력을 사용한다. 호출자는 `contents: read`, `actions: read`를 허용해야 한다. 호출 workflow의 `release_eligible`와 `validated_dmg_sha256` 출력은 해당 DMG의 자동 검사 범위에 한정한다.

## 검증 도구의 출처 계약

- 후보 SHA는 현재 `v<version>` tag와 일치해야 한다. 실행 도구 SHA는 후보의 descendant이면서 현재 origin/main 이력에 포함돼야 한다. tag 실행에서는 두 SHA가 같아야 한다.
- 별도 main 도구는 `release-install-source.py`의 명시적 허용 파일과 `mydocs/`만 바꿀 수 있다. 앱·의존성·시험 문서 생성기·공개 문구·임의 스크립트 변경이 있으면 이 경로를 중단하고 새 후보 계획을 세운다. 태그 이동이나 기존 DMG 교체로 회피하지 않는다.
- 각 job은 깨끗한 checkout과 source proof를 검증한다. 별도 fixture job은 후보 SHA를 추가 checkout해 그 소스의 Rust 예제를 실행한다. 실행 도구 소스에서 fixture를 다시 정의하지 않는다.
- `verify-result.json.source_proof`에 후보 SHA·도구 SHA·fixture SHA·실행 ref·변경 경로를 보존한다. 승격 도구는 Git 이력에서 proof를 다시 계산하고 API run head SHA, artifact head SHA, 결과 harness SHA와 대조한다. 마지막 공개 직전에도 같은 proof인지 확인한다.
- 실패한 실행·artifact는 보존한다. 새 도구의 실행 ID/attempt와 양 아키텍처 증거를 별도로 기록하며 이전 실패 JSON을 수정하거나 구형 schema를 새 PASS로 바꾸지 않는다.

## 검증 단계

- 별도 job에서 고정 후보 소스의 Rust 합성 fixture 예제를 실행한다. 설치 VM에서 앱 빌드나 시험 실행을 하지 않는다.
- 출처·성공한 실행·artifact 연결·hash를 확인하고 ZIP 경로/크기를 검사한다.
- 새 VM의 기존 등록·GUI 세션·TXT 검색 전제를 재확인한다.
- DMG/app staple, Gatekeeper assessment, Developer ID 서명·seal, 버전·빌드·bundle ID 및 universal/importer 구성을 확인한다.
- 읽기 전용 DMG에서 build.noindex staging으로 복사하고 mount를 해제한 뒤 corpus를 준비한다. 원본/설치 앱과 importer의 bytes/디렉터리 시각, 설치 전 corpus를 보존한다.
- 소유한 `~/Applications/AlhangeulSpotlightSmoke-<id>.app` 경로에 복사하고 한 번 실행한다. `/Applications/Alhangeul.app` 설치 경로의 직접 검증과는 구분한다.
- HWP3/HWP5/HWPX 영문 및 HWP5/HWPX 한글 본문 검색, 실제 선택 importer, 앱 종료 후 검색을 확인한다.
- 최초 실행/종료 후 snapshot을 보존하고 후보 sandbox 요청 키를 읽는다. bundle ID 또는 container metadata로 찾은 실제 plist의 importerPath를 대조하며, 없거나 여러 기록이 일치하면 중단한다. 전체 preferences 복사나 설정 초기화는 하지 않는다.
- 같은 후보 bytes·경로·빌드·mtime와 기존 요청 기록을 유지한 제거·재설치를 실행한다. 원본 합성 문서를 재준비하고 복사 전·실행 전 각각 영문/한글/TXT를 4초 이상 안정 관찰한다. 전체 미검색 또는 전체 검색만 수용하며 부분 검색·조회 오류·대조 실패는 통과시키지 않는다. 두 번째 설치에서 한 번 실행한다. 새 설치 객체·새 요청 식별자, 영문/한글 검색·실제 importer 및 종료 후 검색을 별도 snapshot으로 보존한다.
- 실행 전 이미 검색되면 `maintained`(유지), 미검색이었다가 실행 후 검색되면 `recovered`(복구)로 기록한다. 유지는 색인 복구 증거가 아니다. 복구 역시 실행 전후의 관찰이며 내부 색인 완료 시점이나 인과를 직접 측정한 결과는 아니다. 두 경우 모두 새 설치 객체·새 요청 기록과 이후 검색이 필요하다.
- 재설치 상태에서 수정·삭제·보호·손상·한도 전환 33개 판정과 소유 파일/등록 정리를 확인한다.

## 결과와 공개 전 확인

`first-install-evidence-*` artifact에 후보 식별, 환경 JSON, 최초/종료 후 및 재설치/종료 후 snapshot, lifecycle·cleanup state 및 명령 로그를 보존한다. 실패/누락/정리 실패/중간 조회 실패가 남으면 PASS가 아니다. 앱이 이미 삭제돼도 소유 경로의 등록 해제를 요청하고, 최초 검증 오류와 cleanup/state-save/detach 오류를 각각 보존한다. 전체 관찰 기한 때문에 단축된 마지막 명령 timeout은 기한 소진으로 구분하되 관찰 자체는 실패로 남긴다. 취소·job timeout으로 증거 업로드가 불가능했던 실행 역시 유효한 검사 결과가 아니다.

후보 검증은 양쪽 아키텍처의 install job 및 verdict가 성공하고 `verify-result.json`이 schema 3, PASS/release_eligible=true여야 한다. `reinstall-search.json`과 `reinstall-stopped-search.json`이 필수이며 최초 설치만 있는 구형 증거는 현재 승격 gate에서 거부한다. 과거 공개 결과나 tag를 새 schema에 맞춰 고쳐 쓰지 않는다. 환경 조사 결과나 단순 mdimport 추출 성공을 대신 사용하지 않는다.

**공개할 DMG SHA256과 검사한 DMG SHA256이 반드시 같아야 한다.** `Release Publish DMG`는 stable draft 생성만 허용한다. 공개 승인을 받은 뒤 `Release Promote Verified DMG`에 후보 run/artifact, validation run, version/build/hash를 전달한다. 양 아키텍처의 최신 run attempt, 최초/재설치의 실제 검색·종료 후 검색·33개 lifecycle·cleanup 증거와 기존 draft 자산 hash를 대조한다. 빌드·공증·DMG 업로드 없이 같은 파일을 공개하고 Sparkle/Pages를 배포한다. 상세 실행/재시도는 [runbook Gate 5](public_release_runbook.md#gate-5-official-stable-publish)를 따른다.

실제 서명 후보 end-to-end를 실행한 결과와 GUI/업데이트/최소 OS 공백을 릴리스 기록에 남긴 뒤 공개 여부를 판단한다. 설치 자동화 PASS가 릴리스 승인 자체를 대신하지 않는다.

매 릴리스의 완료 조건은 [runbook Gate 8](public_release_runbook.md#gate-8-최초-설치와-실제-sparkle-업데이트-수용)의 최초 설치·같은 버전 재설치·실제 Sparkle 세 경로를 따른다. 이 workflow PASS에 공개 URL에서 새로 받은 DMG의 hash 동일성을 연결하고, 이전 공개 버전에서 실제 Sparkle 다운로드·설치·재실행과 검색/확장을 별도로 검증한다. 해당 업데이트 경로는 이 workflow가 실행하지 않는다.
