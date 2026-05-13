# Task M018 #208 Stage 4 보고서

## 단계 목적

README, GitHub Release note template, v0.1.1 release record, release manuals에 Intel Mac + Apple Silicon 지원과 단일 universal DMG 기준을 반영한다. Stage 3에서 Pages direct DMG 다운로드 정책을 확정했으므로, 이번 단계는 사용자/릴리스 운영 문서가 같은 정책을 따르도록 정리하는 데 집중했다.

## 변경 요약

| 파일/대상 | 변경 내용 |
|-----------|-----------|
| `README.md` | v0.1.1 후보 설명과 Release / Install 섹션에 단일 universal DMG, `arm64 + x86_64`, Intel Mac/Apple Silicon 동일 파일 기준 추가 |
| `scripts/ci/write-release-notes.sh` | GitHub Release body 후보에 “지원 환경과 아키텍처” 섹션 추가, 단일 universal DMG/Homebrew/Sparkle 전제와 실제 Intel smoke 기록 기준 추가 |
| `scripts/ci/check-release-notes-template.sh` | 새 필수 heading `## 지원 환경과 아키텍처` 검증 추가 |
| `mydocs/release/v0.1.1.md` | #208 변경점, universal app/extension 검증, #188 public smoke handoff, 단일 DMG URL 전제와 checklist 보강 |
| `mydocs/manual/release_policy_guide.md` | public DMG를 단일 universal DMG로 운영하고 Pages/Sparkle/Homebrew가 같은 URL을 쓰는 정책 추가 |
| `mydocs/manual/release_packaging_dmg_guide.md` | Release/package/public/rehearsal 경로에서 app/extension `arm64 + x86_64` 검증 기준 추가 |
| `mydocs/manual/release_github_pages_sparkle_guide.md` | release note, Pages, Sparkle enclosure, Homebrew Cask 안내가 단일 universal DMG 기준임을 명시 |
| `mydocs/manual/release_distribution_guide.md` | release flow와 최종 checklist에 universal slice 검증, Intel smoke 기록, 단일 URL 대조 추가 |
| `mydocs/manual/ci_workflow_guide.md` | rehearsal/publish workflow 설명과 로컬 release checks 재현에 universal 검증 기준 추가 |
| `mydocs/manual/release_homebrew_cask_guide.md` | Cask가 `on_arm`/`on_intel` 분기 없이 같은 public universal DMG URL/SHA256을 사용한다는 기준 추가 |

## 정책 결정 기록

- v0.1.1 public DMG는 `alhangeul-macos-0.1.1.dmg` 단일 파일이다.
- 이 DMG는 앱 본체와 Quick Look/Thumbnail extension 실행 파일이 `arm64 + x86_64` slice를 포함해야 한다.
- Intel Mac과 Apple Silicon Mac을 위해 별도 DMG를 나누지 않는다.
- Pages latest download, Sparkle appcast enclosure, Homebrew Cask `url`은 같은 public universal DMG를 기준으로 맞춘다.
- 실제 Intel Mac 실기기 smoke는 실행한 경우에만 성공으로 기록하고, 실행하지 못하면 #188 public smoke handoff에 사유를 남긴다.
- #209 Homebrew 공개 전에는 Homebrew 설치 명령을 사용자-facing 확정 설치 경로로 안내하지 않는다.

## 검증 결과

| 검증 | 결과 |
|------|------|
| `bash -n scripts/ci/*.sh` | 통과 |
| `scripts/ci/write-release-notes.sh 0.1.1 <dummy-sha> build.noindex/release/release-notes-0.1.1-stage4.md` | 통과 |
| `scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.1-stage4.md` | 통과 |
| `rg -n "선택 UI\|아키텍처별\|on_arm\|on_intel\|분리 DMG\|universal DMG\|Intel Mac\|Apple Silicon\|arm64 \\+ x86_64" ...` | 변경 대상 문서/템플릿의 단일 universal DMG 기준 확인 |
| `git diff --check` | 통과 |

## 남은 작업

Stage 5에서는 #208 전체 변경을 통합 검증한다. 이미 Stage 2에서 generic Release build와 package script 검증을 수행했으므로, Stage 5에서는 현 HEAD 기준 script syntax, release note generation, Pages 정적 링크, universal helper, 필요 범위의 release/package 검증 결과를 다시 정리하고 최종 보고 단계로 넘긴다.

## Stage 5 승인 요청

Stage 5에서 통합 검증과 #188/#209 handoff 정리를 진행한다.
