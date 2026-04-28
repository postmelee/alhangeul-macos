# Task #76 Stage 5 완료 보고서

## 단계 목적

Stage 1~4에서 확인한 core pin 갱신, RustBridge/Swift bridge 검증, HostApp/render/image data smoke 결과를 운영 문서와 최종 보고서에 반영한다. 추가로 작업지시자가 직접 확인한 설치본 기준 Finder thumbnail/Quick Look preview 결과를 upstream 메인테이너 회신용 한국어 요약으로 정리한다.

## 산출물

- `mydocs/tech/core_release_compatibility.md`
  - 현재 Demo/Preview pin을 `e91ecea3174a0da0ad7a1ea495cacc4f8772c31d` 기준으로 보정했다.
  - 최신 확인 release를 `v0.7.7` / `033617e23847982135c02091a62f55031a3817b5`로 보정했다.
  - `v0.7.7`의 Stable blocked 사유를 `build_page_render_tree` 누락으로 정리했다.
  - alhangeul-macos use case 검증 결과를 추가했다.
- `mydocs/manual/core_dependency_operation_guide.md`
  - core 기준 요약의 stale `v0.7.6` 표현을 `v0.7.7` 기준으로 보정했다.
- `mydocs/tech/project_architecture.md`
  - Demo/Preview와 Stable 기준 요약의 stale release 표현을 보정했다.
- `mydocs/report/task_m010_76_report.md`
  - 최종 결과, 검증 결과, 수용 기준 충족 여부, 메인테이너 회신용 한국어 요약을 기록했다.
- `mydocs/working/task_m010_76_stage5.md`
  - Stage 5 문서 보정과 최종 검증 결과를 기록했다.
- `mydocs/orders/20260429.md`
  - #76 상태를 완료로 갱신했다.

## 본문 변경 정도 / 본문 무손실 여부

- 기존 compatibility gate의 구조와 원칙은 유지했다.
- stale release/pin 값만 현재 확인 결과로 갱신했다.
- Stable 기준을 완화하지 않았다. `v0.7.7`에 `build_page_render_tree`가 없어 Stable 전환 blocked 상태를 유지한다.
- 추가 확인 결과는 메인테이너 회신에 바로 사용할 수 있도록 한국어로 작성했다.

## 검증 결과

현재 release 상태 재확인:

```bash
gh release view --repo edwardkim/rhwp --json tagName,targetCommitish,publishedAt,url
```

결과:

```text
{"publishedAt":"2026-04-27T04:21:36Z","tagName":"v0.7.7","targetCommitish":"main","url":"https://github.com/edwardkim/rhwp/releases/tag/v0.7.7"}
```

```bash
git ls-remote --tags https://github.com/edwardkim/rhwp.git refs/tags/v0.7.7 refs/tags/v0.7.7^{}
```

결과:

```text
033617e23847982135c02091a62f55031a3817b5	refs/tags/v0.7.7
```

```bash
./scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.7
```

결과: expected failure.

```text
ERROR: missing core API: build_page_render_tree
ERROR: missing core API: target 033617e23847982135c02091a62f55031a3817b5 does not satisfy RustBridge requirements
```

설치본 기준 Quick Look/Thumbnail 추가 확인:

```bash
./scripts/package-release.sh 0.1.0
```

결과: 통과.

```text
** BUILD SUCCEEDED ** [16.545 sec]
d9dfc61d203c8acac6b927e42e5d8ac9bd5b5a4e2b8001d0ca6774aea566ca8d  alhangeul-macos-0.1.0.zip
```

`/Users/melee/Applications/AlhangeulMac.app`을 새 release package 산출물로 교체하고 `lsregister`, `pluginkit`, `qlmanage -r`, `qlmanage -r cache`를 실행했다.

```bash
pluginkit -mAvvv -i com.postmelee.alhangeulmac.QLExtension
pluginkit -mAvvv -i com.postmelee.alhangeulmac.ThumbnailExtension
```

결과:

```text
Path = /Users/melee/Applications/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacPreview.appex
Parent Bundle = /Users/melee/Applications/AlhangeulMac.app

Path = /Users/melee/Applications/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacThumbnail.appex
Parent Bundle = /Users/melee/Applications/AlhangeulMac.app
```

