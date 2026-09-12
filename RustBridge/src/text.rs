//! Spotlight 전용 파싱·모델 순회. 레이아웃과 파일/외부 자원 접근을 사용하지 않는다.
use rhwp::model::{control::Control, document::Document, paragraph::Paragraph, shape::ShapeObject};

pub(crate) fn from_bytes(data: &[u8]) -> Result<Extraction, crate::RhwpTextStatus> {
    use crate::RhwpTextStatus::*;
    use rhwp::parser::{self, FileFormat, ParseError};
    match parser::detect_format(data) {
        FileFormat::DrmProtected => return Err(RHWP_TEXT_PROTECTED),
        FileFormat::Hwp => {
            // 본문 파싱 전에 보호 header만 확인한다. 배포용 본문 복호화도 시도하지 않는다.
            let raw = parser::cfb_reader::CfbReader::open(data)
                .and_then(|mut container| container.read_stream_raw_limited("/FileHeader", 256))
                .or_else(|_| {
                    parser::cfb_reader::LenientCfbReader::open(data)
                        .and_then(|container| container.read_stream_raw_limited("/FileHeader", 256))
                })
                .map_err(|_| RHWP_TEXT_PARSE_ERROR)?;
            let header =
                parser::header::parse_file_header(&raw).map_err(|_| RHWP_TEXT_PARSE_ERROR)?;
            if header.flags.encrypted || header.flags.distribution {
                return Err(RHWP_TEXT_PROTECTED);
            }
        }
        FileFormat::Hwp3 | FileFormat::Hwpx => {}
        _ => return Err(RHWP_TEXT_UNSUPPORTED),
    }
    let document = parser::parse_document(data).map_err(|error| match error {
        ParseError::EncryptedDocument => RHWP_TEXT_PROTECTED,
        _ => RHWP_TEXT_PARSE_ERROR,
    })?;
    if document.header.encrypted || document.header.distribution {
        return Err(RHWP_TEXT_PROTECTED);
    }
    Ok(extract(&document, LIMITS))
}

#[derive(Clone, Copy)]
pub(crate) struct Limits {
    pub bytes: usize,
    pub nodes: usize,
    pub depth: usize,
}

pub(crate) const LIMITS: Limits = Limits {
    bytes: 1024 * 1024,
    nodes: 200_000,
    depth: 64,
};

pub(crate) struct Extraction {
    pub text: String,
    pub truncated: bool,
}

struct Walker {
    output: Extraction,
    limits: Limits,
    nodes: usize,
    pending: Option<char>,
}

pub(crate) fn extract(document: &Document, limits: Limits) -> Extraction {
    let mut walker = Walker {
        output: Extraction {
            text: String::new(),
            truncated: false,
        },
        limits,
        nodes: 0,
        pending: None,
    };
    for section in &document.sections {
        if !walker.visit(0) {
            break;
        }
        walker.paragraphs(&section.paragraphs, 1);
    }
    walker.output
}

impl Walker {
    fn visit(&mut self, depth: usize) -> bool {
        if self.output.truncated || self.nodes >= self.limits.nodes || depth > self.limits.depth {
            self.output.truncated = true;
            return false;
        }
        self.nodes += 1;
        true
    }

    fn character(&mut self, ch: char) {
        if self.output.truncated {
            return;
        }
        let ch = match ch {
            '\r' | '\n' => '\n',
            c if c.is_control() || c.is_whitespace() => ' ',
            c => c,
        };
        if ch == ' ' || ch == '\n' {
            if self.pending != Some('\n') {
                self.pending = Some(ch);
            }
            return;
        }
        let separator = self.pending.filter(|_| !self.output.text.is_empty());
        if self.output.text.len() + usize::from(separator.is_some()) + ch.len_utf8()
            > self.limits.bytes
        {
            self.output.truncated = true;
            return;
        }
        if let Some(separator) = separator {
            self.output.text.push(separator);
        }
        self.pending = None;
        self.output.text.push(ch);
    }

    fn fragment(&mut self, text: &str) {
        for ch in text.chars() {
            self.character(ch);
            if self.output.truncated {
                break;
            }
        }
        self.character('\n');
    }

