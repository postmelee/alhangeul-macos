# Task #78 Stage 2 완료 보고서

## 단계 목적

Apple Developer Program 가입 완료 이후 준비된 Developer ID Application signing identity와 `notarytool` keychain profile을 릴리스/배포 가이드에 반영하고, 저장소에 기록 가능한 운영 값과 기록 금지 secret의 경계를 명확히 한다.

## 산출물

- `mydocs/manual/release_distribution_guide.md`: Apple Developer Program 준비 상태와 secret 관리 원칙 갱신
- `mydocs/working/task_m050_78_stage2.md`: Stage 2 완료 보고서

## 본문 변경 정도 / 본문 무손실 여부

- 기존 release 자산, 확정 기준, public/rehearsal DMG 설명은 유지했다.
- 권한 원칙에 secret 기록 금지 기준을 보강했다.
- `Apple Developer Program 준비 상태` 섹션을 추가했다.
- `공개 release 전 확정 항목`에서 credential 미준비 전제를 제거하고 실제 실행 시점은 작업지시자 명시 지시에 따르도록 보정했다.

## 주요 변경

문서에 기록한 비밀이 아닌 운영 값:

- Team ID: `XH6JHKYXV8`
- Developer ID Application signing identity: `Developer ID Application: Taegyu Lee (XH6JHKYXV8)`
- notarytool keychain profile: `alhangeul-notary`

문서에 기록하지 않는 값:

- Apple ID password
- app-specific password
- App Store Connect API private key(`.p8`)
- exported signing identity(`.p12`)와 password
- Keychain에 저장된 notarytool credential payload

## 검증 결과

구현 계획서의 Stage 2 검증 명령을 실행했다.

```bash
rg --line-number 'XH6JHKYXV8|Developer ID Application: Taegyu Lee|alhangeul-notary|app-specific password|\\.p8|\\.p12|비밀|secret' mydocs/manual/release_distribution_guide.md
```

결과:

- Team ID, Developer ID Application signing identity, notarytool keychain profile 기록 확인
- app-specific password, `.p8`, `.p12` 기록 금지 항목 확인
- 비밀이 아닌 운영 식별자만 문서에 기록한다는 원칙 확인

```bash
git diff --check
```

결과: 통과

## 잔여 위험

- 이 단계는 문서 갱신만 수행했으므로 실제 signing identity와 keychain profile의 현재 사용 가능성은 별도로 재검증해야 한다.
- public DMG 생성 명령 예시와 preflight 확인 명령은 Stage 3에서 실제 운영 값 기준으로 더 구체화한다.

## 다음 단계 영향

Stage 3에서는 `release_distribution_guide.md`의 public DMG 생성 예시, signing identity 확인, `notarytool` profile 확인, public/rehearsal DMG 경계를 갱신한다.

## 승인 요청

Stage 3 진행 승인을 요청한다.
