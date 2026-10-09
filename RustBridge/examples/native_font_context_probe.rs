//! 승인된 고운바탕과 합성 문서로 실제 새 C ABI 및 pinned Skia의 지원 경계를 검사한다.
use rhwp::paint::{LayerNode, LayerNodeKind, PaintOp};
use rhwp::renderer::style_resolver::detect_lang_category;
use rhwp_mac_bridge::*;
use sha2::{Digest, Sha256};
use std::{collections::BTreeMap, env, ffi::CStr, fs, path::PathBuf, ptr};

fn collect(node: &LayerNode, output: &mut BTreeMap<(u32, usize), serde_json::Value>, mode: &str) {
    match &node.kind {
        LayerNodeKind::Group { children, .. } => {
            for child in children {
                collect(child, output, mode);
            }
        }
        LayerNodeKind::ClipRect { child, .. } => collect(child, output, mode),
        LayerNodeKind::Leaf { ops } => {
            for op in ops {
                if let PaintOp::TextRun { run, .. } = op {
                    if run.style.font_family != "Gowun Batang" {
                        continue;
                    }
                    if mode == "regular" && run.style.bold || mode == "bold" && !run.style.bold {
                        continue;
                    }
                    for character in run.text.chars() {
                        let shape = run.char_shape_id.expect("fixture must identify char shape");
                        let lang = detect_lang_category(character);
                        output.insert((shape,lang),serde_json::json!({"charShapeId":shape,"languageIndex":lang,
                            "family":run.style.font_family,"bold":run.style.bold,"italic":run.style.italic,
                            "faceId":if run.style.bold {"bold"} else {"regular"}}));
                    }
                }
            }
        }
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<_> = env::args().skip(1).collect();
    if !(3..=4).contains(&args.len()) {
        return Err(
            "usage: native_font_context_probe <document> <font-directory> <output> [regular|unsupported]"
                .into(),
        );
    }
    let modes = if matches!(
        args.get(3).map(String::as_str),
        Some("regular" | "unsupported")
    ) {
        vec!["regular"]
    } else {
        assert_eq!(args.len(), 3);
        vec!["regular", "bold", "both"]
    };
    let document = fs::read(&args[0])?;
    let font_dir = PathBuf::from(&args[1]);
    let out = PathBuf::from(&args[2]);
    fs::create_dir_all(&out)?;
    let parsed = rhwp::DocumentCore::from_bytes(&document).map_err(|_| "document open failed")?;
    let tree = parsed
        .build_page_layer_tree(0)
        .map_err(|_| "tree unavailable")?;
    let handle = rhwp_open(document.as_ptr(), document.len());
    assert!(!handle.is_null());
    let original_ptr = rhwp_render_page_tree(handle, 0);
    assert!(!original_ptr.is_null());
    let original_tree = unsafe { CStr::from_ptr(original_ptr) }.to_bytes().to_vec();
    rhwp_free_string(original_ptr);
    // 호출 전후 tree를 대조하며 C allocation도 각각 해제한다.
    let mut results = Vec::new();
    for mode in modes {
        let mut requests = BTreeMap::new();
        collect(&tree.root, &mut requests, mode);
        assert!(
            !requests.is_empty(),
            "fixture must include requested style: {mode}"
        );
        let mut payload = Vec::new();
        let mut faces = Vec::new();
        for (style, id) in [("Regular", "regular"), ("Bold", "bold")] {
            if mode == "regular" && id == "bold" || mode == "bold" && id == "regular" {
                continue;
            }
            let bytes = fs::read(font_dir.join(format!("GowunBatang-{style}.ttf")))?;
            let sha: String = Sha256::digest(&bytes)
                .iter()
                .map(|byte| format!("{byte:02x}"))
                .collect();
            assert_eq!(
                sha,
                if id == "regular" {
                    "466c593e7147412e748af4856d5ad14709b5a860bdf62b9c2546f2c5874e9849"
                } else {
                    "dbfcaa646e5831e7478524924f02906f550285a5050699b4e38c9950b3ec4b94"
                }
            );
            faces.push(
                serde_json::json!({"id":id,"postScriptName":format!("GowunBatang-{style}"),
                "sha256":sha,"faceIndex":0,"offset":payload.len(),"length":bytes.len()}),
            );
            payload.extend(bytes);
        }
        let metadata = serde_json::to_vec(
            &serde_json::json!({"version":1,"identity":format!("probe-{mode}"),
            "faces":faces,"requests":requests.into_values().collect::<Vec<_>>()}),
        )?;
        let mut data = ptr::null_mut();
        let mut len = 0;
        let mut diag = ptr::null_mut();
        let status = rhwp_render_page_png_with_font_context(
            handle,
            0,
            1.0,
            2048,
            metadata.as_ptr(),
            metadata.len(),
            payload.as_ptr(),
            payload.len(),
            &mut data,
            &mut len,
            &mut diag,
        );
        let diagnostic: serde_json::Value =
            serde_json::from_slice(unsafe { CStr::from_ptr(diag) }.to_bytes())?;
        rhwp_free_string(diag);
        assert_eq!(
            status,
            if args.get(3).map(String::as_str) == Some("unsupported") {
                RhwpFontRenderStatus::RHWP_FONT_RENDER_UNSUPPORTED
            } else {
                RhwpFontRenderStatus::RHWP_FONT_RENDER_OK
            }
        );
        if status == RhwpFontRenderStatus::RHWP_FONT_RENDER_OK {
            assert!(!data.is_null() && len > 8);
            fs::write(out.join(format!("{mode}.png")), unsafe {
                std::slice::from_raw_parts(data, len)
            })?;
            rhwp_free_bytes(data, len);
        } else {
            assert!(data.is_null() && len == 0);
        }
        results.push(serde_json::json!({"mode":mode,"status":status as u32,"pngBytes":len,"diagnostic":diagnostic}));
        fs::write(out.join(format!("{mode}-metadata.json")), &metadata)?;
    }
    let tree_ptr = rhwp_render_page_tree(handle, 0);
    assert_eq!(
        unsafe { CStr::from_ptr(tree_ptr) }.to_bytes(),
        original_tree
    );
    rhwp_free_string(tree_ptr);
    rhwp_close(handle);
    fs::write(
        out.join("result.json"),
        serde_json::to_vec_pretty(&serde_json::json!({
            "core":"v0.8.7","documentUnchanged":true,"OSFontRegistration":false,"results":results
        }))?,
    )?;
    println!("saved {}", out.join("result.json").display());
    Ok(())
}
