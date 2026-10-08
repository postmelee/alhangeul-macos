//! 작업별 immutable 글꼴 bytes를 portable glyph 경로에 연결한다.
//! 지원되지 않는 run을 다른 face로 조용히 렌더하지 않는다. core 원본은 변경하지 않는다.
use crate::{string_to_c, RhwpHandle};
use rhwp::paint::{
    lower_font_native_glyph_sidecars, EmbeddedFontFace, LayerNode, LayerNodeKind, PaintOp,
};
use rhwp::renderer::layer_renderer::RasterRenderOptions;
use rhwp::renderer::skia::{native_skia_glyph_run_replay_proof, SkiaLayerRenderer};
use rhwp::renderer::style_resolver::detect_lang_category;
use serde::Deserialize;
use sha2::{Digest, Sha256};
use std::collections::{HashMap, HashSet};
use std::ffi::c_char;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::ptr;

const MAX_METADATA: usize = 1024 * 1024;
const MAX_BYTES: usize = 128 * 1024 * 1024;
const MAX_FACE_BYTES: usize = 64 * 1024 * 1024;
mod nominal;

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[allow(non_camel_case_types)]
pub enum RhwpFontRenderStatus {
    RHWP_FONT_RENDER_OK = 0,
    RHWP_FONT_RENDER_INVALID_HANDLE = 1,
    RHWP_FONT_RENDER_INVALID_OUTPUT = 2,
    RHWP_FONT_RENDER_INVALID_PAGE_INDEX = 3,
    RHWP_FONT_RENDER_INVALID_OPTIONS = 4,
    RHWP_FONT_RENDER_FAILURE = 5,
    RHWP_FONT_RENDER_INVALID_CONTEXT = 6,
    RHWP_FONT_RENDER_TOO_LARGE = 7,
    RHWP_FONT_RENDER_UNSUPPORTED = 8,
}

