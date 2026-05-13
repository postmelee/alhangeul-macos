import Foundation

struct RhwpProvenance: Equatable {
    let releaseTag: String
    let resolvedCommit: String

    var shortCommit: String {
        String(resolvedCommit.prefix(7))
    }

    var displayValue: String {
        "rhwp \(releaseTag) (\(shortCommit))"
    }
}

enum RhwpProvenanceLoader {
    static func load(bundle: Bundle = .main) -> RhwpProvenance? {
        guard let manifestURL = bundle.url(
            forResource: "manifest",
            withExtension: "json",
            subdirectory: "rhwp-studio"
        ),
        let data = try? Data(contentsOf: manifestURL),
        let manifest = try? JSONDecoder().decode(RhwpStudioManifest.self, from: data)
        else {
            return nil
        }

        return makeProvenance(
            releaseTag: manifest.source_release_tag,
            resolvedCommit: manifest.source_resolved_commit
        )
    }

    static func makeProvenance(releaseTag: String, resolvedCommit: String) -> RhwpProvenance? {
        let trimmedTag = releaseTag.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCommit = resolvedCommit.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTag.isEmpty, trimmedCommit.count >= 7 else {
            return nil
        }

        return RhwpProvenance(
            releaseTag: trimmedTag,
            resolvedCommit: trimmedCommit
        )
    }
}

private struct RhwpStudioManifest: Decodable {
    let source_release_tag: String
    let source_resolved_commit: String
}
