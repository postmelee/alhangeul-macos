# Task M020 #563 Stage 2 완료보고서

- 일자: 2026-09-17
- 단계: 독립 보관·중복·이름 매칭·공급 경계 설계
- 승인 근거: Stage 1 보고 후 작업지시자의 “진행해줘”
- 마일스톤: M020 / 글꼴 마이그레이션 / v0.2 계열
- 브랜치: `local/task563`
- 산출물: [설계 문서 9~15절](../tech/font_migration_design.md#9-stage-2-결정--독립-저장과-소유-경계)
- 상태: Stage 2 설계 완료, Stage 3 승인 대기

## 1. 결정 사항

1. **원본 참조 대신 독립 복사**: 한컴 앱과 무관한 App Group 기반 관리 저장소를 우선안으로 정했다. 원본 bookmark는 재가져오기 보조이며 렌더링의 필수 의존성이 아니다.
2. **불변 파일과 목록의 분리**: hash 기반 객체를 먼저 준비하고 manifest를 마지막에 교체한다. 취소·중단·디스크 오류가 기존 목록을 손상시키지 않도록 계약을 정의했다.
3. **동명이인 충돌 보존**: 동일 bytes는 중복 제거하고, 같은 이름의 다른 bytes는 기존 선택을 유지한 채 사용자 선택 대상으로 둔다. regular/bold와 collection face는 별도 식별한다.
4. **실제 이름과 공급 이름 분리**: 다국어 이름 레코드를 보존하고 정확한 face를 해석한 뒤 CSS alias로 공급한다. 내부 alias가 HWP/HWPX 저장 이름으로 유출되지 않도록 후속 검증을 요구한다.
5. **출력 snapshot**: 한 번의 렌더링은 같은 글꼴 집합을 사용한다. 사용 중 객체는 lease로 보존하고 삭제는 논리적 비활성화 후 안전하게 정리한다.
6. **소비자별 공급**: Studio CSS·CanvasKit, 전용 PDF, CoreGraphics, Skia를 각각 연결한다. 글꼴 목록에 나타난다는 이유로 모든 경로를 지원했다고 판단하지 않는다.

## 2. 코드 대조로 확인한 변경 지점

| 현재 근거 | 설계에 반영한 내용 |
|-----------|------------------|
| `RhwpStudioPDFFontProvider.swift`의 Noto WOFF2 allowlist·용량 제한 | 사용자 글꼴 전용 snapshot provider와 좁은 리소스 경계 필요 |
| `project_architecture.md`의 PDF Hangul Noto 보정 | 원본 face 선택과 Noto fallback을 구분하고 Unicode 회귀를 검사 |
| bundled Studio의 Local Font Access 기반 SFNT 조회 | native 공급 adapter 필요; CSS만 추가하면 CanvasKit 공급까지 해결되지 않음 |
| `RustBridge/src/lib.rs`의 `PngExportOptions.font_paths: Vec::new()` | Skia에 실제 관리 글꼴을 전달할 FFI/선택 계약 필요 |
| `HwpThumbnailRenderCache.swift`의 캐시 키 | snapshot digest·해석 정책 변경을 캐시에 반영; Finder 외부 캐시는 별도 수용 검증 |
| 현재 HostApp/확장의 App Group 미설정 | group identifier·서명·최소 OS에서의 실제 접근 검증을 제품 구현에 인계 |

처음 확인한 `Frameworks/generated_rhwp.h`와 `Sources/Shared/HwpThumbnailRenderCache.swift`는 현 checkout에 없었다. 생성 헤더를 근거로 삼지 않고 RustBridge 소스와 실제 `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`를 확인했다. 현재 code pin이나 산출물은 변경하지 않았다.

## 3. 설계 시나리오 검토

아래는 문서와 코드 경계의 **설계 검토**이며 실행 테스트가 아니다.

| 시나리오 | 설계 대응 |
|----------|-----------|
| 한컴 삭제·원본 이동 | 관리 객체만 참조; 원본 bookmark 유무와 무관한 렌더링 |
| 동일 글꼴 반복 가져오기 | hash 중복 제거, 필요하면 출처 영수증만 추가 |
| 같은 이름의 다른 버전 | 자동 교체 금지, 기존 선택 유지 및 충돌 선택 |
| 복사 중 종료·공간 부족 | staging과 object 게시를 분리, manifest 성공 전 추가됨 표시 금지 |
| 출력 중 사용자가 삭제 | 진행 중 snapshot/lease 보존, 다음 출력부터 새 generation |
| 렌더 프로세스 비정상 종료 | 불확실한 lease는 보존; 종료 확인과 stale lease 회수는 #564 이슈에서 검증 |
| 시스템·내장 글꼴이 대신 표시됨 | 내부 CSS alias·선택 face/resource 증거와 음성 대조군 |
| PDF 임베딩 조건 불충족 | 자동 임베딩하지 않으며 취소/대체 출력 정책을 명시 |
| TTC와 variable 혼동 | sfnt face와 axes/named instance를 별도로 식별 |
| ZIP 경로 이탈·압축 해제 폭증 | 경로·symlink 검사와 실제 출력량 제한, 실패 staging 정리 |

64 MiB/파일 등 제안된 한도는 Stage 1 실측 크기를 수용할 초기 후보다. 제품 확정값이나 성능 검증 결과가 아니다.

## 4. Stage 3 실험 확정

- 로컬 OFL TTF/OTF의 원본 hash와 고지를 보존하고, Reserved Font Name을 쓰지 않는 별도 내부 이름의 파생 자산을 준비한다.
- 파일명 변경만으로 격리했다고 간주하지 않는다. host 권한에서 파생 PS/family가 시스템 목록에 없는지 확인한다.
- A 정상 공급 / B 원본 위치 분리 후 새 프로세스 / C 관리 객체도 없는 새 프로세스를 비교한다.
- resource hash·선택 face·화면 증거·PDF 글꼴 리소스·한글 추출을 함께 검사한다.
- OFL TTF 두 face로 TTC를 구성하는 실험과 공식 release 가변 글꼴 확보는 확장 검증으로 둔다. 미확보·실패를 성공으로 대체하지 않는다.
- 실험은 `scripts/probe-font-migration.sh`, `scripts/font_migration_probe.swift` 범위에서 작성하고 출력은 `build.noindex/task563-font-migration/`에 둔다.
- 이번 단계에서는 실험 코드·복사본·앱·PDF를 생성하지 않았다.

## 5. 검증 및 변경 범위

- 설계 문서의 저장·복구·수명, 이름 매칭·충돌, renderer 연결, 입력 제한과 실험표를 검토했다.
- Apple App Group/WKURLSchemeHandler 및 OpenType name 규격을 참조했다. 웹 도구가 Apple 본문 Markdown을 해석하지 못한 항목은 기존 Stage 1 근거와 현재 API 사용 코드를 함께 참고했으며 새 실행 보장으로 주장하지 않는다.
- `git diff --check`, GitHub 참조 표기, 로컬 문서 링크와 기대 변경 파일 범위를 검증한다.
- 제품 코드·entitlement·core pin·설치 글꼴·한컴 앱은 변경하지 않는다. 제품 빌드·렌더 테스트를 수행했다고 기록하지 않는다.

## 6. 잔여 조건과 승인 요청

App Group 식별자·서명·macOS 12, 실제 sandbox 접근, CoreText 동명 등록 충돌, Skia 공급 우선순위, TTC/variable의 renderer별 지원, 한컴 글꼴 사용 조건은 제품 구현의 수용 조건이다.

Stage 3의 독립 bytes 공급·재실행·원본 부재 실험을 진행하도록 승인을 요청한다. 실행 결과가 설계 가설과 다르면 같은 단계에서 보정하고 기록한다.
