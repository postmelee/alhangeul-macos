# Task M900 #584 v0.2.3 태그·DMG 실행 준비안

## 확정 source와 현재 승인

[PR #586](https://github.com/postmelee/alhangeul-macos/pull/586)을 **“main 병합·다음 실행 준비”** 승인으로 병합했다. 실제 main SHA는 `c9d59f9300ef78b4cc6a3a8e17a10a3d766d01d4`, tree는 `80fb5eadadbc9ff8f89a8652917e037715c077bd`다. 검토 head `5146d91e`의 제품 내용과 같고 네 source bundle은 0.2.3 / build 21, core·Studio는 공식 v0.8.7 / `1a76570e833917d15817415a53c09ad61ab3203f`다.

[source 증거](../report/assets/task_m900_584/stage3/main-merge/source-identity.json)와 [실행 입력](../report/assets/task_m900_584/stage3/main-merge/release-inputs.json)을 기준으로 한다. 아래 명령은 준비안이며 아직 실행하지 않았다. 최종 DMG 생성·파일/서명·양 VM·실제 Mac·공개/업데이트 수용은 남아 있다.

## 다음 승인 — 태그 생성·원격 게시

| 항목 | 정확한 입력 |
|------|-------------|
| 저장소 | postmelee/alhangeul-macos |
| 태그 | v0.2.3, annotated |
| 대상 commit | c9d59f9300ef78b4cc6a3a8e17a10a3d766d01d4 |
| 태그 메시지 | Alhangeul v0.2.3 |
| 중복 조회 | 로컬/원격 tag 부재. tag Release API 404와 인증된 전체 Release 목록의 0개 일치를 함께 확인 |
| 영향 | 공개 저장소에 불변 source ref를 만든다. 기존 workflow는 tag push로 DMG를 자동 생성하지 않음 |

승인 후 실제 실행 직전 source·원격 tag·Release 중복을 다시 확인한다. 대상 SHA가 바뀌거나 tag가 이미 있으면 강제 이동·덮어쓰기하지 않는다.

```sh
git tag -a v0.2.3 c9d59f9300ef78b4cc6a3a8e17a10a3d766d01d4 -m 'Alhangeul v0.2.3'
git push origin refs/tags/v0.2.3:refs/tags/v0.2.3
git ls-remote --tags origin refs/tags/v0.2.3 'refs/tags/v0.2.3^{}'
```

## 이후 별도 승인 — draft 서명·공증 DMG 생성

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

이 실행은 GitHub Actions의 release environment에 저장된 Developer ID·공증 credential을 사용해 **미공개 draft 후보**를 만든다. 앱 설치·공개 Release 승격·Pages/Sparkle·Homebrew 게시 승인을 대신하지 않는다. 실행 직전 upstream latest와 variable/secret 준비 상태를 비밀값 노출 없이 다시 확인하며, latest가 v0.8.7과 다르면 입력을 임의로 완화하지 않는다.

실제 run ID·artifact ID·DMG hash/size는 아직 없다. 생성 후 동일 파일의 source·checksum·서명/공증·universal·layout을 확인해 기록하고, 그 실제 값을 제시해 release-first-install.yml의 ARM/Intel VM 수용 승인을 받는다. 최종 Mac 시험·원상복원은 이후 구체 파일·설치 대상·백업 계획으로 승인받는다.

## 승인 근거와 공개 보호

[구현계획 §4](../plans/task_m900_584_impl.md)의 “tag 생성과 Release Publish DMG 실행을 각각 승인” 규칙과 [runbook](../manual/public_release_runbook.md)의 별도 gate를 따른다. main 병합 승인을 태그나 서명/공증 실행 승인으로 확장하지 않는다.

병합 후 [Pages run 38179177872](https://github.com/postmelee/alhangeul-macos/actions/runs/38179177872)은 success / 실제 deploy job skipped다. 새 public DMG가 없어 기존 asset gate가 공개를 보류했고 appcast는 0.2.2/20·기존 bytes를 유지한다. [Stage 3 보고](task_m900_584_stage3.md)를 참고한다. #584는 전체 수용 전까지 OPEN이다.
