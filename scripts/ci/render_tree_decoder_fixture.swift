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
    // JSONSerialization의 Double 변환을 거치지 않고 producer의 usize marker를 재현한다.
    let textLine = #"{"id":1,"node_type":{"TextLine":{"line_height":20,"baseline":17,"section_index":0,"para_index":18446744073709551615}},"bbox":{"x":0,"y":0,"width":100,"height":20},"children":[],"visible":true}"#
    let root = try RenderTreeDecoder.decode(Data(textLine.utf8))
    guard case .textLine(let line) = root.nodeType else {
        throw RenderTreeDecoderFixtureError.assertion("core marker TextLine was not decoded")
    }
    try require(line.paraIndex == UInt.max, "unsigned producer marker was lost")
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
    for value: Any in ["TextRun", ["Header": NSNull()], ["TextRun": payload, "Future_PRIVATE_DOCUMENT": true]] {
        root = original
        root["node_type"] = value
        let variant = (value as? [String: Any])?["Header"] != nil ? "Header" : "TextRun"
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
