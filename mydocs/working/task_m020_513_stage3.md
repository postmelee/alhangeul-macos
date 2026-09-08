# Task M020 #513 Stage 3 — 선행 리뷰 반영과 추가 진단 (진행 중)

## 기준

- #513 Stage 2: `2d71a03`.
- #511 오류 진단 보완 `9930fa649b91bfcc0d6278cd1052dec64bb26f64`를 `07e1503`으로 cherry-pick했다. 원래 세션의 orders와 회귀 사례를 모두 보존했다.
- 통합 운영 회귀: 20 tests PASS. source/runtime 후보의 앱·importer bytes는 최초 #341 개발 패키지를 유지한다. 새 extractor/factory 관련 선행 리뷰 보완까지 반영한 최종 배포 후보 검증은 별개다.

## 정리 및 추가 비교

C의 최종 cleanup은 본문 표식 7종 제거, 원래 앱 hash/provider 보존, 시험 앱/문서/프로세스 제거를 통과했다. catalog는 반복 60초 MISS 이후 추가 대기와 같은 cleanup 재호출에서 PASS/cleaned가 됐다. 별도 시스템 명령이나 reset을 하지 않았다.

D는 B와 같은 중첩 위치에서 source importer 디렉터리 mtime만 첫 복사 전에 갱신한 사본을 사용한다. 원본 패키지는 수정하지 않았다. source 사본의 앱 root mtime/실행 파일/Info.plist는 그대로이고 importer 디렉터리 시각만 달라졌다. state에 `source-importer-mtime-only` 진단 이력을 남겨 일반 최초 설치 판정에서 제외한다. 복사/첫 실행/실제 후보 선택/기존 문서 검색을 수동 등록 또는 `mdimport -i` 없이 비교한다.

D는 설치 후 첫 실행 60초 발견 MISS였고 `mdimport -t`는 해당 합성 HWP에 대해 no plugIn을 반환했다. 실제 검색 단계는 실행하지 않았다. E용 사본은 D source의 importer 시각/bytes를 그대로 복사하고 앱 root 시각만 추가 갱신하여 준비한다. D의 정리가 끝난 후 동일 중첩 경로 조건에서 비교하며 일반 설치 수용 기준에는 사용하지 않는다.
