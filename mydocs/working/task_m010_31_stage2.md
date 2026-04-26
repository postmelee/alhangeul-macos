# Task #31 Stage 2 완료 보고서

## 단계 목적

README의 신규 진입자용 설명과 프로젝트 구조 섹션을 제품 타깃 경계 중심으로 재정렬한다. 이번 단계에서는 README만 수정하고, architecture/build guide/source/project 설정은 변경하지 않는다.

## 변경 파일

- `README.md`
- `mydocs/orders/20260426.md`
- `mydocs/working/task_m010_31_stage2.md`

## 변경 내용

README 상단:

- 현재 v0.1.0 배포 목표가 Demo/Preview release임을 명시했다.
- Demo/Preview는 필요한 bridge API가 포함된 resolved commit을 `rev`로 고정하고, Stable release는 upstream release tag가 같은 API를 포함할 때 별도 승격한다고 정리했다.

최근 변경:

- `v0.7.3` 관련 설명을 “즉시 전환 불가”가 아니라 “Stable release tag 승격이 blocked” 상태로 보정했다.

Quick Start:

- 존재하지 않는 “온보딩 가이드(추후 추가 예정)” 안내를 제거했다.
- 신규 진입자는 README의 Project Structure, architecture 문서, build/run guide 순서로 읽도록 연결했다.
- 실제 build 순서를 Rust bridge 산출물 생성 -> Xcode project 생성 -> HostApp build로 짧게 설명했다.

rhwp Core Update:

- 현재 v0.1.0은 Demo/Preview release 목표이므로 `--channel demo --rev`가 기본 경로라고 명시했다.
- Stable release는 release tag + resolved commit을 고정하는 별도 승격 경로이며, 현재 `v0.7.3`은 `build_page_render_tree`, `get_bin_data`가 없어 기준을 충족하지 못한다고 정리했다.

Project Structure:

- 기존 tree 중심 설명을 제품 타깃 -> 공통 Swift 계층 -> Rust bridge -> generated artifact/운영 파일 순서로 재작성했다.
- `Sources/HostApp`, `Sources/QLExtension`, `Sources/ThumbnailExtension`을 독립 제품 타깃으로 먼저 노출했다.
- `Sources/Shared`와 `Sources/RhwpCoreBridge`의 차이를 README 구조 섹션에서도 드러냈다.
- `RustBridge`, `Frameworks`, `project.yml`, `rhwp-core.lock`, `samples`, `scripts`, `mydocs`의 역할을 포함했다.
- `project.yml`이 `AlhangeulMac.xcodeproj`의 원본이라는 규칙을 구조 섹션에도 반복했다.
- `hwpql`에서 참고한 것은 제품 타깃 책임을 먼저 드러내는 설명 방식이며, HTML/WKWebView 중심 viewer/preview, embedded preview only 정책, coarse-grained FFI 구조는 도입하지 않는다고 짧게 명시했다.

## 본문 변경 정도 / 본문 무손실 여부

README의 기존 빌드 명령, render smoke 명령, Finder smoke 명령, hyper-waterfall 운영 설명은 유지했다. 구조 설명은 더 짧아졌지만, `mydocs/` 하위 상세 디렉터리 설명은 뒤쪽 “문서 생성 규칙” 섹션에 이미 있어 정보 손실로 보지 않는다.

source, Xcode target, `project.yml`, build script, lock 파일은 변경하지 않았다.

## 검증 결과

diff whitespace:

```text
$ git diff --check
결과: 통과
```

placeholder 제거:

```text
$ rg --line-number '온보딩 가이드|추후 추가 예정' README.md
결과: 출력 없음
```

`hwpql` 비교 문맥:

```text
$ rg --line-number 'HTML/WKWebView|embedded preview only|coarse-grained FFI|hwpql' README.md mydocs/tech mydocs/manual Sources RustBridge --glob '!RustBridge/target/**'
README.md:332:이 구조 설명은 `hwpql`처럼 제품 타깃의 책임을 먼저 드러내는 방식을 참고합니다. 다만 이 프로젝트는 HTML/WKWebView 중심 viewer/preview, embedded preview only 정책, coarse-grained FFI 구조를 도입하지 않고, native render tree와 Swift/Rust bridge 경계를 장기 방향으로 유지합니다.
```

project 원본 규칙:

```text
$ rg --line-number 'RhwpMac.xcodeproj.*직접|xcodeproj.*원본|project.yml' README.md mydocs
결과: README와 active architecture/build guide에서 `project.yml` 원본 규칙 확인. 과거 report/working/plan 문서는 역사 기록으로 분류.
```

Demo/Preview와 Stable 표현:

```text
$ rg --line-number 'Demo/Preview|Stable|release tag|resolved commit|git dependency|rev|tag' README.md
결과: README 상단, 이정표, core update, project structure에서 Demo/Preview commit pin과 Stable release tag 승격 경로가 확인됨.
```

제품 타깃/공통 계층 구조 표현:

```text
$ rg --line-number 'Sources/HostApp|Sources/QLExtension|Sources/ThumbnailExtension|Sources/Shared|Sources/RhwpCoreBridge|RustBridge/|Frameworks/|project.yml|rhwp-core.lock|samples/' README.md
결과: Project Structure와 관련 설명에서 주요 경계가 모두 확인됨.
```

README submodule 표현:

```text
$ rg --line-number 'Vendor/rhwp|git submodule|submodule' README.md
결과: 출력 없음
```

## 잔여 위험

- hwpql 비교는 README에서 짧게만 처리했다. 상세 비교와 active 문서 전체 검색 gate는 Stage 5에서 다시 다루는 것이 맞다.
- README에 `Frameworks/`를 generated artifact로 명시했지만, 생성 산출물의 세부 구조와 검증 절차는 build/run guide가 계속 소유한다.
- README의 architecture mermaid는 아직 Stage 2에서 손대지 않았다. Stage 3 architecture 문서 보정 후 필요하면 README diagram도 함께 판단한다.

## 다음 단계

Stage 3에서는 `mydocs/tech/project_architecture.md`를 제품 타깃 중심으로 재정렬한다. README에서 정리한 제품 타깃 -> 공통 계층 -> Rust bridge -> generated artifact 흐름과 일관되게 맞춘다.

## 승인 요청

Stage 2 README 재정렬을 완료했다. 이 보고서 기준으로 Stage 3 `architecture 문서의 상위 구조, 소유 경계, runtime flow를 제품 타깃 중심으로 보정`을 진행할지 승인 요청한다.
