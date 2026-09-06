//! 설치/검색 smoke 전용 합성 문서. 실제 사용자 문서를 복사하지 않는다.
use rhwp::{model::document::Document, serializer, DocumentCore};
use std::{env, fs, path::Path};

fn model(text: &str) -> Document {
    let mut core = DocumentCore::new_empty();
    core.create_blank_document_native().unwrap();
    let document = core.document_mut();
    document.sections[0].paragraphs[0].insert_text_at(0, text);
    document.sections[0].raw_stream = None;
    document.sections[0].raw_provenance = None;
    document.clone()
}

fn hwp3(text: &str) -> Vec<u8> {
    assert!(text.is_ascii());
    let mut bytes = vec![0; 30 + 128 + 1008 + 16];
    bytes[..23].copy_from_slice(b"HWP Document File V3.00");
    let mut paragraph = vec![0; 43];
    paragraph[0] = 1;
    paragraph[1..3].copy_from_slice(&((text.len() + 1) as u16).to_le_bytes());
    bytes.extend(paragraph);
    for unit in text.encode_utf16().chain(std::iter::once(13)) {
        bytes.extend(unit.to_le_bytes());
    }
    bytes.extend([0; 43]);
    bytes
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<_> = env::args().skip(1).collect();
    let replacement = "UpdatedDocumentMarker";
    if args.len() != 2
        || args[1].is_empty()
        || !args[1].chars().all(|c| c.is_ascii_alphanumeric())
        || args[1].contains(replacement)
        || replacement.contains(&args[1])
    {
        return Err("usage: spotlight_fixtures <new-directory> <alphanumeric-token>".into());
    }
    let root = Path::new(&args[0]);
    fs::create_dir(root)?;
    fs::create_dir(root.join("initial"))?;
    fs::create_dir(root.join("variants"))?;
    let token = &args[1];
    let original = model(&format!("은빛나비검색 {token} 문서 본문 검색 검증"));
    let changed = model(&format!("새벽바다검색 {replacement} 수정 후 검색 검증"));
    fs::write(
        root.join("manifest.json"),
        serde_json::to_vec_pretty(
            &serde_json::json!({"token": token, "replacement": replacement}),
        )?,
    )?;
    fs::write(
        root.join("initial/index-control.txt"),
        "SpotlightEnvironmentControlOnly",
    )?;
    let hwp = serializer::serialize_document(&original)?;
    let hwpx = serializer::hwpx::serialize_hwpx(&original)?;
    fs::write(root.join("initial/document-a.hwp"), &hwp)?;
    fs::write(root.join("initial/document-b.hwpx"), hwpx)?;
    fs::write(
        root.join("initial/document-c.hwp"),
        hwp3(&format!("{token} LegacyCorpus")),
    )?;
    fs::write(
        root.join("initial/control.hwpx"),
        serializer::hwpx::serialize_hwpx(&model("대조 문서"))?,
    )?;
    fs::write(
        root.join("variants/modified.hwp"),
        serializer::serialize_document(&changed)?,
    )?;
    fs::write(
        root.join("variants/protected.hwpx"),
        serializer::hwpx::serialize_hwpx_with_password(&original, b"test-only-spotlight")?,
    )?;
    fs::write(
        root.join("variants/empty.hwpx"),
        serializer::hwpx::serialize_hwpx(&model(""))?,
    )?;
    fs::write(
        root.join("variants/invalid.hwp"),
        b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1",
    )?;
    fs::write(
        root.join("variants/drm.hwp"),
        b"\x9b DRMONE  synthetic fixture",
    )?;
    let mut distribution = hwp;
    let signature = b"HWP Document File\0";
    let offset = distribution
        .windows(signature.len())
        .position(|bytes| bytes == signature)
        .unwrap();
    distribution[offset + 36] |= 4;
    fs::write(root.join("variants/distribution.hwp"), distribution)?;
    fs::File::create(root.join("variants/large.hwp"))?.set_len(32 * 1024 * 1024 + 1)?;
    fs::write(
        root.join("variants/truncated.hwpx"),
        serializer::hwpx::serialize_hwpx(&model(&"가".repeat(400_000)))?,
    )?;
    println!("합성 Spotlight corpus 생성 완료");
    Ok(())
}
