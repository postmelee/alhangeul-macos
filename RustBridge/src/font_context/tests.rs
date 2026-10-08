use super::*;
use crate::{rhwp_close, rhwp_free_string, rhwp_open};
use std::ffi::CStr;

const REGULAR: &[u8] = include_bytes!("../../../Tests/FontLibraryTests/Fixtures/regular.ttf");
const BOLD: &[u8] = include_bytes!("../../../Tests/FontLibraryTests/Fixtures/bold.ttf");

fn fixture(bytes: &[u8]) -> serde_json::Value {
    let face = ttf_parser::Face::parse(bytes, 0).unwrap();
    let name = |id| {
        face.names()
            .into_iter()
            .find_map(|name| (name.name_id == id).then(|| name.to_string()).flatten())
            .unwrap()
    };
    serde_json::json!({"version":1,"identity":"unit-snapshot", "faces":[{
        "id":"face","postScriptName":name(6),"sha256":sha256(bytes),
        "faceIndex":0,"offset":0,"length":bytes.len()
    }],"requests":[{"charShapeId":0,"languageIndex":0,"family":name(1),
        "bold":face.is_bold(),"italic":false,"faceId":"face"}]})
}

fn parse(value: &serde_json::Value, bytes: &[u8]) -> Result<Context, RhwpFontRenderStatus> {
    Context::parse(&serde_json::to_vec(value).unwrap(), bytes)
}

#[test]
fn validates_regular_and_bold_originals() {
    assert!(parse(&fixture(REGULAR), REGULAR).is_ok());
    assert!(parse(&fixture(BOLD), BOLD).is_ok());
}

#[test]
fn validates_source_identity_and_style_before_lowering() {
    for (key, value) in [
        ("sha256", serde_json::json!("0".repeat(64))),
        ("postScriptName", serde_json::json!("wrong")),
        ("offset", serde_json::json!(1)),
        ("length", serde_json::json!(u64::MAX)),
    ] {
        let mut input = fixture(REGULAR);
        input["faces"][0][key] = value;
        assert!(parse(&input, REGULAR).is_err(), "{key}");
    }
    for (key, value) in [
        ("bold", serde_json::json!(true)),
        ("italic", serde_json::json!(true)),
        ("faceId", serde_json::json!("missing")),
        ("family", serde_json::json!("wrong")),
        ("languageIndex", serde_json::json!(7)),
    ] {
        let mut input = fixture(REGULAR);
        input["requests"][0][key] = value;
        assert_eq!(
            parse(&input, REGULAR).unwrap_err(),
            RHWP_FONT_RENDER_INVALID_CONTEXT,
            "{key}"
        );
    }
    let mut extra = REGULAR.to_vec();
    extra.push(0);
    assert!(parse(&fixture(REGULAR), &extra).is_err());
}

#[test]
fn rejects_duplicates_unknown_fields_versions_and_counts() {
    let mut input = fixture(REGULAR);
    let duplicate = input["requests"][0].clone();
    input["requests"].as_array_mut().unwrap().push(duplicate);
    assert_eq!(
        parse(&input, REGULAR).unwrap_err(),
        RHWP_FONT_RENDER_INVALID_CONTEXT
    );
    let mut input = fixture(REGULAR);
    input["extra"] = serde_json::json!(1);
    assert_eq!(
        parse(&input, REGULAR).unwrap_err(),
        RHWP_FONT_RENDER_INVALID_CONTEXT
    );
    let mut input = fixture(REGULAR);
    input["version"] = serde_json::json!(2);
    assert_eq!(
        parse(&input, REGULAR).unwrap_err(),
        RHWP_FONT_RENDER_INVALID_CONTEXT
    );
    let mut input = fixture(REGULAR);
    input["faces"][0]["filePath"] = serde_json::json!("untrusted");
    assert_eq!(
        parse(&input, REGULAR).unwrap_err(),
        RHWP_FONT_RENDER_INVALID_CONTEXT
    );
    let mut input = fixture(REGULAR);
    input["requests"] = serde_json::json!(vec![input["requests"][0].clone(); 2049]);
    assert_eq!(
        parse(&input, REGULAR).unwrap_err(),
        RHWP_FONT_RENDER_TOO_LARGE
    );
    let mut input = fixture(REGULAR);
    input["faces"] = serde_json::json!(vec![input["faces"][0].clone(); 65]);
    assert_eq!(
        parse(&input, REGULAR).unwrap_err(),
        RHWP_FONT_RENDER_TOO_LARGE
    );
    assert!(Context::parse(b"{", REGULAR).is_err());
}

#[test]
fn rejects_ttc_variable_and_nonzero_index() {
    for bytes in [
        include_bytes!("../../../Tests/FontLibraryTests/Fixtures/two-face.ttc").as_slice(),
        include_bytes!("../../../Tests/FontLibraryTests/Fixtures/variable.ttf").as_slice(),
    ] {
        assert_eq!(
            parse(&fixture(bytes), bytes).unwrap_err(),
            RHWP_FONT_RENDER_UNSUPPORTED
        );
    }
    let mut input = fixture(REGULAR);
    input["faces"][0]["faceIndex"] = serde_json::json!(1);
    assert_eq!(
        parse(&input, REGULAR).unwrap_err(),
        RHWP_FONT_RENDER_UNSUPPORTED
    );
}

