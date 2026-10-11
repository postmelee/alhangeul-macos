# Task M900 #584 v0.2.3 태그·DMG 실행 준비안

## 확정 source와 현재 승인

[PR #586](https://github.com/postmelee/alhangeul-macos/pull/586)을 **“main 병합·다음 실행 준비”** 승인으로 병합했다. 실제 main SHA는 `c9d59f9300ef78b4cc6a3a8e17a10a3d766d01d4`, tree는 `80fb5eadadbc9ff8f89a8652917e037715c077bd`다. 검토 head `5146d91e`의 제품 내용과 같고 네 source bundle은 0.2.3 / build 21, core·Studio는 공식 v0.8.7 / `1a76570e833917d15817415a53c09ad61ab3203f`다.

[source 증거](../report/assets/task_m900_584/stage3/main-merge/source-identity.json)를 기준으로 **“v0.2.3 태그 생성·push”** 승인을 받아 태그를 생성·게시했다. 아래 태그 명령과 DMG dispatch 명령은 실행 기록이다. **“draft DMG 생성·다운로드/검증 승인”**으로 [run 38180977764](https://github.com/postmelee/alhangeul-macos/actions/runs/38180977764)를 실행했고 success / attempt 1로 완료했다. [동일 DMG 파일 검증](../report/assets/task_m900_584/stage3/publish/file-verification.json)과 cleanup도 PASS다. 양 VM·실제 Mac·공개/업데이트 수용은 남아 있다.

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

## 승인된 draft 서명·공증 DMG 생성

태그가 위 commit으로 고정된 것과 upstream latest·main/devel content gate·Release/기존 run 부재를 다시 확인한 뒤 **Release Publish DMG workflow 실행·다운로드/파일 검증**을 따로 승인받아 실행했다. source의 workflow 필드와 아래 입력이 일치한다.

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

이 실행은 GitHub Actions의 release environment에 저장된 Developer ID·공증 credential을 사용해 **미공개 draft 후보**를 만들었다. 앱 설치·공개 Release 승격·Pages/Sparkle·Homebrew 게시 승인을 대신하지 않는다. [운영 준비 조회](../report/assets/task_m900_584/stage3/tag/workflow-readiness.json)에서 준비 상태를 확인한 뒤 실제 workflow의 인증서 import·notary credential validation·서명 preflight를 통과했다. App·DMG 제출 모두 [Apple Accepted](../report/assets/task_m900_584/stage3/publish/ci-notarization.json)이며 다운로드 원본의 strict seal·stapler·Gatekeeper도 확인했다. secret 값이나 환경 보호 설정은 바꾸지 않았다.

이번 최신 조회에서도 upstream latest는 v0.8.7이고 공개 앱은 v0.2.2다. 생성 직전 동일 source의 Release Publish run은 없었으며 승인 후 run 38180977764를 생성했다. 실행 직전 upstream latest와 source/ref·Release 충돌을 다시 확인하며, latest가 v0.8.7과 다르면 입력을 임의로 완화하지 않는다.

| 산출물 | 확정된 값 |
|--------|------------|
| publish run / attempt | 38180977764 / 1, success |
| public-dmg artifact ID | 11717953850 |
| DMG SHA256 | d0050cb7de5d3fea17708aef1bebb7da54d326c7a540afbaf28276c3e50b1e63 |
| DMG size | 211405232 bytes |
| draft Release / DMG asset | 409973398 / 632029048, draft=true·prerelease=false |
| 파일 검증 | checksum·이미지 무결성·strict/deep seal·공증/Gatekeeper·네 bundle 0.2.3/21 및 universal·9개 서명 component·Legal/Studio/endpoint·실제 Finder 설치 화면 PASS |
| 후보 로컬 경로 | build.noindex/task584/stage3/publish/candidate/alhangeul-macos-0.2.3.dmg |
| artifact 만료 | 2026-10-26 07:58:32 KST |

## 다음 별도 승인 — ARM/Intel 새 VM 설치·재설치

[확정 VM 입력](../report/assets/task_m900_584/stage3/publish/vm-inputs.json)으로 같은 artifact의 동일 DMG를 검증한다. 아래 명령은 **미승인·미실행 준비안**이다.

```sh
gh workflow run release-first-install.yml --repo postmelee/alhangeul-macos --ref v0.2.3 \
  -f source_run_id=38180977764 \
  -f source_artifact_id=11717953850 \
  -f source_sha=c9d59f9300ef78b4cc6a3a8e17a10a3d766d01d4 \
  -f dmg_sha256=d0050cb7de5d3fea17708aef1bebb7da54d326c7a540afbaf28276c3e50b1e63 \
  -f expected_version=0.2.3 \
  -f expected_build=21
```

대상은 새 GitHub runner macos-15/arm64 및 macos-15-intel/x86_64다. 소유 합성 corpus 준비·최초 설치·종료 후 검색·재설치·실제 importer·lifecycle 33개·cleanup·schema 3 verdict를 확인하고 maintained/recovered를 구분한다. 생성 파일의 사전 검증 PASS를 VM PASS로 바꾸지 않는다. 사용자 실제 Mac 설치나 공개 배포는 포함하지 않는다. 최종 Mac 시험·원상복원은 이후 구체 파일·설치 대상·백업 계획으로 승인받는다.

## 승인 근거와 공개 보호

[구현계획 §4](../plans/task_m900_584_impl.md)의 “tag 생성과 Release Publish DMG 실행을 각각 승인” 규칙과 [runbook](../manual/public_release_runbook.md)의 별도 gate를 따른다. main 병합·태그 생성/push·draft DMG 실행/파일 검증을 각각 승인받았다. 설치·공개 승인으로 확장하지 않는다.

병합 후 [Pages run 38179177872](https://github.com/postmelee/alhangeul-macos/actions/runs/38179177872)은 success / 실제 deploy job skipped다. 새 public DMG가 없어 기존 asset gate가 공개를 보류했고 appcast는 0.2.2/20·기존 bytes를 유지한다. [Stage 3 보고](task_m900_584_stage3.md)를 참고한다. #584는 전체 수용 전까지 OPEN이다.
