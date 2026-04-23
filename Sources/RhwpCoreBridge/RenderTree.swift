// 렌더 트리 Swift 모델 — Rust RenderNode의 serde JSON에 대응하는 Codable 타입
// serde 기본 외부 태그(externally tagged) enum 포맷:
//   Unit variant: "MasterPage"
//   Newtype variant: {"TextRun": {...}}
//   Struct variant: {"Body": {"clip_rect": ...}}

import Foundation

// MARK: - 렌더 노드

struct RenderNode: Decodable {
    let id: UInt32
    let nodeType: RenderNodeType
    let bbox: BBox
    let children: [RenderNode]
    let dirty: Bool
    let visible: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case nodeType = "node_type"
        case bbox
        case children
        case dirty
        case visible
    }
}

struct BBox: Decodable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

// MARK: - 렌더 노드 타입 (serde externally tagged enum)

enum RenderNodeType: Decodable {
    case page(PageNode)
    case pageBackground(PageBackgroundNode)
    case masterPage
    case header
    case footer
    case body(BodyNode)
    case column(UInt16)
    case footnoteArea
    case textLine(TextLineNode)
    case textRun(TextRunNode)
    case table(TableNode)
    case tableCell(TableCellNode)
    case line(LineNode)
    case rectangle(RectangleNode)
    case ellipse(EllipseNode)
    case path(PathNode)
    case image(ImageNode)
    case group(GroupNode)
    case textBox
    case equation(EquationNode)
    case formObject(FormObjectNode)
    case footnoteMarker(FootnoteMarkerNode)
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Unit variant: "MasterPage" 등
        if let str = try? container.decode(String.self) {
            switch str {
            case "MasterPage": self = .masterPage
            case "Header": self = .header
            case "Footer": self = .footer
            case "FootnoteArea": self = .footnoteArea
            case "TextBox": self = .textBox
            default: self = .unknown
            }
            return
        }
        // Newtype/Struct variant: {"Page": {...}} 등
        let keyed = try decoder.container(keyedBy: DynamicKey.self)
        if let v = try? keyed.decode(PageNode.self, forKey: .init("Page")) { self = .page(v); return }
        if let v = try? keyed.decode(PageBackgroundNode.self, forKey: .init("PageBackground")) { self = .pageBackground(v); return }
        if let v = try? keyed.decode(BodyNode.self, forKey: .init("Body")) { self = .body(v); return }
        if let v = try? keyed.decode(UInt16.self, forKey: .init("Column")) { self = .column(v); return }
        if let v = try? keyed.decode(TextLineNode.self, forKey: .init("TextLine")) { self = .textLine(v); return }
        if let v = try? keyed.decode(TextRunNode.self, forKey: .init("TextRun")) { self = .textRun(v); return }
        if let v = try? keyed.decode(TableNode.self, forKey: .init("Table")) { self = .table(v); return }
        if let v = try? keyed.decode(TableCellNode.self, forKey: .init("TableCell")) { self = .tableCell(v); return }
        if let v = try? keyed.decode(LineNode.self, forKey: .init("Line")) { self = .line(v); return }
        if let v = try? keyed.decode(RectangleNode.self, forKey: .init("Rectangle")) { self = .rectangle(v); return }
        if let v = try? keyed.decode(EllipseNode.self, forKey: .init("Ellipse")) { self = .ellipse(v); return }
        if let v = try? keyed.decode(PathNode.self, forKey: .init("Path")) { self = .path(v); return }
        if let v = try? keyed.decode(ImageNode.self, forKey: .init("Image")) { self = .image(v); return }
        if let v = try? keyed.decode(GroupNode.self, forKey: .init("Group")) { self = .group(v); return }
        if let v = try? keyed.decode(EquationNode.self, forKey: .init("Equation")) { self = .equation(v); return }
        if let v = try? keyed.decode(FormObjectNode.self, forKey: .init("FormObject")) { self = .formObject(v); return }
        if let v = try? keyed.decode(FootnoteMarkerNode.self, forKey: .init("FootnoteMarker")) { self = .footnoteMarker(v); return }
        self = .unknown
    }
}

