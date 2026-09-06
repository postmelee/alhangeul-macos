import Darwin
import Foundation

private enum RenderTreeDecoderFixtureError: Error, CustomStringConvertible {
    case assertion(String)

    var description: String {
        switch self {
        case .assertion(let message):
            return message
        }
    }
}

private let currentJSON = #"""
{
  "id": 1,
  "node_type": "MasterPage",
  "bbox": { "x": 0, "y": 0, "width": 595, "height": 842 },
  "children": [
    {
      "id": 2,
      "node_type": "Header",
      "bbox": { "x": 10, "y": 20, "width": 575, "height": 30 },
      "children": [],
      "visible": true
    }
  ],
  "visible": true
}
"""#

private let legacyJSON = #"""
{
  "id": 1,
  "node_type": "MasterPage",
  "bbox": { "x": 0, "y": 0, "width": 595, "height": 842 },
  "children": [
    {
      "id": 2,
      "node_type": "Header",
      "bbox": { "x": 10, "y": 20, "width": 575, "height": 30 },
      "children": [],
      "dirty": false,
      "visible": true
    }
  ],
  "dirty": true,
  "visible": true
}
"""#

private let textRunPayloadJSON = #"""
{
  "id": 3,
  "node_type": {
    "TextRun": {
      "text": "한글 fixture",
      "style": {
        "font_family": "FixtureSans",
        "font_size": 12,
        "color": 4278190080,
        "bold": false,
        "italic": false,
        "underline": "None",
        "strikethrough": false,
        "letter_spacing": 0,
        "ratio": 1,
        "default_tab_width": 40,
        "tab_stops": [],
        "auto_tab_right": false,
        "available_width": 240,
        "line_x_offset": 0,
        "tab_leaders": [],
        "inline_tabs": [],
        "extra_word_spacing": 0,
        "extra_char_spacing": 0,
        "outline_type": 0,
        "shadow_type": 0,
        "shadow_color": 0,
        "shadow_offset_x": 0,
        "shadow_offset_y": 0,
        "emboss": false,
        "engrave": false,
        "superscript": false,
        "subscript": false,
        "emphasis_dot": 0,
        "underline_shape": 0,
        "strike_shape": 0,
        "underline_color": 0,
        "strike_color": 0,
        "shade_color": 0
      },
      "is_para_end": false,
      "is_line_break_end": false,
      "is_vertical": false,
      "border_fill_id": 0,
      "baseline": 9,
      "field_marker": "None"
    }
  },
  "bbox": { "x": 12, "y": 24, "width": 96, "height": 18 },
  "children": [],
  "visible": true
}
"""#

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else {
        throw RenderTreeDecoderFixtureError.assertion(message)
    }
}

private func verifyFixture(named name: String, json: String) throws {
    let data = Data(json.utf8)
    let root = try JSONDecoder().decode(RenderNode.self, from: data)

    try require(root.id == 1, "\(name): unexpected root id")
    try require(root.visible, "\(name): root must be visible")
    try require(root.children.count == 1, "\(name): expected one child")
    guard case .masterPage = root.nodeType else {
        throw RenderTreeDecoderFixtureError.assertion("\(name): unexpected root node type")
    }

    let child = root.children[0]
    try require(child.id == 2, "\(name): unexpected child id")
    try require(child.visible, "\(name): child must be visible")
    try require(child.children.isEmpty, "\(name): child must not have descendants")
    guard case .header = child.nodeType else {
        throw RenderTreeDecoderFixtureError.assertion("\(name): unexpected child node type")
    }
}

private func verifyTextRunPayloadFixture() throws {
    let data = Data(textRunPayloadJSON.utf8)
    let root = try JSONDecoder().decode(RenderNode.self, from: data)

    try require(root.id == 3, "text-run-payload: unexpected root id")
    try require(root.visible, "text-run-payload: root must be visible")
    try require(root.children.isEmpty, "text-run-payload: root must not have children")
    guard case .textRun(let textRun) = root.nodeType else {
        throw RenderTreeDecoderFixtureError.assertion(
            "text-run-payload: expected TextRun instead of unknown node type"
        )
    }
    try require(textRun.text == "한글 fixture", "text-run-payload: unexpected text")
    try require(textRun.style.fontFamily == "FixtureSans", "text-run-payload: unexpected font")
    try require(textRun.style.tabStops.isEmpty, "text-run-payload: unexpected tab stops")
    try require(textRun.borderFillId == 0, "text-run-payload: unexpected border fill")
    guard case .none = textRun.fieldMarker else {
        throw RenderTreeDecoderFixtureError.assertion(
            "text-run-payload: unexpected field marker"
        )
    }
}

private func jsonData(_ object: [String: Any]) throws -> Data {
    try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
}

private func expectDecodeFailure(_ data: Data, variant: String?, path: String,
                                 reason: RenderTreeDecodingFailure.Reason) throws {
    do {
        _ = try RenderTreeDecoder.decode(data)
        throw RenderTreeDecoderFixtureError.assertion("malformed known/envelope unexpectedly accepted")
    } catch let failure as RenderTreeDecodingFailure {
        try require(failure.variant == variant, "unexpected diagnostic variant: \(failure)")
        try require(failure.path == path, "unexpected diagnostic path: \(failure)")
        try require(failure.reason == reason, "unexpected diagnostic cause: \(failure)")
        try require(!failure.description.contains("PRIVATE_DOCUMENT"), "diagnostic leaked document value")
        print("OK: \(failure)")
    }
}

private func verifyUnsignedCoreIndexMetadata() throws {
    // 원본 숫자 리터럴을 직접 검사하여 fixture 생성 과정의 숫자 변환을 배제한다.
    let textLine = #"{"id":1,"node_type":{"TextLine":{"line_height":20,"baseline":17,"section_index":0,"para_index":18446744073709551615}},"bbox":{"x":0,"y":0,"width":100,"height":20},"children":[],"visible":true}"#
    let root = try RenderTreeDecoder.decode(Data(textLine.utf8))
    guard case .textLine(let line) = root.nodeType else {
        throw RenderTreeDecoderFixtureError.assertion("core marker TextLine was not decoded")
    }
    try require(line.paraIndex == UInt.max, "unsigned producer marker was lost")
    let previous = try RenderTreeDecoder.decode(Data(textLine.replacingOccurrences(of: "18446744073709551615", with: "18446744073709551614").utf8))
    guard case .textLine(let previousLine) = previous.nodeType else {
        throw RenderTreeDecoderFixtureError.assertion("UInt.max-1 marker TextLine was not decoded")
    }
    try require(previousLine.paraIndex == UInt.max - 1, "adjacent unsigned marker was rounded")
    do {
        _ = try RenderTreeDecoder.decode(Data(textLine.replacingOccurrences(of: "18446744073709551615", with: "-1").utf8))
        throw RenderTreeDecoderFixtureError.assertion("negative unsigned index was accepted")
    } catch let failure as RenderTreeDecodingFailure {
        // Foundation versions differ: integer overflow may lack a DecodingError codingPath.
        try require(failure.variant == "TextLine", "numeric failure lost known variant")
        try require(failure.path.hasPrefix("$.node_type.TextLine"), "numeric failure lost payload path")
        try require(failure.reason == .dataCorrupted || failure.reason == .unexpectedDecoderError,
                    "unexpected numeric failure classification")
    }
    print("OK: UInt.max core index marker preserved; negative index rejected")
}

private func verifyUnsignedCellContext() throws {
    let context = #"{"parent_para_index":18446744073709551615,"path":[{"control_index":18446744073709551615,"cell_index":18446744073709551614,"cell_para_index":18446744073709551615,"text_direction":0}]}"#
    let json = textRunPayloadJSON.replacingOccurrences(of: #""field_marker": "None""#,
        with: #""field_marker": "None", "cell_context": "# + context)
    let root = try RenderTreeDecoder.decode(Data(json.utf8))
    guard case .textRun(let run) = root.nodeType, let cell = run.cellContext, let entry = cell.path.first else {
        throw RenderTreeDecoderFixtureError.assertion("missing cell context")
    }
    try require(cell.parentParaIndex == UInt.max && entry.controlIndex == UInt.max &&
                entry.cellIndex == UInt.max - 1 && entry.cellParaIndex == UInt.max,
                "cell usize values lost or rounded")
    for field in ["parent_para_index", "control_index", "cell_index", "cell_para_index"] {
        let value = field == "cell_index" ? "18446744073709551614" : "18446744073709551615"
        let negative = json.replacingOccurrences(of: "\"\(field)\":\(value)", with: "\"\(field)\":-1")
        do {
            _ = try RenderTreeDecoder.decode(Data(negative.utf8))
            throw RenderTreeDecoderFixtureError.assertion("negative \(field) accepted")
        } catch let failure as RenderTreeDecodingFailure {
            try require(failure.variant == "TextRun" && failure.path.hasPrefix("$.node_type.TextRun"),
                        "cell numeric failure lost payload diagnostic")
            try require(failure.reason == .dataCorrupted || failure.reason == .unexpectedDecoderError,
                        "unexpected cell numeric failure")
        }
    }
    print("OK: cell context preserves UInt.max/UInt.max-1; all four unsigned fields reject negatives")
}

private func verifyEveryKnownVariant() throws {
    var root = try JSONSerialization.jsonObject(with: Data(textRunPayloadJSON.utf8)) as! [String: Any]
    let textRun = (root["node_type"] as! [String: Any])["TextRun"]!
    let transform: [String: Any] = ["rotation": 0, "horz_flip": false, "vert_flip": false]
    let style: [String: Any] = ["stroke_width": 1, "stroke_dash": "Solid", "opacity": 1]
    let lineStyle: [String: Any] = ["color": 0, "width": 1, "dash": "Solid", "line_type": "Normal",
        "start_arrow": "None", "end_arrow": "None", "start_arrow_size": 0, "end_arrow_size": 0]
    // Independent wire fixtures: removing/renaming an implemented tag must not silently become unknown.
    let payloads: [String: Any] = [
        "Page": ["page_index": 0, "width": 100, "height": 100, "section_index": 0],
        "PageBackground": ["border_width": 0], "Body": [:] as [String: Any], "Column": 0,
        "TextLine": ["line_height": 20, "baseline": 17], "TextRun": textRun,
        "Table": ["row_count": 1, "col_count": 1, "border_fill_id": 0],
        "TableCell": ["col": 0, "row": 0, "col_span": 1, "row_span": 1, "border_fill_id": 0, "text_direction": 0, "clip": false],
        "Line": ["x1": 0, "y1": 0, "x2": 1, "y2": 1, "style": lineStyle, "transform": transform],
        "Rectangle": ["corner_radius": 0, "style": style, "transform": transform],
        "Ellipse": ["style": style, "transform": transform],
        "Path": ["commands": [], "style": style, "transform": transform],
        "Image": ["bin_data_id": 1, "transform": transform], "Group": [:] as [String: Any],
        "Equation": ["svg_content": "", "color_str": "#000000", "color": 0, "font_size": 12],
        "FormObject": ["form_type": "Edit", "caption": "", "text": ""],
        "Placeholder": ["fill_color": 0, "stroke_color": 0, "label": ""], "RawSvg": ["svg": ""],
        "FootnoteMarker": ["number": 1, "text": "1", "base_font_size": 12, "font_family": "FixtureSans", "color": 0],
    ]
    let units = ["MasterPage", "Header", "Footer", "FootnoteArea", "TextBox"]
    try require(Set(payloads.keys).union(units) == RenderNodeType.knownVariantNames, "known tag contract drift")
    for name in (Array(payloads.keys) + units).sorted() {
        root["node_type"] = payloads[name].map { [name: $0] as Any } ?? name
        let decoded = try RenderTreeDecoder.decode(jsonData(root))
        if case .unknown = decoded.nodeType {
            throw RenderTreeDecoderFixtureError.assertion("known \(name) silently became unknown")
        }
        root["node_type"] = payloads[name] == nil ? [name: NSNull()] as Any : name
        try expectDecodeFailure(try jsonData(root), variant: name, path: "$.node_type", reason: .invalidVariantShape)
    }
    print("OK: all 24 known wire variants decode and reject the opposite unit/payload shape")
}

private func verifyStrictKnownAndUnknownPolicy() throws {
    let original = try JSONSerialization.jsonObject(with: Data(textRunPayloadJSON.utf8)) as! [String: Any]
    let tagged = original["node_type"] as! [String: Any]
    let payload = tagged["TextRun"] as! [String: Any]
    var root = original
    var missing = payload
    missing.removeValue(forKey: "text")
    root["node_type"] = ["TextRun": missing]
    try expectDecodeFailure(try jsonData(root), variant: "TextRun", path: "$.node_type.TextRun.text", reason: .keyNotFound)
    var bad = payload
    bad["text"] = ["PRIVATE_DOCUMENT": "/private/PRIVATE_DOCUMENT.hwp"]
    root["node_type"] = ["TextRun": bad]
    try expectDecodeFailure(try jsonData(root), variant: "TextRun", path: "$.node_type.TextRun.text", reason: .typeMismatch)
    root["node_type"] = ["TextRun": NSNull()]
    try expectDecodeFailure(try jsonData(root), variant: "TextRun", path: "$.node_type.TextRun", reason: .valueNotFound)

    var parent = try JSONSerialization.jsonObject(with: Data(currentJSON.utf8)) as! [String: Any]
    root["node_type"] = ["TextRun": missing]
    parent["children"] = [root]
    try expectDecodeFailure(try jsonData(parent), variant: "TextRun", path: "$.children[0].node_type.TextRun.text", reason: .keyNotFound)

    for value: Any in ["Future_PRIVATE_DOCUMENT", ["Future_PRIVATE_DOCUMENT": ["text": "PRIVATE_DOCUMENT"]]] {
        root = original
        root["node_type"] = value
        let decoded = try RenderTreeDecoder.decode(jsonData(root))
        guard case .unknown = decoded.nodeType else {
            throw RenderTreeDecoderFixtureError.assertion("future variant must remain unknown")
        }
    }
    for value: Any in ["TextRun", ["Header": NSNull()], ["TextRun": payload, "Future_PRIVATE_DOCUMENT": true], ["Body": [:], "TextRun": payload]] {
        root = original
        root["node_type"] = value
        let object = value as? [String: Any]
        let variant: String? = object?.count == 2 ? nil : (object?["Header"] != nil ? "Header" : "TextRun")
        try expectDecodeFailure(try jsonData(root), variant: variant, path: "$.node_type", reason: .invalidVariantShape)
    }
    root = original
    root["node_type"] = [String: Any]()
    try expectDecodeFailure(try jsonData(root), variant: nil, path: "$.node_type", reason: .invalidVariantShape)
    root = original
    root.removeValue(forKey: "bbox")
    try expectDecodeFailure(try jsonData(root), variant: nil, path: "$.bbox", reason: .keyNotFound)
    root = original
    root["visible"] = "PRIVATE_DOCUMENT"
    try expectDecodeFailure(try jsonData(root), variant: nil, path: "$.visible", reason: .typeMismatch)
    try expectDecodeFailure(Data("{PRIVATE_DOCUMENT".utf8), variant: nil, path: "$", reason: .dataCorrupted)
}

@main
private struct RenderTreeDecoderFixture {
    static func main() {
        do {
            try verifyFixture(named: "current-without-dirty", json: currentJSON)
            try verifyFixture(named: "legacy-with-dirty", json: legacyJSON)
            try verifyTextRunPayloadFixture()
            try verifyStrictKnownAndUnknownPolicy()
            try verifyUnsignedCoreIndexMetadata()
            try verifyUnsignedCellContext()
            try verifyEveryKnownVariant()
            print(
                "OK: render tree decoder preserves current/legacy/future variants and diagnoses malformed known/envelope payloads"
            )
        } catch {
            let message = "ERROR: render tree decoder fixture failed: \(error)\n"
            FileHandle.standardError.write(Data(message.utf8))
            exit(EXIT_FAILURE)
        }
    }
}
