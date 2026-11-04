# HFT 대응 글꼴 공급 진단

Task #598의 공식 upstream 릴리스 전 준비 도구다. 제품 Swift 공급 계층과 JavaScript provider를 연결하여 후보·bytes·세대 무효화를 검사한다. HFT 문서를 열거나 원본 대응 OTF/TTF를 선택하는 도구는 아니다. [진단 계약](../../mydocs/tech/task_m020_598_font_supply_contract.md)을 함께 읽는다.

공식 릴리스 반영을 재개할 때는 [인계 문서](../../mydocs/tech/task_m020_598_release_handoff.md)의 기준 커밋·자산 확보·동기화·수용 순서를 따른다.

## 실행

저장소 루트에서 macOS, Xcode Command Line Tools의 `xcrun swiftc`, Node.js, Python 3.9 이상이 필요하다. 검증 환경은 Swift 6.3.3, Node 24.15.0, Python 3.9.6이다. Rust framework와 GUI는 필요하지 않다.

```bash
python3 scripts/probe-hft-font-supply.py --mode fixtures \
  --output-dir build.noindex/task598/fixtures-run1

python3 scripts/probe-hft-font-supply.py --mode installed --family '딸기' \
  --output-dir build.noindex/task598/installed-run1

node --test scripts/ci/test-hft-font-supply.cjs \
  scripts/ci/test-studio-font-provider.cjs scripts/ci/test-studio-font-bootstrap.cjs
python3 scripts/test-hft-font-supply-runner.py
```

출력은 `build.noindex` 아래 **새 디렉터리**여야 한다. 재실행할 때 다른 이름을 사용한다. 기존 파일·결과를 덮어쓰거나 symlink로 외부에 출력하는 경로는 거부한다.

`fixtures`는 자체 제작 fixture의 검사·읽기를 수행하며 scan metadata와 권한 오류를 주입한다. 제품 InstalledFontCatalogService, FontLibraryStore/Service, StudioFontSupply, StudioFontSession 및 Swift에 내장된 실제 JavaScript adapter를 실행한다. TTF만/OTF만/양쪽/없음, Book/빈 style, 권한 거부/손상, 동일 PS 충돌, 관리 우선의 10개 시나리오를 검사한다. 한글 별칭은 관리 보관함의 실제 name table 전달과 영문으로 주입한 설치 metadata의 차이를 관측한다. `both`의 두 fixture는 서로 다른 PS이며 실제 같은 HFT 원본의 OTF/TTF 쌍이 아니다.

`installed`는 실제 InstalledFontSystem scan/read를 사용한다. `--family`와 CoreText family/full/PostScript 이름의 NFC·대소문자 무시 **완전 일치**로 대상을 제한한다. 전체 목록의 metadata는 열거하지만 파일 bytes는 필터와 provider를 통과한 후보만 읽는다. 한글 이름이 0건이면 확인된 영문 family/PS로 별도 실행할 수 있다. 임의 이름 치환이나 부분 문자열 검색은 하지 않는다. 대상 0건은 이 CLI 프로세스의 관측이며 Mac 전체 부재나 앱 sandbox의 실패를 의미하지 않는다.

실행 도구의 격리 환경에서는 파일이 존재해도 CoreText 목록에 나타나지 않을 수 있다. 실제 대상과 함께 이미 활성화된 대조 글꼴도 조회하고, 필요하면 macOS 사용자의 일반 터미널에서 비교한다. Stage 3에서는 제한된 실행의 Pretendard/Hack 0건이 제한 밖 CLI에서는 정상 공급으로 바뀌었다. 이 차이를 제품 App Sandbox 권한 검증과 혼동하지 않는다. [Stage 3 기록](../../mydocs/working/task_m020_598_stage3.md)을 참고한다.

## 결과와 종료 코드

`result.json`에 실행 커밋·dirty 상태, 도구 버전, core/Studio/matcher commit, 실제 입력 소스·fixture 해시, 후보 metadata, bytes SHA256/길이/signature, 검사별 판정이 남는다. 미커밋 도구로 실행했다면 `sourceCommit`만으로 재현하지 말고 `inputHashes`도 비교한다. compile 실패는 `compile.log`, 그 외 실행 오류는 `failedPhase`로 구분한다. 출력 경로/인자 오류는 실행 전 거부되므로 결과 파일을 만들지 않는다.

`request`는 대조 시나리오의 조건을 나타낸다. installed의 family는 목록 필터에 사용하지만 fixture family/weight/slant로 문서 matcher를 실행하지 않는다. 실제 공급한 face는 `observations.candidates`와 `reads`로 확인한다.

| 종료 코드 | 의미 |
|-----------|------|
| 0 | 요청한 공급 검사 완료. `supplyComplete=true` |
| 1 | 계약 실패 또는 도구 실행 오류. 원인을 수정한 뒤 재실행 |
| 2 | 실제 대상 후보 미확보. 공급 검증 미완료 |

정확한 `permissionDenied`/`corrupt`와 미공급을 확인한 주입 음성 대조는 PASS다. 알 수 없는 읽기 오류는 FAIL이다. 정상 반환 bytes는 Swift openFace의 hash·길이, fixture hash·signature와 대조한다. 실제 설치 모드는 fixture 동일성을 요구하지 않고 제품의 실제 검사·전송 결과를 관측한다.

`summary.complete`는 selection/layout/render가 NOT_RUN인 동안 false다. 종료 코드 0이나 공급 PASS를 HFT 문제 해결·문서 출력 성공으로 해석하지 않는다. refresh는 native 세대 폐기, provider 구독 통지, 새 revision, 이전 revision의 read 거부를 검사한다. OS 설치 이벤트나 열린 문서 재조판 완료는 검사하지 않는다.

## 격리와 한계

사용자 글꼴 설치/등록, 앱 설정·사용자 보관함 변경, 인증서 사용·별도 codesign 명령은 없다. 컴파일러가 만드는 CLI를 실행하며 App Sandbox를 재현하지 않는다. 테스트 저장소는 출력 아래 임시 `private-state`를 사용하고 정상·처리된 실패 종료 시 제거한다. 프로세스 강제 종료 뒤 이 디렉터리가 남았다면 공개 자료에 넣지 않는다.

Swift↔Node 글꼴 bytes는 메모리의 JSON-lines pipe로만 전송한다. 영구 결과에는 원본 경로·bookmark·bytes를 넣지 않는다. 컴파일 로그에는 로컬 소스 경로가 있을 수 있으므로 공유 전에 확인한다. `build.noindex` 전체나 상용 글꼴을 커밋하지 않는다.

HostApp message handler의 loadToken 검증, WKWebView, upstream matcher의 실제 선택, native renderer, PDF/인쇄/Finder 출력, 최소 지원 OS/Intel 검증은 범위 밖이다. 실제 문제 글꼴·문서와 공식 릴리스 반영 후 별도 수용 검증이 필요하다.