// MARK: - 노드 데이터 타입

struct PageNode: Decodable {
    let pageIndex: UInt32
    let width: Double
    let height: Double
    let sectionIndex: Int

    enum CodingKeys: String, CodingKey {
        case pageIndex = "page_index"
        case width, height
        case sectionIndex = "section_index"
    }
}

struct PageBackgroundNode: Decodable {
    let backgroundColor: UInt32?
    let borderColor: UInt32?
    let borderWidth: Double
    let gradient: GradientFillInfo?

    enum CodingKeys: String, CodingKey {
        case backgroundColor = "background_color"
        case borderColor = "border_color"
        case borderWidth = "border_width"
        case gradient
    }
}

struct BodyNode: Decodable {
    let clipRect: BBox?
    enum CodingKeys: String, CodingKey {
        case clipRect = "clip_rect"
    }
}

struct TextLineNode: Decodable {
    let lineHeight: Double
    let baseline: Double
    let sectionIndex: Int?
    let paraIndex: Int?

    enum CodingKeys: String, CodingKey {
        case lineHeight = "line_height"
        case baseline
        case sectionIndex = "section_index"
        case paraIndex = "para_index"
    }
}

struct TextRunNode: Decodable {
    let text: String
    let style: TextStyle
    let charShapeId: UInt32?
    let paraShapeId: UInt32?
    let sectionIndex: Int?
    let paraIndex: Int?
    let charStart: Int?
    let cellContext: CellContext?
    let isParaEnd: Bool
    let isLineBreakEnd: Bool
    let rotation: Double?
    let isVertical: Bool
    let charOverlap: CharOverlapInfo?
    let borderFillId: UInt16
    let baseline: Double
    let fieldMarker: FieldMarkerType

    enum CodingKeys: String, CodingKey {
        case text, style, rotation, baseline
        case charShapeId = "char_shape_id"
        case paraShapeId = "para_shape_id"
        case sectionIndex = "section_index"
        case paraIndex = "para_index"
        case charStart = "char_start"
        case cellContext = "cell_context"
        case isParaEnd = "is_para_end"
        case isLineBreakEnd = "is_line_break_end"
        case isVertical = "is_vertical"
        case charOverlap = "char_overlap"
        case borderFillId = "border_fill_id"
        case fieldMarker = "field_marker"
    }
}

struct TableNode: Decodable {
    let rowCount: UInt16
    let colCount: UInt16
    let borderFillId: UInt16
    let sectionIndex: Int?
    let paraIndex: Int?
    let controlIndex: Int?

    enum CodingKeys: String, CodingKey {
        case rowCount = "row_count"
        case colCount = "col_count"
        case borderFillId = "border_fill_id"
        case sectionIndex = "section_index"
        case paraIndex = "para_index"
        case controlIndex = "control_index"
    }
}

struct TableCellNode: Decodable {
    let col: UInt16
    let row: UInt16
    let colSpan: UInt16
    let rowSpan: UInt16
    let borderFillId: UInt16
    let textDirection: UInt8
    let clip: Bool
    let modelCellIndex: UInt32?

    enum CodingKeys: String, CodingKey {
        case col, row, clip
        case colSpan = "col_span"
        case rowSpan = "row_span"
        case borderFillId = "border_fill_id"
        case textDirection = "text_direction"
        case modelCellIndex = "model_cell_index"
    }
}

struct LineNode: Decodable {
    let x1: Double
    let y1: Double
    let x2: Double
    let y2: Double
    let style: LineStyle
    let sectionIndex: Int?
    let paraIndex: Int?
    let controlIndex: Int?
    let transform: ShapeTransform

    enum CodingKeys: String, CodingKey {
        case x1, y1, x2, y2, style, transform
        case sectionIndex = "section_index"
        case paraIndex = "para_index"
        case controlIndex = "control_index"
    }
}

struct RectangleNode: Decodable {
    let cornerRadius: Double
    let style: ShapeStyle
    let gradient: GradientFillInfo?
    let sectionIndex: Int?
    let paraIndex: Int?
    let controlIndex: Int?
    let transform: ShapeTransform

