# Task M020 #513 Stage 1 — 기준 확인과 최초 발견 실패 재현

## 결과

선행 #341 universal Release ad-hoc 패키지로 새 중첩 격리 경로의 발견 실패를 재현했다. 일반 txt 본문 대조는 PASS, 복사·서명 검사·일반 등록 후 60초 및 첫 실행 후 60초의 importer 발견은 모두 MISS다. 앱 프로세스는 실제 실행됐고 LaunchServices는 앱 내부 Spotlight library item과 코드 신뢰 정보를 기록했다. 따라서 앱 실행 요청 실패나 bundle 내부 경로 누락만으로 설명되지 않는다.

## 기준

- 코드 기준: `489f5339820ea38602cfec49af949cd907cfd078`.
- 원본 `package/release`와 `post-reboot-package`의 앱/importer 실행 파일 hash는 같다. 둘 다 `codesign --verify --deep --strict`를 통과했다.
- 앱 SHA-256: `4c198d77a558b7523c9d2a935442c47b5d2feaef8e4ff21ebed3978c9b9034b5`.
- importer SHA-256: `c3230cad403408f060d23b7841b10354279cd0e47f420ce3e1bec26ec31fd3d8`.
- fixture: #342 v4, 독립 한글 단어를 포함한 합성 corpus. 이전 시험 6개의 상태는 cleaned, 기존 격리 폴더와 활성 후보 프로세스는 없었다.
- 원시 결과: 로컬 `build.noindex/task513/baseline-state.json` 및 해당 evidence 폴더. 계정/경로가 포함된 진단은 공개하지 않는다.

## 다음 조사

기존 helper는 prepare/index에서 수동 재색인하고 install에서 수동 등록한다. 이 결과는 순수 자동 최초 설치 판정과 구분해야 한다. 자동 모드에서 수동 명령을 제거하고, 동일 bytes/새 경로로 등록 순서·위치·timestamp를 각각 분리한다. [Apple 문서](https://developer.apple.com/library/archive/documentation/Carbon/Conceptual/MDImporters/Concepts/Troubleshooting.html)는 첫 실행 시 발견과 업데이트 시 변경 시각의 중요성을 설명하지만, 이 관찰만으로 touch를 제품 해결책으로 채택하지 않는다.