```bash
codesign --verify --deep --strict --verbose=2 /Users/melee/Applications/AlhangeulMac.app
```

결과: 통과.

```text
/Users/melee/Applications/AlhangeulMac.app: valid on disk
/Users/melee/Applications/AlhangeulMac.app: satisfies its Designated Requirement
```

```bash
qlmanage -t -x -s 512 -o /tmp/alhangeul-task76-ql \
  samples/basic/KTX.hwp \
  samples/basic/request.hwp \
  samples/basic/KTX-003.hwp
```

결과:

```text
* /Users/melee/Documents/projects/rhwp-mac/samples/basic/request.hwp produced one thumbnail
* /Users/melee/Documents/projects/rhwp-mac/samples/basic/KTX.hwp produced one thumbnail
* /Users/melee/Documents/projects/rhwp-mac/samples/basic/KTX-003.hwp produced one thumbnail
```

이미지 포함 샘플 thumbnail도 생성됐다.

```text
/tmp/alhangeul-task76-ql/exam_kor.hwp.png
/tmp/alhangeul-task76-ql/hwp-img-001.hwp.png
/tmp/alhangeul-task76-ql/pic-in-head-02.hwp.png
/tmp/alhangeul-task76-ql/pic-in-table-01.hwp.png
/tmp/alhangeul-task76-ql/tac-img-02.hwp.png
```

작업지시자가 Finder에서 thumbnail과 Quick Look preview 표시를 직접 확인했다.

Stage 5 통합 검증:

```bash
git diff --check
./scripts/build-rust-macos.sh --verify-lock
./scripts/check-no-appkit.sh
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/validate-stage3-render.sh
rg -n "1e9d78a1d40c71779d81c6ec6870cd301d912626|e91ecea3174a0da0ad7a1ea495cacc4f8772c31d|v0\\.7\\.|build_page_render_tree|get_bin_data|demo-commit-pin|Stable" \
  rhwp-core.lock RustBridge mydocs README.md
git status --short
```

결과:

```text
git diff --check: ok
./scripts/build-rust-macos.sh --verify-lock: Verified: /Users/melee/Documents/projects/rhwp-mac/rhwp-core.lock
./scripts/check-no-appkit.sh: OK: shared Swift code has no AppKit/UIKit dependencies
xcodebuild Debug build: ** BUILD SUCCEEDED ** [5.758 sec]
./scripts/validate-stage3-render.sh: KTX.hwp, request.hwp, exam_kor.hwp 모두 OK
```

`rg` gate 결과, 현재 truth source 문서(`core_release_compatibility.md`, `core_dependency_operation_guide.md`, `project_architecture.md`)는 `v0.7.7` / `e91ecea3174a0da0ad7a1ea495cacc4f8772c31d` 기준으로 정리되었다. 이전 pin `1e9d78a1d40c71779d81c6ec6870cd301d912626`은 과거 stage/report/plan의 이력 설명과 이번 최종 보고서의 "이전 pin에서 변경" 문맥에만 남아 있다.

최종 `git status --short`는 Stage 5 tracked 변경만 표시했다.

## 잔여 위험

- `e91ecea3174a0da0ad7a1ea495cacc4f8772c31d`는 release tag가 아니므로 Demo/Preview commit pin으로만 사용한다.
- Finder/Quick Look 직접 확인은 현재 개발자 환경의 LaunchServices/PlugInKit 상태에 의존한다. 배포 전 release rehearsal에서도 같은 절차로 반복 확인해야 한다.
- 최신 release `v0.7.7`은 `build_page_render_tree` 누락으로 Stable 전환이 여전히 blocked다.

## 다음 단계 영향

모든 구현 단계가 완료되었다. 작업지시자 승인 후 `publish/task76` 원격 브랜치 push와 devel 대상 draft PR 생성을 진행할 수 있다.

## 승인 요청

Stage 5와 최종 보고서 결과를 승인하고 PR 게시 단계로 진행할지 승인 요청한다.