    enum CodingKeys: String, CodingKey {
        case style, gradient, transform
        case cornerRadius = "corner_radius"
        case sectionIndex = "section_index"
        case paraIndex = "para_index"
        case controlIndex = "control_index"
    }
}

struct EllipseNode: Decodable {
    let style: ShapeStyle
    let gradient: GradientFillInfo?
    let sectionIndex: Int?
    let paraIndex: Int?
    let controlIndex: Int?
    let transform: ShapeTransform

    enum CodingKeys: String, CodingKey {
        case style, gradient, transform
        case sectionIndex = "section_index"
        case paraIndex = "para_index"
        case controlIndex = "control_index"
    }
}

struct PathNode: Decodable {
    let commands: [PathCommand]
    let style: ShapeStyle
    let gradient: GradientFillInfo?
    let sectionIndex: Int?
    let paraIndex: Int?
    let controlIndex: Int?
    let transform: ShapeTransform
    let lineStyle: LineStyle?
    let connectorEndpoints: [[Double]]?

    enum CodingKeys: String, CodingKey {
        case commands, style, gradient, transform
        case sectionIndex = "section_index"
        case paraIndex = "para_index"
        case controlIndex = "control_index"
        case lineStyle = "line_style"
        case connectorEndpoints = "connector_endpoints"
    }
}

struct ImageNode: Decodable {
    let binDataId: UInt16
    let sectionIndex: Int?
    let paraIndex: Int?
    let controlIndex: Int?
    let fillMode: String?
    let originalSize: [Double]?
    let transform: ShapeTransform
    let crop: [Int32]?

    enum CodingKeys: String, CodingKey {
        case transform, crop
        case binDataId = "bin_data_id"
        case sectionIndex = "section_index"
        case paraIndex = "para_index"
        case controlIndex = "control_index"
        case fillMode = "fill_mode"
        case originalSize = "original_size"
    }
}

struct GroupNode: Decodable {
    let sectionIndex: Int?
    let paraIndex: Int?
    let controlIndex: Int?

    enum CodingKeys: String, CodingKey {
        case sectionIndex = "section_index"
        case paraIndex = "para_index"
        case controlIndex = "control_index"
    }
}

struct EquationNode: Decodable {
    let svgContent: String
    let colorStr: String
    let color: UInt32
    let fontSize: Double

    enum CodingKeys: String, CodingKey {
        case svgContent = "svg_content"
        case colorStr = "color_str"
        case color
        case fontSize = "font_size"
    }
}

struct FormObjectNode: Decodable {
    let formType: String
    let caption: String
    let text: String

    enum CodingKeys: String, CodingKey {
        case formType = "form_type"
        case caption, text
    }
}

struct FootnoteMarkerNode: Decodable {
    let number: UInt16
    let text: String
    let baseFontSize: Double
    let fontFamily: String
    let color: UInt32

    enum CodingKeys: String, CodingKey {
        case number, text, color
        case baseFontSize = "base_font_size"
        case fontFamily = "font_family"
    }
}

// MARK: - 스타일 타입

struct TextStyle: Decodable {
    let fontFamily: String
    let fontSize: Double
    let color: UInt32
    let bold: Bool
    let italic: Bool
    let underline: String    // UnderlineType enum
    let strikethrough: Bool
    let letterSpacing: Double
    let ratio: Double
    let defaultTabWidth: Double
    let tabStops: [TabStopInfo]
    let autoTabRight: Bool
    let availableWidth: Double
    let lineXOffset: Double
    let tabLeaders: [TabLeaderInfo]
    let inlineTabs: [[UInt16]]
    let extraWordSpacing: Double
    let extraCharSpacing: Double
    let outlineType: UInt8
    let shadowType: UInt8
    let shadowColor: UInt32
    let shadowOffsetX: Double
    let shadowOffsetY: Double
    let emboss: Bool
    let engrave: Bool
    let superscript: Bool
    let `subscript`: Bool
    let emphasisDot: UInt8
    let underlineShape: UInt8
    let strikeShape: UInt8
    let underlineColor: UInt32
    let strikeColor: UInt32
    let shadeColor: UInt32

