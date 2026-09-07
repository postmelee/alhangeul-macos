//! 합성 문서 bytes부터 C 소유권 해제까지의 Spotlight 회귀 계약.
use super::{RhwpTextStatus::*, *};
use rhwp::{serializer, DocumentCore};

fn model(text: &str) -> rhwp::model::document::Document {
    let mut core = DocumentCore::new_empty();
    core.create_blank_document_native().unwrap();
    let doc = core.document_mut();
    doc.sections[0].paragraphs[0].insert_text_at(0, text);
    doc.sections[0].raw_stream = None;
    doc.sections[0].raw_provenance = None;
    doc.clone()
}

fn extract(data: &[u8]) -> (RhwpTextStatus, String) {
    let mut output = ptr::dangling_mut();
    let mut len = usize::MAX;
    let status = rhwp_extract_text_utf8(data.as_ptr(), data.len(), &mut output, &mut len);
    if output.is_null() {
        assert_eq!(len, 0);
        return (status, String::new());
    }
    assert!(len > 0 && len <= text::LIMITS.bytes);
    let value = unsafe { std::str::from_utf8(std::slice::from_raw_parts(output, len)) }
        .expect("출력은 UTF-8")
        .to_owned();
    rhwp_free_bytes(output, len);
    (status, value)
}

#[test]
fn hwp5_hwpx_roundtrip_and_repeated_ffi_ownership() {
    let doc = model("검색검증 English 😀");
    for bytes in [
        serializer::serialize_document(&doc).unwrap(),
        serializer::hwpx::serialize_hwpx(&doc).unwrap(),
    ] {
        for _ in 0..20 {
            assert_eq!(
                extract(&bytes),
                (RHWP_TEXT_OK, "검색검증 English 😀".into())
            );
        }
    }
}

#[test]
fn empty_and_truncated_documents_have_distinct_success_statuses() {
    let bytes = serializer::hwpx::serialize_hwpx(&model(" \t\n")).unwrap();
    assert_eq!(extract(&bytes), (RHWP_TEXT_EMPTY, String::new()));
    let bytes = serializer::hwpx::serialize_hwpx(&model(&"가".repeat(400_000))).unwrap();
    let (status, output) = extract(&bytes);
    assert_eq!(status, RHWP_TEXT_TRUNCATED);
    assert_eq!(output.len(), text::LIMITS.bytes / 3 * 3);
    assert!(output.chars().all(|ch| ch == '가'));
}

