import CoreGraphics
import Foundation

struct HwpThumbnailRenderRequest {
    let fileURL: URL
    let maximumSize: CGSize
    let maximumPixelSize: CGSize
    let key: HwpThumbnailCacheKey

    init(fileURL: URL, maximumSize: CGSize, scale: CGFloat) throws {
        let values = try fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let pixelWidth = Self.pixelBucket(for: maximumSize.width, scale: scale)
        let pixelHeight = Self.pixelBucket(for: maximumSize.height, scale: scale)

        self.fileURL = fileURL
        self.maximumSize = maximumSize
        self.maximumPixelSize = CGSize(width: pixelWidth, height: pixelHeight)
        self.key = HwpThumbnailCacheKey(
            path: fileURL.path,
            modificationTime: values.contentModificationDateKeyTimeInterval,
            fileSize: values.fileSize ?? 0,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight
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

struct HwpThumbnailCacheKey: Hashable {
    let path: String
    let modificationTime: TimeInterval
    let fileSize: Int
    let pixelWidth: Int
    let pixelHeight: Int
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
        qos: .utility,
        attributes: .concurrent
    )
    private let maxEntryCount = 96

    private var cachedPages: [HwpThumbnailCacheKey: HwpRenderedPage] = [:]
    private var accessOrder: [HwpThumbnailCacheKey] = []
    private var inFlight: [HwpThumbnailCacheKey: [(Result<HwpRenderedPage, Error>) -> Void]] = [:]

    private init() {}

    func renderedPage(
        for request: HwpThumbnailRenderRequest,
        completion: @escaping (Result<HwpRenderedPage, Error>) -> Void
    ) {
        stateQueue.async {
            if let (matchedKey, cached) = self.cachedPage(for: request.key) {
                self.touch(matchedKey)
                self.workerQueue.async {
                    completion(.success(cached))
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
                        embeddedThumbnailPolicy: .never
                    )
                }

                self.stateQueue.async {
                    let callbacks = self.inFlight.removeValue(forKey: request.key) ?? []
                    if case .success(let page) = result {
                        self.store(page, for: request.key)
                    }
                    for callback in callbacks {
                        self.workerQueue.async {
                            callback(result)
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

    private func cachedPage(for requestedKey: HwpThumbnailCacheKey) -> (HwpThumbnailCacheKey, HwpRenderedPage)? {
        if let cached = cachedPages[requestedKey] {
            return (requestedKey, cached)
        }

        var bestMatch: (HwpThumbnailCacheKey, HwpRenderedPage)?
        var bestArea = Int.max

        for (candidateKey, page) in cachedPages {
            guard
                candidateKey.path == requestedKey.path,
                candidateKey.modificationTime == requestedKey.modificationTime,
                candidateKey.fileSize == requestedKey.fileSize,
                candidateKey.pixelWidth >= requestedKey.pixelWidth,
                candidateKey.pixelHeight >= requestedKey.pixelHeight
            else {
                continue
            }

            let area = candidateKey.pixelWidth * candidateKey.pixelHeight
            if area < bestArea {
                bestArea = area
                bestMatch = (candidateKey, page)
            }
        }

        return bestMatch
    }
}
