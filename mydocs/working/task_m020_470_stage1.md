# Task M020 #470 Stage 1 완료보고서

known RenderNodeType 24개(19 payload, 5 unit)를 명시적으로 판별한다. payload key가 있으면 `try`로 decode하고 실패를 known variant 문맥과 함께 전파한다. unknown 단일 string/object는 forward compatible `.unknown`이며, 빈/multiple tag object와 known tag의 잘못된 표현은 실패한다.

`RenderTreeDecodingFailure`는 schema coding path, known variant, DecodingError 분류만 보존한다. raw value, debugDescription, underlyingError는 저장하지 않는다. arbitrary dynamic enum tag는 path에 그대로 기록하지 않는다. `RenderTreeDecoder.decode`는 envelope 오류도 동일 구조로 변환한다.

검증: current/legacy/TextRun 성공 3개, future variant 성공 2개, malformed payload/envelope/tag/privacy 진단 11개 통과. 중첩 오류는 `variant=TextRun path=$.children[0].node_type.TextRun.text cause=keyNotFound`로 확인했다. no-AppKit와 diff check 통과. 로그는 `build.noindex/task470-decoder.log`.