use RhwpFontRenderStatus::*;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct Context {
    version: u32,
    identity: String,
    faces: Vec<Face>,
    requests: Vec<Request>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct Face {
    id: String,
    post_script_name: String,
    sha256: String,
    face_index: u32,
    offset: usize,
    length: usize,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct Request {
    char_shape_id: u32,
    language_index: usize,
    family: String,
    bold: bool,
    italic: bool,
    face_id: String,
}

impl Context {
    fn parse(metadata: &[u8], bytes: &[u8]) -> Result<Self, RhwpFontRenderStatus> {
        if metadata.len() > MAX_METADATA || bytes.len() > MAX_BYTES {
            return Err(RHWP_FONT_RENDER_TOO_LARGE);
        }
        let context: Self =
            serde_json::from_slice(metadata).map_err(|_| RHWP_FONT_RENDER_INVALID_CONTEXT)?;
        if context.version != 1
            || !label(&context.identity)
            || context.faces.is_empty()
            || context.requests.is_empty()
        {
            return Err(RHWP_FONT_RENDER_INVALID_CONTEXT);
        }
        if context.faces.len() > 64 || context.requests.len() > 2048 {
            return Err(RHWP_FONT_RENDER_TOO_LARGE);
        }
        let mut ids = HashSet::new();
        let mut end = 0;
        for input in &context.faces {
            if !label(&input.id)
                || !label(&input.post_script_name)
                || !ids.insert(&input.id)
                || input.length == 0
                || input.offset != end
            {
                return Err(RHWP_FONT_RENDER_INVALID_CONTEXT);
            }
            if input.length > MAX_FACE_BYTES {
                return Err(RHWP_FONT_RENDER_TOO_LARGE);
            }
            end = input
                .offset
                .checked_add(input.length)
                .filter(|end| *end <= bytes.len())
                .ok_or(RHWP_FONT_RENDER_INVALID_CONTEXT)?;
            let data = &bytes[input.offset..end];
            if input.sha256.len() != 64 || input.sha256 != sha256(data) {
                return Err(RHWP_FONT_RENDER_INVALID_CONTEXT);
            }
            // 최초 계약은 단일 static SFNT만 지원한다. TTC/가변 지원을 추측하지 않는다.
            if input.face_index != 0 || ttf_parser::fonts_in_collection(data).is_some() {
                return Err(RHWP_FONT_RENDER_UNSUPPORTED);
            }
            let face =
                ttf_parser::Face::parse(data, 0).map_err(|_| RHWP_FONT_RENDER_INVALID_CONTEXT)?;
            if face.is_variable() {
                return Err(RHWP_FONT_RENDER_UNSUPPORTED);
            }
            if !face.names().into_iter().any(|name| {
                name.name_id == ttf_parser::name_id::POST_SCRIPT_NAME
                    && name.to_string().as_deref() == Some(&input.post_script_name)
            }) {
                return Err(RHWP_FONT_RENDER_INVALID_CONTEXT);
            }
        }
        if end != bytes.len() {
            return Err(RHWP_FONT_RENDER_INVALID_CONTEXT);
        }
        let mut slots = HashSet::new();
        let mut used = HashSet::new();
        let mut mapped_bytes = 0usize;
        for request in &context.requests {
            if request.language_index > 6
                || !label(&request.family)
                || !slots.insert((request.char_shape_id, request.language_index))
            {
                return Err(RHWP_FONT_RENDER_INVALID_CONTEXT);
            }
            let input = context
                .faces
                .iter()
                .find(|face| face.id == request.face_id)
                .ok_or(RHWP_FONT_RENDER_INVALID_CONTEXT)?;
            used.insert(&input.id);
            // core nominal lowerer는 slot별 resource 준비를 한다. 같은 큰 파일의
            // 반복 mapping으로 무한 hashing/적재를 유발하지 않도록 작업량도 제한한다.
            mapped_bytes = mapped_bytes
                .checked_add(input.length)
                .filter(|total| *total <= MAX_BYTES)
                .ok_or(RHWP_FONT_RENDER_TOO_LARGE)?;
            let face =
                ttf_parser::Face::parse(&bytes[input.offset..input.offset + input.length], 0)
                    .map_err(|_| RHWP_FONT_RENDER_INVALID_CONTEXT)?;
            let family_matches = face.names().into_iter().any(|name| {
                matches!(name.name_id, 1 | 4 | 6 | 16)
                    && name
                        .to_string()
                        .is_some_and(|name| name.eq_ignore_ascii_case(&request.family))
            });
            if !family_matches
                || face.is_bold() != request.bold
                || face.is_italic() != request.italic
            {
                return Err(RHWP_FONT_RENDER_INVALID_CONTEXT);
            }
        }
        if used.len() != context.faces.len() {
            return Err(RHWP_FONT_RENDER_INVALID_CONTEXT);
        }
        Ok(context)
    }
}

fn label(value: &str) -> bool {
    !value.is_empty() && value.len() <= 1024 && !value.chars().any(char::is_control)
}

fn sha256(bytes: &[u8]) -> String {
    Sha256::digest(bytes)
        .iter()
        .map(|byte| format!("{byte:02x}"))
        .collect()
}

fn visit_ops(node: &LayerNode, operation: &mut impl FnMut(&PaintOp)) {
    match &node.kind {
        LayerNodeKind::Group { children, .. } => {
            for child in children {
                visit_ops(child, operation);
            }
        }
        LayerNodeKind::ClipRect { child, .. } => visit_ops(child, operation),
        LayerNodeKind::Leaf { ops } => {
            for op in ops {
                operation(op);
            }
        }
    }
}

struct Outcome {
    status: RhwpFontRenderStatus,
    png: Vec<u8>,
    diagnostic: serde_json::Value,
}

fn failure(status: RhwpFontRenderStatus, reason: &str) -> Outcome {
    Outcome {
        status,
        png: Vec::new(),
        diagnostic: serde_json::json!({"version":1,"reason":reason}),
    }
}

fn render(
    handle: &RhwpHandle,
    page: u32,
    scale: f64,
    max_dimension: u32,
    metadata: &[u8],
    bytes: &[u8],
) -> Outcome {
    if page >= handle.doc.page_count() {
        return failure(RHWP_FONT_RENDER_INVALID_PAGE_INDEX, "invalidPage");
    }
    let context = match Context::parse(metadata, bytes) {
        Ok(value) => value,
        Err(status) => return failure(status, "invalidContext"),
    };
    let mut tree = match handle.doc.build_page_layer_tree(page) {
        Ok(value) => value,
        Err(_) => return failure(RHWP_FONT_RENDER_FAILURE, "treeUnavailable"),
    };
    let requests: HashMap<_, _> = context
        .requests
        .iter()
        .map(|request| ((request.char_shape_id, request.language_index), request))
        .collect();
    let mut targets = HashSet::new();
    let mut used_slots = HashSet::new();
    let mut invalid = false;
    visit_ops(&tree.root, &mut |op| {
        if let PaintOp::TextRun { run, source, .. } = op {
            if let Some(shape) = run.char_shape_id {
                for character in run.text.chars() {
                    let slot = (shape, detect_lang_category(character));
                    if let Some(request) = requests.get(&slot) {
                        used_slots.insert(slot);
                        if run.style.font_family != request.family
                            || run.style.bold != request.bold
                            || run.style.italic != request.italic
                        {
                            invalid = true;
                        }
                        if let Some(source) = source {
                            targets.insert(source.id.0);
                        } else {
                            invalid = true;
                        }
                    }
                }
            }
        }
    });
    if invalid || targets.is_empty() || used_slots.len() != requests.len() {
        return failure(RHWP_FONT_RENDER_INVALID_CONTEXT, "requestMismatch");
    }
    if targets.len() > 256 {
        return failure(RHWP_FONT_RENDER_TOO_LARGE, "tooManyTargetRuns");
    }
    let mut existing = false;
    visit_ops(&tree.root, &mut |op| {
        if let PaintOp::GlyphRun { run, .. } = op {
            if targets.contains(&run.source.id.0) {
                existing = true;
            }
        }
    });
    if existing {
        return failure(RHWP_FONT_RENDER_UNSUPPORTED, "existingExactGlyphSource");
    }
    let fonts: Vec<_> = context
        .requests
        .iter()
        .map(|request| {
            let input = context
                .faces
                .iter()
                .find(|face| face.id == request.face_id)
                .unwrap();
            EmbeddedFontFace {
                char_shape_id: request.char_shape_id,
                language_index: request.language_index,
                family: &request.family,
                alternate_family: None,
                bytes: &bytes[input.offset..input.offset + input.length],
                face_index: input.face_index,
            }
        })
        .collect();
    let report = lower_font_native_glyph_sidecars(&mut tree.root, &mut tree.resources, &fonts);
    let adapted_runs = nominal::lower(&mut tree, &context, bytes).unwrap_or(0);
    let mut proven = HashSet::new();
    let mut proof_failures = HashSet::new();
    visit_ops(&tree.root, &mut |op| {
        if let PaintOp::GlyphRun { run, .. } = op {
            if targets.contains(&run.source.id.0) {
                let proof = native_skia_glyph_run_replay_proof(run, &tree.resources);
                if proof.contract_replayable && proof.typeface_constructible {
                    proven.insert(run.source.id.0);
                } else {
                    for reason in proof.reasons {
                        proof_failures.insert(reason.as_str());
                    }
                }
            }
        }
    });
    let mut reasons: Vec<_> = proof_failures.into_iter().collect();
    reasons.sort_unstable();
    let exact = proven == targets;
    let diagnostic = serde_json::json!({"version":1,"identity":context.identity,
        "reason":if exact {"exactPortableGlyphReplay"} else {"glyphLoweringUnsupported"},
        "targetRuns":targets.len(),"provenRuns":proven.len(),"emittedRuns":report.emitted_glyph_runs + adapted_runs,
        "proofFailures":reasons,"faces":context.faces.iter().map(|face| serde_json::json!({
            "postScriptName":face.post_script_name,"sha256":face.sha256,"faceIndex":face.face_index
        })).collect::<Vec<_>>()});
    if !exact {
        return Outcome {
            status: RHWP_FONT_RENDER_UNSUPPORTED,
            png: Vec::new(),
            diagnostic,
        };
    }
    let mut options = RasterRenderOptions::default();
    if max_dimension > 0 {
        options.max_dimension = max_dimension as i32;
    }
    options.scale = if scale > 0.0 {
        scale
    } else if max_dimension > 0 {
        (f64::from(max_dimension) / tree.page_width.max(tree.page_height)).clamp(0.1, 1.0)
    } else {
        1.0
    };
    match SkiaLayerRenderer::new().render_raster_with_options(&tree, options) {
        Ok(output) if !output.bytes.is_empty() => Outcome {
            status: RHWP_FONT_RENDER_OK,
            png: output.bytes,
            diagnostic,
        },
        _ => failure(RHWP_FONT_RENDER_FAILURE, "rasterFailure"),
    }
}

/// 단일 static SFNT의 검증된 bytes를 호출 동안만 빌려 Skia PNG를 생성한다.
/// 입력 pointer/length는 호출 중 readable, outputs는 정렬되고 서로/입력과 별개여야 한다.
/// 유효한 output slot은 실패에도 NULL/0. PNG는 rhwp_free_bytes, JSON은 rhwp_free_string으로 해제.
/// JSON v1은 identity, faces(id/postScriptName/sha256/faceIndex/offset/length), requests
/// (charShapeId/languageIndex/family/bold/italic/faceId). metadata 1 MiB, 64 faces, 2048 requests,
/// 64 MiB/face, 고유 및 slot별 mapping bytes 각각 128 MiB, 대상 run 256개.
/// 기존 core replay와 한국어 완성형/ASCII host 어댑터 범위만 지원한다. portable 어댑터의
/// 적용 한도는 32 MiB/face, 64 MiB/작업이며 미지원은 UNSUPPORTED와 빈 PNG로 반환한다.
/// 호출 후 pointer/context를 저장하지 않고
/// OS 등록, font path 탐색, 문서 변경을 수행하지 않는다.
#[no_mangle]
pub extern "C" fn rhwp_render_page_png_with_font_context(
    handle: *const RhwpHandle,
    page: u32,
    scale: f64,
    max_dimension: u32,
    metadata: *const u8,
    metadata_len: usize,
    font_bytes: *const u8,
    font_bytes_len: usize,
    out_data: *mut *mut u8,
    out_len: *mut usize,
    out_diagnostic: *mut *mut c_char,
) -> RhwpFontRenderStatus {
    unsafe {
        if !out_data.is_null() {
            *out_data = ptr::null_mut();
        }
        if !out_len.is_null() {
            *out_len = 0;
        }
        if !out_diagnostic.is_null() {
            *out_diagnostic = ptr::null_mut();
        }
    }
    if out_data.is_null() || out_len.is_null() || out_diagnostic.is_null() {
        return RHWP_FONT_RENDER_INVALID_OUTPUT;
    }
    if handle.is_null() {
        return RHWP_FONT_RENDER_INVALID_HANDLE;
    }
    if !scale.is_finite() || scale < 0.0 || max_dimension > i32::MAX as u32 {
        return RHWP_FONT_RENDER_INVALID_OPTIONS;
    }
    if metadata_len > MAX_METADATA || font_bytes_len > MAX_BYTES {
        return RHWP_FONT_RENDER_TOO_LARGE;
    }
    if metadata.is_null() || metadata_len == 0 || font_bytes.is_null() || font_bytes_len == 0 {
        return RHWP_FONT_RENDER_INVALID_CONTEXT;
    }
    let outcome = catch_unwind(AssertUnwindSafe(|| unsafe {
        render(
            &*handle,
            page,
            scale,
            max_dimension,
            std::slice::from_raw_parts(metadata, metadata_len),
            std::slice::from_raw_parts(font_bytes, font_bytes_len),
        )
    }))
    .unwrap_or_else(|_| failure(RHWP_FONT_RENDER_FAILURE, "panic"));
    unsafe {
        *out_diagnostic = string_to_c(outcome.diagnostic.to_string());
        if outcome.status == RHWP_FONT_RENDER_OK {
            let bytes = outcome.png.into_boxed_slice();
            *out_len = bytes.len();
            *out_data = Box::into_raw(bytes) as *mut u8;
        }
    }
    outcome.status
}

#[cfg(test)]
mod tests;
