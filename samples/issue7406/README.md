# OLE 차트 Quick Look 회귀 사례

출처: [edwardkim/rhwp v0.9.0 samples/issue7406](https://github.com/edwardkim/rhwp/tree/c9095c5f67632e6721e800ccc7fb43ea49d26682/samples/issue7406). 원본 bytes를 변경하지 않고 복사했다. 기준 PDF는 upstream 제공 기준이며 알한글의 생성 결과가 아니다.

| 파일 | SHA-256 |
|---|---|
| 7406_OLE__CHART.hwp | a29d415afb06755471eb52caa21d2bad2855d7498d73ad7faa80f11332eaeb06 |
| 7406_OLE__CHART.pdf | bd3a5a0ed14b584717ee694ef08c41feddaaa69029c8450c4a352aafae5bed61 |

[Task #612](https://github.com/postmelee/alhangeul-macos/issues/612): 본앱은 차트를 표시하지만 CoreGraphics Quick Look은 복합 RawSvg를 SVG 자리표시자로 표시한다. 별도의 Jangster 제보와 동일 문서라고 판단하지 않는다.

물리 1쪽에서 누적 막대 6개, 0–100% 축, 연령대 5개와 Total, 한글 범례 6개, 그림 5 캡션을 대조한다. PDF 자체의 라벨 겹침과 글꼴 차이는 차트 누락과 분리한다.

검증 진입점: `scripts/test-quicklook-raw-svg.sh` (Frameworks 및 Poppler 필요). 선택 정책·실제 확장 공급 경로·PNG/PDF 출력과 독립 PDF 영역 비교를 수행하고 `build.noindex/quicklook-raw-svg`에 이미지와 JSON을 남긴다. 글꼴 차이가 있으므로 영역 누락/막대 면적 검사와 직접 시각 검토를 구분한다.
