# Task M020 #87 Stage 4 완료보고서

## 단계 목적

Stage 3의 gated Quick Look PDFKit probe를 실제 `qlmanage -p` preview 경로에서 실행해, `QLPreviewReply(forPDFWithPageSize:)`가 visible page 중심 lazy rendering으로 동작하는지 확인한다.

## 산출물

| 파일 | 요약 |
| --- | --- |
| `Sources/QLExtension/HwpPDFKitLazyPreviewProbe.swift` | extension sandbox에서 summary를 남길 수 있도록 probe 출력 위치를 sandbox cache 디렉터리로 보정 |
| `mydocs/working/task_m020_87_stage4.md` | Quick Look runtime smoke, provider routing, page draw 관측 결과 기록 |

Stage 4 중 생성된 app bundle, zip, probe summary, smoke output은 ignored 산출물 또는 `/private/tmp`, `~/Library/Containers/.../Caches` 아래 runtime 산출물이며 커밋하지 않는다.

## 실행 환경 정리

처음 등록 상태 점검:

```bash
scripts/check-extension-registration-hygiene.sh --check-only
```

결과 요약:

- issue 없음.
- PlugInKit이 preview/thumbnail provider path를 보고하지 않는 warning이 있었다.
- `build.noindex` 아래 개발 app bundle은 존재하지만 등록된 개발 app으로는 보고되지 않았다.

Release package가 없는 상태였으므로 smoke 기준에 맞춰 Release app을 생성했다.

```bash
env ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 scripts/package-release.sh 0.2.0
```

첫 package 시도는 `rhwp-core.lock`의 staticlib byte hash와 로컬 toolchain 산출물 hash가 달라 중단됐다. source provenance, generated header, FFI symbol 확인은 통과했고, 스크립트가 안내한 정책에 따라 lock을 수정하지 않고 `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1`만 사용했다.

결과:

```text
** BUILD SUCCEEDED ** [31.824 sec]
alhangeul-macos-0.2.0.zip
```

빌드 중 CoreSimulator version warning은 출력됐지만 macOS Release app, Quick Look extension, Thumbnail extension build는 성공했다.

## Finder 통합 smoke

task87 Release app을 표준 user install 위치에 설치하고 등록 smoke를 실행했다.

```bash
scripts/smoke-finder-integration.sh \
  --skip-package \
  --app build.noindex/release/Alhangeul.app \
  --output-dir /private/tmp/rhwp-task87-finder-smoke-stage4-cache
```

결과:

```text
OK: Finder integration smoke passed
Installed app: /Users/melee/Applications/Alhangeul.app
Output: /private/tmp/rhwp-task87-finder-smoke-stage4-cache/task151-20260518-092942
```

HWP/HWPX thumbnail output이 생성됐다.

## provider routing 분리

초기 `qlmanage -p` 실행은 summary를 만들지 못했다. `/usr/bin/log show`로 확인한 결과, preview extension이 task87 앱이 아니라 기존 `/Applications/Alhangeul.app`에서 실행됐다.

```text
Extension `/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex/Contents/MacOS/AlhangeulPreview` ... launched.
```

`/Applications/Alhangeul.app`의 preview binary에는 probe symbol이 없었고, `/Users/melee/Applications/Alhangeul.app`에는 probe symbol이 있었다. 따라서 Stage 4 관측 시에는 파일 삭제 없이 다음 순서로 등록을 격리했다.

1. `/Applications/Alhangeul.app`의 preview/thumbnail appex를 `pluginkit -r`로 임시 등록 해제.
2. `/Applications/Alhangeul.app`를 `lsregister -u`로 임시 등록 해제.
3. `/Users/melee/Applications/Alhangeul.app`를 `lsregister -f -R -trusted`와 `pluginkit -a`로 재등록.
4. 관측 후 `/Applications/Alhangeul.app` 등록을 복원.

관측 직전 provider path:

```text
com.postmelee.alhangeul.QLExtension
Path = /Users/melee/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex

com.postmelee.alhangeul.ThumbnailExtension
Path = /Users/melee/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex
```

## probe 출력 경로 보정

Stage 3 probe는 `/private/tmp/rhwp-task87-pdfkit-extension-probe`에 summary를 쓰도록 만들었다. 실제 extension sandbox에서는 gate flag 읽기는 성공했지만 summary 쓰기가 거부됐다.

```text
Preview selected PDFKit lazy probe file=hwp-multi-001.hwp pages=10
Sandbox: AlhangeulPreview deny(1) file-write-create /private/tmp/rhwp-task87-pdfkit-extension-probe/latest-summary.txt
```

