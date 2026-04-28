# Task #82 Stage 4 완료 보고서

## 단계 목적

`validate-stage3-render.sh`가 자체 사용법을 설명할 수 있도록 `--help`/`-h` usage를 추가했다. 사용법 확인은 Rust bridge 산출물이 없어도 실행 가능하게 유지했다.

## 산출물

| 파일 | 변경 요약 |
|------|-----------|
| `scripts/validate-stage3-render.sh` | `usage()` 함수와 `--help`/`-h` 처리 추가 |
| `mydocs/manual/build_run_guide.md` | `--help`로 사용법을 확인할 수 있다는 안내 추가 |

## 본문 변경 정도 / 본문 무손실 여부

기존 기본 호출 `./scripts/validate-stage3-render.sh`와 custom 호출 `./scripts/validate-stage3-render.sh <output-dir> <sample...>` 동작은 유지했다. 첫 번째 인자가 `--help` 또는 `-h`일 때만 usage를 출력하고 종료한다.

## 검증 결과

### shell syntax

```bash
bash -n scripts/validate-stage3-render.sh
```

결과: 통과.

### help 출력

```bash
./scripts/validate-stage3-render.sh --help
./scripts/validate-stage3-render.sh -h
```

결과: 두 명령 모두 usage를 출력하고 exit code 0으로 종료했다. 출력에는 기본 output dir, 기본 샘플, smoke 검사 항목, pixel equivalence test가 아니라는 한계가 포함됐다.

### diff check

```bash
git diff --check
```

결과: 통과.

## 잔여 위험

- unknown option을 별도로 차단하지 않았다. 기존 스크립트는 첫 인자를 output dir로 받는 구조라, 보수적으로 `--help`와 `-h`만 특수 처리했다.
- 실제 render smoke full run은 Stage 4 범위가 usage 보강에 한정되어 실행하지 않았다. 최종 보고에서 제외 사유를 다시 기록한다.

## 다음 단계 영향

Stage 5에서는 전체 문서 링크와 검색 gate를 최종 확인하고, 최종 보고서와 오늘할일 완료 처리를 진행한다.

## 승인 요청

Stage 4 산출물 검토 후 Stage 5 진행 승인을 요청한다.
