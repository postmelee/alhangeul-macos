import Foundation
import Rhwp

enum RhwpDocumentProtection: Equatable, Sendable {
    case plain
    case passwordProtected
    case unsupportedProtection
    case invalidOrUnknown

    init(status: UInt32) {
        switch status {
        case 0:
            self = .plain
        case 1:
            self = .passwordProtected
        case 2:
            self = .unsupportedProtection
        default:
            self = .invalidOrUnknown
        }
    }

    static func classify(data: Data) -> RhwpDocumentProtection {
        guard !data.isEmpty else {
            return .invalidOrUnknown
        }

        return data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                return .invalidOrUnknown
            }
            let status = rhwp_document_protection(
                baseAddress.assumingMemoryBound(to: UInt8.self),
                UInt(rawBuffer.count)
            )
            return RhwpDocumentProtection(status: status.rawValue)
        }
    }
}
