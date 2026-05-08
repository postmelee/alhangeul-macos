# Task M016 #149 Stage 5 보고서

## 단계 목적

HostApp, Quick Look, Thumbnail의 synthetic negative smoke 결과를 기록하고, 손상/대용량 opening fallback 기준을 release gate 문서와 연결했다. 이번 단계에서는 release package 생성이나 설치본 등록은 수행하지 않고, 설치본 기준 검증 항목은 #151 smoke gate로 분리했다.

## 산출물

| 파일 | 요약 |
|---|---|
| `mydocs/manual/build_run_guide.md` | 손상/대용량 문서 opening fallback smoke 절차 추가 |
| `README.md` | `corrupt file fallback` 구현 상태 체크 |
| `mydocs/working/task_m016_149_stage5.md` | Stage 5 smoke와 release gate 정리 |

## 변경 내용

- `build_run_guide.md`에 synthetic `empty.hwp`, `corrupt.hwp`, `large.hwp` 생성 절차를 추가했다.
- HostApp fallback smoke는 Debug app으로 확인 가능하다고 명시했다.
- Quick Look/Thumbnail smoke는 현재 시스템에 등록된 extension 산출물 기준이므로, Debug build를 Finder/Quick Look 등록 검증의 진실 원천으로 쓰지 말라고 명시했다.
- 설치본 기준 smoke에서 정상 sample, 50 MB 초과 파일, 손상/미지원 입력 모두 thumbnail이 생성되어야 하고, 손상/미지원 입력은 fallback tile이어야 한다고 정리했다.
- README의 v0.4 checklist 중 `corrupt file fallback`을 현재 저장소 구현 상태에 맞춰 체크했다.

## 본문 무손실 여부

사용자 원본 문서와 sample 파일은 수정하지 않았다. synthetic 파일은 `build.noindex/task149-negative/` 아래에만 생성했다.

## 검증 결과

```text
$ git status --short --branch
## local/task149
 M README.md
 M mydocs/manual/build_run_guide.md
```

```text
$ ./scripts/check-no-appkit.sh
OK: shared Swift code has no AppKit/UIKit dependencies
```

```text
$ xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
** BUILD SUCCEEDED ** [0.475 sec]
```

빌드 중 CoreSimulator 관련 경고와 provisioning profile 경고가 출력됐지만 macOS HostApp build는 성공했다.

```text
$ mkdir -p build.noindex/task149-negative /tmp/alhangeul-ql
$ printf '' > build.noindex/task149-negative/empty.hwp
$ printf 'not hwp' > build.noindex/task149-negative/corrupt.hwp
$ mkfile 51m build.noindex/task149-negative/large.hwp
$ stat -f '%N %z' build.noindex/task149-negative/empty.hwp build.noindex/task149-negative/corrupt.hwp build.noindex/task149-negative/large.hwp
build.noindex/task149-negative/empty.hwp 0
build.noindex/task149-negative/corrupt.hwp 7
build.noindex/task149-negative/large.hwp 53477376
```

HostApp smoke:

```text
$ /usr/bin/open -n -a build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app build.noindex/task149-negative/empty.hwp
$ /usr/bin/open -a build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app build.noindex/task149-negative/corrupt.hwp
$ pgrep -x Alhangeul
32523
```

Debug app은 빈 파일과 손상 파일을 받은 뒤 프로세스가 유지됐다. 확인 후 `osascript`로 앱을 종료했다.

Quick Look/Thumbnail smoke:

```text
$ qlmanage -t -x -s 512 -o /tmp/alhangeul-ql samples/basic/KTX.hwp
* /Users/melee/Documents/projects/rhwp-mac/samples/basic/KTX.hwp produced one thumbnail

$ qlmanage -t -x -s 512 -o /tmp/alhangeul-ql build.noindex/task149-negative/large.hwp
* /Users/melee/Documents/projects/rhwp-mac/build.noindex/task149-negative/large.hwp produced one thumbnail

$ qlmanage -t -x -s 512 -o /tmp/alhangeul-ql build.noindex/task149-negative/empty.hwp
* No thumbnail created for /Users/melee/Documents/projects/rhwp-mac/build.noindex/task149-negative/empty.hwp

$ qlmanage -t -x -s 512 -o /tmp/alhangeul-ql build.noindex/task149-negative/corrupt.hwp
* No thumbnail created for /Users/melee/Documents/projects/rhwp-mac/build.noindex/task149-negative/corrupt.hwp
```

