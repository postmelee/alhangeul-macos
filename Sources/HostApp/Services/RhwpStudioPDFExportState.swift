import Foundation

struct RhwpStudioPDFExportRequest: Equatable {
    let id: Int
    let loadID: Int
}

enum RhwpStudioPDFExportState: Equatable {
    case idle
    case choosingDestination(RhwpStudioPDFExportRequest)
    case collectingPages(RhwpStudioPDFExportRequest, URL)
    case exporting(requestID: Int)

    var isIdle: Bool {
        if case .idle = self {
            return true
        }
        return false
    }

    @discardableResult
    mutating func beginChoosingDestination(
        for request: RhwpStudioPDFExportRequest
    ) -> Bool {
        guard isIdle else {
            return false
        }
        self = .choosingDestination(request)
        return true
    }

    @discardableResult
    mutating func beginCollectingPages(
        for request: RhwpStudioPDFExportRequest,
        destinationURL: URL,
        currentLoadID: Int
    ) -> Bool {
        guard request.loadID == currentLoadID,
              case .choosingDestination(let activeRequest) = self,
              activeRequest == request
        else {
            return false
        }

        self = .collectingPages(request, destinationURL)
        return true
    }

    func collection(
        for requestID: Int
    ) -> (request: RhwpStudioPDFExportRequest, destinationURL: URL)? {
        guard case .collectingPages(let request, let destinationURL) = self,
              request.id == requestID
        else {
            return nil
        }
        return (request, destinationURL)
    }

    mutating func beginExporting(requestID: Int) -> URL? {
        guard let collection = collection(for: requestID) else {
            return nil
        }
        self = .exporting(requestID: requestID)
        return collection.destinationURL
    }

    @discardableResult
    mutating func cancelDestinationSelection(requestID: Int) -> Bool {
        guard case .choosingDestination(let request) = self,
              request.id == requestID
        else {
            return false
        }
        self = .idle
        return true
    }

    @discardableResult
    mutating func failCollection(requestID: Int) -> Bool {
        guard collection(for: requestID) != nil else {
            return false
        }
        self = .idle
        return true
    }

    @discardableResult
    mutating func finishExport(requestID: Int) -> Bool {
        guard case .exporting(let activeRequestID) = self,
              activeRequestID == requestID
        else {
            return false
        }
        self = .idle
        return true
    }

    mutating func invalidatePendingRequestForDocumentChange() {
        switch self {
        case .choosingDestination, .collectingPages:
            self = .idle
        case .idle, .exporting:
            break
        }
    }
}
