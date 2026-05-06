import CoreText
import Foundation

struct HwpFontRegistrationStatus {
    let fontDirectory: URL?
    let registeredCount: Int
    let missingFiles: [String]
    let failedFiles: [String]

    var hasRegisteredFonts: Bool {
        registeredCount > 0
    }
}

enum HwpBundledFontRegistry {
    private static let lock = NSLock()
    private static var cachedStatus: HwpFontRegistrationStatus?

    private static let bundledFontFileNames = [
        "Cafe24Ssurround-v2.0.woff2",
        "Cafe24Supermagic-Regular-v1.0.woff2",
        "D2Coding-Bold.woff2",
        "D2Coding-Regular.woff2",
        "GowunBatang-Bold.woff2",
        "GowunBatang-Regular.woff2",
        "GowunDodum-Regular.woff2",
        "Happiness-Sans-Bold.woff2",
        "Happiness-Sans-Regular.woff2",
        "Happiness-Sans-Title.woff2",
        "HappinessSansVF.woff2",
        "LatinModernMath-Regular.woff2",
        "NanumGothic-Bold.woff2",
        "NanumGothic-ExtraBold.woff2",
        "NanumGothic-Regular.woff2",
        "NanumGothicCoding-Bold.woff2",
        "NanumGothicCoding-Regular.woff2",
        "NanumMyeongjo-Bold.woff2",
        "NanumMyeongjo-ExtraBold.woff2",
        "NanumMyeongjo-Regular.woff2",
        "NotoSansKR-Bold.woff2",
        "NotoSansKR-Regular.woff2",
        "NotoSerifKR-Bold.woff2",
        "NotoSerifKR-Regular.woff2",
        "Pretendard-Black.woff2",
        "Pretendard-Bold.woff2",
        "Pretendard-ExtraBold.woff2",
        "Pretendard-ExtraLight.woff2",
        "Pretendard-Light.woff2",
        "Pretendard-Medium.woff2",
        "Pretendard-Regular.woff2",
        "Pretendard-SemiBold.woff2",
        "Pretendard-Thin.woff2",
        "SourceHanSerifK-OldHangul-subset.woff2",
        "SpoqaHanSans-Regular.woff2",
    ]

    static func ensureRegistered() {
        _ = registrationStatus()
    }

    static func registrationStatus() -> HwpFontRegistrationStatus {
        lock.lock()
        defer { lock.unlock() }

        if let cachedStatus {
            return cachedStatus
        }

        let status = registerBundledFonts()
        cachedStatus = status
        return status
    }

    private static func registerBundledFonts() -> HwpFontRegistrationStatus {
        guard let fontDirectory = firstExistingFontDirectory() else {
            return HwpFontRegistrationStatus(
                fontDirectory: nil,
                registeredCount: 0,
                missingFiles: bundledFontFileNames,
                failedFiles: []
            )
        }

        let fileManager = FileManager.default
        var registeredCount = 0
        var missingFiles: [String] = []
        var failedFiles: [String] = []

        for fileName in bundledFontFileNames {
            let fontURL = fontDirectory.appendingPathComponent(fileName, isDirectory: false)
            guard fileManager.fileExists(atPath: fontURL.path) else {
                missingFiles.append(fileName)
                continue
            }

            var error: Unmanaged<CFError>?
            let registered = CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error)
            if registered || isAlreadyRegistered(error) {
                registeredCount += 1
            } else {
                failedFiles.append(fileName)
            }
        }

        return HwpFontRegistrationStatus(
            fontDirectory: fontDirectory,
            registeredCount: registeredCount,
            missingFiles: missingFiles,
            failedFiles: failedFiles
        )
    }

    private static func firstExistingFontDirectory() -> URL? {
        candidateFontDirectories().first { url in
            var isDirectory = ObjCBool(false)
            return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
    }

    private static func candidateFontDirectories() -> [URL] {
        var candidates: [URL] = []

        if let resourceURL = Bundle.main.resourceURL {
            candidates.append(resourceURL.appendingPathComponent("rhwp-studio/fonts", isDirectory: true))
            candidates.append(contentsOf: resourceCandidates(ascendingFrom: resourceURL))
        }

        candidates.append(contentsOf: resourceCandidates(ascendingFrom: Bundle.main.bundleURL))

        let workingDirectory = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        )
        candidates.append(
            workingDirectory.appendingPathComponent(
                "Sources/HostApp/Resources/rhwp-studio/fonts",
                isDirectory: true
            )
        )

        var seen = Set<String>()
        return candidates.filter { url in
            let key = url.standardizedFileURL.resolvingSymlinksInPath().path
            return seen.insert(key).inserted
        }
    }

    private static func resourceCandidates(ascendingFrom startURL: URL) -> [URL] {
        var candidates: [URL] = []
        var cursor = startURL.standardizedFileURL

        for _ in 0..<8 {
            candidates.append(
                cursor.appendingPathComponent(
                    "Contents/Resources/rhwp-studio/fonts",
                    isDirectory: true
                )
            )

            if cursor.lastPathComponent == "Contents" {
                candidates.append(
                    cursor.appendingPathComponent(
                        "Resources/rhwp-studio/fonts",
                        isDirectory: true
                    )
                )
            }

            let parent = cursor.deletingLastPathComponent()
            if parent.path == cursor.path {
                break
            }
            cursor = parent
        }

        return candidates
    }

    private static func isAlreadyRegistered(_ error: Unmanaged<CFError>?) -> Bool {
        guard let error else {
            return false
        }

        let nsError = error.takeRetainedValue() as Error as NSError
        return nsError.domain == kCTFontManagerErrorDomain as String
            && nsError.code == CTFontManagerError.alreadyRegistered.rawValue
    }
}
