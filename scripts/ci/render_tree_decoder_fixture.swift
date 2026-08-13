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

@main
private struct RenderTreeDecoderFixture {
    static func main() {
        do {
            try verifyFixture(named: "current-without-dirty", json: currentJSON)
            try verifyFixture(named: "legacy-with-dirty", json: legacyJSON)
            try verifyTextRunPayloadFixture()
            print(
                "OK: render tree decoder accepts current/legacy envelopes and TextRun payload"
            )
        } catch {
            let message = "ERROR: render tree decoder fixture failed: \(error)\n"
            FileHandle.standardError.write(Data(message.utf8))
            exit(EXIT_FAILURE)
        }
    }
}