따라서 recorder 출력 위치를 `FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)` 아래의 `rhwp-task87-pdfkit-extension-probe`로 바꿨다. 최종 summary는 다음 경로에 생성됐다.

```text
/Users/melee/Library/Containers/com.postmelee.alhangeul.QLExtension/Data/Library/Caches/rhwp-task87-pdfkit-extension-probe/latest-summary.txt
```

## Quick Look 관측

샘플:

```text
samples/hwp-multi-001.hwp
```

관측 명령 요약:

```bash
touch /private/tmp/rhwp-task87-enable-pdfkit-probe
qlmanage -p /Users/melee/Documents/projects/rhwp-mac-task87/samples/hwp-multi-001.hwp
rm -f /private/tmp/rhwp-task87-enable-pdfkit-probe
```

실행 자동화에서는 `qlmanage -p`를 10초 동안 열고 종료했다. 별도 scroll/page 이동 전, 최초 preview load만으로 event가 충분히 발생했다.

summary 핵심값:

```text
Filename: hwp-multi-001.hwp
PageCount: 10
PageSize: 793.7x1122.5
EventCount: 34
```

event sequence 요약:

| 범위 | 관측 |
| --- | --- |
| 1-2 | document 생성 시작/종료 |
| 3 | `dataRepresentation` begin |
| 4-13 | `page(at:)`가 1-10 page 전체를 순서대로 요청 |
| 14-33 | 다시 1-10 page 전체를 요청하면서 각 page마다 `draw(with:to:)` 호출 |
| 34 | `dataRepresentation` end, bytes=8030 |

핵심 event:

```text
3  dataRepresentation begin
4  pageRequest page=1
...
13 pageRequest page=10
15 draw page=1
17 draw page=2
...
33 draw page=10
34 dataRepresentation end bytes=8030
```

## 결론

이번 관측 기준에서 `QLPreviewReply(forPDFWithPageSize:)`에 custom `PDFDocument`를 반환해도 Quick Look preview는 최초 load 중 `PDFDocument.dataRepresentation()`을 호출했고, 그 안에서 10개 page 전체의 `draw(with:to:)`가 실행됐다.

따라서 이 경로는 `hwp-multi-001.hwp` 10페이지 샘플에서 visible page 중심 lazy rendering으로 보기 어렵다. Stage 2 standalone 결과와 같은 방향이며, PDFKit document reply만으로 #87의 lazy preview 목표를 만족할 가능성은 낮다.

## 검증 결과

```bash
env ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 scripts/package-release.sh 0.2.0
```

결과: 성공.

```bash
scripts/smoke-finder-integration.sh --skip-package --app build.noindex/release/Alhangeul.app
```

결과: 성공.

```bash
qlmanage -p samples/hwp-multi-001.hwp
```

결과: probe gate 활성화 상태에서 summary 생성 성공.

```bash
scripts/check-extension-registration-hygiene.sh --check-only
```

결과: issue 없음. 다만 PlugInKit path 미보고 warning은 계속 출력됐다.

```bash
git diff --check -- Sources/QLExtension/HwpPDFKitLazyPreviewProbe.swift mydocs/working/task_m020_87_stage4.md
```

결과: 통과.

## 잔여 위험

- 이번 관측은 `qlmanage -p` 최초 load 기준이다. scroll/page 이동을 추가해도 이미 최초 load에서 전체 page draw가 끝났으므로 lazy 가능성 판단에는 영향을 주기 어렵다.
- `/Applications/Alhangeul.app`와 `/Users/melee/Applications/Alhangeul.app`가 동시에 존재하면 preview provider routing이 흔들릴 수 있다. Stage 4에서는 `/Applications` 등록을 임시 해제했다가 복원했다.
- `scripts/check-extension-registration-hygiene.sh`는 현재 worktree의 `build.noindex` 개발 등록에는 경고하지만, 다른 worktree나 `/Applications` 설치본과의 provider 우선순위까지 완전히 판정하지 못한다.
- Stage 4에서 probe summary를 남기기 위해 제품 소스의 debug-only probe 출력 위치를 보정했다. Stage 5에서 probe를 제거할지, debug-only 상태로 남길지 결정해야 한다.

## 다음 단계 영향

Stage 5에서는 PDFKit reply 기반 lazy preview를 "불가능 또는 실효성 낮음"으로 정리하고, #88 view-based Quick Look lazy rendering 쪽으로 handoff하는 결론을 작성하는 것이 타당하다. 제품 기본 preview 경로는 계속 기존 data reply를 유지해야 한다.

## 승인 요청

Stage 4 완료 검토와 Stage 5 `결론, probe 정리, #88 handoff` 진행 승인을 요청한다.
