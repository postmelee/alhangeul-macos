# Task M013 #330 Stage 2 보고서

## 단계 목적

GitHub 공개 body file에서 PR/Issue 참조 토큰 직후 한글이 붙는 위험 패턴을 차단하는 공통 validator를 추가하고, 실패/통과 샘플을 검증한다.

## 산출물

| 파일 | 내용 |
|------|------|
| `scripts/validate-github-body.sh` | GitHub body file에서 `#328으로`, `PR #328은`, `Issue #132를` 같은 참조 토큰+한글 붙임 패턴을 검사하는 shell script 추가 |
| `mydocs/working/task_m013_330_stage2.md` | Stage 2 구현과 검증 결과 기록 |

## 구현 내용

- `scripts/validate-github-body.sh`를 추가했다.
- script는 body file 경로를 1개 이상 인자로 받는다.
- `rg --pcre2`와 Unicode property matching을 preflight로 확인한다.
- 검사 패턴은 다음과 같다.

```text
(?:(?:PR|Issue)[[:space:]]+)?#[0-9]+\p{Hangul}
```

- 이 패턴은 다음 위험 사례를 잡는다.
  - `#328으로`
  - `PR #328은`
  - `Issue #132를`
- 다음처럼 참조 토큰을 분리한 표현은 통과한다.
  - `#328 반영으로`
  - `PR #328 반영은`
  - `Issue #132 이슈를`
- script는 잘못된 사용과 검사 실패를 구분한다.
  - 금지 패턴 발견: exit 1
  - 인자 없음, 파일 없음, `rg`/PCRE2 지원 없음: exit 2

## 구현 중 발견한 문제와 보정

초기 구현에서 `rg`가 "매치 없음"으로 반환하는 exit 1을 shell `if` 바깥에서 읽으려다 정상 통과 케이스를 오류로 처리했다. `if rg ...; then ... else status=$? ... fi` 구조로 고쳐 `rg` exit status를 정확히 보존했다.

## 검증 결과

| 명령 | 기대 | 결과 |
|------|------|------|
| `bash -n scripts/validate-github-body.sh` | shell syntax 통과 | OK |
| `scripts/validate-github-body.sh /tmp/task330-bad.md` | 금지 패턴 3개 출력 후 exit 1 | OK |
| `scripts/validate-github-body.sh /tmp/task330-good.md` | exit 0 | OK |
| `scripts/validate-github-body.sh` | usage 출력 후 exit 2 | OK |
| `scripts/validate-github-body.sh /tmp/task330-missing.md` | 파일 없음 오류 후 exit 2 | OK |

### 실패 샘플

```text
PR #328은 처리됨
#328으로 해결
Issue #132를 닫음
```

실행 결과:

```text
error: GitHub reference tokens must be separated from Korean particles.

Use forms like "#328 반영으로", "PR #328 반영은", or "Issue #132 이슈를".
Problem lines:
1:PR #328은 처리됨
2:#328으로 해결
3:Issue #132를 닫음
```

### 통과 샘플

````text
PR #328 반영은 완료됨
#328 반영으로 해결
Issue #132 이슈를 닫음

```text
gh pr checks 328 --repo postmelee/alhangeul-macos
```
````

실행 결과: exit 0

## 남은 리스크

- 이 validator는 한국어 조사를 문법적으로 분석하지 않고, 참조 토큰 직후 한글이 붙는 위험 패턴을 conservative하게 차단한다.
- GitHub 웹 UI에서 직접 작성한 본문/코멘트는 이 script로 사전 차단할 수 없다.
- code block 안에 금지 패턴 예시를 일부러 넣은 공개 body file도 실패한다. 공개 등록 전 body validator라는 목적상 허용 가능한 보수 동작으로 본다.

## 다음 단계

Stage 3에서 매뉴얼과 tracked Skill 절차를 `--body-file` + `scripts/validate-github-body.sh` 흐름으로 보정한다.

## 승인 요청

Stage 2 결과 기준으로 Stage 3 매뉴얼과 Skill 절차 보정에 들어가도 되는지 승인 요청한다.
