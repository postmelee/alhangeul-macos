# Task M018 #185 Stage 3 완료 보고서

## 단계 목적

현재 Pages 업데이트 페이지 디자인을 유지하면서 `v0.1.1` 후보 페이지와 업데이트 index를 추가하고, README를 최신 공개 릴리즈 1개 요약 중심으로 정리했다.

이번 단계는 public release 게시가 아니라 #188에서 사용할 사용자-facing 문서 후보와 README 운영 기준을 마련하는 단계다.

## 산출물

- `docs/updates/v0.1.1.html`: 97 lines
  - `docs/updates/v0.1.0.html`과 같은 site header, hero, action button, `updates-content`, `updates-section`, footer 구조 사용
  - 사용자용 요약, 주요 변경, 알려진 한계, 설치와 업데이트 안내 작성
  - DMG 다운로드 URL은 `releases/latest/download/alhangeul-macos-0.1.1.dmg` 기준으로 작성
- `docs/updates/index.html`: 110 lines
  - 최신 DMG 다운로드 버튼 2곳을 `alhangeul-macos-0.1.1.dmg`로 갱신
  - 릴리즈 노트 목록 최상단에 `알한글 v0.1.1` 항목 추가
- `README.md`: 403 lines
  - 장기 로드맵 상세 체크리스트를 README에서 제거하고 현재 작업 축, 최신 공개 릴리즈, 압축된 이정표로 정리
  - 최신 공개 릴리즈는 실제 공개 상태가 확인된 `v0.1.0`으로 유지
  - `v0.1.1`은 public release 완료 전 patch release 후보로만 표시

## 본문 변경 정도 / 본문 무손실 여부

- `docs/updates/v0.1.0.html`은 수정하지 않았다. 사용자가 현재 양식과 디자인이 마음에 든다고 확인한 기존 페이지는 보존했다.
- `docs/updates/v0.1.1.html`은 새 파일이며, `v0.1.0` 페이지의 class와 레이아웃 흐름을 유지했다. 본문만 `v0.1.1` 후보 내용으로 교체했다.
- Pages에는 GitHub Release 본문 수준의 긴 provenance, delta checklist, PR별 검증을 복제하지 않았다. 이 정보는 Stage 4의 `mydocs/release/v0.1.1.md`와 #188 GitHub Release 본문으로 넘긴다.
- README의 상세 로드맵 체크리스트는 의도적으로 축약했다. 제품 소개, 현재 작업 축, 최신 공개 릴리즈, 기능 설명, 렌더링 경로, 개발 안내는 유지했고 과거 릴리즈 상세가 누적되지 않는 방향으로 정리했다.
- `v0.1.1`은 아직 public release가 아니므로 README의 "최신 공개 릴리즈"는 `v0.1.0`으로 남겼다.

## 검증 결과

구현계획서 Stage 3 검증 명령을 수행했다.

```bash
git status --short --branch
```

결과:

```text
## local/task185
 M README.md
 M docs/updates/index.html
?? docs/updates/v0.1.1.html
```

```bash
rg -n "v0\\.1\\.1|alhangeul-macos-0\\.1\\.1\\.dmg|Quick Look|Thumbnail|Sparkle|업데이트 확인" docs/updates README.md
```

결과 요약:

- `docs/updates/index.html`의 header download와 hero primary action이 `alhangeul-macos-0.1.1.dmg`를 가리키는 것을 확인
- `docs/updates/index.html` 릴리즈 목록에 `알한글 v0.1.1` 항목이 추가된 것을 확인
- `docs/updates/v0.1.1.html`의 title, OG URL, hero, DMG URL, Sparkle 업데이트 확인, Quick Look/Thumbnail 안내 확인
- README에서 `v0.1.1`은 patch release 후보로만 표시되고, 최신 공개 릴리즈 본문은 `v0.1.0`으로 유지됨을 확인

```bash
rg -n "updates-hero|updates-content|updates-section|page-action-button|site-footer" docs/updates/v0.1.0.html docs/updates/v0.1.1.html
```

결과 요약:

- `v0.1.0.html`과 `v0.1.1.html` 모두 `updates-hero`, `page-action-button`, `updates-content`, `updates-section`, `site-footer` 구조를 포함한다.
- 두 페이지 모두 주요 변경/기능, 알려진 한계, 설치와 업데이트의 3개 section 흐름을 유지한다.

```bash
git diff --check
```

결과: 출력 없음, exit code 0.

```bash
wc -l README.md docs/updates/index.html docs/updates/v0.1.1.html
```

결과:

```text
     403 README.md
     110 docs/updates/index.html
      97 docs/updates/v0.1.1.html
     610 total
```

추가 브라우저 확인:

- `python3 -m http.server 8765 --bind 127.0.0.1`을 `docs/`에서 실행해 정적 페이지를 확인했다.
- `http://127.0.0.1:8765/updates/v0.1.1.html`에서 title `알한글 v0.1.1 릴리즈 노트`, hero `알한글 v0.1.1`, `주요 변경`, `설치와 업데이트`가 보이는 것을 확인했다.
- `http://127.0.0.1:8765/updates/`에서 title `알한글 업데이트`, `알한글 v0.1.1`, `alhangeul-macos-0.1.1.dmg`가 보이는 것을 확인했다.
- 확인 후 로컬 정적 서버를 종료했다.

## 잔여 위험

- `docs/updates/index.html`과 `docs/updates/v0.1.1.html`의 latest DMG URL은 #188에서 `v0.1.1` public release와 asset이 게시되어야 실제로 유효해진다.
- README는 `mydocs/release/`를 장기 기록 위치로 설명하지만, 실제 `mydocs/release/` 문서 구조는 Stage 4에서 생성한다.
- `v0.1.1` Pages 본문은 후보 문구다. #188에서 실제 GitHub Release, SHA256, appcast, public smoke 결과가 확정되면 최종 문구와 링크를 다시 확인해야 한다.
- 이번 단계는 HTML 정적 표시와 문서 기준 검증만 수행했다. 앱 바이너리, DMG, Sparkle appcast 검증은 #188 또는 Stage 5 handoff 범위다.

## 다음 단계 영향

Stage 4에서는 `mydocs/release/` 장기 기록 문서 구조와 `v0.1.1` 릴리즈 상세 문서 초안을 만든다. 또한 `release_distribution_guide.md`에서 사용자가 지적한 `v0.1` 특정 정보, 환경 의존 식별자, troubleshooting 분리 후보를 실제로 분류한다.

Stage 5에서는 GitHub Release 본문 template, Pages, README, `mydocs/release/`, 배포 매뉴얼이 같은 기준을 쓰는지 최종 dry-run으로 확인하고 #188 handoff 목록을 정리한다.

## 승인 요청

Stage 3 산출물 승인을 요청한다.

승인 후 Stage 4 `mydocs/release/ 장기 기록과 delta 검증 체크리스트 기준 구현`으로 진행한다.
