# Task M018 #188 Stage 7 작업 보고서

## 단계 목적

Quick Look/Thumbnail hotfix를 사용자가 직접 시각 검증할 수 있도록, 기존 설치본과 과거 개발 extension 등록 상태가 섞이지 않는 clean visual smoke 절차를 만든다.

확인 시각: `2026-05-11 04:56 KST`

## 추가한 도구

| 파일 | 목적 |
|------|------|
| `scripts/smoke-clean-quicklook-install.sh` | 기존 앱/extension 등록을 정리하고, hotfix app을 설치한 뒤 새 샘플 폴더와 시각 검증 helper를 생성 |

이 스크립트는 public release artifact를 만들지 않는다. 현재 로컬 Mac에서 시각 smoke를 하기 위한 보조 도구이며, signed/notarized respin 검증을 대체하지 않는다.

## 오염 방지 기준

스크립트는 다음 순서로 테스트 오염을 줄인다.

| 단계 | 내용 |
|------|------|
| app 준비 | `build.noindex/release/Alhangeul.app` 또는 지정 app을 `/private/tmp/alhangeul-visual-smoke/<timestamp>/staging`으로 복사 |
| local 재서명 | staging app, Quick Look/Thumbnail appex, Sparkle nested component를 ad-hoc runtime 서명으로 재서명 |
| entitlement 정리 | release entitlements를 사용해 extension의 `get-task-allow`가 남지 않도록 함 |
| 기존 provider 정리 | 기존 `/Applications/Alhangeul.app`과 `$HOME/Applications/Alhangeul.app`의 PlugInKit/LaunchServices 등록을 해제 |
| 설치 경로 제한 | `/Applications/Alhangeul.app` 또는 `$HOME/Applications/Alhangeul.app`만 허용 |
| 중복 app 차단 | user Applications copy가 있으면 기본 실패, 명시 옵션에서만 제거 |
| 새 등록 | `lsregister`, `pluginkit -a`, `pluginkit -e use`로 새 app/appex 등록 |
| cache refresh | `quicklookd`, `QuickLookUIService`, extension process 종료 후 `qlmanage -r`, `qlmanage -r cache` 실행 |
| provider 경로 검증 | active provider path가 설치된 app 내부 `.appex`와 일치하지 않으면 실패 |
| 새 샘플 생성 | 원본 sample을 timestamp가 붙은 `/private/tmp` 새 폴더로 복사해 Finder/Quick Look cache 영향을 줄임 |
| forced UTI smoke | `.hwp`, `.hwpx` 확장자에 맞춰 `qlmanage -c com.postmelee.alhangeul.*`로 provider를 강제 지정 |

첫 `qlmanage -t` 요청은 등록 직후 Quick Look server warm-up 때문에 thumbnail이 나오지 않을 수 있어 최대 3회 재시도한다. 이번 실행에서도 첫 HWP 샘플은 1회 실패 후 2회차에서 생성됐다.

## 실행 결과

실행 명령:

```bash
scripts/smoke-clean-quicklook-install.sh \
  --skip-package \
  --app build.noindex/release/Alhangeul.app \
  --replace-applications-install \
  --remove-user-application-copy \
  --open-finder
```

결과:

| 항목 | 결과 |
|------|------|
| 설치 app | `/Applications/Alhangeul.app` |
| 설치본 성격 | local ad-hoc hotfix smoke build |
| 새 샘플 폴더 | `/private/tmp/alhangeul-visual-smoke/20260511-045624/samples` |
| thumbnail 산출물 | `/private/tmp/alhangeul-visual-smoke/20260511-045624/thumbnails` |
| 시각 검증 안내 | `/private/tmp/alhangeul-visual-smoke/20260511-045624/VISUAL_CHECK.md` |
| Quick Look 직접 열기 helper | `/private/tmp/alhangeul-visual-smoke/20260511-045624/open-preview.command` |
| crash 확인 helper | `/private/tmp/alhangeul-visual-smoke/20260511-045624/check-crashes.command` |

PlugInKit active provider:

| Provider | Path |
|----------|------|
| `com.postmelee.alhangeul.QLExtension` | `/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex` |
| `com.postmelee.alhangeul.ThumbnailExtension` | `/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex` |

Thumbnail 산출물:

| 샘플 | 결과 |
|------|------|
| `alhangeul-smoke-01-20260511-045624.hwp` | `544 x 768` PNG 생성 |
| `alhangeul-smoke-02-20260511-045624.hwp` | `544 x 768` PNG 생성 |
| `alhangeul-smoke-03-20260511-045624.hwpx` | `544 x 768` PNG 생성 |

Crash report 확인:

```text
OK: no new AlhangeulPreview/AlhangeulThumbnail crash reports since smoke setup.
```

## 작업지시자 시각 검증 방법

1. Finder에서 `/private/tmp/alhangeul-visual-smoke/20260511-045624/samples`를 연다.
2. icon view에서 3개 샘플 thumbnail이 깨진 줄무늬나 generic icon이 아니라 문서 page image로 보이는지 확인한다.
3. 각 파일을 선택하고 Space를 눌러 Quick Look preview가 metadata card가 아니라 문서 preview로 열리는지 확인한다.
4. 직접 강제 provider 경로를 확인하려면 `/private/tmp/alhangeul-visual-smoke/20260511-045624/open-preview.command`를 실행한다.
5. 확인 후 `/private/tmp/alhangeul-visual-smoke/20260511-045624/check-crashes.command`를 실행해 새 extension crash report가 생기지 않았는지 확인한다.

`open-preview.command`는 sample마다 Quick Look 창을 순서대로 연다. 한 preview 창을 닫아야 다음 sample이 열린다.

## 판단

Stage 6 hotfix는 local ad-hoc 설치본 기준으로 Quick Look/Thumbnail provider path, thumbnail 생성, crash 부재를 확인했다. 첨부 영상처럼 단일 페이지를 PNG reply로 유지해도 문서 preview 형태로 표시될 수 있다는 기존 판단도 유지한다. 현재 fallback card처럼 보였던 핵심 원인은 PNG/PDF 정책이 아니라 extension crash였다.

다만 이번 단계는 public signed/notarized respin이 아니다. `v0.1.1` 재배포 전에는 Developer ID signed/notarized DMG를 다시 만들고, Sparkle update 설치 후 active provider가 새 app 내부 `.appex`로 refresh되는지 반복 확인해야 한다.
