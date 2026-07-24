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

    static func withTemporaryDirectory<Result>(
        _ body: (URL) throws -> Result
    ) throws -> Result {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "rhwp-external-image-tests-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        return try body(directoryURL)
    }

    @discardableResult
    static func write(
        _ data: Data,
        named filename: String,
        in directoryURL: URL
    ) throws -> URL {
        let fileURL = directoryURL.appendingPathComponent(filename)
        try data.write(to: fileURL)
        return fileURL
    }
}
