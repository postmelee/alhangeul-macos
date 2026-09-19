# Task M020 #565 Stage 3 — Mac 설치 글꼴 최소 연결 실험

- 수행일: 2026-09-20
- 승인: 수정 계획 제시 후 작업지시자의 “진행해줘”로 Stage 3 착수
- 상태: **독립 연결·재실행 실험 통과, signed sandbox 검증 대기**. Stage 4 미착수.
- 기준: [구현계획](../plans/task_m020_565_impl.md)

## 1. 결과

Mac에 활성 설치된 NanumSquareR/Regular와 NanumSquareB/Bold를 native CoreText로 식별하고, 고정 rhwp의 이름 매칭·bytes loader·CanvasKit renderer를 통해 실제 textRun에 적용했다. 같은 renderer의 반복 사용에서는 추가 파일 읽기가 없고, 새 프로세스에서는 저장된 메타데이터를 복원하여 사용자 재감지 없이 필요한 두 파일을 다시 읽었다.

이는 **합성 PageLayerTree 문서의 최소 연결** 증거다. 실제 HWP/HWPX 파싱·Studio 편집 화면·PDF·인쇄·Quick Look·썸네일의 제품 통합 성공이 아니다.

## 2. 산출물과 재현

- `Tests/InstalledFontConnectionProbe/main.swift`: CoreText 활성 목록, 불투명 ID→원본 URL, 필요한 bytes 공급, 원본 PS·크기 검증, 메타데이터 저장, 계측.
- `Tests/InstalledFontConnectionProbe/probe.js`: 기존 upstream 모듈 연결, 실제 renderer 선택 관찰, cold/warm/재실행/동시 요청/실패 대조.
- `Tests/InstalledFontConnectionProbe/package.json`, `package-lock.json`: 독립 빌드 도구 잠금.
- `scripts/probe-installed-font-connection.sh`: 고정 commit·깨끗한 source 확인, macOS 12 대상 Swift 빌드, probe 실행.
- [재현 안내](../../Tests/InstalledFontConnectionProbe/README.md)

제품 Sources, RustBridge, project.yml, rhwp-core.lock, upstream checkout, bundled minified 산출물은 수정하지 않았다. 사용자 글꼴을 설치·삭제·변경하거나 관리 저장소로 복사하지 않았다. 기존 Stage 1–2 구현도 보존했다.

## 3. 증거와 검증

기준: rhwp v0.8.6 / `f1f9c6ae58344ee9368996d3543f76b9345cf227`, CanvasKit 0.42.0, macOS 26.5.2 (25F84). esbuild 0.25.12, @noble/hashes 2.4.0.

| 실행 | PID | 감지 호출 | 첫 렌더 bytes 요청/읽기 | warm 추가 읽기 |
|------|-----|----------|------------------------|----------------|
| cold | 80251 | 1 | 2 face / 2 파일 | 0 |
| 새 프로세스 복원 | 80317 | 0 | 2 face / 2 파일 | 0 |

표의 감지 호출은 upstream `detectLocalFonts`의 실제 열거 호출 수다. native는 프로세스 시작 시 CoreText 목록을 조사하고 요청 시 활성 상태를 다시 확인한다. “재감지 없음”은 사용자 재작업이 없다는 뜻이며 OS 내부 I/O가 없다는 뜻이 아니다. 요청/읽기 수는 실험 adapter와 native Data 읽기의 계측이다.

| 원본 | PS | 크기 | SHA-256 |
|------|----|------|---------|
| NanumSquareRegular.ttf | NanumSquareR | 723,640 bytes | `5a51deae5237435d9a0bc0cc6cc30619a914b29801f895698cfdacadcad06e94` |
| NanumSquareBold.ttf | NanumSquareB | 733,500 bytes | `f737d58294faec9c632189af3a2a3e48e49c03c0256de09db61e879e2857bfbf` |

CoreText 원본 PS와 hash → 기존 resolver의 PS/faceKey → renderer가 실제 선택한 local 객체의 동일성·NanumSquare family를 확인했다. renderer의 private 선택 메서드는 원래 함수에 위임하는 관찰 wrapper만 추가했고 선택 로직은 바꾸지 않았다. CSS `local(PS)`는 두 항목 모두 loaded였지만 이를 CanvasKit 적용 증거로 대신하지 않았다.

- 동일 face 동시 bytes 요청 2개는 face당 1회로 병합: 두 face 총 2회 추가 읽기.
- Regular/Bold를 포함하는 family만 요청하면 null, 없는 이름도 null: 모호한 face 임의 선택 없음.
- 원본 부재/권한 거부 주입 및 native 검증에서 거부한 손상 바이트: local 등록 0, 두 요청 모두 `Noto Sans KR / unregisteredDefault` fallback, 렌더 완료.
- reset 후 정상 원본 재공급: 2 face 복구.
- 메타데이터만 저장하며 원본 bytes는 디스크에 별도 저장하지 않는다.
- Swift macOS 12 대상 warnings-as-errors, shell/JS 구문, 공용 Swift AppKit 경계, diff 검증 통과. macOS 12 실제 실행은 미검증.
- extension registration hygiene: 개발 등록 없음, Issues/Warnings 없음, `/Applications/Alhangeul.app` 정식 provider 유지.

