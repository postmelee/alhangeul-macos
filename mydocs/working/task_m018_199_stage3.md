# Task M018 #199 Stage 3 완료 보고서

## 단계 목적

수정된 빌드에서 HWP/HWPX thumbnail PNG 생성이 시간 내 완료되는지 Debug/Release smoke로 확인했다.

## 빌드 결과

Debug build:

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
** BUILD SUCCEEDED ** [11.980 sec]
```

Release build:

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Release \
  -derivedDataPath build.noindex/DerivedDataRelease \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과:

```text
** BUILD SUCCEEDED ** [23.150 sec]
```

새 worktree에는 ignored `Frameworks/Rhwp.xcframework`가 없어서 기존 worktree의 `Frameworks/`를 복사한 뒤 빌드했다. 이 파일은 git 변경 대상이 아니다.

## Quick Look smoke

unsigned build 산출물은 PluginKit에서 `plug-ins must be sandboxed`로 거부되므로, smoke 전 임시 설치본의 appex에 sandbox entitlements를 넣어 ad-hoc signing했다.

Debug 임시 설치본:

```bash
qlmanage -t -x -s 256 -o /private/tmp/alhangeul-qlsigned2.UuOTCA/hwp \
  /Users/melee/Documents/projects/rhwp-mac-task199/samples/exam_science.hwp
qlmanage -t -x -s 256 -o /private/tmp/alhangeul-qlsigned2.UuOTCA/hwpx \
  /Users/melee/Documents/projects/rhwp-mac-task199/samples/hwpx/hwpx-01.hwpx
```

결과:

| 샘플 | 결과 파일 |
|------|-----------|
| `samples/exam_science.hwp` | PNG image data, `177 x 256`, RGBA |
| `samples/hwpx/hwpx-01.hwpx` | PNG image data, `182 x 256`, RGBA |

Release 임시 설치본:

```bash
qlmanage -t -x -s 256 -o /private/tmp/alhangeul-qlrelease-smoke2/hwp \
  /Users/melee/Documents/projects/rhwp-mac-task199/samples/exam_science.hwp
qlmanage -t -x -s 256 -o /private/tmp/alhangeul-qlrelease-smoke2/hwpx \
  /Users/melee/Documents/projects/rhwp-mac-task199/samples/hwpx/hwpx-01.hwpx
qlmanage -t -x -s 256 -c com.postmelee.alhangeul.hwp \
  -o /private/tmp/alhangeul-qlrelease-smoke2/hwp-forced \
  /Users/melee/Documents/projects/rhwp-mac-task199/samples/exam_science.hwp
```

결과:

| 샘플 | 결과 파일 |
|------|-----------|
| `samples/exam_science.hwp` | PNG image data, `177 x 256`, RGBA |
| `samples/hwpx/hwpx-01.hwpx` | PNG image data, `182 x 256`, RGBA |
| forced `com.postmelee.alhangeul.hwp` | PNG image data, `177 x 256`, RGBA |

Release smoke 직후 `took more than 60 seconds to reply` timeout 재발은 확인되지 않았다.

## 설치본 정리

검증을 위해 임시로 등록했던 `/Users/melee/Applications/Alhangeul.app`은 제거했다.

현재 LaunchServices/PluginKit 등록은 공식 설치본만 가리킨다.

```text
/Applications/Alhangeul.app
Path = /Applications/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex
Parent Bundle = /Applications/Alhangeul.app
```

주의: 공식 `/Applications/Alhangeul.app` `v0.1.0` 자체에는 이번 수정이 아직 포함되지 않았으므로, Finder thumbnail은 v0.1.1 패치 설치본으로 교체되기 전까지 계속 실패할 수 있다.

## 추가 확인

```bash
git diff --check
```

결과: 출력 없음.

