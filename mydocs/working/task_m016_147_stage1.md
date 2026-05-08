# Task M016 #147 Stage 1 보고서

## 단계 목적

현재 저장소에 포함된 v0.1 release artifact 후보의 third-party provenance와 bundled font 목록을 확인하고, license 고지 문서 보강 전에 실제 resource tree와 문서 상태의 불일치 후보를 분리한다.

## 산출물

| 파일 | 라인 수 | 내용 |
|------|---------|------|
| `mydocs/working/task_m016_147_stage1.md` | 187 | release artifact provenance inventory와 Stage 2 보강 항목 정리 |

조사 대상 파일의 현재 라인 수:

| 파일 | 라인 수 |
|------|---------|
| `rhwp-core.lock` | 17 |
| `Sources/HostApp/Resources/rhwp-studio/manifest.json` | 33 |
| `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md` | 77 |
| `THIRD_PARTY_LICENSES.md` | 10 |
| `README.md` | 454 |
| `mydocs/tech/font_fallback_strategy.md` | 62 |

## 본문 변경 정도 / 본문 무손실 여부

Stage 1은 inventory 조사 단계라 제품 코드와 기존 문서 본문을 변경하지 않았다. `README.md`, `THIRD_PARTY_LICENSES.md`, `FONTS.md`, `font_fallback_strategy.md`, `rhwp-core.lock`, `manifest.json`은 읽기만 했다.

## 검증 결과

### 브랜치 상태

```text
$ git status --short --branch
## local/task147
```

### core provenance

`rhwp-core.lock` 확인 결과:

```text
rhwp_repo = "https://github.com/edwardkim/rhwp.git"
rhwp_ref_kind = "release-tag"
rhwp_release_tag = "v0.7.9"
rhwp_commit = "0fb3e6758b8ad11d2f3c3849c83b914684e83863"
```

기록된 Rust bridge 산출물:

| path | sha256 | size |
|------|--------|------|
| `Frameworks/universal/librhwp.a` | `4fc34a8cb7b6489d18705ee342fab13a79df5bd559893c10c163a0787c04e619` | 104179008 |
| `Frameworks/generated_rhwp.h` | `69aeca5047bf743286d1b2260f8fc9a091ce4f1d7fd61c80084fab81c3a95ac5` | 1349 |

### bundled `rhwp-studio` provenance

`Sources/HostApp/Resources/rhwp-studio/manifest.json` 확인 결과:

```text
source_repository: https://github.com/edwardkim/rhwp.git
source_ref_kind: release-tag
source_release_tag: v0.7.9
source_resolved_commit: 0fb3e6758b8ad11d2f3c3849c83b914684e83863
copied_from: rhwp-studio/dist
excluded_paths: samples/
copied_file_count: 50
copied_total_bytes: 27704089
```

entrypoint hash:

| entrypoint | path | sha256 |
|------------|------|--------|
| index HTML | `index.html` | `4bcec64910b0fdfcacb8bae593b614c4af76c3c4d3f1d2252372a3d1a4202a29` |
| main JS | `assets/index-CCXookfl.js` | `3bb81abc018113c808253d75a62aa8ce19545bbccd4ece16d1b4c4df2f465986` |
| main CSS | `assets/index-ro3nVBB2.css` | `d669a5f84fd2945f4d6be9a5471d6d2782ff629f77658a73f6f5d0f1133d7179` |
| WASM | `assets/rhwp_bg-DtQ01XFR.wasm` | `bfcf7632d7f4877b69abe3a95e52fa23636f5253c149de877d1975fdac608b41` |

`rhwp-core.lock`과 `manifest.json`은 모두 `v0.7.9` release tag와 commit `0fb3e6758b8ad11d2f3c3849c83b914684e83863`로 맞는다.

### bundled font inventory

검증 명령:

```text
$ find Sources/HostApp/Resources/rhwp-studio/fonts -maxdepth 1 -name '*.woff2' -type f | wc -l
      34

$ find Sources/HostApp/Resources/rhwp-studio/fonts -maxdepth 1 -type f | wc -l
      35
```

font directory는 WOFF2 34개와 `FONTS.md` 1개로 구성된다. 실제 WOFF2 파일 목록:

```text
Cafe24Ssurround-v2.0.woff2
Cafe24Supermagic-Regular-v1.0.woff2
D2Coding-Bold.woff2
D2Coding-Regular.woff2
GowunBatang-Bold.woff2
GowunBatang-Regular.woff2
GowunDodum-Regular.woff2
Happiness-Sans-Bold.woff2
Happiness-Sans-Regular.woff2
Happiness-Sans-Title.woff2
HappinessSansVF.woff2
LatinModernMath-Regular.woff2
NanumGothic-Bold.woff2
NanumGothic-ExtraBold.woff2
NanumGothic-Regular.woff2
NanumGothicCoding-Bold.woff2
NanumGothicCoding-Regular.woff2
NanumMyeongjo-Bold.woff2
NanumMyeongjo-ExtraBold.woff2
NanumMyeongjo-Regular.woff2
NotoSansKR-Bold.woff2
NotoSansKR-Regular.woff2
NotoSerifKR-Bold.woff2
NotoSerifKR-Regular.woff2
Pretendard-Black.woff2
Pretendard-Bold.woff2
Pretendard-ExtraBold.woff2
Pretendard-ExtraLight.woff2
Pretendard-Light.woff2
Pretendard-Medium.woff2
Pretendard-Regular.woff2
Pretendard-SemiBold.woff2
Pretendard-Thin.woff2
SpoqaHanSans-Regular.woff2
```

