# Task M900 #584 Stage 5 실제 업데이트·Homebrew 실행안

## 공개 배포와 별도 경계

**2026-10-15 작업지시자가 “Sparkle·Homebrew 시험/반영·앱 없음 복원까지 허용”으로 승인했다. 실제 시험·tap PR #2 병합·원상복원은 종료했으며 [Stage 5 보고](task_m900_584_stage5.md)에 결과를 기록했다. 아래는 실행 전 준비한 계획이다.**

작업지시자가 승인한 동일 v0.2.3/21 DMG의 공개 승격·Pages/Sparkle 피드 배포는 run 38629062837로 실행 중이다. 이 문서는 실제 Mac의 앱 설치·업데이트 시험과 별도 tap 저장소 반영 범위를 구체화한다. 준비만으로 실행·성공을 기록하지 않는다.

## 실제 Sparkle 시험

- 실행 직전 /Applications/Alhangeul.app 부재를 다시 확인한다. 예상과 다르면 덮어쓰지 않는다.
- 공식 v0.2.2/20 DMG를 public URL에서 받아 SHA256 8d8b8cbd24376fcd2c7ebd48343be44edc1f0f154a1e75282714798806ed4b90·서명을 확인하고 임시 설치한다. 새 로컬 서명·공증은 하지 않는다.
- 기존 사용자 문서·OS 글꼴·전역 색인을 바꾸지 않는다. 현재 사용자가 직접 검색하는 SpotlightCheck 폴더도 유지한다.
- 앱 실행 전에 실제 UUID sandbox를 metadata로 해결하고 최근 문서 key·sfl4, 글꼴 catalog/공유 policy·권한, 재색인 receipt와 시험으로 바뀔 Sparkle key만 비공개 백업한다. 사용자 동시 변경이 있으면 무조건 덮어쓰지 않고 멈춘다.
- 앱의 Sparkle UI로 0.2.3/21 발견·실제 다운로드·설치·자동 재실행을 확인한다. 도구 getApp이 앱을 다시 켜기 전에 새 PID·실제 설치 bundle을 확인해 자동 재실행과 구분한다.
- 소유 HWP/HWPX만 열어 문서·설정·Finder 제공자를 확인한다. Spotlight는 이번 수용 보정대로 환경 미확인·후속 조사로 유지하며 대기나 전역 재색인을 추가하지 않는다.
- 시험 후 정상 종료하고 소유 등록·앱·mount·시험 파일만 정리한다. 관련 설정/최근 문서의 현재 시험 사전 상태와 앱 없음 상태를 복원한다. 과거 10월 13일 이력 공백을 해결했다고 기록하지 않는다.

## Homebrew

- 대상: postmelee/homebrew-tap의 Casks/alhangeul.rb. 현재 원격 blob은 5dd3cb3aac343a0ef848e5393e6ec446ea42b8cd다. 실행 직전 다시 확인한다.
- public 신규 다운로드에서 hash를 확인한 동일 DMG d0050cb7de5d3fea17708aef1bebb7da54d326c7a540afbaf28276c3e50b1e63 / 211405232 bytes만 사용한다.
- 아래 version/hash 두 줄만 변경하는 검토용 브랜치·PR을 준비하고 기존 코드·이력을 보존한다. 저장소 Casks/alhangeul.rb도 같은 값으로 정렬한다.
- style·일반 audit 및 소유 격리 캐시를 사용하는 install/uninstall smoke를 실행한다. 현재 Homebrew receipt·앱 상태를 먼저 확인하고 기존 사용자 설치가 있으면 계획을 보정한다. --zap·사용자 설정 초기화·전역 캐시 초기화는 하지 않는다. 설치 시험 종료 후 앱 없음 상태로 복원한다.
- tap 게시/병합·Homebrew 설치 시험은 구현계획 §6과 Homebrew 매뉴얼의 별도 승인 항목이다.

```diff
--- 기존 tap Cask
+++ v0.2.3 Cask
@@ -1,6 +1,6 @@
 cask "alhangeul" do
-  version "0.2.2"
-  sha256 "8d8b8cbd24376fcd2c7ebd48343be44edc1f0f154a1e75282714798806ed4b90"
+  version "0.2.3"
+  sha256 "d0050cb7de5d3fea17708aef1bebb7da54d326c7a540afbaf28276c3e50b1e63"

   url "https://github.com/postmelee/alhangeul-macos/releases/download/v#{version}/alhangeul-macos-#{version}.dmg"
   name "알한글"
```