    fn paragraphs(&mut self, paragraphs: &[Paragraph], depth: usize) {
        for paragraph in paragraphs {
            if !self.visit(depth) {
                break;
            }
            self.fragment(&paragraph.text);
            for control in &paragraph.controls {
                if !self.visit(depth + 1) {
                    break;
                }
                match control {
                    Control::Table(table) => {
                        for cell in &table.cells {
                            if !self.visit(depth + 2) {
                                break;
                            }
                            self.paragraphs(&cell.paragraphs, depth + 3);
                        }
                        if let Some(caption) = &table.caption {
                            self.paragraphs(&caption.paragraphs, depth + 2);
                        }
                    }
                    Control::Shape(shape) => self.shape(shape, depth + 2),
                    Control::Picture(picture) => {
                        if let Some(caption) = &picture.caption {
                            self.paragraphs(&caption.paragraphs, depth + 2);
                        }
                    }
                    Control::Header(value) => self.paragraphs(&value.paragraphs, depth + 2),
                    Control::Footer(value) => self.paragraphs(&value.paragraphs, depth + 2),
                    Control::Footnote(value) => self.paragraphs(&value.paragraphs, depth + 2),
                    Control::Endnote(value) => self.paragraphs(&value.paragraphs, depth + 2),
                    Control::Equation(value) => self.fragment(&value.script),
                    Control::Form(value) => {
                        self.fragment(&value.text);
                        self.fragment(&value.caption);
                    }
                    Control::Ruby(value) => {
                        self.fragment(&value.main_text);
                        self.fragment(&value.ruby_text);
                    }
                    Control::CharOverlap(value) => {
                        for &ch in &value.chars {
                            self.character(ch);
                            if self.output.truncated {
                                break;
                            }
                        }
                        self.character('\n');
                    }
                    // 표시 문자열은 paragraph.text에 있다. 명령·URL·메모·숨은 설명은 제외한다.
                    _ => {}
                }
            }
        }
    }