    enum CodingKeys: String, CodingKey {
        case bold, italic, underline, strikethrough, ratio, emboss, engrave, superscript
        case fontFamily = "font_family"
        case fontSize = "font_size"
        case color
        case letterSpacing = "letter_spacing"
        case defaultTabWidth = "default_tab_width"
        case tabStops = "tab_stops"
        case autoTabRight = "auto_tab_right"
        case availableWidth = "available_width"
        case lineXOffset = "line_x_offset"
        case tabLeaders = "tab_leaders"
        case inlineTabs = "inline_tabs"
        case extraWordSpacing = "extra_word_spacing"
        case extraCharSpacing = "extra_char_spacing"
        case outlineType = "outline_type"
        case shadowType = "shadow_type"
        case shadowColor = "shadow_color"
        case shadowOffsetX = "shadow_offset_x"
        case shadowOffsetY = "shadow_offset_y"
        case `subscript`
        case emphasisDot = "emphasis_dot"
        case underlineShape = "underline_shape"
        case strikeShape = "strike_shape"
        case underlineColor = "underline_color"
        case strikeColor = "strike_color"
        case shadeColor = "shade_color"
    }
}

struct TabStopInfo: Decodable {
    let position: Double
    let tabType: UInt8
    let fillType: UInt8

    enum CodingKeys: String, CodingKey {
        case position
        case tabType = "tab_type"
        case fillType = "fill_type"
    }
}

struct TabLeaderInfo: Decodable {
    let startX: Double
    let endX: Double
    let fillType: UInt8

    enum CodingKeys: String, CodingKey {
        case startX = "start_x"
        case endX = "end_x"
        case fillType = "fill_type"
    }
}

struct ShapeStyle: Decodable {
    let fillColor: UInt32?
    let pattern: PatternFillInfo?
    let strokeColor: UInt32?
    let strokeWidth: Double
    let strokeDash: String   // StrokeDash enum
    let opacity: Double
    let shadow: ShadowStyleInfo?

    enum CodingKeys: String, CodingKey {
        case pattern, opacity, shadow
        case fillColor = "fill_color"
        case strokeColor = "stroke_color"
        case strokeWidth = "stroke_width"
        case strokeDash = "stroke_dash"
    }
}

struct PatternFillInfo: Decodable {
    let patternType: Int32
    let patternColor: UInt32
    let backgroundColor: UInt32

    enum CodingKeys: String, CodingKey {
        case patternType = "pattern_type"
        case patternColor = "pattern_color"
        case backgroundColor = "background_color"
    }
}

struct ShadowStyleInfo: Decodable {
    let shadowType: UInt32
    let color: UInt32
    let offsetX: Double
    let offsetY: Double
    let alpha: UInt8

    enum CodingKeys: String, CodingKey {
        case color, alpha
        case shadowType = "shadow_type"
        case offsetX = "offset_x"
        case offsetY = "offset_y"
    }
}

struct GradientFillInfo: Decodable {
    let gradientType: Int16
    let angle: Int16
    let centerX: Int16
    let centerY: Int16
    let colors: [UInt32]
    let positions: [Double]

    enum CodingKeys: String, CodingKey {
        case angle, colors, positions
        case gradientType = "gradient_type"
        case centerX = "center_x"
        case centerY = "center_y"
    }
}

struct LineStyle: Decodable {
    let color: UInt32
    let width: Double
    let dash: String         // StrokeDash enum
    let lineType: String     // LineRenderType enum
    let startArrow: String   // ArrowStyle enum
    let endArrow: String     // ArrowStyle enum
    let startArrowSize: UInt8
    let endArrowSize: UInt8
    let shadow: ShadowStyleInfo?

    enum CodingKeys: String, CodingKey {
        case color, width, dash, shadow
        case lineType = "line_type"
        case startArrow = "start_arrow"
        case endArrow = "end_arrow"
        case startArrowSize = "start_arrow_size"
        case endArrowSize = "end_arrow_size"
    }
}

struct ShapeTransform: Decodable {
    let rotation: Double
    let horzFlip: Bool
    let vertFlip: Bool

