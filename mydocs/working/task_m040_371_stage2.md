# Task M040 #371 Stage 2 완료보고서

## 단계 목적

HostApp이 `alhangeul-document://` URL로 문서 bytes를 bundled `rhwp-studio`에 넘긴 뒤, Studio의 원격 문서 byte guard가 HWP 3.0 문서를 다시 차단하지 않도록 보강했다. Stage 1의 Swift validator 허용과 같은 `HWP Document File V3.` prefix를 Studio asset에도 반영했다.

## 산출물

| 파일 | 변경량 | 요약 |
|------|--------|------|
| `Sources/HostApp/Resources/rhwp-studio/assets/index-2nxfiXnQ.js` | 52 lines, minified 1줄 치환 | `Af` 문서 byte kind 판정에서 HWP5 CFB 또는 HWP 3.0 prefix이면 `hwp`로 분류 |
| `mydocs/orders/20260624.md` | 7 lines, 1행 갱신 | #371 상태를 Stage 2 완료보고서 승인 대기로 갱신 |
| `mydocs/working/task_m040_371_stage2.md` | 신규 | Stage 2 완료보고서 |

핵심 변경 위치:

```text
var Df=[208,207,17,224,161,177,26,225],Of=[[80,75,3,4],[80,75,5,6],[80,75,7,8]];
function Af(e,t){
  if(kf(e,Df)||kf(e,[72,87,80,32,68,111,99,117,109,101,110,116,32,70,105,108,101,32,86,51,46]))return`hwp`;
  if(Of.some(t=>kf(e,t)))return`hwpx`;
  ...
}
```

실제 파일은 minified bundle이라 위 코드는 설명용으로 줄바꿈했다.

## 본문 변경 정도 / 본문 무손실 여부

문서 본문 parsing, rendering, 저장, 편집 로직은 변경하지 않았다. 이번 단계는 URL로 fetch된 byte stream을 `hwp`, `hwpx`, `html`, `unknown` 중 하나로 분류하는 guard만 확장한다.

HWPX ZIP magic 판정, HTML content-type/본문 판정, `unknown` 거부 경로, 파일 input/drag extension gate, error toast/modal UX는 변경하지 않았다.

## 검증 결과

```bash
git diff --check
```

- 결과: 통과, 출력 없음.

```bash
node --check Sources/HostApp/Resources/rhwp-studio/assets/index-2nxfiXnQ.js
```

- 결과: 통과, 출력 없음.

```bash
rg -n "HWP Document File V3|72,87,80,32|Df=|Of=|function Af|function jf" Sources/HostApp/Resources/rhwp-studio/assets/index-2nxfiXnQ.js
```

주요 출력:

```text
52:...var Df=[208,207,17,224,161,177,26,225],Of=[[80,75,3,4],[80,75,5,6],[80,75,7,8]];function kf(e,t){...}function Af(e,t){if(kf(e,Df)||kf(e,[72,87,80,32,68,111,99,117,109,101,110,116,32,70,105,108,101,32,86,51,46]))return`hwp`;if(Of.some(t=>kf(e,t)))return`hwpx`;...
```

```bash
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

- 결과: 통과.
- 최종 출력: `** BUILD SUCCEEDED ** [0.934 sec]`

## 잔여 위험

- 변경 대상은 bundled `rhwp-studio`의 minified build 산출물이다. 향후 upstream `rhwp-studio` asset을 다시 동기화하면 같은 byte guard 변경이 사라질 수 있으므로, 최종 보고서에 source drift 위험을 남겨야 한다.
- 이번 단계는 URL byte guard만 수정했다. 로컬 Studio file input과 drag/drop의 확장자 gate는 기존처럼 `.hwp`/`.hwpx`만 허용하며, HWP 3.0 파일도 `.hwp` 확장자이면 기존 gate를 통과한다.
- HWP 3.0 prefix는 `HWP Document File V3.`만 허용한다. HWP 2.x나 알 수 없는 legacy signature는 계속 `unknown`으로 남는다.
- 실제 제보 샘플을 HostApp에서 여는 통합 smoke는 Stage 3에서 Swift validator와 Studio guard를 함께 검증한다.

## 다음 단계 영향

Stage 3에서는 Swift validator와 Studio URL guard가 함께 동작하는지 확인해야 한다. 특히 `/Users/melee/Documents/projects/forks/rhwp/samples/hwp3-sample16.hwp`를 Debug HostApp으로 열어 기존 미지원 오류 대신 문서 로드까지 진행되는지 확인하고, PDF/텍스트 같은 비지원 파일이 여전히 지원 문서로 오인되지 않는지 확인한다.

## 승인 요청

Stage 2 산출물 검토와 Stage 3 진입 승인을 요청한다. 승인 전에는 통합 검증과 최종 보고 단계로 넘어가지 않는다.
