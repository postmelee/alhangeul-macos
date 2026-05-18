# Task M020 #87 Stage 3 완료보고서

## 단계 목적

기존 Quick Look preview 기본 경로는 유지하면서, 명시 opt-in gate가 켜진 경우에만 `QLPreviewReply(forPDFWithPageSize:documentCreationBlock:)` 기반 PDFKit probe reply를 선택하도록 추가한다.

## 산출물

| 파일 | 요약 | 라인 수 |
| --- | --- | ---: |
| `Sources/QLExtension/HwpPDFKitLazyPreviewProbe.swift` | PDFKit lazy probe reply, custom `PDFDocument`/`PDFPage`, `/private/tmp` summary recorder 추가 | 280 |
| `Sources/QLExtension/HwpPreviewProvider.swift` | probe gate가 켜진 경우에만 PDFKit probe reply 선택 | 94 |
| `Alhangeul.xcodeproj/project.pbxproj` | `xcodegen generate` 결과로 새 QLExtension source 포함 | - |
| `mydocs/working/task_m020_87_stage3.md` | Stage 3 구현과 검증 결과 기록 | - |

`project.yml`은 변경하지 않았다. `Sources/QLExtension` 전체가 target source path로 이미 포함되어 있으므로, `xcodegen generate`가 tracked `Alhangeul.xcodeproj/project.pbxproj`에 새 파일 reference를 반영했다.

## 구현 내용

### opt-in gate

`HwpPreviewProvider.createPreview(for:)`에서 `HwpPreviewPDFRenderer.inspect(fileURL:)` 이후 다음 조건을 확인한다.

- 환경변수 `ALHANGEUL_PDFKIT_LAZY_PROBE` 값이 `1`, `true`, `yes`, `on` 중 하나
- 또는 `/private/tmp/rhwp-task87-enable-pdfkit-probe` 파일 존재

gate가 꺼져 있으면 기존 흐름이 그대로 유지된다.

- 단일 페이지: PNG data reply
- 다중 페이지: 기존 `HwpPreviewPDFRenderer.render(previewInfo:)` 기반 PDF data reply

gate가 켜진 경우에만 `HwpPDFKitLazyPreviewProbe.reply(previewInfo:)`로 분기한다.

### PDFKit probe reply

`HwpPDFKitLazyPreviewProbe.reply(previewInfo:)`는 다음을 수행한다.

1. `QLPreviewReply(forPDFWithPageSize: previewInfo.contentSize)`를 만든다.
2. document creation block 안에서 `HwpPDFKitLazyProbeDocument`를 만든다.
3. page count만큼 `HwpPDFKitLazyProbePage`를 삽입한다.
4. document 생성, page request, data representation, page draw event를 기록한다.
5. summary를 `/private/tmp/rhwp-task87-pdfkit-extension-probe/summary-{UUID}.txt`와 `latest-summary.txt`에 쓴다.

custom document는 `page(at:)`와 `dataRepresentation()`을 override해 Quick Look이 어느 경로로 document를 소비하는지 기록한다. custom page는 `draw(with:to:)`를 override해 page별 draw event를 기록하고 synthetic page content를 그린다.

Stage 3의 목적은 runtime smoke가 아니라 빌드 가능한 gated probe를 넣는 것이다. 실제 Finder/Quick Look 안에서 event가 어떻게 찍히는지는 Stage 4에서 확인한다.

## 본문 변경 정도 / 본문 무손실 여부

해당 없음. 제품 동작 기본 경로는 유지했고, probe는 명시 gate가 켜진 경우에만 활성화된다.

## 검증 결과

### diff check

```bash
git diff --check -- Sources/QLExtension/HwpPreviewProvider.swift Sources/QLExtension/HwpPDFKitLazyPreviewProbe.swift project.yml mydocs/working/task_m020_87_stage3.md
```

결과: 통과.

### xcodegen

```bash
xcodegen generate
```

결과:

```text
Created project at /Users/melee/Documents/projects/rhwp-mac-task87/Alhangeul.xcodeproj
```

### Rust bridge 준비

새 worktree에는 `Frameworks/Rhwp.xcframework`가 없어서 build 전 준비 단계로 다음을 실행했다.

```bash
./scripts/build-rust-macos.sh
```

결과 요약:

```text
[1/4] Rust staticlib (arm64 + x86_64)...
[2/4] Universal binary...
[3/4] cbindgen header check...
[4/4] XCFramework...
Done: /Users/melee/Documents/projects/rhwp-mac-task87/Frameworks/Rhwp.xcframework
```

`Frameworks/`, `RustBridge/target/`, `build.noindex/`는 ignored 산출물이며 커밋하지 않는다.

### Debug build

첫 실행은 sandbox 안에서 Sparkle package fetch가 DNS/network 제한으로 실패했다.

```text
Could not resolve package dependencies:
  Failed to clone repository https://github.com/sparkle-project/Sparkle
  fatal: unable to access 'https://github.com/sparkle-project/Sparkle/': Could not resolve host: github.com
```

같은 명령을 승인된 네트워크 환경에서 재실행했고 성공했다.

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과:

```text
** BUILD SUCCEEDED ** [12.675 sec]
```

보고서 작성 후 같은 명령을 sandbox 안에서 재실행했을 때는 SwiftPM manifest/module cache 쓰기 제한으로 실패했다. 승인된 환경에서 다시 실행한 결과 다음처럼 성공했다.

```text
** BUILD SUCCEEDED ** [1.753 sec]
```

빌드 중 CoreSimulator version/cache 관련 경고가 출력됐지만 macOS HostApp/QLExtension/ThumbnailExtension build는 성공했다.

## 잔여 위험

- Stage 3은 compile/link 확인 단계다. Quick Look runtime이 `QLIsDataBasedPreview = true` 설정에서 PDFDocument reply를 실제로 받아들이는지는 Stage 4 smoke 전까지 확정할 수 없다.
- `PDFDocument.dataRepresentation()`은 Stage 2에서 전체 page draw를 호출하는 것으로 관측됐다. Stage 4에서 Quick Look이 이 경로를 호출하면 PDFKit reply도 true lazy가 아닐 수 있다.
- `/private/tmp` flag 방식은 smoke용 debug gate다. 최종 단계에서 probe를 남길지 제거할지 다시 판단해야 한다.
- Debug build가 LaunchServices registration을 수행했을 수 있으므로 Stage 4 smoke에서는 active provider path와 정리 절차를 별도로 기록해야 한다.

## 다음 단계 영향

Stage 4는 `/private/tmp/rhwp-task87-enable-pdfkit-probe` flag로 probe를 활성화하고, `/private/tmp/rhwp-task87-pdfkit-extension-probe/latest-summary.txt`의 event sequence를 기준으로 Quick Look의 page request/draw/dataRepresentation 호출 양상을 확인한다.

## 승인 요청

Stage 3 완료 검토와 Stage 4 `Quick Look smoke와 page draw 관측` 진행 승인을 요청한다.