최종 로그: `build.noindex/task565-stage3/final/result-80251.json`, `result-80317.json`. 각 프로세스의 실제 디스크 읽기는 정상 첫 렌더 2회 + 별도 동시 요청 대조 2회 + 복구 2회다. 손상 대조는 메모리 생성 바이트이며 디스크 읽기로 세지 않는다.

![고정 rhwp CanvasKit의 설치 글꼴 Regular/Bold 렌더](../../build.noindex/task565-stage3/final/render-80251.png)

위 그림은 실제 renderer가 생성한 PNG이며 제품 설정 UI가 아니다. 화면을 사용자에게 제공했다.

## 4. 확인한 설계 보완점

1. **감지 시 전체 bytes 공급 방지**: 기존 감지는 `blob()`으로 SFNT 이름을 보강한다. 실험 adapter는 열거에는 메타데이터만 주고 PS를 지정한 실제 bytes 요청에만 blob을 제공한다. 한글/영문 alias 보강은 native descriptor/이름 테이블의 제한된 읽기로 설계해야 한다. 제품에서는 실험용 브라우저 API shim을 그대로 배포하지 않고 native provenance를 명시한 계약을 확정한다.
2. **캐시 무효화**: 원본 부재 상태를 주입해도 이미 준비된 renderer는 local 객체 2개를 유지하고 다시 읽지 않는다. 설치·활성·원본 변경 generation을 소비자에 전달해 `resetDocumentResources` 또는 그에 준하는 무효화/재준비를 연결해야 한다. 설정 목록 새로고침만으로 해결되지 않는다.
3. **손상 판정**: 12-byte 손상 데이터를 검증 없이 공급하면 Typeface는 없지만 family 이름이 빈 FontMgr(1 family)가 생성되어 2건 등록으로 계산됐다. native PS 검증에서 거부하면 정상 fallback이 된다. 임의 형식·TTC·축까지 안전하다는 증거는 아니며 제품 검증과 renderer 준비 상태 확인이 모두 필요하다.
4. **원본·버전 식별**: 동일 PS에 다른 fullName/version을 넣은 합성 메타데이터 3건은 upstream 정규화에서 2건으로 줄었다. 실제 두 버전 글꼴 설치 실험은 아니다. native catalog는 PS 외에 resource identity/변경 정보/face/축을 보존하고, 충돌을 해결한 공급 목록만 resolver에 전달해야 한다.
5. **문서 이름·스타일 경계**: 이번 정상 textRun은 face별 PS 이름을 요청한다. family 이름만 기록된 문서에서 bold 속성으로 정확한 face를 선택하는 제품 경로까지 증명한 것은 아니다. 기존 resolver는 다중 face family 단독 요청을 null로 처리하므로 #567 에서 문서 family+style 연결을 별도 검증한다.
6. **실험 권한 경계**: `/Library/Fonts`의 활성 2종만 실제 읽었다. 사용자 Fonts, 외부 폴더, stale bookmark, 실제 비활성화/이동, 앱 확장 권한은 미검증이다. 사용자가 요청하지 않은 글꼴 설치/삭제로 대조하지 않았다.

## 5. 남은 검증과 승인 경계

App Sandbox entitlement만 가진 probe를 로컬 Developer ID 인증서로 서명하려 했으나 `codesign`이 대기 중이다. 일반 ad-hoc 실행 성공을 signed sandbox 성공으로 보고하지 않는다. 키체인 창 확인을 시도했으나 Computer Use가 SecurityAgent 접근을 제한했으므로 사용자에게 직접 확인·승인을 요청했다. 인증 정보 입력·보안 설정 변경·우회는 하지 않았다.

서명 완료 후 sandbox cold/재실행과 `/Library/Fonts` 접근을 확인하고 이 보고서에 결과를 반영한다. 서명된 실험 앱은 현재 서명 착수 시점의 probe이며, 이후 추가한 중복 메타데이터 대조·계측 변경까지 동일하게 검증하려면 최종 소스로 다시 빌드/서명한다. Stage 3을 완료로 선언하거나 Stage 4를 시작하지 않는다.

Stage 4에는 활성 catalog·메타데이터·설정·권한 지속·generation을, #567 에는 정식 Studio adapter와 열린 문서 캐시 무효화를, #568 에는 소비자별 원본 접근·실제 선택·출력 검증을 인계한다. 배포나 이슈 close는 수행하지 않았다.
