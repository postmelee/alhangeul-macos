# Task #55 Stage 2 완료 보고서

## 단계 목적

release tag dependency 전환 전에 확인해야 하는 core API contract, render tree JSON contract, compatibility gate, 실패 유형, #30 unblock checklist를 독립 기술 문서로 정리한다.

## 산출물

- `mydocs/tech/core_release_compatibility.md`: 274 lines
- `mydocs/working/task_m010_55_stage2.md`: Stage 2 완료 보고서

소스, lock, 스크립트, 매뉴얼 본문은 변경하지 않았다.

## 본문 변경 정도 / 본문 무손실 여부

신규 기술 문서를 추가했다. 기존 문서 본문을 수정하지 않았으므로 기존 내용 손실은 없다.

`core_release_compatibility.md`에는 다음 내용을 포함했다.

- release tag + resolved commit 안정 기준
- release tag 전환 후 `rhwp-core.lock`이 가져야 할 필드 의미
- `Cargo.lock`과 `rhwp-core.lock` resolved commit 정합성 기준
- 2026-04-26 확인 기준 최신 release `v0.7.3` 상태
- `RustBridge` core API contract
- render tree JSON contract와 현재 schema version 부재 처리 기준
- latest release 조회부터 render smoke까지의 compatibility gate
- `missing core API`, `Cargo.lock mismatch`, `artifact hash mismatch`, `FFI symbol diff`, `render smoke failure` 실패 유형
- #30 unblock checklist
- SVG fallback이 #30 unblock 조건이 아니라는 경계

## 검증 결과

diff check:

```text
$ git diff --check -- mydocs/tech/core_release_compatibility.md mydocs/working/task_m010_55_stage2.md
결과: 통과.
```

Stage 2 검색 게이트:

```text
$ rg -n "build_page_render_tree|get_bin_data|render_page_svg_native|get_page_info_native|extract_thumbnail_only|release tag|resolved commit|unblock" mydocs/tech/core_release_compatibility.md
결과: 필수 core API, release tag, resolved commit, #30 unblock checklist 문구 확인.
```

라인 수 확인:

```text
$ wc -l mydocs/tech/core_release_compatibility.md
274 mydocs/tech/core_release_compatibility.md
```

## 잔여 위험

- Stage 2는 문서화 단계이므로 실제 release tag dependency 전환이나 `Cargo.lock` 검증 구현은 수행하지 않았다.
- `v0.7.3` 이후 새 release가 나오면 latest release와 resolved commit은 다시 확인해야 한다.
- compatibility gate 명령은 문서화되었지만, 후속 Stage 4에서 script가 최소 안내 또는 dry-run 검증을 제공해야 하는지는 다시 판단해야 한다.

## 다음 단계 영향

Stage 3에서는 기존 운영 매뉴얼과 build/run 문서가 `core_release_compatibility.md`로 자연스럽게 연결되도록 보강한다. 특히 현재 submodule 임시 운용 절차와 후속 release tag dependency 전환 기준을 분리해 설명해야 한다.

## 승인 요청

Stage 2 문서 작성을 완료했다. Stage 3 core 운영 매뉴얼과 build/run 문서 보강으로 진행할지 승인 요청한다.
