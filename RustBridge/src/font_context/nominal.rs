//! 공개 FontResolver/TextShapeLowerer를 이용한 제한된 host exact-face 어댑터.
//! 원본 TextRun/style을 변경하지 않는다. 한국어 완성형/출력 가능한 ASCII와 동일 face로
//! 매핑된 언어 혼합만 지원하며 복잡 shaping, 합성 스타일, 폰트 재탐색은 수행하지 않는다.
use super::{Context, MAX_BYTES};
use rhwp::paint::*;
use rhwp::renderer::layout::{EmbeddedTextMeasurer, TextMeasurer};
use rhwp::renderer::{render_tree::TextRunNode, style_resolver::detect_lang_category};
use std::borrow::Cow;
use std::collections::HashMap;

struct Resolver<'a> {
    context: &'a Context,
    bytes: &'a [u8],
    keys: HashMap<&'a str, FontFaceKey>,
}

impl FontResolver for Resolver<'_> {
    fn resolve_font(&self, request: &FontRequest) -> ResolvedFontFace {
        ResolvedFontFace {
            portability: if self.context.requests.iter().any(|entry| {
                entry.family == request.family
                    && entry.bold == request.bold
                    && entry.italic == request.italic
            }) {
                FontPortabilityKind::PortableBlob
            } else {
                FontPortabilityKind::UnresolvedFallback
            },
        }
    }

    fn shape_glyph_run(
        &self,
        request: &FontRequest,
        run: &TextRunNode,
        _: &ResolvedFontFace,
    ) -> Option<ResolvedGlyphRun> {
        let shape = run.char_shape_id?;
        if run.is_vertical
            || run.rotation.abs() > f64::EPSILON
            || run.char_overlap.is_some()
            || run
                .display_text
                .as_deref()
                .is_some_and(|text| text != run.text)
            || !run.style.font_size.is_finite()
            || !(0.0..=4096.0).contains(&run.style.font_size)
            || run.style.font_size == 0.0
            || (run.style.ratio - 1.0).abs() > f64::EPSILON
            || run.style.superscript
            || run.style.subscript
            || !run.style.tab_leaders.is_empty()
            || !run.style.inline_tabs.is_empty()
        {
            return None;
        }
        let characters: Vec<_> = run.text.chars().collect();
        if characters.is_empty()
            || characters.len() > 4096
            || characters
                .iter()
                .any(|character| !matches!(*character as u32, 0x20..=0x7e | 0xac00..=0xd7a3))
        {
            return None;
        }
        let mut chosen: Option<&str> = None;
        for character in &characters {
            let mapping = self.context.requests.iter().find(|entry| {
                entry.char_shape_id == shape
                    && entry.language_index == detect_lang_category(*character)
                    && entry.family == request.family
                    && entry.bold == request.bold
                    && entry.italic == request.italic
            })?;
            if chosen.is_some_and(|id| id != mapping.face_id) {
                return None;
            }
            chosen = Some(&mapping.face_id);
        }
        let id = chosen?;
        let input = self.context.faces.iter().find(|face| face.id == id)?;
        let face =
            ttf_parser::Face::parse(&self.bytes[input.offset..input.offset + input.length], 0)
                .ok()?;
        // Context::parse도 검증하지만 resolver의 스타일 의미를 이 경계에서 명확히 한다.
        if face.is_bold() != request.bold || face.is_italic() != request.italic {
            return None;
        }
        if face.units_per_em() == 0 {
            return None;
        }
        // 공개된 layout positions의 경계를 검사하고, 없으면 core의 공개 기본
        // TextMeasurer를 사용한다. private replay helper/측정 알고리즘을 복제하지 않는다.
        let producer: Cow<'_, [f64]> = match run.layout_positions.as_deref() {
            Some(values)
                if values.len() == characters.len() + 1
                    && values.first() == Some(&0.0)
                    && values
                        .iter()
                        .all(|value| value.is_finite() && *value >= 0.0)
                    && values.windows(2).all(|pair| pair[0] <= pair[1]) =>
            {
                Cow::Borrowed(values)
            }
            _ => Cow::Owned(EmbeddedTextMeasurer.compute_char_positions(&run.text, &run.style)),
        };
        if producer.len() != characters.len() + 1 || producer.iter().any(|value| !value.is_finite())
        {
            return None;
        }
        let mut glyphs = Vec::new();
        let mut positions = Vec::new();
        let mut advances = Vec::new();
        let mut clusters = Vec::new();
        let mut utf8 = 0;
        let mut utf16 = 0;
        let mut delta = 0.0f64;
        for (index, character) in characters.iter().enumerate() {
            let glyph = face.glyph_index(*character).filter(|glyph| glyph.0 != 0)?;
            let actual = f64::from(face.glyph_hor_advance(glyph)?) * run.style.font_size
                / f64::from(face.units_per_em());
            let advance = producer[index + 1] - producer[index];
            delta = delta.max((advance - actual).abs());
            glyphs.push(u32::from(glyph.0));
            positions.push(LayerPoint {
                x: producer[index],
                y: 0.0,
            });
            advances.push(LayerVector {
                dx: advance,
                dy: 0.0,
            });
            let end8 = utf8 + character.len_utf8() as u32;
            let end16 = utf16 + character.len_utf16() as u32;
            clusters.push(GlyphCluster {
                source_range_utf8: TextSourceRange::new(utf8, end8),
                source_range_utf16: Some(TextSourceRange::new(utf16, end16)),
                text_range_utf8: Some(TextSourceRange::new(utf8, end8)),
                glyph_range: GlyphRange::new(index as u32, index as u32 + 1),
                flags: Vec::new(),
            });
            utf8 = end8;
            utf16 = end16;
        }
        Some(ResolvedGlyphRun {
            shape_key: ShapeKey {
                font_instance: FontInstanceKey {
                    face_key: self.keys.get(id)?.clone(),
                    size_px: run.style.font_size,
                    variations: Vec::new(),
                    synthetic_bold: false,
                    synthetic_italic: false,
                },
                direction: TextDirection::Ltr,
                writing_mode: WritingMode::HorizontalTb,
                script: None,
                language: None,
                features: Vec::new(),
                shaping_engine: ShapingEngineId("alhangeul-host-nominal-v1".into()),
                fallback_policy: FontFallbackPolicyId("none".into()),
            },
            glyph_ids: glyphs,
            positions,
            advances: Some(advances),
            clusters,
            diagnostics: GlyphRunDiagnostics {
                quality: TextVariantQuality::PositionAdjusted,
                replay_eligibility: GlyphRunReplayEligibility::Portable,
                strict_visual_eligible: true,
                max_origin_delta_px: 0.0,
                max_advance_delta_px: delta,
                max_residual_after_adjustment_px: 0.0,
                cluster_mismatch_count: 0,
                missing_glyph_count: 0,
                used_fallback_font_count: 0,
                reason: Some("hostExactFaceProducerPositionedNominalGlyphs".into()),
            },
        })
    }
}

