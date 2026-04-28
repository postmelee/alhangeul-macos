# Task #78 Stage 1 완료 보고서

## 단계 목적

현행 릴리스/배포 문서와 `scripts/release.sh`의 public release 입력값을 대조해, Apple Developer Program 가입 이후 수정해야 할 문서 지점을 분류한다.

## 산출물

- `mydocs/working/task_m050_78_stage1.md`: Stage 1 점검 결과 보고서

Stage 1은 조사 단계이므로 `README.md`, `mydocs/manual/release_distribution_guide.md`, `scripts/release.sh` 본문은 변경하지 않았다.

## 본문 변경 정도 / 본문 무손실 여부

- 본문 변경 없음
- 기존 release manual, README, release script 내용 무손실

## 점검 결과

`scripts/release.sh --help` 기준 public release 입력값은 다음 네 가지다.

- `ALHANGEUL_DEVELOPER_ID_APPLICATION`
- `ALHANGEUL_NOTARY_PROFILE`
- `ALHANGEUL_DEVELOPER_ID_DMG`
- `ALHANGEUL_BUILD_ROOT`

현행 `release_distribution_guide.md`는 위 환경변수를 이미 설명하고 있으며, public mode가 수행하는 app signing, app notarization, app staple, DMG signing, DMG notarization, DMG staple, Gatekeeper 검증 흐름도 script와 일치한다.

다만 다음 문서 지점은 Apple Developer Program credential 준비 완료 상태와 맞지 않거나, 실제 운영 값을 반영해야 한다.

- `공개 release 전 확정 항목`: Developer ID 서명/notarization 실행을 "credential 준비 후"로만 설명한다.
- `릴리스 전 확인`: public release 산출물 준비 조건은 맞지만, 현재 준비된 identity/profile 값을 별도로 보여주지 않는다.
- `Release pipeline dry check`: credential 누락 실패 확인이 중심이라 준비 완료 이후의 profile 확인 명령이 없다.
- `공개 배포용 DMG`: 예시 identity가 placeholder 상태다.
- `주의`: "public mode는 Apple Developer Program credential 없이 실행하지 않는다"는 원칙은 유지하되, 현재 준비된 credential profile 사용법을 함께 적어야 한다.
- `Rehearsal DMG`: "credential이 없거나"라는 표현은 이제 "public release 전 layout만 확인할 때" 중심으로 보정하는 편이 자연스럽다.

README는 release packaging 상세를 복제하지 않고 `릴리스/배포 가이드`로 연결하고 있으므로, Stage 4에서 링크와 표현만 확인하면 충분하다.

## 검증 결과

구현 계획서의 Stage 1 검증 명령을 실행했다.

```bash
rg --line-number 'Apple Developer|Developer ID|notarytool|notarization|ALHANGEUL|공증|서명|credential|public mode|rehearsal' README.md mydocs/manual/release_distribution_guide.md scripts/release.sh
```

결과:

- `scripts/release.sh`에서 public release 환경변수와 notarization submit/staple 흐름 확인
- `release_distribution_guide.md`에서 Developer ID, notarytool, rehearsal/public mode 관련 문구 확인
- README에서는 release packaging 상세가 아니라 roadmap/checklist/manual link 수준으로만 노출됨 확인

```bash
./scripts/release.sh --help
```

결과:

- public release environment로 `ALHANGEUL_DEVELOPER_ID_APPLICATION`, `ALHANGEUL_NOTARY_PROFILE`, `ALHANGEUL_DEVELOPER_ID_DMG`, `ALHANGEUL_BUILD_ROOT` 출력 확인
- 예시 명령은 placeholder identity와 `alhangeul-notary` profile을 사용함 확인

```bash
git diff --check
```

결과: 통과

## 잔여 위험

- Stage 1은 정적 문서/script 대조만 수행했으므로 실제 public release signing/notarization 성공은 검증하지 않았다.
- 현재 준비된 `Developer ID Application: Taegyu Lee (XH6JHKYXV8)` identity와 `alhangeul-notary` profile은 사용자 로컬 Keychain 상태에 의존한다.

## 다음 단계 영향

Stage 2에서는 `release_distribution_guide.md`에 비밀이 아닌 운영 값과 secret 관리 원칙을 반영한다. 실제 public release 실행은 하지 않는다.

## 승인 요청

Stage 2 진행 승인을 요청한다.
