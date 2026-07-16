# Task M020 #406 Stage 1 완료보고서

## 단계 목적

HOP source가 선언하는 HWP/HWPX UTI 계약을 revision과 함께 고정하고, 알한글의 HostApp, Quick Look preview, Finder thumbnail, 앱 내부 열기 패널에서 두 HOP UTI가 누락된 상태를 재확인한다.

정적 source 조사로 확정할 수 있는 호환성 누락과 HOP 설치본 또는 사용자 파일이 있어야 확인할 수 있는 LaunchServices 재현 항목을 분리한다.

## 산출물

| 파일 | 변경 | 요약 |
|------|------|------|
| `mydocs/working/task_m020_406_stage1.md` | 신규 | HOP UTI 계약, 알한글 누락 matrix, 재현 한계와 Stage 2 입력 기록 |
| `mydocs/orders/20260711.md` | 수정 | #406 상태를 `Stage 1 완료보고서 승인 대기`로 갱신 |

제품 source는 변경하지 않았다. 조사용 HOP checkout은 저장소 밖의 `/private/tmp/hop-uti-analysis`에만 준비했으며 알한글 커밋 대상에 포함하지 않는다.

## 조사 결과

### HOP source 기준

- 저장소: `golbin/hop`
- 확인 revision: `bbd6bf69db05f275d714e7c61cef58b662809c6a`
- commit date: `2026-05-27T18:45:41+09:00`
- commit subject: `chore(release): bump version to v0.3.1`
- 설정 파일: `apps/desktop/src-tauri/tauri.conf.json`
- Quick Look preview: `apps/desktop/quicklook/Resources/Preview/Info.plist`
- Finder thumbnail: `apps/desktop/quicklook/Resources/Thumbnail/Info.plist`

HOP의 file association 계약은 다음과 같다.

| 형식 | Identifier | Extension | MIME type | Conforms to | Role / Rank |
|------|------------|-----------|-----------|-------------|-------------|
| HWP | `net.golbin.hop.hwp` | `hwp` | `application/x-hwp` | `public.data` | `Editor` / `Owner` |
| HWPX | `net.golbin.hop.hwpx` | `hwpx` | `application/vnd.hancom.hwpx` | `public.data`, `public.zip-archive` | `Editor` / `Owner` |

HOP의 `contentTypes`에는 custom UTI와 함께 Hancom 및 Hancom Office Viewer UTI가 들어 있다. HOP Quick Look preview와 thumbnail의 `QLSupportedContentTypes`에도 `net.golbin.hop.hwp`, `net.golbin.hop.hwpx`가 모두 포함된다. 따라서 두 identifier는 HOP 앱에서만 임시로 쓰는 문자열이 아니라 앱 연결과 Finder extension routing을 함께 구성하는 공개 macOS 타입 계약이다.

### 알한글 지원 표면 matrix

| 지원 표면 | 현재 HWP/HWPX 계열 | HOP HWP | HOP HWPX | 판단 |
|----------|---------------------|---------|----------|------|
| HostApp `CFBundleDocumentTypes > LSItemContentTypes` | 알한글, Hancom, Hancom Office Viewer, LibreOffice HWP | 없음 | 없음 | 두 UTI 추가 필요 |
| HostApp `UTImportedTypeDeclarations` | Hancom, Hancom Office Viewer, LibreOffice HWP | 없음 | 없음 | HOP 계약과 일치하는 imported declaration 필요 |
| Quick Look `QLSupportedContentTypes` | 알한글, Hancom, Hancom Office Viewer, LibreOffice HWP | 없음 | 없음 | 두 UTI 추가 필요 |
| Thumbnail `QLSupportedContentTypes` | 알한글, Hancom, Hancom Office Viewer, LibreOffice HWP | 없음 | 없음 | 두 UTI 추가 필요 |
| `DocumentOpenPanel.supportedContentTypes` | 알한글, Hancom, Hancom Office Viewer와 `.data` fallback | 없음 | 없음 | 목록 일관성을 위해 두 UTI 추가 필요 |

알한글 HostApp의 기존 역할은 `Viewer`, handler rank는 `Alternate`다. Stage 2에서는 이 정책을 유지하고 HOP UTI만 외부 호환 타입으로 추가한다.

## 본문 변경 정도 / 본문 무손실 여부

- 제품 source 및 기존 매뉴얼 본문 변경 없음
- 기존 수행계획서와 구현계획서 변경 없음
- 오늘할일은 #406 비고 한 칸만 단계 상태에 맞게 갱신
- HOP source는 read-only 조사 대상으로 사용했으며 수정 없음
- 사용자 문서 또는 sample 파일 변경 없음

