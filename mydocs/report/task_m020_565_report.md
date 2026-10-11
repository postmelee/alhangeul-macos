# Task M020 #565 최종 결과보고서 — Mac 설치 글꼴 자동 사용 기반

## 작업 결과

- 이슈: [#565](https://github.com/postmelee/alhangeul-macos/issues/565), 상위 #562
- M020 / v0.2 계열, `local/task565` → `publish/task565` → `devel`
- 승인: Stage 6 완료 보고 후 작업지시자의 “진행해줘”로 최종 보고 및 PR 게시 승인

Mac의 활성 설치 글꼴을 감지하고 설정·메타데이터·필요한 읽기 권한을 지속하는 기반을 구현했다. 앱 시작 시 목록을 재검사하고 필요한 bytes만 읽는다. 기본 흐름에서는 전체 글꼴을 복사하지 않는다. 설정에는 검색, family별 스타일 묶음, 행 전체 펼치기/접기, 제한 안내 및 원본 폴더 접근 복구를 제공한다.

**이번 완료는 설치 글꼴 기반과 설정 UI에 한정한다.** 체크한 설정이 제품 Studio·PDF·인쇄·Quick Look·썸네일에 적용되는 연결은 후속 #567 / #568 범위다. UI에도 문서 적용 준비 중을 표시한다. 한컴 삭제로 글꼴 원본까지 없어지면 계속 사용할 수 있다고 보장하지 않는다.

## 구현과 단계

| 단계 | 결과 |
|------|------|
| [Stage 1](../working/task_m020_565_stage1.md) | 제한된 Mac 후보 탐색 및 선택 원본 scope 수명 |
| [Stage 2](../working/task_m020_565_stage2.md) | 기존 복사 기반 가져오기·보관함 UI |
| [Stage 3](../working/task_m020_565_stage3.md) | 고정 rhwp에서 설치 face 매칭·CanvasKit 적용 최소 실험 |
| [Stage 4](../working/task_m020_565_stage4.md) | 활성 catalog, 설정·bookmark 지속, 필요 bytes 검증, generation 무효화 |
| [Stage 5](../working/task_m020_565_stage5.md) | 설치 글꼴 중심 UI·소비자 DTO 및 사용자 피드백 반영 |
| [Stage 6](../working/task_m020_565_stage6.md) | 최종 회귀·signed sandbox 재실행·소비자 인계 |

기존 한컴 앱/폴더 복사 흐름은 별도 보관함으로 유지했다. 기본 자동 사용은 OS 활성 목록을 기준으로 하며 한컴 앱 내부 추출을 필수로 하지 않는다. Windows ZIP 입력은 #566 범위다.

핵심 구현은 `Sources/HostApp/Services/InstalledFont*.swift`, `Views/InstalledFontSettings*.swift`다. 동명 PS의 다른 원본 충돌, 원본 교체/비활성, 손상·크기·형식 제한을 처리한다. 읽기는 현재 generation과 활성 상태를 확인하며 완료 bytes를 영구 캐시하지 않는다. 소비자 DTO는 원본 URL/bookmark/stat를 노출하지 않는다. 프로젝트 구성은 `project.yml`에서 생성했다.

## 검증 증거

| 검증 | 결과 |
|------|------|
| 글꼴/설정 XCTest | 리뷰 수정 후 91개 통과 |
| 개인정보 설정·Studio 세션 XCTest | 42개 통과 |
| 실제 SwiftUI/Studio 문서 수명주기 | 39항목 통과 |
| 최종 HostApp Debug 빌드 | 통과 |
| macOS 12 대상 probe 컴파일 | warnings-as-errors 및 서명 검증 통과 |
| sandbox 재실행 | PID 30035 → 35867, 설정 복원·bookmark 1개 읽기 성공, 권한 오류/누락 0 |
| 실제 글꼴 공급 | NanumSquare Regular/Bold의 bytes·SHA-256·faceIndex가 두 프로세스에서 일치 |
| 개발 앱 등록 정리 | Issues/Warnings 없음, 정식 설치본 유지 |
| main/source 콘텐츠 검사 | 통과, main 병합에 의한 추가 콘텐츠 없음 |

로그는 `build.noindex/task565-stage6/`에 있다. 실제 자체 fixture 교체 거부, 늦은 요청 무효화, stale/resolve 실패, 설정 저장 실패 및 선택 취소는 테스트로 확인했다. 최초 접근 거부→사용자 선택→권한 저장은 Stage 4 증거이며 Stage 6에서 재선택 없는 복원을 재검증했다.

## 직접 확인

- `scripts/probe-installed-font-ui.sh`: 가상 family 28개 / 스타일 84개, 정상·긴 이름·권한·충돌·미지원 상태를 조작한다.
- `scripts/probe-installed-font-ui.sh --live`: 실제 Mac 목록을 격리 설정 저장소로 조회한다.
- 실제 화면은 `build.noindex/task565-stage5/screenshots/row-click.jpeg`, `spacing.jpeg`, `refined-search.jpeg`에 있다. 화면 파일은 로컬 증거이며 재현 명령은 [probe 안내](../../Tests/InstalledFontUIProbe/README.md)에 있다.

## 후속 책임과 한계

[소비자별 계약](../tech/font_library_integration.md)에 연결 표와 수용 시나리오를 기록했다.

- #567: 신뢰한 native 메시지 경계·기존 이름/스타일 매칭·렌더러 캐시 무효화.
- #568: 화면/출력의 동일 face 선택, extension별 외부 원본 접근 권한.
- #569: 실제 문서와 출력별 수용, 설치 원본과 독립 복사본을 구분하는 웹 안내.

실제 실행 OS는 macOS 26.5.2다. macOS 12 실제 실행, 실제 한컴 편집기 설치본, 폴더/볼륨 이동 후 OS 권한 복구 및 영구 설치/비활성 UI 조작은 미검증이다. TTC/가변 소비자 적용을 지원 완료로 표시하지 않는다. OS 설치·fsType·사용자 체크는 외부 사용 라이선스 허가의 증명이 아니다.

PR 게시 후 리뷰·CI 확인이 남는다. merge·이슈 close·배포는 이번 승인 범위에서 수행하지 않는다.

## PR 리뷰 반영 — 과거 글꼴 기록 누적 방지

작업지시자의 수정 승인으로 성공한 스캔에서 사라진 원본 기록을 정리하도록 변경했다. 20,000개 과거 기록 뒤 현재 1개만 남는 경우의 공급·저장·재실행과, 실제 20,001개 한도 초과 뒤 정상 목록으로 복구하는 경우를 회귀 테스트로 추가했다. 삭제된 ID 거부와 generation 무효화도 유지한다. 전체 글꼴 테스트 91개와 공용 Swift 의존 검사를 통과했다. 로그: `build.noindex/task565-review-fix/font-tests.log`.