    fn shape(&mut self, shape: &ShapeObject, depth: usize) {
        if !self.visit(depth) {
            return;
        }
        if let Some(drawing) = shape.drawing() {
            if let Some(text_box) = &drawing.text_box {
                self.paragraphs(&text_box.paragraphs, depth + 1);
            }
            if let Some(caption) = &drawing.caption {
                self.paragraphs(&caption.paragraphs, depth + 1);
            }
        }
        match shape {
            ShapeObject::Group(group) => {
                for child in &group.children {
                    self.shape(child, depth + 1);
                    if self.output.truncated {
                        break;
                    }
                }
                if let Some(caption) = &group.caption {
                    self.paragraphs(&caption.paragraphs, depth + 1);
                }
            }
            ShapeObject::Picture(picture) => {
                if let Some(caption) = &picture.caption {
                    self.paragraphs(&caption.paragraphs, depth + 1);
                }
            }
            _ => {}
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use rhwp::model::{
        control::{Equation, Field, FormObject, HiddenComment, Ruby},
        footnote::{Endnote, Footnote},
        header_footer::{Footer, Header},
        shape::{Caption, GroupShape, RectangleShape, TextBox},
        table::{Cell, Table},
    };

    fn paragraph(text: &str) -> Paragraph {
        Paragraph {
            text: text.into(),
            ..Default::default()
        }
    }

    fn document(paragraph: Paragraph) -> Document {
        let mut document = Document::default();
        document.sections.push(Default::default());
        document.sections[0].paragraphs = vec![paragraph];
        document
    }

    #[test]
    fn normalizes_controls_without_damaging_unicode_or_word_boundaries() {
        let result = extract(
            &document(paragraph(" \t한글\0English\r\n\n😀 e\u{301} \t")),
            LIMITS,
        );
        assert_eq!(result.text, "한글 English\n😀 e\u{301}");
        assert!(!result.truncated);
    }

    #[test]
    fn includes_nested_search_text_and_excludes_hidden_payloads() {
        let mut root = paragraph("본문");
        let mut nested = paragraph("셀");
        nested.controls.push(Control::Table(Box::new(Table {
            cells: vec![Cell {
                paragraphs: vec![paragraph("중첩")],
                ..Default::default()
            }],
            ..Default::default()
        })));
        root.controls.push(Control::Table(Box::new(Table {
            cells: vec![Cell {
                paragraphs: vec![nested],
                ..Default::default()
            }],
            caption: Some(Caption {
                paragraphs: vec![paragraph("표제목")],
                ..Default::default()
            }),
            ..Default::default()
        })));
        let mut rectangle = RectangleShape::default();
        rectangle.drawing.text_box = Some(TextBox {
            paragraphs: vec![paragraph("글상자")],
            ..Default::default()
        });
        root.controls
            .push(Control::Shape(Box::new(ShapeObject::Group(GroupShape {
                children: vec![ShapeObject::Rectangle(rectangle)],
                ..Default::default()
            }))));
        root.controls.extend([
            Control::Field(Field {
                command: "추가하면안되는명령".into(),
                memo_paragraphs: vec![paragraph("메모비밀")],
                ..Default::default()
            }),
            Control::Header(Box::new(Header {
                paragraphs: vec![paragraph("머리말")],
                ..Default::default()
            })),
            Control::Footer(Box::new(Footer {
                paragraphs: vec![paragraph("꼬리말")],
                ..Default::default()
            })),
            Control::Footnote(Box::new(Footnote {
                paragraphs: vec![paragraph("각주")],
                ..Default::default()
            })),
            Control::Endnote(Box::new(Endnote {
                paragraphs: vec![paragraph("미주")],
                ..Default::default()
            })),
            Control::Equation(Box::new(Equation {
                script: "x + y".into(),
                ..Default::default()
            })),
            Control::Form(Box::new(FormObject {
                text: "양식".into(),
                caption: "설명".into(),
                ..Default::default()
            })),
            Control::Ruby(Ruby {
                main_text: "基".into(),
                ruby_text: "기".into(),
                ..Default::default()
            }),
            Control::HiddenComment(Box::new(HiddenComment {
                paragraphs: vec![paragraph("숨은비밀")],
            })),
        ]);
        let result = extract(&document(root), LIMITS);
        assert_eq!(
            result.text,
            "본문\n셀\n중첩\n표제목\n글상자\n머리말\n꼬리말\n각주\n미주\nx + y\n양식\n설명\n基\n기"
        );
        assert!(!result.truncated);
    }

    #[test]
    fn bounds_utf8_nodes_and_depth_and_distinguishes_exact_fit() {
        let doc = document(paragraph("한😀글"));
        let result = extract(&doc, Limits { bytes: 6, ..LIMITS });
        assert_eq!(result.text, "한");
        assert!(result.truncated);
        let result = extract(
            &doc,
            Limits {
                bytes: 10,
                ..LIMITS
            },
        );
        assert_eq!(result.text, "한😀글");
        assert!(!result.truncated);
        for limits in [Limits { nodes: 1, ..LIMITS }, Limits { depth: 0, ..LIMITS }] {
            let result = extract(&doc, limits);
            assert!(result.text.is_empty());
            assert!(result.truncated);
        }
        let result = extract(&document(paragraph(" \r\n\t")), LIMITS);
        assert!(result.text.is_empty());
        assert!(!result.truncated);
    }

    #[test]
    fn stops_inside_deep_groups_and_preserves_only_visited_prefix() {
        let mut shape = ShapeObject::Rectangle(RectangleShape::default());
        for _ in 0..80 {
            shape = ShapeObject::Group(GroupShape {
                children: vec![shape],
                ..Default::default()
            });
        }
        let mut root = paragraph("유지할본문");
        root.controls.push(Control::Shape(Box::new(shape)));
        root.controls.push(Control::Equation(Box::new(Equation {
            script: "한도뒤본문".into(),
            ..Default::default()
        })));
        let doc = document(root);
        for limits in [LIMITS, Limits { nodes: 5, ..LIMITS }] {
            let result = extract(&doc, limits);
            assert_eq!(result.text, "유지할본문");
            assert!(result.truncated);
        }
    }
}
