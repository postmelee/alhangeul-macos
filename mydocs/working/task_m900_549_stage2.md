# Task M900 #549 Stage 2 — Homebrew 배포·실제 설치 수용

2026-09-15 공개 tap [PR #1](https://github.com/postmelee/homebrew-tap/pull/1)을 검토 후 병합했다. main은 `5844bad4bdf6c3b314957a337d53957ce33284e3`이다. 저장소와 tap Cask 모두 0.2.2 및 공개 DMG SHA256 `8d8b8cbd24376fcd2c7ebd48343be44edc1f0f154a1e75282714798806ed4b90`으로 일치한다.

| 실제 검증 | 결과 |
|---|---|
| `brew style --cask alhangeul` | PASS, 위반 없음 |
| `brew audit --cask alhangeul` | PASS |
| `brew audit --cask --new alhangeul` | 참고 검사도 PASS |
| 이전 공개 tap `brew install --cask postmelee/tap/alhangeul` | 0.1.11(17) 설치·receipt·서명 PASS |
| 공개 tap main 갱신 후 `brew upgrade --cask postmelee/tap/alhangeul` | 0.1.11 → 0.2.2(20), receipt·서명 PASS |
| `brew uninstall --cask alhangeul` | 앱 제거 PASS, zap 없이 사용자 설정 유지 |
| 다시 `brew install --cask postmelee/tap/alhangeul` | 0.2.2(20) 설치·receipt·서명 PASS |
| 앱 첫 실행·About | 0.2.2(20), rhwp v0.8.6 표시 |
| 설치 전 공개 앱과 최종 앱 비교 | Info.plist·실행 파일 SHA256 동일 |
| Finder preview/thumbnail 제공자 | 모두 `/Applications/Alhangeul.app` 내부 0.2.2, 선택 표시 `+` |
| Spotlight 번들 계약·실제 importer | PASS, `mdimport -t`가 설치 앱 importer 선택 |
| 기존 두 corpus 본문 검색 | 영문 6개·한글 4개 유지, 수동 재색인 없음 |
| 등록 hygiene | PASS, 개발 산출물 등록 없음 |

`mdimport -L` 목록에 알한글이 나오지 않아 이 목록만으로 실패 판정하지 않았다. 실제 `mdimport -t`와 검색 결과를 함께 확인했다. 현재 Mac은 설치 이력이 있으므로 Homebrew 제거·신규 설치를 깨끗한 OS 최초 설치로 부르지 않는다. 새 VM·실제 Sparkle·문서/Finder GUI는 동일 DMG의 기존 [v0.2.2 기록](../release/v0.2.2.md)을 연결한다. 이전 복구 후보는 #525를 위해 유지했다.

[구조화 결과](../report/assets/task_m900_549/homebrew-validation.json)와 같은 디렉터리의 명령 로그에 근거를 보존했다. audit 다운로드의 임시 서명 URL은 공개 로그에서 제거했다. 실행 때 사용한 전용 Homebrew 캐시와 audit이 새로 만든 homebrew/core tap은 최종 배포 완료 후 정리한다.

![Homebrew 최종 설치본 About](../report/assets/task_m900_549/homebrew-about.jpg)
