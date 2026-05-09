# 릴리즈 기록 인덱스

## 목적

이 폴더는 알한글 public release의 장기 기록을 보관한다. GitHub Release 본문, Pages 릴리즈 노트, Sparkle appcast, README가 각각 다른 독자를 대상으로 하므로, 내부 검증 기록과 release decision record는 이 폴더에 모은다.

## 문서 역할

| 문서 | 역할 |
|------|------|
| `index.md` | 릴리즈 목록, 최신 public/candidate 상태, 링크 관리 기준 |
| `v<version>.md` | 릴리즈별 decision record, 변경점, 검증, provenance, handoff |

파일명은 Git tag와 같은 semantic version을 사용한다. 예: `v0.1.1.md`.

## 릴리즈 목록

| 버전 | 상태 | GitHub Release | Pages 릴리즈 노트 | 내부 기록 |
|------|------|----------------|-------------------|-----------|
| `v0.1.1` | 후보, #188 public 배포 대기 | [예정](https://github.com/postmelee/alhangeul-macos/releases/tag/v0.1.1) | [v0.1.1](https://postmelee.github.io/alhangeul-macos/updates/v0.1.1.html) | [`v0.1.1.md`](v0.1.1.md) |
| `v0.1.0` | 공개 완료 | [Alhangeul v0.1.0](https://github.com/postmelee/alhangeul-macos/releases/tag/v0.1.0) | [v0.1.0](https://postmelee.github.io/alhangeul-macos/updates/v0.1.0.html) | [`v0.1.0.md`](v0.1.0.md) |

## 정보 소유 기준

| 표면 | 소유 정보 |
|------|-----------|
| GitHub Release | public 배포 본문, DMG asset, checksum, 사용자 설치/검증 안내 |
| Pages `docs/updates/` | 사용자용 짧은 릴리즈 노트와 최신 다운로드 진입점 |
| `docs/appcast.xml` | Sparkle client가 읽는 update feed |
| README | 프로젝트 소개, 현재 작업 축, 최신 공개 릴리즈 1개 요약 |
| `mydocs/release/` | 릴리즈별 내부 decision record, delta, 검증, provenance, #188 handoff |
| `mydocs/tech/release_environment.md` | Team ID, signing identity 표시명, notary profile name 같은 비밀이 아닌 운영 환경 식별자 |
| `mydocs/troubleshootings/` | 실제 실패 사례, 재현 조건, 원인, 재발 방지 절차 |

일반 release policy와 버전별 release decision record는 troubleshooting으로 옮기지 않는다. Gatekeeper, notarization, Finder integration, appcast push 같은 주제라도 실제 실패와 재발 방지 절차가 명확할 때만 `troubleshootings/` 문서로 분리한다.

## 릴리즈 문서 갱신 순서

1. 직전 public release tag와 release candidate commit을 확정한다.
2. `scripts/ci/write-release-delta-checklist.sh <previous-tag> <candidate-ref> <output>`로 영향 영역 초안을 만든다.
3. 릴리즈 owner가 자동 분류의 누락과 과잉을 보정한다.
4. `v<version>.md`에 사용자 요약, delta, 연결 Issue/PR, 검증 결과, known limitations, provenance, GitHub Release/Pages/appcast 링크를 기록한다.
5. GitHub Release 본문과 Pages 릴리즈 노트가 같은 version, DMG filename, SHA256, provenance 기준을 쓰는지 대조한다.
6. README에는 최신 공개 릴리즈 1개만 반영한다.

## 현재 기준 링크

- GitHub Releases: https://github.com/postmelee/alhangeul-macos/releases
- 사용자용 업데이트 페이지: https://postmelee.github.io/alhangeul-macos/updates/
- Sparkle appcast: https://postmelee.github.io/alhangeul-macos/appcast.xml
- 배포 매뉴얼: [`../manual/release_distribution_guide.md`](../manual/release_distribution_guide.md)
- 릴리즈 환경 스냅샷: [`../tech/release_environment.md`](../tech/release_environment.md)
