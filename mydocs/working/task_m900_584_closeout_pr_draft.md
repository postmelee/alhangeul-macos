v0.2.3(21)의 검증된 동일 DMG 공개와 실제 업데이트·Homebrew 수용 결과를 기록하고, README와 웹의 Homebrew 안내를 실제 제공 버전에 맞춥니다. 기존 ‘미공개 후보 / Homebrew 0.2.2’ 안내가 ‘공개 v0.2.3 / Homebrew 0.2.3’으로 바뀝니다.

- 이 PR은 아직 공개하지 않은 Stage 3~5 검증 증거·보고서를 함께 포함합니다. 제품 변경은 Cask version/hash와 공개 안내에 한정됩니다.
- 공개 승격 run 38629062837의 promote/Pages 성공, 신규 public 다운로드 hash·기존 자산 ID 유지와 실제 Sparkle 0.2.2→0.2.3 다운로드·설치·자동 재실행을 확인했습니다.
- Mac 글꼴 ON/재실행 유지·HWP/HWPX·Quick Look·새 경로 썸네일, tap PR postmelee/homebrew-tap#2 의 style/audit·병합과 Homebrew 제거/신규 설치·서명/공증/universal을 검증했습니다.
- 관련 설정·최근 문서/sfl4·글꼴 정책·기존 Homebrew metadata와 앱 없음 상태를 복원했고 사용자 TXT/Finder 검색 창을 유지했습니다.
- 실제 Mac Spotlight 검색은 양 VM 검색·실제 Mac 본문 추출 대체 근거로 수용했습니다. 원인·회귀 여부는 미확정이며 별도 후속 #587로 추적합니다. 과거 최근 문서 이력 공백과 #480/#525 한계도 남겨 둡니다.

검증: Ruby 문법, 실제 tap style/audit·설치 검증, Pages 조립과 공개 appcast bytes 보존, Homebrew 업데이트 탭 화면, 문서 링크·이미지 형식·checksum·공백 검사. 제품 Swift/Rust/Studio·버전·태그·DMG는 변경하지 않습니다.

main 병합은 README·홈/업데이트의 Homebrew 안내를 정렬하고 docs-only Pages 배포를 유발합니다. public 0.2.3/21 appcast를 보존하며 새 업데이트 서명·제품 재빌드는 하지 않습니다. 병합 후 devel로 문서/Cask 변경을 인계합니다.

이번 릴리즈 PR: #585(준비), #586(main), postmelee/homebrew-tap#2(Cask), 이번 종료 정리 PR과 이후 devel 인계 PR입니다. 준비·불변 제품 공개·별도 tap·필수 통합 브랜치 인계의 경계를 구분합니다.

Closes #584