#[test]
fn ffi_initializes_outputs_and_rejects_lengths_before_borrowing() {
    let handle = rhwp_open(
        include_bytes!("../../../samples/basic/KTX.hwp").as_ptr(),
        include_bytes!("../../../samples/basic/KTX.hwp").len(),
    );
    assert!(!handle.is_null());
    let mut data = ptr::dangling_mut();
    let mut len = 99;
    let mut diagnostic = ptr::dangling_mut();
    let invoke = |h, metadata, ml, bytes, bl, data, len, diag| {
        rhwp_render_page_png_with_font_context(
            h, 0, 1.0, 0, metadata, ml, bytes, bl, data, len, diag,
        )
    };
    assert_eq!(
        invoke(
            ptr::null(),
            ptr::null(),
            0,
            ptr::null(),
            0,
            &mut data,
            &mut len,
            &mut diagnostic
        ),
        RHWP_FONT_RENDER_INVALID_HANDLE
    );
    assert!(data.is_null() && len == 0 && diagnostic.is_null());
    assert_eq!(
        invoke(
            handle,
            ptr::null(),
            MAX_METADATA + 1,
            ptr::null(),
            0,
            &mut data,
            &mut len,
            &mut diagnostic
        ),
        RHWP_FONT_RENDER_TOO_LARGE
    );
    assert_eq!(
        invoke(
            handle,
            ptr::null(),
            1,
            ptr::null(),
            MAX_BYTES + 1,
            &mut data,
            &mut len,
            &mut diagnostic
        ),
        RHWP_FONT_RENDER_TOO_LARGE
    );
    assert_eq!(
        invoke(
            handle,
            ptr::null(),
            1,
            ptr::null(),
            1,
            &mut data,
            &mut len,
            &mut diagnostic
        ),
        RHWP_FONT_RENDER_INVALID_CONTEXT
    );
    assert_eq!(
        invoke(
            handle,
            ptr::null(),
            0,
            ptr::null(),
            0,
            ptr::null_mut(),
            &mut len,
            &mut diagnostic
        ),
        RHWP_FONT_RENDER_INVALID_OUTPUT
    );
    let metadata = serde_json::to_vec(&fixture(REGULAR)).unwrap();
    assert_eq!(
        invoke(
            handle,
            metadata.as_ptr(),
            metadata.len(),
            REGULAR.as_ptr(),
            REGULAR.len(),
            &mut data,
            &mut len,
            &mut diagnostic
        ),
        RHWP_FONT_RENDER_INVALID_CONTEXT
    );
    assert!(data.is_null() && len == 0 && !diagnostic.is_null());
    assert!(unsafe { CStr::from_ptr(diagnostic) }
        .to_str()
        .unwrap()
        .contains("requestMismatch"));
    rhwp_free_string(diagnostic);
    rhwp_close(handle);
}

fn nominal_tree(bytes: &[u8], text: &str) -> (rhwp::paint::PageLayerTree, Context) {
    use rhwp::paint::{LayerNode, PageLayerTree, PaintOp};
    use rhwp::renderer::{render_tree::BoundingBox, TextStyle};
    let document =
        rhwp::DocumentCore::from_bytes(include_bytes!("../../../samples/basic/KTX.hwp")).unwrap();
    let source = document.build_page_layer_tree(0).unwrap();
    let mut template = None;
    visit_ops(&source.root, &mut |op| {
        if let PaintOp::TextRun { run, .. } = op {
            template = Some(run.clone());
        }
    });
    let input = fixture(bytes);
    let mut input = input;
    let mut latin = input["requests"][0].clone();
    latin["languageIndex"] = serde_json::json!(1);
    input["requests"].as_array_mut().unwrap().push(latin);
    let context = parse(&input, bytes).unwrap();
    let mut run = template.unwrap();
    run.text = text.into();
    run.char_shape_id = Some(0);
    run.style = TextStyle::default();
    run.style.font_family = context.requests[0].family.clone();
    run.style.bold = context.requests[0].bold;
    run.style.font_size = 20.0;
    run.rotation = 0.0;
    run.is_vertical = false;
    run.char_overlap = None;
    run.layout_positions = None;
    run.display_text = None;
    let bbox = BoundingBox {
        x: 10.0,
        y: 10.0,
        width: 90.0,
        height: 30.0,
    };
    let root = LayerNode::leaf(
        bbox,
        None,
        vec![PaintOp::TextRun {
            bbox,
            run,
            source: None,
        }],
    );
    (PageLayerTree::new(140.0, 70.0, root), context)
}

#[test]
fn public_resolver_replays_real_bold_and_same_face_language_mix_without_style_mutation() {
    for bytes in [REGULAR, BOLD] {
        let (mut tree, context) = nominal_tree(bytes, "가A");
        assert_eq!(nominal::lower(&mut tree, &context, bytes), Some(1));
        let mut original_bold = None;
        let mut replayed = 0;
        visit_ops(&tree.root, &mut |op| match op {
            PaintOp::TextRun { run, .. } => {
                original_bold = Some(run.style.bold);
            }
            PaintOp::GlyphRun { run, .. } => {
                assert!(!run.shape_key.font_instance.synthetic_bold);
                assert_eq!(run.glyph_ids.len(), 2);
                assert_eq!(run.bidi_level, Some(0));
                let proof = native_skia_glyph_run_replay_proof(run, &tree.resources);
                assert!(
                    proof.contract_replayable && proof.typeface_constructible,
                    "{:?}",
                    proof.reasons
                );
                replayed += 1;
            }
            _ => {}
        });
        assert_eq!(original_bold, Some(context.requests[0].bold));
        assert_eq!(replayed, 1);
    }
}

#[test]
fn public_resolver_rejects_missing_glyph_and_unsupported_shaping_scalars() {
    for text in ["B", "가\u{301}", "😀", "ا", "가\tA"] {
        let (mut tree, context) = nominal_tree(REGULAR, text);
        assert_eq!(
            nominal::lower(&mut tree, &context, REGULAR),
            Some(0),
            "{text}"
        );
    }
}