    enum CodingKeys: String, CodingKey {
        case rotation
        case horzFlip = "horz_flip"
        case vertFlip = "vert_flip"
    }
}

// MARK: - PathCommand (serde externally tagged enum)

enum PathCommand: Decodable {
    case moveTo(Double, Double)
    case lineTo(Double, Double)
    case curveTo(Double, Double, Double, Double, Double, Double)
    case arcTo(Double, Double, Double, Bool, Bool, Double, Double)
    case closePath

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self), str == "ClosePath" {
            self = .closePath; return
        }
        let keyed = try decoder.container(keyedBy: DynamicKey.self)
        if let v = try? keyed.decode([Double].self, forKey: .init("MoveTo")) {
            self = .moveTo(v[0], v[1]); return
        }
        if let v = try? keyed.decode([Double].self, forKey: .init("LineTo")) {
            self = .lineTo(v[0], v[1]); return
        }
        if let v = try? keyed.decode([Double].self, forKey: .init("CurveTo")) {
            self = .curveTo(v[0], v[1], v[2], v[3], v[4], v[5]); return
        }
        // ArcTo는 mixed tuple: (f64, f64, f64, bool, bool, f64, f64)
        // serde는 이를 배열로 직렬화: [rx, ry, xrot, large_arc, sweep, x, y]
        if let v = try? keyed.decode([ArcToValue].self, forKey: .init("ArcTo")) {
            self = .arcTo(v[0].asDouble, v[1].asDouble, v[2].asDouble,
                          v[3].asBool, v[4].asBool, v[5].asDouble, v[6].asDouble)
            return
        }
        self = .closePath
    }
}

// MARK: - FieldMarkerType (serde externally tagged enum)

enum FieldMarkerType: Decodable {
    case none
    case fieldBegin
    case fieldEnd
    case fieldBeginEnd
    case shapeMarker(Int)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            switch str {
            case "None": self = .none
            case "FieldBegin": self = .fieldBegin
            case "FieldEnd": self = .fieldEnd
            case "FieldBeginEnd": self = .fieldBeginEnd
            default: self = .none
            }
            return
        }
        let keyed = try decoder.container(keyedBy: DynamicKey.self)
        if let v = try? keyed.decode(Int.self, forKey: .init("ShapeMarker")) {
            self = .shapeMarker(v); return
        }
        self = .none
    }
}

// MARK: - 보조 타입

struct CharOverlapInfo: Decodable {
    let borderType: UInt8
    let innerCharSize: Int8

    enum CodingKeys: String, CodingKey {
        case borderType = "border_type"
        case innerCharSize = "inner_char_size"
    }
}

struct CellContext: Decodable {
    let parentParaIndex: Int
    let path: [CellPathEntry]

    enum CodingKeys: String, CodingKey {
        case parentParaIndex = "parent_para_index"
        case path
    }
}

struct CellPathEntry: Decodable {
    let controlIndex: Int
    let cellIndex: Int
    let cellParaIndex: Int
    let textDirection: UInt8

    enum CodingKeys: String, CodingKey {
        case controlIndex = "control_index"
        case cellIndex = "cell_index"
        case cellParaIndex = "cell_para_index"
        case textDirection = "text_direction"
    }
}

// MARK: - 유틸리티

/// serde의 동적 키 디코딩용
struct DynamicKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init(_ string: String) { self.stringValue = string; self.intValue = nil }
    init?(stringValue: String) { self.stringValue = stringValue; self.intValue = nil }
    init?(intValue: Int) { self.stringValue = "\(intValue)"; self.intValue = intValue }
}

/// ArcTo의 mixed tuple (f64/bool) 디코딩용
enum ArcToValue: Decodable {
    case double(Double)
    case bool(Bool)

    var asDouble: Double {
        if case .double(let v) = self { return v }
        return 0
    }
    var asBool: Bool {
        if case .bool(let v) = self { return v }
        return false
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) { self = .bool(v); return }
        if let v = try? container.decode(Double.self) { self = .double(v); return }
        self = .double(0)
    }
}
