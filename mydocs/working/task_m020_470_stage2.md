# Task M020 #470 Stage 2 완료보고서

## 결과

`renderPageTreeThrowing(at:)`를 추가하고 기존 optional API는 `try?`로 위임한다. 음수/UInt32 범위 밖 page와 producer의 null JSON을 구분한다. C 문자열은 `defer`로 복사 후 해제한다. native smoke/debug helper는 구조화된 오류를 출력하며 제품 wrapper에는 로그를 추가하지 않았다.

실제 smoke에서 기존 decoder가 숨긴 타입 불일치를 발견했다. pinned rhwp `f1f9c6a`의 `renderer/render_tree.rs`는 section/para/control/char_start에 usize를 사용하고, `layout.rs`는 머리말에서 `usize::MAX - i` marker를 사용한다. KTX TextLine의 para_index는 `18446744073709551615`와 `18446744073709551608`을 포함했다. 해당 Swift index metadata를 UInt로 맞춰 손실 없이 보존한다. 필드를 optional/default로 완화하지 않았다. Foundation의 비-DecodingError에도 최소 known payload path와 `unexpectedDecoderError`를 남긴다.

## 검증

- decoder의 16개 기존/신규 계약과 UInt.max marker 보존/음수 거부 추가 2개 통과.
- native smoke: KTX 415 TextRun/458075 non-white pixels, request 103/71110, exam_kor 133/173728, hwpx-01 269/132731 통과.
- smoke에서 실제 RhwpDocument의 음수/UInt32 범위 밖 page, optional nil, pageCount 경계의 FFI null-output 오류 구분을 검증했다.
- no-AppKit, diff check 통과. 산출물은 `build.noindex/task470/`.
- core/native 상세 비교와 HostApp compile은 Stage 3에서 수행한다. 원본 sample과 core pin은 변경하지 않았다.
