# Task M020 #513 Stage 3 — 선행 리뷰 반영과 추가 진단

## 기준

- #513 Stage 2: `2d71a03`.
- #511 오류 진단 보완 `9930fa649b91bfcc0d6278cd1052dec64bb26f64`를 `07e1503`으로 cherry-pick했다. 원래 세션의 orders와 회귀 사례를 모두 보존했다.
- 통합 운영 회귀: 20 tests PASS. source/runtime 후보의 앱·importer bytes는 최초 #341 개발 패키지를 유지한다. 새 extractor/factory 관련 선행 리뷰 보완까지 반영한 최종 배포 후보 검증은 별개다.

## 정리 및 추가 비교

C의 최종 cleanup은 본문 표식 7종 제거, 원래 앱 hash/provider 보존, 시험 앱/문서/프로세스 제거를 통과했다. catalog는 반복 60초 MISS 이후 추가 대기와 같은 cleanup 재호출에서 PASS/cleaned가 됐다. 별도 시스템 명령이나 reset을 하지 않았다.

D는 B와 같은 중첩 위치에서 source importer 디렉터리 mtime만 첫 복사 전에 갱신한 사본을 사용한다. 원본 패키지는 수정하지 않았다. source 사본의 앱 root mtime/실행 파일/Info.plist는 그대로이고 importer 디렉터리 시각만 달라졌다. state에 `source-importer-mtime-only` 진단 이력을 남겨 일반 최초 설치 판정에서 제외한다. 복사/첫 실행/실제 후보 선택/기존 문서 검색을 수동 등록 또는 `mdimport -i` 없이 비교한다.

D는 설치 후 첫 실행 60초 발견 MISS였고 `mdimport -t`는 해당 합성 HWP에 대해 no plugIn을 반환했다. 실제 검색 단계는 실행하지 않았다. E용 사본은 D source의 importer 시각/bytes를 그대로 복사하고 앱 root 시각만 추가 갱신하여 준비한다. D의 정리가 끝난 후 동일 중첩 경로 조건에서 비교하며 일반 설치 수용 기준에는 사용하지 않는다.

E는 첫 실행 60초에 이어 무조작 180초 추가 관찰도 MISS였다. 이후 소유 앱/문서/프로세스·LaunchServices·importer catalog 제거와 원래 앱/provider 보존을 확인해 cleaned 상태로 마쳤다.

최종 선행 #512 `b3b1009bd75e1ca787d0adcf775f92fa350a0874`를 `91e2e12`로 통합했다. 신규 #513 회귀 9개와 선행 12개를 모두 보존해 21 tests PASS, 강화된 bundle 회귀는 5 tests PASS다. 단계 예외도 state에 저장해 추출 진단 실패가 공개 결과 목록에서 누락되지 않게 했다. GitHub 재조회 시 #511/#512/#513은 OPEN, devel은 `1a5eefb50db4aef01fc82bdb61eabeabf94b19ed`다.

F는 Stage 2에서 수정한 direct 복사를 실제 앱으로 재검증하는 실행이다. 원본 bytes/디렉터리 시각을 그대로 유지하는 조건에서 새 direct 위치의 첫 실행을 확인하고 정리한다.

F의 수정된 direct 복사에서 원본 앱/importer hash와 두 디렉터리 시각이 모두 보존됐다. 첫 실행 후 60초 발견은 MISS이며 본문 검색은 실행하지 않았다. 조사 도구의 복사 보완 검증과 제품 최초 설치 판정을 구분한다.

## 최종 정리와 제출 판정

A–F 여섯 실행 모두 cleaned다. 소유 앱/문서/프로세스·LaunchServices·mdimport catalog 부재를 별도 최종 조회로 확인했다. 기존 앱 hash/provider 보존은 각 cleanup에서 통과했고, 실제 HWP/HWPX UTI의 현재 기본 연결도 인계와 동일한 한컴 뷰어다. 별도 등록이 없는 소유 source 진단 사본은 제거했으며 원본 package/fixture는 유지했다.

운영 21개·bundle 5개 회귀, source bundle 계약과 Python 구문/diff 검사를 통과했다. 이 단계는 검증 도구 개선과 원인 분리 조사 결과를 제출하는 범위다. 일반 최초 설치 수용 기준과 제품 통합/OS 등록 이력의 원인 구분은 미완료이며 #513/상위 #337은 열린 상태로 유지한다. 최종 리뷰 보완으로 새로 만든 후보, 신규 설치 이력 환경, 서명·공증 배포 후보와 macOS 12/Intel 실행 관문을 구분해 남긴다.

## PR 검토 중 판정 보완

자동 검색 시작 후 외부 touch/교체 또는 corpus 수정이 발생해도 최초 설치로 통과할 수 있던 여지를 차단했다. 설치본 hash/시각과 설치 provenance를 관찰 전후에 대조하고 corpus snapshot도 관찰 후 재확인한다. 이력에 없는 bundle 변경과 대기 중 corpus 변경 회귀를 추가해 운영 23 tests PASS다. 실제 A–F 결과는 진단 조작 이력을 명시했으므로 판정이 달라지지 않는다.
