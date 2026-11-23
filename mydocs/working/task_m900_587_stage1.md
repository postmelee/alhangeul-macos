# #587 1단계 — 공개판 재현과 색인 경계 확인

macOS 26.5.2 Apple Silicon의 공개 알한글 v0.2.7/25로 T7에 HWP·HWPX·TXT·RTF 합성 표본을 만들었다. HWP·HWPX와 TXT에는 같은 독립 영문·한글 단어를 본문에 넣었고 파일명에는 넣지 않았다.

| 경로 | 결과 |
|---|---|
| 새 표본 자동 색인 | TXT와 RTF는 5초 관측에서 영문 검색을 통과했다. 한글 TXT도 검색됐다. HWP·HWPX 본문은 180초까지 검색되지 않았다. |
| 파일 단위 요청 | HWPX에 한정한 `mdimport -i`는 0으로 종료했다. 요청 후 60초까지 HWPX 본문 검색과 importer가 제공하는 제목이 나타나지 않았다. |
| 공개판 test mode | Polaris HWP는 `com.infraware.polarisofficeservice.hwp`로 분류됐고 선택된 importer가 없었다. HWPX는 Hancom Viewer HWPX UTI로 분류됐고, 설치된 알한글 importer가 동일 표본의 본문을 반환했다. |
| 정식 앱의 설치 요청 | 시스템 로그에서 v0.2.7의 재색인 요청 접수를 확인했다. 비동기 요청 접수와 검색 반영은 구분했다. |

Apple의 `kMDItemTextContent`는 검색할 수 있으나 직접 읽을 수 없는 속성이다. 따라서 `mdls` 본문 열의 null은 판단 근거로 쓰지 않았다. 파일명에 없는 단어의 검색과 importer가 제공하는 제목을 따로 관찰했다. [Apple 속성 명세](https://developer.apple.com/documentation/coreservices/kmditemtextcontent)

Polaris HWP에는 UTI 연결 누락이 확인됐다. 공개 HWPX의 재현 범위는 시험 추출 결과와 실제 색인 결과 사이로 좁혔다. `mdimport -t`는 색인에 결과를 기록하지 않으므로 시험 추출 성공에는 자동 색인 성공을 포함하지 않는다. [Apple Spotlight importer 진단 안내](https://developer.apple.com/library/archive/documentation/Carbon/Conceptual/MDImporters/Concepts/Troubleshooting.html)
