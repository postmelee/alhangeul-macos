# Task M900 #584 구현계획서

## 1. 승인 상태와 실행 기준

[수행계획서](task_m900_584.md)의 범위·5단계·수용 기준을 작업지시자가 2026-10-12 **“수행계획 승인·구현계획 작성 진행”**으로 승인했다. Stage 1·2 승인에 따라 조사와 소스·안내/unsigned 검증을 완료했다. 준비 [PR #585](https://github.com/postmelee/alhangeul-macos/pull/585)는 보정 head `938b59b9`의 CI 4개 통과 후 `5146d91e`로 devel에 병합했다. 현재 작업지시자의 **“모두 통과했으면 PR #585를 병합한 뒤 #584 Stage 3 준비”** 승인으로 main 인계 PR 초안·출처·실행 입력을 준비한다. 아래 tag·서명/공증 workflow·설치·공개 명령은 별도 gate가 남은 계획이며 아직 실행하지 않았다.

- 이슈: [#584](https://github.com/postmelee/alhangeul-macos/issues/584), Release Operations / M900.
- local/task584 → publish/task584 → devel 준비 PR. 시작 제품 기준 e75d3ec4662457eaca990bdf95596442e5e56503, 계획 준비 커밋 be655ab4930e9dd97ec1c334daf04cc6174ca9f4.
- 계획 기준 v0.2.3 / build 21, 직전 public v0.2.2 / build 20. 네 source bundle은 0.2.3 / 21이며 Stage 2의 unsigned Debug/universal Release에서도 일치했다. main 인계 source는 devel `5146d91e61e29959b45f6af68090cca4e9c3b97d`다.
- core/Studio는 공식 rhwp v0.8.7 / 1a76570e833917d15817415a53c09ad61ab3203f를 유지한다. 새 dependency/FFI/renderer 변경은 없다.
- 최종 source SHA, tag, run/artifact ID, DMG hash는 산출물이 확정되는 단계에서 기록하며 가짜 값이나 이전 후보 값으로 채우지 않는다.

각 단계 종료 시 mydocs/working/task_m900_584_stage{N}.md와 해당 변경을 묶어 커밋하고 다음 단계를 승인받는다. 준비 PR은 부분 인계이므로 Refs #584 로 연결하며 이슈를 자동 종료시키는 closing keyword를 넣지 않는다. 전체 실행·공개 수용 전에는 #584 이슈를 닫지 않는다.

## 2. Stage 1 — 맥락·포함 변경·출시 기준

### 작업과 산출물

제품 소스를 수정하지 않고 최신 main/devel·public/upstream release, 네 bundle, lock/generated build info/Studio 출처를 대조한다. v0.2.2 이후 병합 PR의 제목·본문·연결 이슈·보고서를 읽어 사용자 변화와 운영/검증/운반 변경을 분류한다. 자동 분석은 초안이며 최종 표의 근거를 직접 확인한다.

- mydocs/release/v0.2.3.md: **미공개 준비 상태**와 포함 PR 분석, 사용자 변화 초안, 기존/신규 위험, 미확정 항목.
- mydocs/tech/task_m900_584_release_acceptance.md: VM/실제 Mac/문서·출력·Finder의 수용표와 증거 수준, 같은 DMG 식별 계약.
- build.noindex/task584/stage1/: 최신 context, PR 원문/자동 분석, delta, 출처 검증 로그. 필요한 장기 증거만 report/assets/task_m900_584 로 선별한다.

기존 #480 암호 문서 저장 및 #525 복구 후보 이슈의 최신 상태, 현재 native save/close RPC 경로와 기존 재현 증거를 조사한다. 코드나 기존 증거로 확정되지 않는 runtime 동작은 미확인으로 남겨 필요한 후보 재현을 수용표에 넣는다. 무경고 보호 해제 가능성이 남으면 공개 전 차단/독립 수정 필요성을 권고한다. 기존 릴리즈의 한계 수용을 이번 공개 승인으로 재사용하지 않는다. 이 단계에서 새 진단 앱, 암호 문서 저장 또는 UI 시험은 실행하지 않는다.

### 검증 명령

```sh
git status --short --branch
git fetch origin --prune
scripts/ci/check-main-devel-content.sh origin/main origin/devel
scripts/verify-rhwp-core-build-info.sh
scripts/verify-rhwp-studio-assets.sh
node scripts/build-native-font-matcher.mjs --verify
scripts/ci/write-release-pr-analysis.sh v0.2.2 e75d3ec4662457eaca990bdf95596442e5e56503 build.noindex/task584/stage1/pr-analysis.md
scripts/ci/write-release-delta-checklist.sh v0.2.2 e75d3ec4662457eaca990bdf95596442e5e56503 build.noindex/task584/stage1/delta.md
```

위 두 분석의 기준 SHA는 준비 시작점이다. 새 devel 병합이 있으면 영향을 읽고 승인 범위에 맞게 조사 ref를 갱신하며, 최종 후보 확정 후 같은 두 분석을 다시 확정한다. 앱/업스트림 release는 gh release view, PR은 gh pr view, 이슈는 gh issue view의 구조화된 원문으로 확인한다. 결과 파일 작성 전 해당 출력 디렉터리를 준비한다.

### 종료 기준

core/Studio와 네 bundle의 기준이 일치하고 main 내용이 인계되었으며, 포함 변경·알려진 문제의 판단/미확인 부분·검증 범위가 명확해야 한다. #480 문제 해결이 공개 선행 조건으로 판단되면 별도 작업 승인 없이 Stage 2 소스 준비를 진행하지 않는다. Stage 1 보고 승인 후에만 Stage 2로 진입한다.

커밋: Task #584 Stage 1: v0.2.3 포함 변경과 공개 수용 기준 확정.

## 3. Stage 2 — 소스·사용자 안내 후보와 준비 PR

### 수정 범위

| 파일/영역 | 변경 |
|-----------|------|
| Sources/HostApp/Info.plist, Sources/QLExtension/Info.plist, Sources/ThumbnailExtension/Info.plist, Sources/SpotlightImporter/Info.plist | short version 0.2.3 / build 21 일치 |
| .github/workflows/release-rehearsal.yml, release-publish.yml, release-promote.yml | 해당 입력의 version 0.2.3, previous_release_ref v0.2.2, expected_rhwp_tag v0.8.7, expected_build 21. draft=true/prerelease=false와 기존 보호 계약 유지 |
| mydocs/release/v0.2.3.md, mydocs/release/index.md | 포함 PR 분석·주요 변화·지원 한계·미확정 hash·수용 상태를 정확히 기록 |
| docs/updates/v0.2.3.html, docs/updates/index.html, docs/index.html, docs/fonts/index.html, README.md | 공개될 안내 후보 준비. 기존 글꼴 목록 선택·Mac 지원·Windows 후속과 실제 제공 버전 구분 |
| 이전 docs/updates/v*.html | 기존 helper의 이전 버전 안내만 정규화. 과거 본문·공개일·고정 자산 보존 |

CSS나 홈페이지 외곽 구조는 문구 변경에 필요한 범위만 다룬다. 원래 글꼴 동선·출처·설치/제거 한계와 홈/업데이트의 작성 규칙을 유지한다. 긴 source hash·ABI·측정 절차는 제품 페이지에 넣지 않는다. upstream 개선은 공식 릴리즈·포함 PR에서 확인된 사용자 변화만 설명하고 알한글에서 직접 구현한 개선과 구분한다.

### 공개 timing

개발 소스에서 공개할 v0.2.3 안내를 준비하되 **실제 public Pages·Release·Sparkle·Homebrew 제공 상태는 v0.2.2로 유지**한다. 로컬 화면은 후보 미리보기임을 사용자에게 안내하고 실제 공개일은 미확정으로 둔다. main 운반 PR에서 docs-only workflow의 public asset gate가 새 DMG 미공개/draft 상태를 deploy=false로 판정하는지 확인한다. 이 gate를 제거하거나 우회하지 않는다.

공개 전에는 공개 사이트·appcast를 바꾸지 않는다. 공개 승격 시 후보 페이지가 함께 게시되므로 기능 제공 버전·다운로드·Homebrew 배지는 실제 상태와 맞게 준비한다. Homebrew는 실제 tap 갱신 전까지 v0.2.2 제공 상태를 구분한다. 불가피한 사후 공개 문구 보정은 같은 DMG bytes를 유지하는 별도 문서 PR로 승인·검증한다.

### 최소 검증

```sh
scripts/build-rust-macos.sh --verify-portable
scripts/verify-rhwp-core-build-info.sh
scripts/verify-rhwp-studio-assets.sh
scripts/verify-render-tree-golden.sh --check-environment
scripts/verify-render-tree-golden.sh
scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/task584/stage2/DerivedData CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Release -derivedDataPath build.noindex/task584/stage2/DerivedDataRelease CODE_SIGNING_ALLOWED=NO build
scripts/ci/verify-app-execution-endpoint-config.sh --release-app build.noindex/task584/stage2/DerivedDataRelease/Build/Products/Release/Alhangeul.app
scripts/ci/verify-universal-macos-app.sh build.noindex/task584/stage2/DerivedDataRelease/Build/Products/Release/Alhangeul.app
scripts/validate-stage3-render.sh build.noindex/task584/stage2/render
scripts/ci/update-release-version-notices.sh --updates-dir docs/updates --check
python3 scripts/ci/update-rhwp-readme-badge.py --check
scripts/ci/check-main-devel-content.sh origin/main HEAD
```

네 source plist와 built bundle 값을 별도로 읽어 0.2.3/21을 확인하고, Legal/FONTS 문서의 canonical 일치도 점검한다. plist·변경 YAML·shell 문법, 릴리즈 본문 필수 heading 및 GitHub reference 형식·문서 링크를 검사한다. heading은 scripts/ci/check-release-notes-template.sh, 공개 본문은 scripts/validate-github-body.sh로 검사한다. DMG hash 미확정 초안은 실제 공개 입력으로 쓰지 않는다.

Pages 조립은 새로 받은 public appcast의 XML/bytes/hash를 보존하는 경로에서 확인한다. 기존 조립·릴리즈 helper fixture는 python3 scripts/ci/test-news-pages.py, python3 scripts/ci/test-release-promotion.py, python3 scripts/ci/test-release-install-smoke.py로 검증하고 외부 공개 mutation을 실행하지 않는다. 새 tests를 단순 version/string 변경에 맞춰 추가하지 않는다. 실제 변경에 맞는 PR CI는 모두 통과해야 한다.

Mac/문서/출력 계약의 기존 #569/#580 통과 증거를 출처와 함께 인계한다. 로컬에서 같은 제품 소스의 광범위 FontLibrary/Studio/WebKit 테스트를 반복할지는 변경·실패·미해결 우려로 결정하며, PR CI가 요청하는 기존 검증은 생략하지 않는다. 원본 Swift·Studio·글꼴 공급 구조를 추가 수정해야 하면 범위 보정부터 받는다.

1280px 및 390/320px의 로컬 화면·키보드 동선·다운로드 링크를 확인하고 스크린샷 또는 로컬 URL로 작업지시자가 직접 볼 수 있게 제공한다. 공통 CSS를 바꾸면 홈/기존 노트 영향도 확인한다.

### 준비 보고·게시

Stage 2.1 소스/문구, Stage 2.2 검증/화면, Stage 2.3 준비 보고/PR의 하위 작업으로 추적한다. mydocs/report/task_m900_584_report.md는 **소스 준비 완료 / DMG 수용·공개 대기**를 명시한 부분 최종 보고로 시작한다. 준비한 PR 본문·정확한 local commit을 제시해 승인받은 뒤 publish/task584 push와 devel 대상 Open PR을 생성한다. CI와 fresh review를 거쳐 병합 승인을 받는다. PR을 task artifact로 연결한다.

커밋: Task #584 [Stage 2.1]: v0.2.3 후보 버전과 안내 준비; Task #584 Stage 2 + 최종 보고서: 릴리즈 준비 검증과 부분 인계.

## 4. Stage 3 — main 통합·고정 DMG·양 VM 수용

### 실행 순서와 별도 gate

1. 준비 PR 병합 후 정확한 devel source·포함 변경·content gate를 재확인한다. main 대상 릴리즈 PR을 준비하고 자동 Pages 배포의 asset gate와 영향을 설명한 뒤 게시/병합 승인을 받는다.
2. main에 반영된 정확한 source SHA와 0.2.3/21·v0.8.7 일치를 확인한다. 작업지시자에게 SHA/tag 및 workflow 입력을 제시해 **tag 생성과 Release Publish DMG 실행을 각각 승인**받는다. tag를 강제 이동하지 않는다.
3. Release Publish DMG를 v0.2.3 tag에서 version=0.2.3, previous_release_ref=v0.2.2, expected_rhwp_tag=v0.8.7, require_latest_rhwp=true, include_rhwp_in_title=false, draft=true, prerelease=false로 실행한다. upstream latest를 실행 직전 다시 확인하고 달라졌으면 예외 또는 새 scope 판정을 받는다.
4. 성공한 run ID/head SHA, public-dmg artifact ID·DMG SHA256·size·draft Release ID를 기록한다. 내려받은 파일의 checksum·hdiutil verify·Developer ID seal·staple·Gatekeeper·네 실행 파일 universal slice·layout을 확인한다. 실제 일반 Release app이며 새 진단 flag/fixture UUID를 주입하지 않는다.
5. 같은 artifact의 source_run_id, source_artifact_id, source_sha, dmg_sha256, expected_version=0.2.3, expected_build=21을 제시한 뒤 release-first-install.yml의 승인된 pre-public 검증을 실행한다. 기본은 v0.2.3 tag ref이며 새 macos-15/arm64와 macos-15-intel/x86_64 결과를 받는다.

### 수용 기준

양 VM의 install job·verdict 성공뿐 아니라 schema 3 verify-result.json의 PASS/release_eligible=true, 최초/종료 후 snapshot, reinstall-search.json 및 reinstall-stopped-search.json, lifecycle 33개·cleanup·실제 importer·candidate/source proof를 확인한다. maintained(유지)와 recovered(복구)를 구분하고 환경 조사 PASS를 후보 수용으로 바꾸지 않는다.

후보 실패/누락/cleanup 실패는 원래 증거를 보존해 재시험과 분리한다. 도구만 수정한 재검증은 검토된 main 및 release-install-source.py의 허용 변경 계약을 충족할 때만 가능하다. 제품·의존성·공개 문구나 DMG가 바뀌면 기존 PASS를 재사용하지 않는다. artifact 14일 만료 전에 수용·공개 gate를 확인하며 만료 시 stale 파일로 강행하지 않는다.

종료: 새 동일 DMG의 출처·파일 검증과 양 VM 수용이 충족되고 Stage 4의 구체 임시 설치·복원 계획이 준비되어야 한다. 커밋: Task #584 Stage 3: 동일 공증 DMG와 양 VM 설치 수용 기록.

## 5. Stage 4 — 최종 DMG의 실제 Mac 글꼴·문서·출력·Finder 수용

### 시험 준비·원상복원

build.noindex/task584/stage4 아래에 확정 DMG·추출 앱·소유 시험 문서·증거를 준비한다. 원래 /Applications/Alhangeul.app의 버전·실행 상태·서명·파일/link/mode inventory를 읽고 백업 위치·교체 대상·복원 절차를 제시한다. 이미 signed/notarized된 원본 앱을 그대로 설치하며 로컬 재서명·bundle 수정은 하지 않는다.

임시 설치와 필요한 글꼴 설정/권한·소유 저장 파일 범위를 **구체 후보·백업/복원 계획으로 승인받은 뒤** 실제 UI 수용을 진행한다. 기존 사용자 문서·다른 앱·OS 설치 글꼴을 바꾸지 않는다. 임시 시험에서 바꾼 사용자 설정의 원래 값도 기록해 복구하며 전체 preferences를 복사/초기화하지 않는다.

Finder는 scripts/smoke-clean-quicklook-install.sh의 --app, --install-app /Applications/Alhangeul.app, --replace-applications-install, --preserve-signature, --scoped-registrations, --skip-global-reset, 명시한 --sample/--output-dir 경로를 검토해 승인된 표준 절차 안에서 실행한다. 기본 샘플·전역 reset·다른 앱 등록 제거 옵션은 사용하지 않는다. 해당 helper가 백업/복원을 대신한다고 가정하지 않고 별도 복원 receipt를 남긴다.

기존 prepare-extension-font-smoke.py와 extension-font-finder-smoke.py는 task 568/569/580의 진단 앱·fixture 절차다. task 584 최종 앱에 해당 flag/UUID/보관함을 주입하거나 task 번호만 덧붙여 재사용하지 않는다. 최종 제품을 검사할 수 없는 항목은 보조 도구/별도 fixture의 필요성과 권한을 먼저 구체화한다.

### 기능 수용표

| 경로 | 실제 확인과 증거 |
|------|------------------|
| Mac 설정·목록 | ⌘, → 글꼴 → Mac에 설치된 글꼴 사용 ON/OFF, 실제 감지 목록과 기존 시스템 글꼴 선택, 권한 필요 상태, 새 프로세스의 설정 유지 |
| 문서 저장 | 소유 HWP/HWPX 복사본에서 설치 글꼴 Regular/Bold 선택·저장·재열기, family/원문/서식 유지. 진단 alias 이름이 문서에 저장되지 않음 |
| PDF | 실제 PDF 저장·글꼴 program/ToUnicode·텍스트 추출·검색·확대 화면. 별도 renderer/helper 결과를 실제 제품 PDF 성공으로 합산하지 않음 |
| 인쇄 | HWP/HWPX의 실제 macOS 인쇄 패널 열기·취소·문서 복귀. 물리 출력 없음 |
| Finder | 실제 single/multiple Quick Look과 새로운 경로의 Thumbnail, active provider 및 표준 앱 경로. 파일 수/환경/시간·fallback 상태를 구분 |
| 현재성·fallback | 원본/권한 상실과 보관함 경계는 기존 #569 계약을 대조. 추가 mutation은 소유 fixture와 승인된 설정 범위에서만 진행 |
| 저장·닫기·검색 | 기존 저장·닫기/종료·취소, Spotlight GUI/본문 검색 및 실제 importer. #480/#525 판단 또는 미확인 조건을 숨기지 않음 |
| Help | Mac 글꼴 안내 링크의 정확한 URL. 공개 전 페이지 부재를 제품 글꼴 실패 또는 이미 배포됨으로 표시하지 않음 |

실제 catalog/family count를 새로 기록하며 이전 232 family/809 records나 가상 28개를 예상 정답으로 고정하지 않는다. 현재 Mac에 있는 일반 무료 글꼴/기존 소유 fixture를 우선 사용하고 OS 설치나 사용권·폴더 권한이 추가로 필요하면 구체 대상을 제시한다. 진단 앱의 GUI 허용 범위나 예전 인증서 승인으로 새 최종 앱의 임시 설치를 허용됐다고 간주하지 않는다.

시험 후 후보와 개발 앱 등록을 필요한 범위에서 정리하고 원래 앱/설정을 복원한다. inventory·seal·원래 버전·active provider·소유 파일/보관함 cleanup을 확인한다. 원시 실패·UI 화면과 자동/수동 수용을 나눠 기록한다. 최소 macOS 12 및 Intel 실기기 GUI는 수행하지 못했다면 계속 미검증이다.

종료: 같은 DMG의 실제 Mac 수용 및 복원 PASS, 공개 전 위험/한계·정확한 hash의 최종 제시. 커밋: Task #584 Stage 4: 공증 후보 Mac 글꼴·출력·Finder 수용과 복원.

## 6. Stage 5 — 동일 파일 공개·업데이트·최종 기록

1. publish run/artifact, validation run/attempt, 정확한 source/tag/version/build/DMG hash와 실제 Mac 수용·미검증 환경을 제시한다. 필요하면 release-promotion.py verify의 읽기 전용 proof를 새 디렉터리에 준비한다. 이 검증은 공개 승인이 아니다.
2. **공개 승격·Pages/Sparkle 승인** 후 Release Promote Verified DMG를 승인한 ref에서 실행한다. version=0.2.3, expected_build=21, source_run_id/source_artifact_id/validation_run_id/source_sha/dmg_sha256은 확정 receipt의 실제 값만 사용한다. 재빌드·재공증·자산 재업로드 없이 검증한 동일 DMG를 공개한다.
3. 인증 없는 public DMG와 checksum URL에서 새로 다운로드해 hash를 대조한다. GitHub latest, Pages /updates/v0.2.3.html 및 /fonts/, 다운로드, 이전 버전 배너, appcast version=0.2.3/build=21/enclosure/hash 및 배포 성공을 확인한다.
4. 원래 공개 v0.2.2에서 실제 Sparkle 다운로드·설치·자동 재실행과 HWP/HWPX·검색·확장·Mac 글꼴 유지/기본 설정 동작을 검증한다. 로컬 강제 복사 결과를 실제 업데이트로 대신하지 않는다. 업데이트 후 최종 설치 앱을 유지할지는 구체 시험 승인에 명시한다.
5. 정확한 public SHA256으로 Casks/alhangeul.rb와 postmelee/homebrew-tap 반영안을 준비하고 **별도 Cask/tap 및 설치 시험 승인** 후 게시·audit·upgrade/install smoke를 수행한다. 분리 판정 시 기존 Homebrew 버전과 자체 이슈/미완료 조건을 명시한다.
6. mydocs/release/v0.2.3.md, mydocs/report/task_m900_584_report.md, Stage 5, 오늘할일에 최종 상태를 기록하고 승인된 문서 PR로 devel/main을 정렬한다. 전체 #584 종료와 task 브랜치/부산물 정리는 완료 판정·승인 후 진행한다.

공개 후 Pages만 실패하면 같은 입력의 승격 복구 절차를 사용한다. 공개 DMG 교체·tag 강제 이동·오래된 appcast 복구로 회피하지 않는다. 더 새 공개 릴리즈나 source/hash 변화가 있으면 중단·보정한다.

커밋: Task #584 Stage 5 + 최종 보고서: v0.2.3 동일 DMG 공개·업데이트 수용 기록.

## 7. 자원·증거·실행 경계

| 항목 | 원칙 |
|------|------|
| 저장 공간 | build.noindex/task584 아래에 앱/산출물 배치. 기존 matching Rust/Frameworks 입력과 필요한 cache/receipt 재사용. 새 build 전 가용 공간·활성 프로세스·필요 backup 확인 |
| 정리 | 검증/복원에 더 필요 없는 재생성 가능한 task 산출물만 정리. 확정 DMG·필수 증거·원래 앱 backup·public/draft 기존 자산과 전역 cache는 보존 |
| 증거 | 실행일·macOS/arch·source·run/artifact/hash·설정/권한·자동/수동 범위를 JSON/문서/필요 화면에 연결. 실패/미실행과 PASS 분리 |
| 시간·성능 | 이전 #580 보정과 #581 분리 유지. 실제 수치를 앱 전체 시작시간·모든 Mac 상한으로 확대하지 않으며 이번 릴리즈의 추가 <300ms 목표를 만들지 않음 |
| 승인 | 구현계획/Stage 1, 각 단계 종료, source 범위 변경, push/PR/merge, main/tag/서명·공증, 임시 설치, 공개/Pages/Sparkle, Homebrew는 해당 구체 자료로 확인 |
| 비밀 | 인증서/credential/secret 값은 읽어 출력·문서화·커밋하지 않음. 운영 식별자와 준비 여부만 확인 |

이 문서의 최소 명령은 계획이며 실행 결과가 아니다. 새로운 실패·source 변경·미해결 우려가 없으면 통과한 검사 범위를 무작정 확대하거나 반복하지 않는다. 필수 gate 실패, 새 제품 수정 필요, source/아키텍처/지원 범위 변경이 생기면 Stage 계획과 작업 범위를 보정한다.

## 8. 절차 근거

- [타스크 절차](../manual/task_workflow_guide.md), [빌드/실행](../manual/build_run_guide.md), [Swift/macOS 규칙](../manual/swift_macos_code_rules_guide.md).
- [public runbook](../manual/public_release_runbook.md), [DMG 패키징](../manual/release_packaging_dmg_guide.md), [서명·공증](../manual/release_signing_notarization_guide.md).
- [최초 설치 검증](../manual/release_first_install_guide.md), [Release/Pages/Sparkle](../manual/release_github_pages_sparkle_guide.md), [Homebrew](../manual/release_homebrew_cask_guide.md).
- [Mac 수용 보고](../report/task_m020_569_report.md), [Finder 비용 수용 보고](../report/task_m020_580_report.md), [v0.2.2 기록](../release/v0.2.2.md).
