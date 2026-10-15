## 변경 내용

웹의 Mac 글꼴 설정 안내를 찾기 어려웠던 동선을 개선합니다. HTML 21개 헤더에 ‘글꼴 안내’를 추가하고 홈 v0.2.3 배너에서 ‘Mac 글꼴 설정 방법 →’으로 바로 이동할 수 있게 합니다. 글꼴 안내 헤더는 홈과 통일하고 중복된 파란 보조 문구는 제거합니다.

700px 이하에서는 로고/다운로드와 주요 메뉴를 두 줄로 표시합니다. 작은 화면에서 헤더의 보조 링크를 숨기는 경우 푸터에서 계속 접근할 수 있고, 글꼴 목차는 실제 sticky 헤더 높이를 반영합니다. 최신 소식·문의의 다운로드 URL/접근성 이름은 공식 v0.2.3으로 정렬합니다.

과거 릴리즈 본문·버전별 다운로드·news 동작과 저장소 appcast는 보존합니다. 앱·core/Studio·버전·DMG·Cask·workflow는 변경하지 않습니다.

Closes #590

## 검증

- 홈·글꼴·대표 하위 페이지·경계 폭의 실제 25개 화면 조합: 가로 넘침/헤더 겹침/잘림 없음.
- 데스크톱·모바일의 Tab/Shift+Tab·본문 바로가기·초점·Enter 진입, 목차 8개 최종 위치 및 푸터 보조 링크 접근 PASS.
- `node --test scripts/ci/test-news-ui.cjs`: 9 PASS.
- `PYTHONDONTWRITEBYTECODE=1 python3 scripts/ci/test-news-pages.py`: 14 PASS. 기존 Ruby ffi extensions 경고는 로그에 기록.
- `scripts/ci/update-release-version-notices.sh --updates-dir docs/updates --check`: v0.2.3 일치.
- 21개 헤더·본문/16개 릴리즈 보존, 로컬 링크·자산·fragment 295곳, 증거 checksum·JPEG·문서 링크·`git diff --check` PASS.

화면은 Codex 내장 브라우저 viewport에서 검증했으며 실제 휴대폰·다른 브라우저 시험은 포함하지 않습니다. 뉴스는 로컬 데이터의 비어 있는 안내 상태로 확인했습니다. 공개 CI는 게시 후 확인합니다.

## 단계별 요약

- **[Stage 1 및 1.1](https://github.com/postmelee/alhangeul-macos/blob/fe7c2c0d2f67bee3defa66346ca411be425d6536/mydocs/working/task_m020_590_stage1.md)** ([12fcbf69](https://github.com/postmelee/alhangeul-macos/commit/12fcbf69dd5374108b4708fd0c16a3750576df3b), [a626a6de](https://github.com/postmelee/alhangeul-macos/commit/a626a6dee98b416a8df310f6f6cc03eb2c789969)): 공통 진입점·모바일 배치, 글꼴 헤더 통일·중복 문구 제거.
- **[Stage 2](https://github.com/postmelee/alhangeul-macos/blob/fe7c2c0d2f67bee3defa66346ca411be425d6536/mydocs/working/task_m020_590_stage2.md)** ([1d99a8aa](https://github.com/postmelee/alhangeul-macos/commit/1d99a8aa9cd1f02711a05d3356c8dce0e5ea8238)): 전체 화면 폭·키보드·목차/진입 검증. 추가 소스 보정 없음.
- **[Stage 3](https://github.com/postmelee/alhangeul-macos/blob/fe7c2c0d2f67bee3defa66346ca411be425d6536/mydocs/working/task_m020_590_stage3.md)** ([검증·보고 커밋](https://github.com/postmelee/alhangeul-macos/commit/fe7c2c0d2f67bee3defa66346ca411be425d6536)): 기존 회귀·최종 보존 검사·최종 보고·PR 초안 준비.

## 작업 문서·화면

- [수행계획서](https://github.com/postmelee/alhangeul-macos/blob/fe7c2c0d2f67bee3defa66346ca411be425d6536/mydocs/plans/task_m020_590.md)
- [구현계획서](https://github.com/postmelee/alhangeul-macos/blob/fe7c2c0d2f67bee3defa66346ca411be425d6536/mydocs/plans/task_m020_590_impl.md)
- [최종 보고서와 데스크톱·모바일 화면](https://github.com/postmelee/alhangeul-macos/blob/fe7c2c0d2f67bee3defa66346ca411be425d6536/mydocs/report/task_m020_590_report.md)

이 PR의 대상은 `devel`입니다. 공개 웹 반영은 이후 main 인계·Pages 배포가 필요하며, 그 직전에 실제 공개 appcast 보존 입력과 동시 배포 상태를 확인해야 합니다.
