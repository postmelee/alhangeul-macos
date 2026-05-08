# Task M016 #147 Stage 3 보고서

## 단계 목적

v0.1 release artifact 기준 third-party license/provenance 고지 문서를 실제로 보강한다. 루트 `THIRD_PARTY_LICENSES.md`만 읽어도 현재 bundle 기준 `rhwp` core, `rhwp-studio` asset, Rust bridge generated artifact, bundled WOFF2 font, proprietary font 비포함 정책의 위치를 알 수 있게 한다.

## 산출물

| 파일 | 라인 수 | 요약 |
|------|---------|------|
| `THIRD_PARTY_LICENSES.md` | 63 | v0.1 artifact 범위, `rhwp` `v0.7.9` pin, `rhwp-studio` manifest, bundled font, proprietary font 비포함 정책 고지 |
| `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md` | 81 | release artifact 기준 intro 정리, proprietary font 비포함 문구 보강, `LatinModernMath-Regular.woff2`와 Happiness Sans 개별 파일명 보강 |
| `mydocs/tech/font_fallback_strategy.md` | 62 | 사용자용 third-party 고지 위치를 `THIRD_PARTY_LICENSES.md`로 연결 |
| `mydocs/working/task_m016_147_stage3.md` | 116 | Stage 3 변경 요약과 검증 결과 |

diff 통계:

```text
3 files changed, 67 insertions(+), 10 deletions(-)
```

## 본문 변경 정도 / 본문 무손실 여부

이번 단계는 문서 본문 변경 단계다.

- `THIRD_PARTY_LICENSES.md`는 기존 10줄 영어 요약을 한국어 release artifact 기준 고지 문서로 확장했다.
- `FONTS.md`는 기존 font 목록 구조를 유지하고, 실제 bundle에 포함된 `LatinModernMath-Regular.woff2` 누락과 `HappinessSansVF.woff2` wildcard 불일치만 보강했다.
- `font_fallback_strategy.md`는 정책 내용은 유지하고 third-party 고지 위치 연결 문장만 추가했다.
- `rhwp-core.lock`, `rhwp-studio/manifest.json`, `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, actual WOFF2 resource는 변경하지 않았다.

## 검증 결과

### 브랜치 상태

```text
$ git status --short --branch
## local/task147
 M Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md
 M THIRD_PARTY_LICENSES.md
 M mydocs/tech/font_fallback_strategy.md
```

### rhwp-studio asset 검증

```text
$ scripts/verify-rhwp-studio-assets.sh
OK: rhwp-studio assets verified at /Users/melee/Documents/projects/rhwp-mac/Sources/HostApp/Resources/rhwp-studio
```

### bundled WOFF2 목록

```text
$ find Sources/HostApp/Resources/rhwp-studio/fonts -maxdepth 1 -name '*.woff2' -type f | sort | wc -l
      34
```

Stage 3에서 WOFF2 파일을 추가하거나 제거하지 않았다.

### font 목록 대조

실제 WOFF2 파일명 중 `FONTS.md`에 literal 파일명으로 없는 항목:

```text
Pretendard-Black.woff2
Pretendard-Bold.woff2
Pretendard-ExtraBold.woff2
Pretendard-ExtraLight.woff2
Pretendard-Light.woff2
Pretendard-Medium.woff2
Pretendard-Regular.woff2
Pretendard-SemiBold.woff2
Pretendard-Thin.woff2
```

이 9개는 `FONTS.md`의 `Pretendard-*.woff2 (9종)` family row로 의도적으로 묶어 둔 항목이다. Stage 1에서 문제로 분리한 `LatinModernMath-Regular.woff2`와 `HappinessSansVF.woff2`는 이번 단계에서 literal 파일명으로 보강했다.

### 주요 고지 검색

```text
$ rg -n "rhwp|rhwp-studio|release-tag|v0.7.9|0fb3e6758b8ad11d2f3c3849c83b914684e83863|WOFF2|SIL OFL|proprietary|한컴|HY|Microsoft|THIRD_PARTY_LICENSES" THIRD_PARTY_LICENSES.md Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md mydocs/tech/font_fallback_strategy.md
```

핵심 match:

- `THIRD_PARTY_LICENSES.md`: `v0.7.9`, `release-tag`, `0fb3e6758b8ad11d2f3c3849c83b914684e83863`, `rhwp-core.lock`, `rhwp-studio/manifest.json`, WOFF2 34개, proprietary font 비포함 정책
- `FONTS.md`: Alhangeul v0.1 bundle 기준 WOFF2 목록, 한컴/HY/HCR/Microsoft proprietary font 비포함 정책, SIL OFL 항목, `LatinModernMath-Regular.woff2`
- `font_fallback_strategy.md`: `THIRD_PARTY_LICENSES.md`와 `FONTS.md` 연결

### whitespace 검증

```text
$ git diff --check
통과
```

## attribution 범위 판단

- #147의 고지 기준은 현재 app artifact에 실제 포함된 `v0.7.9` pin과 bundled resource tree다.
- upstream 최신 `v0.7.10`은 Stage 2에서 확인했지만, 현재 app bundle에 포함되지 않으므로 `THIRD_PARTY_LICENSES.md`의 current artifact 고지 기준으로 쓰지 않았다.
- `LatinModernMath-Regular.woff2`는 CTAN `lm-math` package 기준 GUST Font License로 확인해 `FONTS.md`에 추가했다.
- Cafe24/Happiness Sans의 “무료 배포” 표현은 기존 문서의 표현을 유지했고, 법률 해석으로 확장하지 않았다.
- npm transitive dependency license inventory는 현재 `manifest.json`에 존재하지 않으므로 이번 단계에 포함하지 않았다.

## 잔여 위험

- 추후 core/asset pin을 `v0.7.10` 이상으로 갱신하면 `THIRD_PARTY_LICENSES.md`의 `v0.7.9` 고지도 함께 갱신해야 한다.
- “무료 배포” font의 재배포 조건은 이번 단계에서 법률적으로 재해석하지 않았다.
- `rhwp-studio` JS/CSS/WASM transitive dependency license manifest가 필요하면 별도 작업으로 분리해야 한다.

## 다음 단계 영향

Stage 4에서는 README 하단 License/Notice 주변에 `LICENSE`, `THIRD_PARTY_LICENSES.md`, `rhwp-core.lock`, `rhwp-studio/manifest.json`, `FONTS.md`로 이어지는 짧은 진입점을 추가한다. 이번 단계에서 확정한 third-party 고지의 본문은 README에 중복 복제하지 않는다.

## 승인 요청

Stage 3 완료를 보고한다. 승인 후 Stage 4 `README 진입점, 최종 검증, 보고 정리`로 진행한다.
