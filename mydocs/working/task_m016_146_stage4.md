# Task M016 #146 Stage 4 보고서 - release note 한계 문구 보강

## 단계 목적

public GitHub Release note skeleton에 v0.1 렌더링 경로와 알려진 제한 사항이 빠지지 않도록 `scripts/ci/write-release-notes.sh`를 보강했다. README와 release guide에서 정한 책임 경계에 맞춰 HostApp viewer/editor, PDF 내보내기, 인쇄, Quick Look preview, Finder thumbnail의 경로 차이를 짧게 공개하고, smoke 결과와 수동 확인 여부는 최종 보고서로 연결하도록 했다.

## 산출물

| 파일 | 내용 |
|------|------|
| `scripts/ci/write-release-notes.sh` | release note skeleton에 `렌더링 경로와 알려진 제한 사항` 섹션 추가, 검증 섹션의 최종 보고서 연결 문구 보강 |
| `mydocs/working/task_m016_146_stage4.md` | Stage 4 변경 내용, dummy output 검증 결과, 잔여 위험 정리 |

## 본문 변경 정도 / 본문 무손실 여부

- Swift/Rust 소스, Xcode project, bundled `rhwp-studio` asset, workflow 파일은 변경하지 않았다.
- 기존 설치, 산출물, `rhwp core`, viewer asset provenance, Third Party notices 섹션은 유지했다.
- 새 섹션은 `Third Party notices`와 `검증` 사이에 추가해 provenance와 검증 문구를 분리했다.
- `write-release-notes.sh`는 기존 repository 관례대로 실행 bit 없이 `bash scripts/ci/write-release-notes.sh ...`로 호출되는 파일 모드를 유지했다.

## 주요 변경

- release note skeleton에 다음 항목을 추가했다.
  - 앱 viewer/editor 화면은 bundled `rhwp-studio`를 WKWebView에서 실행한다.
  - PDF 내보내기, Quick Look preview, Finder thumbnail은 Rust bridge와 Swift native renderer 계열 경로를 사용하므로 앱 화면과 표시가 다를 수 있다.
  - 인쇄는 `rhwp-studio` page payload를 별도 WKWebView/PDFKit/AppKit 출력 경로로 처리한다.
  - Quick Look/Thumbnail smoke 통과는 extension 등록과 기본 렌더 성공 확인이며, 모든 문서가 앱 화면과 같은 시각 결과로 보인다는 보장은 아니다.
  - 손상·대용량·미지원 문서 fallback은 복구가 아니라 앱과 extension이 raw error, hang, crash로 끝나지 않게 하는 안전장치다.
  - native renderer parity 개선은 v0.5 이후 Swift native viewer 범위로 남는다.
- `검증` 섹션의 최종 보고서 연결 문구에 preview 수동 확인 여부를 추가했다.

## 검증 결과

Stage 4 구현계획서의 검증 명령을 실행했다.

```bash
git status --short --branch
```

결과: `local/task146`에서 `scripts/ci/write-release-notes.sh`만 수정 상태로 확인했다.

```bash
bash -n scripts/ci/write-release-notes.sh
```

결과: syntax error 없이 통과했다.

```bash
scripts/ci/write-release-notes.sh 0.1.0 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef /tmp/alhangeul-task146-release-note.md
```

결과: `zsh:1: permission denied: scripts/ci/write-release-notes.sh`. 기존 `scripts/ci/*.sh` 파일들이 repository에서 100644 mode이고 release workflow와 #145 검증이 `bash scripts/ci/write-release-notes.sh ...` 방식으로 호출하므로, 실행 bit 변경 없이 아래 명령으로 output을 검증했다.

```bash
bash scripts/ci/write-release-notes.sh 0.1.0 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef /tmp/alhangeul-task146-release-note.md
```

결과: `/tmp/alhangeul-task146-release-note.md` 생성 성공.

```bash
rg -n "렌더|Quick Look|Thumbnail|WKWebView|rhwp-studio|PDF|인쇄|한계|제한|smoke|최종 보고서|rhwp core|Third Party" \
  /tmp/alhangeul-task146-release-note.md
```

주요 결과:

```text
13:## 포함된 rhwp core
24:## Third Party notices
29:## 렌더링 경로와 알려진 제한 사항
31:- 앱 viewer/editor 화면은 bundled `rhwp-studio`를 WKWebView에서 실행합니다.
32:- PDF 내보내기, Quick Look preview, Finder thumbnail은 Rust bridge와 Swift native renderer 계열 경로를 사용하므로 앱 화면과 표시가 다를 수 있습니다.
33:- 인쇄는 `rhwp-studio` page payload를 별도 WKWebView/PDFKit/AppKit 출력 경로로 처리합니다.
34:- Quick Look/Thumbnail smoke 통과는 extension 등록과 기본 렌더 성공 확인이며, 모든 문서가 앱 화면과 같은 시각 결과로 보인다는 보장은 아닙니다.
41:- 상세 smoke test 결과, preview 수동 확인 여부, 알려진 제한 사항은 해당 릴리스의 최종 보고서를 기준으로 확인합니다.
```

```bash
git diff --check
```

결과: whitespace error 없이 통과했다.

## 잔여 위험

- release note skeleton은 실제 smoke 결과를 자동 수집하지 않는다. public release 시점의 성공/미실행 항목은 최종 보고서와 release workflow 결과를 기준으로 별도 기록해야 한다.
- dummy output은 release note 형식 검증용이며, public DMG signing/notarization/Gatekeeper 검증을 대체하지 않는다.
- 구현계획서의 직접 실행 예시는 현재 파일 mode와 맞지 않았다. 이번 단계에서는 기존 CI 호출 방식과 #145 선례에 맞춰 `bash` 호출로 검증했고, 불필요한 file mode 변경은 하지 않았다.

## 다음 단계 영향

Stage 5에서는 README, 아키텍처 문서, release guide, release note skeleton의 최종 결과를 한 번 더 정리하고, 오늘할일을 완료 상태로 갱신한 뒤 최종 보고서와 PR 준비 절차로 넘어간다.

## 승인 요청

Stage 4 `release note skeleton과 검증 정리`를 완료했다. Stage 5 `최종 보고와 PR 준비`로 진행해도 되는지 승인 요청한다.
