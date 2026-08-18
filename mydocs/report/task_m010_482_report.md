# Task #482 최종 결과보고서

## 작업 요약

- 이슈: [#482 평문 HWP3 저장 시 무경고 HWP5 원본 덮어쓰기를 차단한다](https://github.com/postmelee/alhangeul-macos/issues/482)
- 마일스톤: v0.1 (`M010`)
- 대상 통합 브랜치: `devel`
- 작업 브랜치: `local/task482` → 게시 브랜치 `publish/task482`
- 기준 `origin/devel`: `ab49ba3fb96f779b648a0f010d9044a542dc2ec3`
- 단계 수: 3

평문 HWP3에서 일반 저장을 실행하면 확장자가 `.hwp`라는 이유로 in-place 저장을 허용하고, bundled Studio가 만든 HWP5 bytes로 HWP3 원본을 경고 없이 덮어쓰던 회귀를 차단했다. 원본 bytes의 HWP3 identity와 요청 output format에서 변환 의도를 계산해 저장 전에 HWP3 원형 미보존을 알리고, 존재하지 않는 신규 destination에 HWP5 또는 HWPX 변환 복사본만 기록한다.

보호 해제 정책과 형식 변환 정책을 독립적으로 계산한 뒤 한 번의 경고로 합성한다. 따라서 #480의 보호 문서 평문 복사본 안전 경계를 유지하면서 보호된 HWP3에는 암호 보호 해제와 HWP3 변환을 함께 설명한다. 기존 평문 HWP5/HWPX same-format 저장은 계속 in-place로 동작한다.

## Stage와 커밋

| Stage | 커밋 | 결과 |
|-------|------|------|
| 계획 | `b11ecdd`, `f37dfbe` | 수행계획서와 3단계 구현계획 확정 |
| Stage 1 | `a0e8ce9` | v0.1.10 release app에서 평문 HWP3의 무경고 HWP5 원본 덮어쓰기 재현, 변환·destination 계약 확정 |
| Stage 2 | `6c4feaa` | HWP3 source identity, 변환 경고, 신규 destination 정책과 단위 회귀 구현 |
| Stage 3 | `8c9375b` | Debug app HWP5/HWPX 변환·보호 정책 회귀 smoke와 사용자 문서 보정 |

## 변경 파일과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/Services/DocumentSaveContract.swift` | HWP3 source identity, HWP3 → HWP5/HWPX conversion intent, in-place·신규 destination·write·current document 검증 추가 |
| `Sources/HostApp/Services/RhwpStudioDocumentPayload.swift` | 원본 payload bytes에서 source format identity 노출 |
| `Sources/HostApp/Services/DocumentProtectionSaveAlert.swift` | 보호 해제와 HWP3 변환을 한 alert로 합성하고 실제 output format 문구·확인 버튼 제공 |
| `Sources/HostApp/Services/DocumentSavePanel.swift` | 보호·변환 조합별 평문/변환 복사본 제안 파일명 연결 |
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | HWP3 in-place 차단, pending source identity 캡처, 단계별 destination 재검증, 신규 파일 write와 성공 상태 전환 구현 |
| `Tests/HostAppTests/DocumentSaveContractTests.swift` | HWP3 identity·conversion·warning·destination·write·filename·current state 단위 회귀 추가 |
| `README.md` | 평문 HWP5/HWPX 저장, HWP3 변환 복사본과 native 암호 저장 제한 명시 |
| `docs/updates/v0.1.10.html` | v0.1.10 저장 범위를 실제 native 지원 경계로 보정 |
| `mydocs/release/v0.1.10.md` | upstream 암호 저장 지원과 알한글 native 저장 경계, #480/#482 제한 분리 |
| `mydocs/plans/task_m010_482.md` | Task #482 수행 범위와 3단계 계획 |
| `mydocs/plans/task_m010_482_impl.md` | source identity·변환·destination·검증 구현계획 |
| `mydocs/working/task_m010_482_stage1.md` ~ `task_m010_482_stage3.md` | 재현, 구현, 실제 fixture 회귀와 문서 보정 결과 |
| `mydocs/orders/20260818.md` | Task #482 진행·완료 상태 기록 |

upstream `rhwp` core, Rust FFI, `rhwp-core.lock`, bundled `rhwp-studio` asset, `project.yml`과 Xcode project는 변경하지 않았다. HWP3 원형 serializer와 암호 저장 API 연결도 이번 범위에 포함하지 않았다.

## 변경 전·후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| 평문 HWP3 `Command+S` | 경고·panel 없이 HWP5로 원본 overwrite 가능 | 변환 경고 뒤 신규 destination만 허용 |
| HWP3 source 판정 | `.hwp` 확장자로 HWP5와 구분 불가 | 원본 `HWP Document File` magic 기반 typed identity |
| HWP3 output | HWP5 변환 사실 미표시 | 요청에 따라 HWP5 또는 HWPX 변환 의도 명시 |
| 기존 destination | macOS 대치 확인 뒤 overwrite 가능 | 원본과 다른 기존 파일까지 HostApp이 write 전 거부 |
| 보호 HWP3 안내 | 보호 해제 중심 | 보호 해제와 HWP3 형식 변환을 한 alert에 표시 |
| 변환 제안 파일명 | 원본과 같은 stem·형식 | `(변환 복사본)` 또는 `(평문 변환 복사본)` suffix |
| `DocumentSaveContractTests` | 18개 | 25개, 7개 증가 |
| HostAppTests 전체 | 135개 | 142개, 실패 0개 |
| 실제 HWP3 변환 smoke | release app의 위험 동작 재현 | HWP5/HWPX 신규 저장·원본 보존·후속 저장 확인 |

최종 보고서 작성 전 `origin/devel...HEAD` diff는 15개 파일, 1,536줄 추가, 92줄 삭제였다.

| 구분 | 추가 | 삭제 |
|------|------|------|
| HostApp 제품 source | 327 | 62 |
| HostAppTests | 318 | 14 |
| 사용자·release 문서 | 30 | 15 |
| 계획·단계·orders 문서 | 861 | 1 |

## 구현 결과

### source identity와 저장 의도

`DocumentSourceFormatIdentity`는 원본 bytes의 `HWP Document File` magic prefix로 HWP3를 판정한다. `.hwp` 확장자를 HWP3/HWP5 구분에 사용하지 않는다. `DocumentSaveConversionIntent`는 source identity와 요청 output format에서 HWP3 → HWP5 또는 HWP3 → HWPX를 계산한다.

in-place 저장은 다음 세 조건을 모두 만족할 때만 허용한다.

1. source protection이 평문이다.
2. source가 HWP3가 아니다.
3. source URL 형식과 요청 output format이 일치한다.

따라서 평문 HWP3의 일반 저장도 exporter로 바로 진행하지 않고 변환 경고와 native save panel을 거친다.

### 경고와 제안 파일명

| source 상태 | 경고 확인 버튼 | 제안 파일명 |
|-------------|----------------|-------------|
| 평문 HWP3 | `변환 복사본 저장` | `원본 (변환 복사본).hwp` 또는 `.hwpx` |
| 보호/미지원/불명 HWP3 | `평문 변환 복사본 저장` | `원본 (평문 변환 복사본).hwp` 또는 `.hwpx` |
| 평문 HWP5/HWPX | 경고 없음 | 기존 정규화 파일명 |
| 보호/미지원/불명 HWP5/HWPX | `평문 복사본 저장` | `원본 (평문 복사본).hwp` 또는 `.hwpx` |

HWP3의 `.hwp` output은 HWP3 원형이 아니라 HWP5 변환이라고 표시한다. 보호 HWP3는 보호 해제와 형식 변환을 두 개의 연속 alert로 나누지 않는다.

### destination과 write 안전 경계

HWP3 conversion intent가 있는 요청은 source URL 유무와 보호 상태에 관계없이 존재하지 않는 신규 destination만 허용한다.

- canonical source URL, 표준화·대소문자 변형과 symlink로 같은 원본을 가리키는 경로 거부
- 원본이 아닌 다른 기존 destination도 거부
- save panel 반환 뒤, exporter 호출 직전, payload 검증 뒤와 실제 write 직전에 반복 검증
- pending request의 revision·protection·source identity·conversion intent가 현재 문서와 다르면 중단
- 일반 저장은 기존 atomic write, HWP3 변환은 `.withoutOverwriting` 신규 write 사용
- 성공 뒤에만 current payload와 source URL을 output bytes·destination으로 갱신

경고 취소, panel 취소, 정책 거부, export/payload/write 실패에서는 원본 bytes와 성공 상태를 변경하지 않는다. 저장 성공 뒤 payload identity가 HWP5/HWPX로 전환되므로 후속 same-format `Command+S`는 변환 경고 없이 같은 URL에 저장한다.

## 실제 fixture 검증

exact pinned upstream `rhwp v0.8.4` commit `496333b27d21ddb9114ba9ae340bcb895870c9a7`의 공개 fixture 복사본만 `build.noindex/`에서 사용했다. 평문 HWP3 원본 SHA-256은 `645525c8cd5ec11b1742ba7cfc759f68622861916233b5e982385cdb12f0ced2`다.

| 경로 | 결과 | 원본 보존 |
|------|------|-----------|
| 경고 취소 | export/write 결과 없음 | 예 |
| save panel 취소 | 제안 파일명 확인 뒤 결과 파일 없음 | 예 |
| HWP3 → HWP5 | 신규 HWP 5.x CFB, SHA `4c537176ce8f734ab977c7c2813c059adcfd401d6abaf364fcd93acd79b3d95b` | 예 |
| HWP5 변환본 후속 `Command+S` | 경고·panel 없이 같은 URL 저장과 mtime 갱신 | 예 |
| HWP3 → HWPX | 신규 ZIP/HWPX, SHA `7e67c4818ef25adcc31996b77c85f4197673c0408414e0b6605302e8392c9e99` | 예 |
| HWPX 변환본 후속 `Command+S` | 경고·panel 없이 같은 URL 저장과 mtime 갱신 | 예 |
| 원본 destination | HostApp 정책 오류로 write 거부 | 예 |
| 다른 기존 destination | HostApp 정책 오류로 write 거부, destination bytes도 유지 | 예 |

평문 HWP5/HWPX는 경고·panel 없이 same-format in-place 저장됐고 container signature를 유지했다. 보호 HWP3/HWP5/HWPX는 #480의 보호 해제 경고와 평문 복사본 정책을 유지했으며, 보호 HWP3는 HWP5 변환 문구까지 같은 alert에 표시했다.

## 수용 기준별 결과

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| 평문 HWP3 `Command+S`가 원본 URL에 HWP5 bytes를 쓰지 않음 | OK | in-place 조건에서 HWP3 제외, 실제 경고·panel·원본 SHA 유지 |
| 저장 전에 HWP3 원형 미보존과 선택 형식 변환을 안내 | OK | HWP5/HWPX별 실제 alert 문구와 확인 버튼 smoke |
| 취소·정책 거부에서 원본 hash 유지 | OK | 경고/panel 취소, 원본·기존 destination 거부 fixture hash 확인 |
| 변환 결과가 요청 signature와 일치 | OK | HWP5 CFB와 HWPX ZIP 결과 확인 |
| 변환 결과는 신규 destination만 사용 | OK | 원본 동일·다른 기존 파일 거부와 신규 파일 성공 |
| 성공 뒤 후속 `Command+S`가 output 형식과 URL 유지 | OK | HWP5/HWPX 각각 panel 없는 후속 저장과 mtime 갱신 |
| 기존 평문 HWP5/HWPX in-place 저장 유지 | OK | 두 형식의 실제 Debug app 회귀 smoke |
| #480 보호 문서 정책 유지 | OK | 보호 HWP3/HWP5/HWPX 경고·버튼·취소와 원본 hash 유지 |
| upstream/core/asset 직접 수정 없음 | OK | core lock·bundled asset unchanged, asset verifier 통과 |
| 사용자 문서가 실제 저장 범위와 일치 | OK | README, v0.1.10 update/release record 보정 |

## 최종 통합 검증

| 검증 | 결과 |
|------|------|
| `xcodegen generate` | 통과. project 재생성 뒤 추가 diff 없음 |
| HostAppTests | `** TEST SUCCEEDED **`, 142개, 실패 0개 |
| HostApp Debug build | `** BUILD SUCCEEDED **` |
| `./scripts/check-no-appkit.sh` | 통과 |
| 저장소 bundled asset 검증 | 통과 |
| Debug app bundled asset 검증 | 통과 |
| `scripts/check-extension-registration-hygiene.sh --cleanup-dev-registrations` | 통과. development registration 없음 |
| registration hygiene `--check-only` | 통과. issue 없음 |
| `git diff --check` | 통과 |
| 최신 `origin/devel...HEAD` | `0 5`, 작업 브랜치가 뒤처지지 않고 5개 commit 앞섬 |

HostAppTests와 build에는 기존 `RhwpStudioPagePDFRenderer.swift`의 Swift 6 main-actor warning과 WebKit test process의 sandbox 진단이 남지만 테스트·빌드 실패는 없다. UI smoke가 만든 Debug 앱은 종료했고 최종 등록 위생 검사에서 개발 경로 registration이 남지 않았다.

## 잔여 위험과 후속 작업

- HWP3 원형 serializer는 지원하지 않는다. HWP3 저장은 HWP5/HWPX 변환 복사본으로만 제공한다.
- native 저장 경로는 암호 보호 유지나 새 암호 설정을 지원하지 않는다. #480 정책에 따라 사용자 확인 뒤 신규 평문 복사본만 허용한다.
- 대표 fixture의 container와 원본 보존을 확인했지만 upstream exporter가 모든 문서 요소를 의미론적으로 완전 무손실 보존한다고 보장하지 않는다.
- HWPX runtime guard는 ZIP magic까지 확인하며 필수 entry 전체 검증은 exporter·재열기 smoke에 의존한다.
- HWP3 저장 뒤 앱 종료에서 저장 직후에도 unsaved-changes 경고가 한 차례 다시 관찰됐다. #480 Stage 1에도 기록된 현상이며 durable write·후속 저장·원본 보존에는 영향이 없었다. 반복 원인 조사는 별도 승인 범위로 남긴다.
- PR merge 확인 뒤 #482 close, `publish/task482`/`local/task482`와 필요 없는 worktree·개발 등록 부산물을 정리한다.

## 작업지시자 승인 요청

Task #482의 3개 Stage, 최종 수용 검증과 결과보고서 작성을 완료했다. `publish/task482`를 `devel` 대상으로 게시한 PR의 리뷰와 merge 승인을 요청한다.
