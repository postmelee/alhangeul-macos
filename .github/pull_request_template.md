## 요약

<!--
이 PR이 해결하는 문제와 핵심 변경을 간결하게 적습니다.
최종 보고서가 있는 task PR은 최종 보고서의 압축본으로 작성합니다.
-->

- 

## 변경 내역

<!--
stage 기반 작업이면 Stage 기준으로 적습니다.
작은 변경이면 파일/기능 단위로 적어도 됩니다.
-->

- **Stage 1**: 
- **Stage 2**: 

## 검증

<!--
실제로 실행한 검증만 체크합니다. 실행하지 않은 항목은 지우거나 미체크로 둡니다.
-->

- [ ] `git diff --check`
- [ ] `./scripts/check-no-appkit.sh`
- [ ] `./scripts/build-rust-macos.sh`
- [ ] `xcodegen generate`
- [ ] `xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build`
- [ ] `./scripts/validate-stage3-render.sh`
- [ ] Finder / Quick Look / Thumbnail 수동 확인

## 문서

<!--
관련 계획서, 단계 보고서, 최종 보고서, troubleshooting 문서를 적습니다.
해당 없는 항목은 삭제합니다.
-->

- 수행 계획서: 
- 구현 계획서: 
- 단계 보고서: 
- 최종 보고서: 

## 관련 이슈

<!--
merge 시 issue를 닫아도 되는 task PR이면 Closes #번호를 사용합니다.
아직 issue를 닫으면 안 되면 Related #번호 또는 Refs #번호를 사용합니다.
-->

Closes #

## 남은 리스크

<!--
리뷰어가 알고 있어야 하는 미해결 항목, 검증 한계, 후속 task 후보를 적습니다.
없으면 "없음"으로 적습니다.
-->

- 

## 스크린샷

<!--
UI, Finder, Quick Look, Thumbnail 표시 변경처럼 시각 확인이 필요한 경우 첨부합니다.
해당 없으면 이 섹션을 삭제합니다.
-->
