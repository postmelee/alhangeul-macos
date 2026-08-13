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

@main
private struct RenderTreeDecoderFixture {
    static func main() throws {
        try verifyFixture(named: "current-without-dirty", json: currentJSON)
        try verifyFixture(named: "legacy-with-dirty", json: legacyJSON)
        print("OK: render tree decoder accepts current JSON without dirty and legacy JSON with dirty")
    }
}
