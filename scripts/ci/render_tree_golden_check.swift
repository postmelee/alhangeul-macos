import Foundation

@main
private struct GoldenContractCheck {
    static func main() {
        do {
            guard CommandLine.arguments.count > 1 else {
                throw NSError(domain: "golden requires a tree file", code: 1)
            }
            for file in CommandLine.arguments.dropFirst() {
                let tree = try RenderTreeDecoder.decode(Data(contentsOf: URL(fileURLWithPath: file)))
                var textRuns = 0
                var tables = 0
                var textLines = 0
                func visit(_ node: RenderNode) {
                    switch node.nodeType {
                    case .textRun: textRuns += 1
                    case .table: tables += 1
                    case .textLine: textLines += 1
                    default: break
                    }
                    node.children.forEach(visit)
                }
                visit(tree)
                guard textRuns > 0, tables > 0, textLines > 0 else {
                    throw NSError(domain: "golden requires TextRun, Table and TextLine coverage", code: 1)
                }
                print("OK: producer golden decoded (TextRun=\(textRuns), Table=\(tables), TextLine=\(textLines))")
            }
        } catch {
            FileHandle.standardError.write(Data("ERROR: golden decoder: \(error)\n".utf8))
            exit(1)
        }
    }
}