#[test]
fn protected_and_malformed_inputs_never_return_body() {
    let doc = model("노출금지");
    let encrypted = serializer::hwpx::serialize_hwpx_with_password(&doc, b"test-only").unwrap();
    assert_eq!(extract(&encrypted), (RHWP_TEXT_PROTECTED, String::new()));
    // 평문 exporter는 보호 flag를 제거하므로 합성 CFB의 FileHeader만 변형한다.
    let plain = serializer::serialize_document(&doc).unwrap();
    let signature = b"HWP Document File\0";
    let offsets: Vec<_> = plain
        .windows(signature.len())
        .enumerate()
        .filter_map(|(i, bytes)| (bytes == signature).then_some(i))
        .collect();
    assert_eq!(offsets.len(), 1);
    for flag in [2u8, 4u8] {
        let mut protected = plain.clone();
        protected[offsets[0] + 36] |= flag;
        assert_eq!(extract(&protected), (RHWP_TEXT_PROTECTED, String::new()));
    }
    assert_eq!(
        extract(b"\x9b DRMONE  synthetic"),
        (RHWP_TEXT_PROTECTED, String::new())
    );
    assert_eq!(
        extract(b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1"),
        (RHWP_TEXT_PARSE_ERROR, String::new())
    );
    assert_eq!(
        extract(b"PK\x03\x04invalid"),
        (RHWP_TEXT_UNSUPPORTED, String::new())
    );
    let mut damaged = serializer::hwpx::serialize_hwpx(&doc).unwrap();
    let name = b"Contents/header.xml";
    let offset = damaged
        .windows(name.len())
        .position(|bytes| bytes == name)
        .unwrap();
    let extra = u16::from_le_bytes([damaged[offset - 2], damaged[offset - 1]]) as usize;
    damaged[offset + name.len() + extra] ^= 0xff;
    assert_eq!(
        rhwp::parser::detect_format(&damaged),
        rhwp::parser::FileFormat::Hwpx
    );
    assert_eq!(extract(&damaged), (RHWP_TEXT_PARSE_ERROR, String::new()));
    assert_eq!(
        extract(b"not a document"),
        (RHWP_TEXT_UNSUPPORTED, String::new())
    );
}

#[test]
fn validates_slots_and_input_limit_before_borrowing_bytes() {
    let mut output = ptr::dangling_mut();
    let mut len = usize::MAX;
    assert_eq!(
        rhwp_extract_text_utf8(ptr::null(), 0, &mut output, &mut len),
        RHWP_TEXT_INVALID_INPUT
    );
    assert!(output.is_null());
    assert_eq!(len, 0);
    let byte = 0;
    len = 10;
    assert_eq!(
        rhwp_extract_text_utf8(&byte, 1, ptr::null_mut(), &mut len),
        RHWP_TEXT_INVALID_INPUT
    );
    assert_eq!(len, 0);
    output = ptr::dangling_mut();
    assert_eq!(
        rhwp_extract_text_utf8(&byte, 1, &mut output, ptr::null_mut()),
        RHWP_TEXT_INVALID_INPUT
    );
    assert!(output.is_null());
    assert_eq!(
        rhwp_extract_text_utf8(&byte, RHWP_TEXT_MAX_INPUT_BYTES + 1, &mut output, &mut len),
        RHWP_TEXT_INPUT_TOO_LARGE
    );
    assert!(output.is_null());
    assert_eq!(len, 0);
    assert_eq!(
        text_guard::<()>(|| panic!("test-only unwind")),
        Err(RHWP_TEXT_PANIC)
    );
}

#[test]
fn hwp3_synthetic_plain_and_password_header() {
    // HWP3: signature 30, DocInfo 128, summary 1008, 7개 빈 font list와 styles.
    let mut bytes = vec![0u8; 30 + 128 + 1008 + 16];
    bytes[..23].copy_from_slice(b"HWP Document File V3.00");
    let word = "SpotlightLegacyBody";
    let mut paragraph = vec![0u8; 43];
    paragraph[0] = 1; // 이전 문단 형식 사용, 별도 ParaShape 없음.
    paragraph[1..3].copy_from_slice(&((word.len() + 1) as u16).to_le_bytes());
    bytes.extend_from_slice(&paragraph);
    for ch in word.encode_utf16().chain(std::iter::once(13)) {
        bytes.extend_from_slice(&ch.to_le_bytes());
    }
    bytes.extend_from_slice(&[0u8; 43]); // 문단 리스트 종료.
    assert_eq!(extract(&bytes), (RHWP_TEXT_OK, word.into()));
    bytes[126] = 1; // DocInfo encrypted (30 + 96).
    assert_eq!(extract(&bytes), (RHWP_TEXT_PROTECTED, String::new()));
}

#[test]
fn public_corpus_remains_searchable() {
    for (path, needle) in [
        ("samples/re-05-mixed-koen-hancom.hwp", "한글"),
        ("samples/inner-table-01.hwp", ""),
        ("samples/table-in-tbox.hwp", ""),
        ("samples/eq-01.hwp", ""),
        ("samples/hwpx/ref/ref_text.hwpx", ""),
    ] {
        let bytes = std::fs::read(
            std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
                .join("..")
                .join(path),
        )
        .unwrap();
        let (status, output) = extract(&bytes);
        assert_eq!(status, RHWP_TEXT_OK, "{path}");
        assert!(!output.is_empty(), "{path}");
        assert!(output.contains(needle), "{path}");
    }
}