최초 sandbox 안의 `qlmanage -t`는 `sandbox initialization failed`로 실패해, 동일 명령을 sandbox 밖에서 재실행했다. 정상 sample과 50 MB 초과 파일은 thumbnail이 생성됐다. 빈/손상 synthetic 파일은 현재 등록된 Quick Look 경로에서 thumbnail이 생성되지 않았다. 이번 Stage 4 코드 자체는 QLExtension/ThumbnailExtension build로 검증됐지만, `qlmanage`는 현재 시스템 등록 산출물을 사용하므로 설치본 기준 재검증을 #151로 넘긴다.

추가 관찰:

```text
$ qlmanage -p -x -o /tmp/alhangeul-ql build.noindex/task149-negative/corrupt.hwp
NSInvalidArgumentException: key cannot be nil
```

`qlmanage -p -x -o` preview 출력 경로는 Quick Look/ExtensionFoundation 내부 예외로 종료되어 Stage 5 gate로 사용하지 않았다.

문서 검색:

```text
$ rg -n "50 MB|손상|대용량|fallback|corrupt file fallback|Quick Look|Thumbnail" README.md mydocs/manual/build_run_guide.md
```

결과: 새 smoke 절차와 README checklist 문구가 검색됐다.

```text
$ git diff --check
```

출력 없음.

## #151 설치본 smoke gate 입력

- signed/sealed package를 `$HOME/Applications/Alhangeul.app`에 설치한 뒤 `qlmanage -r`, `qlmanage -r cache` 후 확인한다.
- `qlmanage -t -x -s 512 -o /tmp/alhangeul-ql`로 정상 sample, `empty.hwp`, `corrupt.hwp`, `large.hwp`를 모두 확인한다.
- 빈/손상 synthetic 입력도 thumbnail fallback tile을 생성해야 한다.
- `qlmanage -p` preview에서 손상/미지원 입력이 plain text fallback을 표시하는지 별도 확인한다.
- 설치본에서 빈/손상 thumbnail이 생성되지 않으면 extension 등록 대상, Quick Look cache, content type routing, fallback classifier 순서로 분리한다.

## #146 known limitations 입력

- HostApp에는 50 MB hard block을 두지 않는다. 대용량 문서 앱 opening 안정성은 별도 성능/호환성 항목으로 남긴다.
- HWPX signature preflight는 ZIP magic만 확인한다. 실제 HWPX 구조 검증은 parser/render 단계에서 fallback 처리한다.
- 손상/미지원 문서 fallback은 문서 복구가 아니라 crash/hang/raw error 방지 목적이다.
- Quick Look/Thumbnail 설치본 smoke는 Debug build가 아니라 signed/sealed package 기준으로 해석해야 한다.

## 잔여 위험

- 빈/손상 synthetic 파일의 `qlmanage -t` thumbnail fallback은 현재 등록 산출물 기준에서 아직 성공으로 확인되지 않았다. Stage 5에서는 설치본 생성/등록을 수행하지 않았으므로 #151에서 release package 기준으로 재검증한다.
- Quick Look preview fallback 문구는 GUI 또는 설치본 기준 `qlmanage -p`로 직접 눈검증하지 않았다.
- `devel-webview`가 작업 중 #148 merge로 전진했다. Stage 5 변경은 `local/task149`에 보존했으며, 최종 PR 전 통합 브랜치 최신화 여부를 확인해야 한다.

## 다음 단계 영향

모든 구현 단계가 끝났으므로 다음 승인을 받으면 `task-final-report` 절차로 최종 결과보고서, 오늘할일 완료 처리, 최종 커밋, `publish/task149` push, PR 생성을 진행한다.

## 승인 요청

Stage 5 완료 검토 후 최종 보고와 PR 게시 절차 진행 승인을 요청한다.
