# Task M018 #184 Stage 4 완료 보고서

## 단계 목적

Stage 3 rehearsal DMG와 사용자 시각 검증에서 확정한 DMG layout 기준을 public release 운영 문서에 반영한다. signed/notarized public DMG 생성, GitHub Release 게시, appcast/Cask 갱신은 수행하지 않는다.

## 산출물

- `mydocs/manual/release_distribution_guide.md`
  - 사용자 설치 안내 기준에 DMG root 구성, 설치 창 안내, 첫 실행 문구 기준을 추가했다.
  - release pipeline 검증 절에 DMG layout smoke 기준을 추가했다.
  - public/rehearsal DMG 설명과 릴리스 체크리스트에 layout smoke 반복 확인 항목을 추가했다.
- `mydocs/orders/20260509.md`
  - #184 상태를 Stage 4 완료 후 최종 보고 승인 대기로 갱신했다.
- `mydocs/working/task_m018_184_stage4.md`
  - Stage 4 문서 보강 결과와 검증 내용을 기록했다.

## 반영 기준

Stage 3에서 확정한 기준을 public release 문서의 진실 원천으로 정리했다.

- DMG root에는 `Alhangeul.app`과 `Applications` symlink만 사용자에게 노출한다.
- `설치 안내.txt`는 두지 않는다.
- 설치 안내는 DMG background와 release note/README/Homebrew caveats에 유지한다.
- background는 `.background/alhangeul-dmg-background.png`, 720x460 PNG를 기준으로 한다.
- Retina/multi-representation TIFF background는 현재 Finder 환경에서 확대 표시 문제가 재현되어 public 기준으로 쓰지 않는다.
- rehearsal DMG layout smoke가 정상이어도 signed/notarized public DMG 생성 후 같은 smoke를 반복한다.

## 변경 내용

`사용자 설치 안내 기준`에는 다음을 추가했다.

- DMG 설치 창 root 구성과 background 안내 기준
- 첫 실행 안내 문구: `설치 후 앱을 한 번 실행해야 Quick Look/Thumbnail이 활성화됩니다.`

`release pipeline 검증`에는 `DMG layout smoke` 절을 추가했다.

- root 노출 파일
- background PNG 파일명과 크기
- TIFF 사용 금지 판단
- Finder window/icon 위치 확인
- public DMG에서 smoke 반복 기준

`공개 배포용 DMG`, `Rehearsal DMG`, `릴리스 체크리스트`에는 layout metadata 적용과 public DMG layout smoke 확인 항목을 추가했다.

## 검증 결과

문서 내용 검색:

```text
$ rg -n "DMG layout smoke|설치 안내.txt|alhangeul-dmg-background|720x460|multi-representation|Quick Look/Thumbnail이 활성화" mydocs/manual/release_distribution_guide.md
```

기대 결과:

- 사용자 설치 안내 기준에 첫 실행 문구가 존재한다.
- DMG layout smoke 절에 root 구성과 background 기준이 존재한다.
- `설치 안내.txt`를 root에 두지 않는 기준이 존재한다.
- multi-representation TIFF를 public 기준으로 쓰지 않는 근거가 존재한다.

최종 검증:

```text
$ git diff --check
# 출력 없음, 성공
```

```text
$ rg -n "설치 안내.txt|multi-representation|720x460|alhangeul-dmg-background.png|public DMG layout smoke" mydocs/manual/release_distribution_guide.md mydocs/working/task_m018_184_stage4.md
# 기대 항목 출력, 성공
```

## 잔여 위험

- Stage 4는 문서 보강 단계라 signed/notarized public DMG를 새로 만들지 않았다.
- public DMG signing/notarization/staple 후 Finder metadata와 background 표시가 유지되는지는 #188 public release 실행 시 다시 확인해야 한다.
- TIFF/Retina background는 이번 환경에서 실패로 정리했지만, 다른 도구나 Finder 버전에서 다른 결과가 나올 수 있다. 별도 호환성 검증 없이 public 기준으로 재도입하지 않는다.

## 다음 단계 영향

다음 단계에서는 최종 보고서와 PR 게시 준비로 넘어간다.

- Stage 1~4 변경과 검증 결과를 최종 보고서에 요약한다.
- #184 범위의 변경 파일과 커밋 목록을 정리한다.
- public release 실행은 이 작업 범위에서 수행하지 않았음을 명확히 남긴다.

## 승인 요청

Stage 4 결과를 승인해주면 최종 보고서 작성과 PR 게시 준비 단계로 진행한다.
