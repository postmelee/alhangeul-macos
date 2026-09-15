# Alhangeul v0.2.2

## 이번 버전의 주요 변경 사항

### 변경 요약

- 문서를 연 뒤 새 HWP/HWPX 문서를 만들어 저장했을 때, 저장이 끝나도 닫기·앱 종료가 취소되고 미저장 경고가 반복되는 문제를 수정했습니다.
- 같은 버전의 알한글을 삭제한 뒤 다시 설치했을 때 기존 한글 문서의 Spotlight 검색 준비가 생략될 수 있던 문제를 보완했습니다.

### 포함된 rhwp 변화

문서 처리 엔진과 편집 화면은 직전 공개 버전과 같은 [rhwp v0.8.6](https://github.com/edwardkim/rhwp/releases/tag/v0.8.6)을 사용합니다. 이번 릴리즈에서 bundled rhwp core와 rhwp-studio 버전 변경은 없습니다.

### 알한글 앱 변화

- 새 문서를 저장한 뒤 저장된 상태를 유지하여 창 닫기와 앱 종료를 이어갈 수 있도록 수정했습니다. 취소하거나 저장에 실패하면 문서를 유지합니다.
- 같은 버전 앱을 같은 위치에 다시 설치해도 새 설치로 인식하여 기존 평문 HWP3/HWP5/HWPX 문서의 검색 준비를 다시 요청합니다.
- 설치 후 한 번 실행하고 앱을 켜 둔 채 잠시 기다려 주세요. macOS의 색인 상태와 문서 수에 따라 검색 결과가 반영되기까지 시간이 걸릴 수 있습니다. 색인된 문서는 앱 종료 후에도 검색할 수 있습니다.

## 다운로드 및 설치

### 다운로드

- DMG: [`alhangeul-macos-0.2.2.dmg`](https://github.com/postmelee/alhangeul-macos/releases/download/v0.2.2/alhangeul-macos-0.2.2.dmg)
- SHA256: `8d8b8cbd24376fcd2c7ebd48343be44edc1f0f154a1e75282714798806ed4b90`
- SHA256 file: `alhangeul-macos-0.2.2.dmg.sha256`

### 지원 환경

- macOS 12 이상을 지원합니다.
- Intel Mac과 Apple Silicon Mac 모두 같은 DMG 파일을 사용합니다.

### 설치 후 첫 실행

- DMG를 열고 `Alhangeul.app`을 `Applications` 폴더로 드래그해 설치합니다.
- GitHub Release에 게시된 signed/notarized public DMG만 사용자 배포 산출물로 사용합니다.
- 설치 후 `Applications` 폴더의 `Alhangeul.app`을 한 번 실행합니다.
- 첫 실행 후 macOS가 Quick Look preview와 Finder thumbnail extension을 발견하고 등록할 수 있습니다.
- Finder에서 `.hwp` 또는 `.hwpx` 파일을 선택한 뒤 Space로 Quick Look preview를 확인하고, icon view에서 thumbnail 갱신을 확인합니다.

### 업데이트 확인

- 앱 메뉴에서 `알한글 > 업데이트 확인...`을 선택해 Sparkle 업데이트를 수동 확인할 수 있습니다.
- 업데이트 feed: `https://postmelee.github.io/alhangeul-macos/appcast.xml`
- 버전별 Pages 릴리즈 노트: https://postmelee.github.io/alhangeul-macos/updates/v0.2.2.html

### Homebrew

- Homebrew Cask에서도 같은 v0.2.2 DMG를 설치합니다: `brew install --cask postmelee/tap/alhangeul`.
- 기존 Homebrew 설치본은 `brew update` 후 `brew upgrade --cask postmelee/tap/alhangeul`로 업데이트하세요.
- 설치 후 앱을 한 번 실행하고 Spotlight 색인이 반영될 때까지 잠시 기다려 주세요.

## 알려진 제한 사항

- macOS 12 실행 검증은 환경 부재로 수행하지 못했습니다. 새 macOS 15.7.9 ARM/Intel VM과 현재 macOS 26.5.2의 검증 결과·한계는 아래 상세 기록에서 확인할 수 있습니다.
- 앱 viewer/editor 화면은 bundled `rhwp-studio`를 WKWebView에서 실행합니다.
- PDF 내보내기와 인쇄는 현재 editor의 page SVG를 별도 script-disabled WKWebView/PDFKit/AppKit 출력 경로로 처리하므로 앱 화면과 표시가 다를 수 있습니다.
- Quick Look preview와 Finder thumbnail은 Rust bridge와 Swift native renderer 경로를 사용하므로 앱 viewer/editor·PDF/인쇄와 표시가 다를 수 있습니다.
- HWP/HWPX 저장은 형식별 container와 대표 문서 재열기를 확인하지만, 모든 문서 요소의 의미론적 완전 무손실을 보장하지 않습니다.
- PDF 내보내기는 전체 page SVG를 memory에 보유하며 document 전체 progress, deadline과 수집 중 취소 UI는 아직 없습니다.
- Quick Look/Thumbnail smoke 통과는 extension 등록과 기본 렌더 성공 확인이며, 모든 문서가 앱 화면과 같은 시각 결과로 보인다는 보장은 아닙니다.
- 손상·대용량·미지원 문서 fallback은 복구가 아니라 앱과 extension이 raw error, hang, crash로 끝나지 않게 하는 안전장치입니다.
- native renderer의 style, image effect/fill, text layout, RawSvg/OLE 등 parity 개선은 v0.5 이후 Swift native viewer 범위에서 계속 다룹니다.

## 이번 릴리즈 관련 PR과 Issue

### 릴리즈 요약에 반영된 PR

- [#538: 저장 후 닫기·앱 종료 수정](https://github.com/postmelee/alhangeul-macos/pull/538) - 새 문서 저장 후 미저장 경고 반복 해결
- [#530: 동일 버전 재설치 검색 준비 보완](https://github.com/postmelee/alhangeul-macos/pull/530) - 기존 문서 색인 요청 복구

### 해결된 Issue

- [#537: 저장 후 창 닫기·앱 종료 경고 반복](https://github.com/postmelee/alhangeul-macos/issues/537) - 수정 PR 병합과 실제 SwiftUI 회귀 검증 완료

- [#513: 최초 설치·재설치 색인 수용](https://github.com/postmelee/alhangeul-macos/issues/513) - 최초 설치·재설치·공개 업데이트 검색 검증 완료
- [#337: Spotlight 본문 검색](https://github.com/postmelee/alhangeul-macos/issues/337) - 평문 HWP/HWPX 본문 검색과 실제 Spotlight 수용 완료

### 참고/연관 Issue

- [#539: v0.2.2 배포 수용](https://github.com/postmelee/alhangeul-macos/issues/539) - 동일 DMG 공개와 실제 Sparkle·Spotlight 검증 완료
- [#525: 저장하지 않음 후 복구 후보 잔존](https://github.com/postmelee/alhangeul-macos/issues/525) - 별도 남은 한계

## 상세 기록

- 릴리즈 상세 기록: [`mydocs/release/v0.2.2.md`](https://github.com/postmelee/alhangeul-macos/blob/main/mydocs/release/v0.2.2.md)
- 릴리즈 기록 index: [`mydocs/release/index.md`](https://github.com/postmelee/alhangeul-macos/blob/main/mydocs/release/index.md)
- 사용자용 Pages 릴리즈 노트: https://postmelee.github.io/alhangeul-macos/updates/v0.2.2.html
- GitHub Release: https://github.com/postmelee/alhangeul-macos/releases/tag/v0.2.2
- Third Party notices: `THIRD_PARTY_LICENSES.md`
- Font notices: `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md`

### Release metadata

| 항목 | 값 |
|------|----|
| App version | `v0.2.2` |
| rhwp core release tag | `v0.8.6` |
| rhwp core commit | `f1f9c6ae58344ee9368996d3543f76b9345cf227` |
| bundled rhwp-studio release tag | `v0.8.6` |
| bundled rhwp-studio commit | `f1f9c6ae58344ee9368996d3543f76b9345cf227` |
| core lock | `rhwp-core.lock` |
| studio manifest | `Sources/HostApp/Resources/rhwp-studio/manifest.json` |