`FontResourceRegistry.swift`의 allowlist도 WOFF2 34개를 명시한다. `FONTS.md`는 Pretendard 9종과 Happiness Sans 4종을 wildcard로 적고 있어 전체 수량은 대체로 맞지만, Stage 2-3에서 다음 정확성 보강을 검토해야 한다.

- `LatinModernMath-Regular.woff2`는 실제 bundle과 allowlist에는 있으나 `FONTS.md` 오픈 라이선스 표에는 직접 항목이 없다.
- `HappinessSansVF.woff2`는 실제 파일명에 `Happiness-Sans-` prefix가 없어 `FONTS.md`의 `Happiness-Sans-*.woff2 (4종)` 표기와 정확히 맞지 않는다.
- Pretendard 9종은 `Pretendard-*.woff2 (9종)`으로 묶여 있어 파일별 고지는 없지만 수량과 prefix는 맞다.

### proprietary font 비포함 확인

계획서의 proprietary 후보 검색은 `FONTS.md`의 "Git 미포함" 표에서만 match되었다.

```text
FONTS.md: hamchob-r.woff2, hamchod-r.woff2, h2hdrm.woff2, hygprm.woff2, hygtre.woff2, hymjre.woff2
FONTS.md: ArialW05-Regular.woff2, Calibri.woff2, MalgunGothicW35-Regular.woff2, WebdingsW95-Regular.woff2, WingdingsW95-3.woff2
```

실제 파일명 검색:

```text
$ find Sources/HostApp/Resources/rhwp-studio/fonts -maxdepth 1 -type f \( -name 'hamchob*' -o -name 'hamchod*' -o -name 'h2hdrm*' -o -name 'hygprm*' -o -name 'hygtre*' -o -name 'hymjre*' -o -name 'ArialW05*' -o -name 'Calibri*' -o -name 'MalgunGothic*' -o -name 'Wingdings*' -o -name 'Webdings*' \) -print
```

출력 없음. 따라서 조사한 proprietary 후보 파일은 실제 bundled font resource tree에 없다.

### existing license 고지 수준

`THIRD_PARTY_LICENSES.md`는 현재 `rhwp` MIT license와 `Sources/RhwpCoreBridge` 일부 유래만 적는다. `rhwp-studio` bundled asset, WOFF2 font, `FONTS.md`, `manifest.json`, `rhwp-core.lock`에 대한 release artifact 관점의 연결은 없다.

README는 `rhwp-studio`, `rhwp-core.lock`, `scripts/verify-rhwp-studio-assets.sh`를 설명하지만, 하단 License 섹션은 `[MIT License](LICENSE)`만 연결한다. third-party license/provenance 진입점은 없다.

`mydocs/tech/font_fallback_strategy.md`는 proprietary font 비포함, WOFF2 34개 재사용, `FONTS.md` 소유권을 이미 설명한다. 다만 사용자용 third-party license 고지 위치와의 연결은 없다.

### whitespace 검증

```text
$ git diff --check
통과
```

## 잔여 위험

- `FONTS.md`의 font license/source 표는 기존 문서 내용을 기준으로 한 inventory이며, Stage 3에서 license 문구를 보강할 때 source/license별 원문 확인이 추가로 필요할 수 있다.
- bundled `rhwp-studio` JS/CSS/WASM 내부 dependency attribution을 어느 수준까지 `THIRD_PARTY_LICENSES.md`에 포함할지는 Stage 2에서 범위를 확정해야 한다.
- `manifest.json`의 `copied_file_count`는 source snapshot 기준 값으로 보이며, 이번 Stage 1에서는 hash 재계산이나 artifact 재생성을 하지 않았다.

## 다음 단계 영향

Stage 2 설계에서 다음 항목을 반영한다.

- `THIRD_PARTY_LICENSES.md`를 `rhwp`, `rhwp-studio`, Rust bridge/generated artifact, bundled font 고지의 중심 문서로 확장한다.
- README 하단 License 또는 배포 관련 위치에 `THIRD_PARTY_LICENSES.md`, `rhwp-core.lock`, `manifest.json`, `FONTS.md` 진입점을 추가한다.
- `FONTS.md`의 `LatinModernMath-Regular.woff2` 누락과 `HappinessSansVF.woff2` 표기 정확성을 Stage 3 보강 후보로 둔다.
- `font_fallback_strategy.md`에는 사용자용 license 고지 위치 연결만 추가하는 방향을 우선 검토한다.

## 승인 요청

Stage 1 완료를 보고한다. 승인 후 Stage 2 `license/attribution 문서 구조 설계`로 진행한다.
