# Task M900 #584 v0.2.3 태그·DMG 실행 준비안

## 확정 source와 현재 승인

[PR #586](https://github.com/postmelee/alhangeul-macos/pull/586)을 **“main 병합·다음 실행 준비”** 승인으로 병합했다. 실제 main SHA는 `c9d59f9300ef78b4cc6a3a8e17a10a3d766d01d4`, tree는 `80fb5eadadbc9ff8f89a8652917e037715c077bd`다. 검토 head `5146d91e`의 제품 내용과 같고 네 source bundle은 0.2.3 / build 21, core·Studio는 공식 v0.8.7 / `1a76570e833917d15817415a53c09ad61ab3203f`다.

[source 증거](../report/assets/task_m900_584/stage3/main-merge/source-identity.json)를 기준으로 **“v0.2.3 태그 생성·push”** 승인을 받아 태그를 생성·게시했다. [새 실행 입력](../report/assets/task_m900_584/stage3/tag/release-inputs.json)은 태그의 실제 object와 commit을 고정한다. 아래 태그 명령은 실행 완료 기록이며 DMG 명령은 아직 실행하지 않은 준비안이다. 최종 DMG 생성·파일/서명·양 VM·실제 Mac·공개/업데이트 수용은 남아 있다.

## 태그 생성·원격 게시 결과

| 항목 | 정확한 입력 |
|------|-------------|
| 저장소 | postmelee/alhangeul-macos |
| 태그 | v0.2.3, annotated |
| 대상 commit | c9d59f9300ef78b4cc6a3a8e17a10a3d766d01d4 |
| 태그 메시지 | Alhangeul v0.2.3 |
| 생성 직전 중복 조회 | 로컬/원격 tag 부재와 인증된 전체 Release 목록의 0개 일치를 다시 확인 |
| 실제 태그 object | 041343f5f1c747d50ccfdaee8e8f28040527efa3 |
| 완료 시각·검증 | 2026-10-12 07:27 KST. 로컬/원격 tag object·peeled commit 일치 PASS |
| 영향 | 공개 저장소에 불변 source ref를 만든다. 기존 workflow는 tag push로 DMG를 자동 생성하지 않음 |

승인 후 실제 생성 직전 source·원격 tag·Release 중복을 다시 확인했다. 아래 두 명령을 순서대로 실행했고 ls-remote의 object/peeled commit을 [태그 증거](../report/assets/task_m900_584/stage3/tag/tag-verification.json)와 대조했다. 강제 이동·덮어쓰기는 하지 않았다.

```sh
git tag -a v0.2.3 c9d59f9300ef78b4cc6a3a8e17a10a3d766d01d4 -m 'Alhangeul v0.2.3'
git push origin refs/tags/v0.2.3:refs/tags/v0.2.3
git ls-remote --tags origin refs/tags/v0.2.3 'refs/tags/v0.2.3^{}'
```

## 다음 별도 승인 — draft 서명·공증 DMG 생성

태그가 위 commit으로 고정된 것을 확인한 뒤 **Release Publish DMG workflow 실행**을 따로 승인받는다. source의 workflow 필드와 아래 입력이 일치한다.

```sh
gh workflow run release-publish.yml --repo postmelee/alhangeul-macos --ref v0.2.3 \
  -f version=0.2.3 \
  -f previous_release_ref=v0.2.2 \
  -f expected_rhwp_tag=v0.8.7 \
  -f require_latest_rhwp=true \
  -f include_rhwp_in_title=false \
  -f draft=true \
  -f prerelease=false
```

이 실행은 GitHub Actions의 release environment에 저장된 Developer ID·공증 credential을 사용해 **미공개 draft 후보**를 만든다. 앱 설치·공개 Release 승격·Pages/Sparkle·Homebrew 게시 승인을 대신하지 않는다. [운영 준비 조회](../report/assets/task_m900_584/stage3/tag/workflow-readiness.json)에서 workflow 활성·source의 실행 입력 7개 일치·필수 secret 이름 5개 존재·기존 Developer ID 및 Team ID·notary profile 변수를 확인했다. release 환경의 ref 제한은 없으며 설정을 변경하지 않았다. secret 값은 읽지 않았고 인증서·공증 인증의 실제 유효성은 아직 미검증이다. 승인된 workflow의 import·notary credential validation·서명 preflight가 이를 판정한다.

이번 최신 조회에서도 upstream latest는 v0.8.7이고 공개 앱은 v0.2.2다. 새 source의 Release Publish run은 아직 없다. 실행 직전 upstream latest와 source/ref·Release 충돌을 다시 확인하며, latest가 v0.8.7과 다르면 입력을 임의로 완화하지 않는다.

실제 run ID·artifact ID·DMG hash/size는 아직 없다. 생성 후 동일 파일의 source·checksum·서명/공증·universal·layout을 확인해 기록하고, 그 실제 값을 제시해 release-first-install.yml의 ARM/Intel VM 수용 승인을 받는다. 최종 Mac 시험·원상복원은 이후 구체 파일·설치 대상·백업 계획으로 승인받는다.

## 승인 근거와 공개 보호

[구현계획 §4](../plans/task_m900_584_impl.md)의 “tag 생성과 Release Publish DMG 실행을 각각 승인” 규칙과 [runbook](../manual/public_release_runbook.md)의 별도 gate를 따른다. main 병합과 태그 생성·push는 각각 승인받아 완료했으며, 태그 승인을 서명/공증 실행 승인으로 확장하지 않는다.

병합 후 [Pages run 38179177872](https://github.com/postmelee/alhangeul-macos/actions/runs/38179177872)은 success / 실제 deploy job skipped다. 새 public DMG가 없어 기존 asset gate가 공개를 보류했고 appcast는 0.2.2/20·기존 bytes를 유지한다. [Stage 3 보고](task_m900_584_stage3.md)를 참고한다. #584는 전체 수용 전까지 OPEN이다.
