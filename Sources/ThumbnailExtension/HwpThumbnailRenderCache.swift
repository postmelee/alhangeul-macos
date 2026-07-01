import CoreGraphics
import Foundation

struct HwpThumbnailRenderRequest {
    let fileURL: URL
    let maximumSize: CGSize
    let maximumPixelSize: CGSize
    let policy: HwpPageRenderPolicy
    let renderSignature: HwpThumbnailRenderSignature
    let key: HwpThumbnailCacheKey

    init(
        fileURL: URL,
        maximumSize: CGSize,
        scale: CGFloat,
        policy: HwpPageRenderPolicy = .coreGraphicsOnly,
        renderSignature: HwpThumbnailRenderSignature? = nil
    ) throws {
        let values = try fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let pixelWidth = Self.pixelBucket(for: maximumSize.width, scale: scale)
        let pixelHeight = Self.pixelBucket(for: maximumSize.height, scale: scale)
        let resolvedSignature = renderSignature ?? HwpThumbnailRenderSignature(policy: policy)

        self.fileURL = fileURL
        self.maximumSize = maximumSize
        self.maximumPixelSize = CGSize(width: pixelWidth, height: pixelHeight)
        self.policy = policy
        self.renderSignature = resolvedSignature
        self.key = HwpThumbnailCacheKey(
            path: fileURL.path,
            modificationTime: values.contentModificationDateKeyTimeInterval,
            fileSize: values.fileSize ?? 0,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            renderSignature: resolvedSignature
        )
    }

    private static func pixelBucket(for value: CGFloat, scale: CGFloat) -> Int {
        let scaledValue = max(16, Int(ceil(max(value, 1) * max(scale, 1))))
        var bucket = 16
        while bucket < scaledValue {
            bucket *= 2
        }
        return min(bucket, 2048)
    }
}

struct HwpThumbnailRenderSignature: Hashable {
    private static let rendererOptionVersion = "thumbnail-renderer-v1"
    private static let coreReleaseTag = RhwpCoreBuildInfo.releaseTag
    private static let coreCommit = RhwpCoreBuildInfo.commit
    private static let coreEnabledFeatures = RhwpCoreBuildInfo.enabledFeatures
    private static let maxDimensionPolicyVersion = "skia-max-dimension-0"

    let backendPolicy: String
    let rendererOptionVersion: String
    let coreReleaseTag: String
    let coreCommit: String
    let coreEnabledFeatures: String
    let maxDimensionPolicyVersion: String

    init(
        policy: HwpPageRenderPolicy,
        rendererOptionVersion: String = Self.rendererOptionVersion,
        coreReleaseTag: String = Self.coreReleaseTag,
        coreCommit: String = Self.coreCommit,
        coreEnabledFeatures: String = Self.coreEnabledFeatures,
        maxDimensionPolicyVersion: String = Self.maxDimensionPolicyVersion
    ) {
        self.backendPolicy = policy.identifier
        self.rendererOptionVersion = rendererOptionVersion
        self.coreReleaseTag = coreReleaseTag
        self.coreCommit = coreCommit
        self.coreEnabledFeatures = coreEnabledFeatures
        self.maxDimensionPolicyVersion = maxDimensionPolicyVersion
    }

    var identifier: String {
        [
            backendPolicy,
            rendererOptionVersion,
            coreReleaseTag,
            coreCommit,
            coreEnabledFeatures,
            maxDimensionPolicyVersion
        ].joined(separator: "|")
    }
}

struct HwpThumbnailCacheKey: Hashable {
    let path: String
    let modificationTime: TimeInterval
    let fileSize: Int
    let pixelWidth: Int
    let pixelHeight: Int
    let renderSignature: HwpThumbnailRenderSignature
}

enum HwpThumbnailCacheEvent: CustomStringConvertible, Equatable {
    case miss
    case exactHit
    case largerBucketHit(pixelWidth: Int, pixelHeight: Int)

    var description: String {
        switch self {
        case .miss:
            return "miss"
        case .exactHit:
            return "exactHit"
        case .largerBucketHit(let pixelWidth, let pixelHeight):
            return "largerBucketHit(\(pixelWidth)x\(pixelHeight))"
        }
    }
}

struct HwpThumbnailRenderResult {
    let page: HwpRenderedPage
    let cacheEvent: HwpThumbnailCacheEvent
    let requestedKey: HwpThumbnailCacheKey
    let matchedKey: HwpThumbnailCacheKey
}

private struct HwpThumbnailCacheHit {
    let key: HwpThumbnailCacheKey
    let page: HwpRenderedPage
    let event: HwpThumbnailCacheEvent
}

