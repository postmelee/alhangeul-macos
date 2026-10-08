# Task M020 #568 — Stage 4 공통 native 글꼴 공급 수용

- 이슈: [#568](https://github.com/postmelee/alhangeul-macos/issues/568), 부모 #562, M020/v0.2.
- 작업: `local/task568`, core/Studio v0.8.7 / `1a76570e833917d15817415a53c09ad61ab3203f` 유지.
- 승인: “Stage 4 진행해줘”, 새 C ABI/Swift wrapper/header/symbol 확장 승인 및 이후 “진행해줘”.
- 상태: Stage 4 완료. **Quick Look/Thumbnail 프로세스 연결·signed Finder 수용은 Stage 5이며 미완료**다. PR/push/배포와 upstream 공개 기여는 수행하지 않았다.

## 1. 결과와 소유 경계

설치 참조·관리 복사본의 실제 공급 snapshot과 공식 Studio 선택을 공통 native 렌더 진입점에 연결했다. 선택된 static SFNT의 PS/hash/style을 확인하고 CoreGraphics/Skia에 동일한 원본 bytes를 전달한다. 관리 우선·동명 모호성/미해결 충돌 차단·필요 face 읽기·lease/취소·원본/세대/문서 변화·cache identity를 검증했다.

HostApp의 주 viewer는 계속 Studio다. `StudioFontSupply.renderNativePage`와 Shared의 `HwpNativeFontPageRenderer`는 native 소비자용 진입점이며 이번에 별도 native viewer UI를 추가하지 않았다. 현재 확장은 기존 호출을 사용한다. App Group에 파일이 있거나 HostApp이 읽을 수 있다는 이유로 확장의 실제 접근 성공을 선언하지 않는다.

| 계층 | 변경 |
|------|------|
| RustBridge | 기존 bytes 렌더 ABI에 더해 원본 페이지의 slot/family/style 조회 ABI. public core의 언어 분류·portable glyph API를 사용하며 upstream source를 수정하지 않음 |
| RhwpCoreBridge | 요청 JSON 수명 관리, 작업별 immutable bytes context·CoreText/Skia 적용과 정확한 성공 진단. AppKit/UIKit 없음 |
| Shared | 공급 DTO/budget, 공식 matcher의 작업별 JavaScriptCore realm, 문서 copy·선택·필요 bytes·종료를 묶는 native 요청 |
| HostApp | 기존 설치/관리 service의 공급을 native 요청에 연결. metadata snapshot을 사용하며 권한/URL/bookmark를 JS에 노출하지 않음 |
| 생성 자산/CI | Studio 원본 8개 module과 기존 catalog 정책을 esbuild 0.25.12로 생성. core/source/adapter/output receipt를 CI에서 검사 |

## 2. 선택·수명·캐시

`rhwp_page_font_requests_json`은 원본 TextRun의 charShape/language/family/bold/italic만 반환한다. 요청 2,048·JSON 1 MiB 한도를 적용하고 실패 시 NULL, 성공 JSON은 `rhwp_free_string`으로 해제한다. Swift에서 언어 분류나 이름/스타일 matcher를 복제하지 않는다. 잘못된 handle/output/page와 원본 slot·혼합 언어/Bold 요청을 Rust 시험으로 확인했다.

family는 실제 원본 문서 slot의 binding이고, 선택된 face는 실제 PS/SHA/style로 검증한다. 문서 이름을 재명명하지 않는다. 공식 matcher가 PS/full-name exact로 고른 face와 문서 Bold/Italic이 다르면 스타일을 억지로 바꾸지 않고 거부한다. 관리 우선·유일 설치 후보를 적용하며 disabled/모호성/미해결 충돌/판독 실패를 기본 OS 이름 조회로 조용히 우회하지 않는다. catalog에 없는 family는 기존 fallback 경로에 남긴다.

job은 문서 bytes copy와 snapshot lease를 소유한다. 선택된 고유 face를 공유 2-slot budget 안에서 읽고 inspector·실제 hash·PS/style을 확인한다. 읽기 전후 및 렌더 전후에 설치/관리 generation과 문서 current를 검사한다. 취소한 read가 실제로 반환하기 전에 slot/lease를 풀지 않으며 성공·실패에서 release를 한 번 실행한다. 파일 64 MiB·작업 사용자 source bytes 128 MiB·face 64·request 2,048 제한을 유지하고 읽기 전에 최대 file slot을 예약한다. 이것은 inspector/Skia/CoreText/전송 복제까지 포함한 프로세스 peak RSS 보장이 아니다.

기존 `acquireSnapshot`은 모든 선택 object의 해시를 판독했다. catalog 공급에 `acquireMetadataSnapshot`을 추가해 metadata/lease만 획득하고, 실제로 쓰는 `readResource`에서 object 길이/hash를 검증한다. 기존 전체 검증 API와 시작 recovery는 그대로 유지한다. 없는/변조된 원본을 metadata 열거 성공만으로 사용할 수 없으며 snapshot의 GC 보호도 동일하다. 실제로 쓰지 않는 관리 Bold object를 제거한 뒤 Regular 문서는 성공하고, 필요한 Regular object가 없으면 실패하는 시험을 통과했다.

cache identity에는 문서 hash/filename/page, core/matcher 버전, renderer/크기, 공급 snapshot, 선택 face ID/SHA/PS/slot 및 fallback 목록을 포함한다. 공통 job은 영구 bytes/PNG cache를 만들지 않는다. 사용자 glyph는 작업별 portable resource/CTFont context를 사용한다. 기존 thumbnail cache와 Finder의 cache/변경 통지는 Stage 5에서 이 identity와 연결해야 한다. 이번 key/새 렌더 수용을 Finder cache-hit 수용으로 표현하지 않는다.

## 3. 실제 원본과 시험 구분

| 입력/조건 | 증거 |
|-----------|------|
| 관리 고운바탕 R/B | 격리 FontLibraryService의 실제 import/select/acquire/read/release를 사용. HWP/HWPX × CG/Skia에서 필요한 두 face만 공급, 합계 16,612,008 bytes |
| 활성 ArialUnicodeMS | 현재 Mac의 실제 활성 원본 23,278,008 bytes를 읽기만 수행. 한글 두 글자의 CG/Skia 렌더, 정확한 PS·선택 source 검증. 설치/수정/삭제하지 않음 |
| 고운바탕 설치 경로 | 프로세스 한정 CoreText 등록 fixture로 실제 InstalledFontSystem의 열거/활성·stamp·읽기를 검사. 영구 사용자 설치는 아니며 종료 시 해제. renderer는 계속 exact bytes context를 사용 |
| 같은 PS 원본 교체 | 별도 private 검증 파일의 ‘한’ glyph를 가로 변형하고 version을 바꿈. 실제 관리 충돌 선택을 전환하면 두 backend 이미지와 cache identity가 바뀌고 원본 선택으로 돌아가면 Skia 이미지도 복원 |
| 동명/미해결 충돌 | 기존 관리 active 선택은 새 동명 원본을 추가해도 보존. 모호한 설치/미해결 관리 DTO는 주입 시험으로 native 진입점에서 판독 전 거부 |
| stale/취소 | 실제 관리 read 결과를 gate에서 대기시킨 뒤 세대 변경/취소. 이는 실제 물리 disk read 중단 시험이 아니다. 반환되지 않은 I/O를 소비자가 기다리는 수명·2-slot budget·release 한 번·늦은 결과 폐기 수용 |
| 원본 상실·한도·문서 변경 | 격리 관리 object 제거 실패, 크기 제한, document-current 주입 및 읽기 전/후 세대 변경 거부. 사용자 원본은 건드리지 않음 |

현재 사용자 설치 목록에 고운바탕/나눔스퀘어는 없었다. 따라서 이전 세션의 활성 원본과 이번 process fixture를 동일한 사용자 설치 상태로 표현하지 않는다. AppleMyungjo/AppleGothic은 OS에서 활성이나 기존 inspector가 `malformedStructure`로 거부했다. 이번 단계에서 해당 구조 지원/오류 분류를 확대하지 않았으며 모든 macOS static 글꼴을 지원한다고 선언하지 않는다.

원본 고운바탕은 #567의 승인된 OFL 입력을 재사용했다. 변형 TTF·OS 원본·생성 문서·binary는 커밋하지 않는다. [수용 결과](assets/task_m020_568_stage4/supply-result.json)·[receipt](assets/task_m020_568_stage4/supply-receipt.json)에 원본/소스/산출물 hash와 실제/주입 시험을 구분했다. [관리 Skia](assets/task_m020_568_stage4/supply-managed-hwpx-skiaOptIn.png)·[관리 CG](assets/task_m020_568_stage4/supply-managed-hwpx-coreGraphicsOnly.png)·[실제 설치 Skia](assets/task_m020_568_stage4/supply-real-installed-skiaOptIn.png)도 보존했다.

## 4. 검증과 정리

- Rust: **29개 통과**. 기존 ABI/renderer 및 Stage 4.1 원본/스타일/한도/실패 검사에 원본 요청 조회 수용 2개 추가.
- FontLibraryTests: **127개 통과**. 공식 matcher 3개와 metadata snapshot의 판독 지연·기존 전체 검증·lease/GC 보호 2개 추가. 기존 설치/관리·Studio/PDF 수명/권한 회귀 포함.
- CLI 수용: `scripts/probe-native-font-supply.py`, `build.noindex/task568/stage4/supply-complete/result.json`, 실제 service+공통 renderer 통과.
- arm64/x86_64 Rust build·header/symbol·portable 및 동일 환경 strict reference 검사 통과. 새 ABI 산출물에 따라 명시적 lock 갱신을 수행했으며 upstream release/commit은 바꾸지 않음.
- HostApp 및 확장 unsigned Debug compile/link 통과. `project.yml`에서 Xcode project를 재생성.
- source/matcher receipt·Studio 자산·build info·no-AppKit·render tree decode 24개 variant·workflow/helper 문법 검사 통과. Stage 4.1의 기본 render smoke/golden 결과는 이후 기본 렌더 변경 없이 재사용.

검증 환경은 arm64/macOS 26.5.2이며 Swift/macOS 12 target compile과 Intel Rust archive를 확인했다. 실제 macOS 12/Intel 실행·signed sandbox/Finder·물리 인쇄·전체 typography/복합 스크립트·프로세스 최고 메모리는 이번 수용이 아니다. 제한된 native glyph replay는 기존 producer 위치의 **PositionAdjusted** 적용이며 선택 글꼴로 pagination/kerning을 전부 재계산했다는 뜻이 아니다.

Xcode가 Debug 앱과 nested Updater를 자동 등록해 이번 소유 절대 경로만 해제했다. 강제 scan의 -10814는 성공으로 기록하지 않고 `-u` 및 등록 dump로 잔여 경로를 확인했다. 생성 앱/appex·중복 시험 binary/module cache/저장소를 제거했고, 최종 hygiene에서 설치 provider는 `/Applications/Alhangeul.app`, 개발 등록/앱/issue/warning은 0이다. [정리 기록](assets/task_m020_568_stage4/supply-generated-cleanup.json)에 삭제 범위를 남겼으며 기존 체험 앱/사용자 파일은 보존했다.

## 5. 다음 단계와 upstream 후보

Stage 5에서 Quick Look·Thumbnail의 프로세스별 공급/권한 및 thumbnail/Finder cache를 연결한다. 기존 설치본 보존/복원과 소유 등록 해제까지 포함한 구체 signed smoke를 준비해 별도 승인받은 뒤 실행한다. 이 결과 없이 확장 지원이나 #568 전체 완료로 표시하지 않는다.

upstream에는 exact host-selected static bytes를 portable native glyph resource/replay로 연결하는 범용 helper와 그 검증이 의미 있는 후보다. 기존 공개 API로 우리 연결을 구현했으므로 추가 upstream 수정이 구현의 필수 전제였다고 주장하지 않는다. C ABI·Swift/CoreText·보관함/bookmark/App Group 정책은 앱 소유다. 폴더 custom-font의 family당 한 face 문제는 독립 runtime 재현이 남아 있으며, 구현/수용을 취합한 뒤 도움이 되는 범위만 기여한다.
