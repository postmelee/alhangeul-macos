# Task #148 Stage 2 완료 보고서: v0.1 배포 수준과 사용자 안내 기준 확정

## 단계 목적

v0.1 public 배포 기준을 `Developer ID signed + notarized DMG`로 명확히 하고, unsigned/ad-hoc/rehearsal 산출물을 일반 사용자 배포 기준에서 제외하는 운영 기준을 문서화했다. README에는 공개 사용자용 최소 설치 안내를 추가하고, 상세 release 판단은 `release_distribution_guide.md`를 진실 원천으로 유지했다.

## 산출물

| 파일 | 변경 요약 |
|------|-----------|
| `mydocs/manual/release_distribution_guide.md` | `v0.1 배포 수준 결정`과 `사용자 설치 안내 기준` 섹션 추가 |
| `README.md` | `Release / Install` 섹션 추가 |
| `mydocs/working/task_m010_148_stage2.md` | Stage 2 완료 보고서 추가 |

변경량:

```text
README.md                                   |  8 ++++++
mydocs/manual/release_distribution_guide.md | 38 +++++++++++++++++++++++++++++
2 files changed, 46 insertions(+)
```

## 본문 변경 정도 / 본문 무손실 여부

- 기존 release 절차, credential 원칙, public DMG/rehearsal DMG/Homebrew Cask 기준은 삭제하지 않았다.
- 수행계획서와 구현계획서의 Stage 2 범위에 맞춰 배포 수준 판단과 사용자 설치 안내 기준만 추가했다.
- README에는 secret, notarization credential, 운영 절차를 복제하지 않고 public 설치 기준과 source build 전환 안내만 추가했다.

## 변경 내용

### v0.1 배포 수준

`mydocs/manual/release_distribution_guide.md`에 배포 수준 비교 표를 추가했다.

- unsigned app/DMG: public 배포 기준 아님
- ad-hoc signed app/DMG: public 배포 기준 아님
- Developer ID signed, not notarized: public 배포 기준 아님
- Developer ID signed + notarized DMG: v0.1 public 기본값
- Mac App Store: v0.1 범위 밖, 후속 배포 lane

운영 기준도 함께 정리했다.

- public 사용자는 `scripts/release.sh <version>` public mode로 생성한 `alhangeul-macos-<version>.dmg`를 받는다.
- `--skip-notarize` rehearsal DMG, 개발용 zip, unsigned/ad-hoc 산출물은 GitHub Release public asset이나 Homebrew Cask URL에 사용하지 않는다.
- public DMG의 `.sha256` 파일을 GitHub Release와 release note에 공개하고, Cask `sha256`은 이 digest로 고정한다.

### 사용자 설치 안내 기준

release guide에는 release note, README, Homebrew caveats에 공통 적용할 기준을 정리했다.

- DMG 파일명과 `/Applications` 복사 방식
- 앱 최초 실행으로 Quick Look/Thumbnail extension 등록 유도
- Finder에서 Space preview와 thumbnail 확인
- Gatekeeper/quarantine 문제를 기본 설치 경로로 다루지 않는 원칙
- GitHub Release `.sha256`과 다운로드 DMG checksum 비교
- Homebrew 안내는 notarized DMG 업로드와 sha256 고정 이후에만 포함

README에는 다음 public 안내를 추가했다.

- v0.1 public 배포 기준은 Developer ID signed/notarized DMG
- GitHub Release 게시 후 DMG와 checksum을 함께 공개
- Homebrew Cask는 같은 notarized DMG와 고정 sha256을 기준으로 제공
- 설치 후 앱을 한 번 실행해 Quick Look/Thumbnail extension 등록
- release 게시 전에는 source build 사용

## 검증 결과

구현계획서 Stage 2 검증 명령을 실행했다.

```bash
rg --line-number 'unsigned|ad-hoc|Developer ID|notarized|Gatekeeper|quarantine|Quick Look|Thumbnail|rehearsal' \
  README.md mydocs/manual/release_distribution_guide.md
```

결과: README의 `Release / Install` 섹션과 release guide의 `v0.1 배포 수준 결정`, `사용자 설치 안내 기준`, 기존 public/rehearsal DMG 섹션에서 필요한 문구를 확인했다.

대표 확인 라인:

```text
README.md:209:v0.1 public 배포 기준은 Developer ID로 서명하고 Apple notarization을 통과한 DMG입니다.
README.md:211:설치 후에는 `AlhangeulMac.app`을 한 번 실행하세요.
README.md:213:릴리스가 게시되기 전에는 아래 소스 빌드 절차를 사용하세요. unsigned, ad-hoc signed, rehearsal DMG는 일반 사용자 배포 산출물이 아닙니다.
mydocs/manual/release_distribution_guide.md:73:v0.1 public release의 기본 배포 수준은 **Developer ID signed + notarized DMG**로 둔다.
mydocs/manual/release_distribution_guide.md:86:`--skip-notarize` rehearsal DMG, 개발용 zip, unsigned/ad-hoc 산출물은 GitHub Release public asset 또는 Homebrew Cask URL에 사용하지 않는다.
```

추가 검증:

```bash
git diff --check
```

결과: 통과.

## 잔여 위험

- 실제 public DMG 생성과 notarization submission은 아직 실행하지 않았다.
- GitHub Release가 아직 게시되지 않았으므로 README의 설치 안내는 “게시되면” 기준이다.
- Homebrew Cask의 실제 installability는 public DMG 업로드와 sha256 고정 후에 확정된다.
- App Store 배포는 Stage 4에서 후속 lane으로만 정리할 예정이며, 이번 단계에서 제출 준비를 완료하지 않았다.

## 다음 단계 영향

Stage 3에서는 Homebrew Cask와 release 준비 자동화 보강으로 넘어간다. Cask sha256 고정 자동화, public/rehearsal DMG 혼동 방지, Homebrew tap 운영 방식을 점검해야 한다. Stage 3 진행 중 Homebrew 배포 대상을 작업지시자에게 확인한다.

## 승인 요청

Stage 2를 완료했다. 이 보고서 기준으로 Stage 3 `Homebrew Cask와 release 준비 자동화 보강`을 진행할지 승인 요청한다.