pub(super) fn lower(tree: &mut PageLayerTree, context: &Context, bytes: &[u8]) -> Option<usize> {
    // core portable resource/proof의 상한을 넘는 source는 적용하지 않고 실패로 처리한다.
    if bytes.len() > MAX_BYTES / 2
        || context
            .faces
            .iter()
            .any(|face| face.length > 32 * 1024 * 1024)
    {
        return None;
    }
    let mut keys = HashMap::new();
    for input in &context.faces {
        let data = &bytes[input.offset..input.offset + input.length];
        let digest = FontDigest {
            algorithm: RESOURCE_KEY_ALGORITHM.into(),
            value: resource_digest_hex(data),
        };
        let resource = font_blob_resource_key(data.len(), &digest.value);
        let blob_key = FontBlobKey(resource.clone());
        let face_key = FontFaceKey(format!("{resource}:face:{}", input.face_index));
        let data_ref = BinaryResourceRef {
            kind: BinaryResourceKind::FontBlob,
            id: resource,
        };
        tree.resources.intern_font_blob_bytes(data);
        let table = tree.resources.font_resources_mut();
        if !table.blobs.iter().any(|blob| blob.id == blob_key) {
            table.blobs.push(FontBlobResource {
                id: blob_key.clone(),
                digest: Some(digest.clone()),
                source: FontResourceSource::Embedded,
                data_ref: Some(data_ref.clone()),
                portability: FontPortability::PortableBlob { digest, data_ref },
            });
        }
        if !table.faces.iter().any(|face| face.id == face_key) {
            let face = ttf_parser::Face::parse(data, 0).ok()?;
            table.faces.push(FontFaceResource {
                id: face_key.clone(),
                blob_key,
                face_index: input.face_index,
                postscript_name: Some(input.post_script_name.clone()),
                family_names: Vec::new(),
                style_names: Vec::new(),
                weight_class: Some(face.weight().to_number()),
                width_class: Some(face.width().to_number()),
                italic: Some(face.is_italic()),
            });
        }
        keys.insert(input.id.as_str(), face_key);
    }
    let resolver = Resolver {
        context,
        bytes,
        keys,
    };
    let report = TextShapeLowerer::new(&resolver).lower_root(&mut tree.root);
    fn bind_ltr(node: &mut LayerNode) {
        match &mut node.kind {
            LayerNodeKind::Group { children, .. } => {
                for child in children {
                    bind_ltr(child);
                }
            }
            LayerNodeKind::ClipRect { child, .. } => bind_ltr(child),
            LayerNodeKind::Leaf { ops } => {
                for op in ops {
                    if let PaintOp::GlyphRun { run, .. } = op {
                        if run.shape_key.shaping_engine.0 == "alhangeul-host-nominal-v1" {
                            // 위 scalar 제한은 수평 LTR만 허용한다. public lowerer가 생략한
                            // bidi level을 이 검증된 범위에 한해 기록하고 native proof로 재검사한다.
                            run.bidi_level = Some(0);
                        }
                    }
                }
            }
        }
    }
    bind_ltr(&mut tree.root);
    Some(report.public_glyph_run_count())
}
