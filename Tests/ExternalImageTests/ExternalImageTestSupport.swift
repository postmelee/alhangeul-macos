import Foundation

enum ExternalImageTestSupport {
    static let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    static func sampleData(at relativePath: String) throws -> Data {
        try Data(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            options: [.mappedIfSafe]
        )
    }
}