따라서 Stage 1은 제품 동작에 영향을 주지 않는 조사·기록 단계이며 기존 본문과 source는 무손실이다.

## 검증 결과

### HOP revision

```text
$ git -C /private/tmp/hop-uti-analysis rev-parse HEAD
bbd6bf69db05f275d714e7c61cef58b662809c6a
```

### HOP UTI 계약

```text
tauri.conf.json: HWP mimeType = application/x-hwp
tauri.conf.json: HWP contentTypes includes net.golbin.hop.hwp
tauri.conf.json: HWP exportedType conformsTo = public.data
tauri.conf.json: HWPX mimeType = application/vnd.hancom.hwpx
tauri.conf.json: HWPX contentTypes includes net.golbin.hop.hwpx
tauri.conf.json: HWPX exportedType conformsTo = public.data, public.zip-archive
Preview/Info.plist: QLSupportedContentTypes includes both HOP UTIs
Thumbnail/Info.plist: QLSupportedContentTypes includes both HOP UTIs
```

두 extension plist의 문법 검사도 통과했다.

```text
$ plutil -lint apps/desktop/quicklook/Resources/Preview/Info.plist apps/desktop/quicklook/Resources/Thumbnail/Info.plist
Preview/Info.plist: OK
Thumbnail/Info.plist: OK
```

### 알한글 누락 확인

```text
Sources/HostApp/Info.plist: LSItemContentTypes와 UTImportedTypeDeclarations는 존재하지만 net.golbin.hop 항목 없음
Sources/QLExtension/Info.plist: QLSupportedContentTypes는 존재하지만 net.golbin.hop 항목 없음
Sources/ThumbnailExtension/Info.plist: QLSupportedContentTypes는 존재하지만 net.golbin.hop 항목 없음
Sources/HostApp/Services/DocumentOpenPanel.swift: supportedContentTypes는 존재하지만 net.golbin.hop 항목 없음
```

### 설치본 확인

```text
$ find /Applications /Users/melee/Applications -maxdepth 2 -iname '*hop*.app' -print
(출력 없음)
```

로컬 HOP 설치본이 없어 bundle과 실제 LaunchServices 선택 결과는 확인하지 않았다. source 계약과 알한글 누락은 설치본 없이 확정 가능하다.

### 문서 검증

```text
$ git diff --check -- mydocs/working/task_m020_406_stage1.md mydocs/orders/20260711.md
(출력 없음, 통과)
```

## 잔여 위험

- 사용자 제보 파일의 `mdls` 결과가 없어 해당 파일이 실제로 `net.golbin.hop.hwp` 또는 `net.golbin.hop.hwpx`로 분류됐는지는 확정할 수 없다.
- 로컬 HOP 설치본이 없어 HOP `Owner` handler와 알한글 `Alternate` handler가 함께 등록된 실제 Finder 후보 목록은 Stage 1에서 재현하지 못했다.
- LaunchServices 후보 표시는 설치 위치, 최초 실행, 등록 캐시, 기존 기본 앱 상태에도 영향을 받는다. Stage 2 정적 선언 추가만으로 사용자 환경의 모든 원인을 해결한다고 단정하지 않는다.
- HOP source가 향후 UTI 계약을 변경하면 imported declaration을 다시 대조해야 한다. 이번 기준 revision을 최종 보고서에도 남겨야 한다.

## 다음 단계 영향

Stage 2에서는 확인한 HOP 계약을 그대로 사용한다.

- HostApp `LSItemContentTypes`: 두 HOP UTI 추가
- HostApp `UTImportedTypeDeclarations`: HWP/HWPX imported type 두 개 추가
- Quick Look/Thumbnail `QLSupportedContentTypes`: 두 HOP UTI 추가
- `DocumentOpenPanel.supportedContentTypes`: 두 HOP UTI 추가
- 기존 `Viewer` / `Alternate`, 기존 UTI, `.data` fallback 유지
- parser, renderer, `project.yml`, generated Xcode project 변경 없음

Stage 2의 필수 gate는 plist lint, UTI 값 확인, Swift compile/HostApp Debug build다. 실제 Finder 후보와 HOP 공존 `mdls` 재현은 Stage 3의 설치본 검증으로 분리한다.

## 승인 요청

Stage 1 조사 결과와 누락 matrix 검토를 요청한다. 승인 후 Stage 2 `HOP HWP/HWPX UTI 호환 선언 구현`으로 진행한다.