private extension URLResourceValues {
    var contentModificationDateKeyTimeInterval: TimeInterval {
        contentModificationDate?.timeIntervalSinceReferenceDate ?? 0
    }
}

final class HwpThumbnailRenderCache {
    static let shared = HwpThumbnailRenderCache()

    private let stateQueue = DispatchQueue(label: "com.postmelee.alhangeul.thumbnail-cache")
    private let workerQueue = DispatchQueue(
        label: "com.postmelee.alhangeul.thumbnail-render",
        qos: .utility
    )
    private let maxEntryCount = 96

    private var cachedPages: [HwpThumbnailCacheKey: HwpRenderedPage] = [:]
    private var accessOrder: [HwpThumbnailCacheKey] = []
    private var inFlight: [HwpThumbnailCacheKey: [(Result<HwpThumbnailRenderResult, Error>) -> Void]] = [:]

    private init() {}

    func renderedPage(
        for request: HwpThumbnailRenderRequest,
        completion: @escaping (Result<HwpRenderedPage, Error>) -> Void
    ) {
        renderedPageResult(for: request) { result in
            switch result {
            case .success(let renderResult):
                completion(.success(renderResult.page))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func renderedPageResult(
        for request: HwpThumbnailRenderRequest,
        completion: @escaping (Result<HwpThumbnailRenderResult, Error>) -> Void
    ) {
        stateQueue.async {
            if let hit = self.cachedPage(for: request.key) {
                self.touch(hit.key)
                self.workerQueue.async {
                    completion(.success(HwpThumbnailRenderResult(
                        page: hit.page,
                        cacheEvent: hit.event,
                        requestedKey: request.key,
                        matchedKey: hit.key
                    )))
                }
                return
            }

            if self.inFlight[request.key] != nil {
                self.inFlight[request.key, default: []].append(completion)
                return
            }

            self.inFlight[request.key] = [completion]
            self.workerQueue.async {
                let result = Result {
                    try HwpPageImageRenderer.renderFirstPage(
                        fileURL: request.fileURL,
                        maximumPixelSize: request.maximumPixelSize,
                        embeddedThumbnailPolicy: .never,
                        policy: request.policy
                    )
                }

                self.stateQueue.async {
                    let callbacks = self.inFlight.removeValue(forKey: request.key) ?? []
                    let callbackResult: Result<HwpThumbnailRenderResult, Error>
                    switch result {
                    case .success(let page):
                        self.store(page, for: request.key)
                        callbackResult = .success(HwpThumbnailRenderResult(
                            page: page,
                            cacheEvent: .miss,
                            requestedKey: request.key,
                            matchedKey: request.key
                        ))
                    case .failure(let error):
                        callbackResult = .failure(error)
                    }
                    for callback in callbacks {
                        self.workerQueue.async {
                            callback(callbackResult)
                        }
                    }
                }
            }
        }
    }

    private func store(_ page: HwpRenderedPage, for key: HwpThumbnailCacheKey) {
        cachedPages[key] = page
        touch(key)

        while accessOrder.count > maxEntryCount {
            let removedKey = accessOrder.removeFirst()
            cachedPages.removeValue(forKey: removedKey)
        }
    }

    private func touch(_ key: HwpThumbnailCacheKey) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }

    private func cachedPage(for requestedKey: HwpThumbnailCacheKey) -> HwpThumbnailCacheHit? {
        if let cached = cachedPages[requestedKey] {
            return HwpThumbnailCacheHit(
                key: requestedKey,
                page: cached,
                event: .exactHit
            )
        }

        var bestMatch: HwpThumbnailCacheHit?
        var bestArea = Int.max

        for (candidateKey, page) in cachedPages {
            guard
                candidateKey.path == requestedKey.path,
                candidateKey.modificationTime == requestedKey.modificationTime,
                candidateKey.fileSize == requestedKey.fileSize,
                candidateKey.renderSignature == requestedKey.renderSignature,
                candidateKey.pixelWidth >= requestedKey.pixelWidth,
                candidateKey.pixelHeight >= requestedKey.pixelHeight
            else {
                continue
            }

            let area = candidateKey.pixelWidth * candidateKey.pixelHeight
            if area < bestArea {
                bestArea = area
                bestMatch = HwpThumbnailCacheHit(
                    key: candidateKey,
                    page: page,
                    event: .largerBucketHit(
                        pixelWidth: candidateKey.pixelWidth,
                        pixelHeight: candidateKey.pixelHeight
                    )
                )
            }
        }

        return bestMatch
    }
}
