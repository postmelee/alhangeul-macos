import Foundation
import CoreFoundation

@MainActor
final class StudioFontSession {
    private struct Transfer {
        let bytes: StudioFontBytes
        let slot: UUID
        var touched: Date
    }
    private let supply: StudioFontSupply
    private let budget: StudioFontTransferBudget
    private let now: () -> Date
    private var snapshot: StudioFontSupplySnapshot?
    private var revision = UUID().uuidString
    private var session = UUID().uuidString
    private var transfers: [String: Transfer] = [:]
    private var reads: [String: Task<StudioFontBytes, Error>] = [:]
    private var opening = Set<String>()
    private var pending = 0
    private var epoch = 0
    private var expiry: Task<Void, Never>?

    init(supply: StudioFontSupply = .live, budget: StudioFontTransferBudget = .shared,
         now: @escaping () -> Date = Date.init) {
        self.supply = supply; self.budget = budget; self.now = now
    }

    deinit {
        expiry?.cancel()
        for task in reads.values { task.cancel() }
        let slots = transfers.values.map(\.slot)
        let old = snapshot
        let budget = budget
        Task {
            for slot in slots { await budget.release(slot) }
            await old?.release()
        }
    }

    func invalidate() {
        epoch += 1
        session = UUID().uuidString; revision = UUID().uuidString
        for task in reads.values { task.cancel() }
        reads.removeAll()
        opening.removeAll()
        let old = snapshot; snapshot = nil
        let slots = transfers.values.map(\.slot); transfers.removeAll()
        expiry?.cancel(); expiry = nil
        Task { [budget] in
            for slot in slots { await budget.release(slot) }
            await old?.release()
        }
    }

    func handle(_ body: Any) async throws -> [String: Any] {
        guard let message = body as? [String: Any], JSONSerialization.isValidJSONObject(message),
              let encoded = try? JSONSerialization.data(withJSONObject: message), encoded.count <= 4096,
              let operation = message["op"] as? String,
              message["version"] as? Int == 1,
              Set(message.keys).isSubset(of: ["op", "version", "session", "revision", "id", "offset", "length"])
        else { throw StudioFontError.invalidRequest }
        for value in message.values {
            if let string = value as? String, string.utf8.count > 1024 { throw StudioFontError.invalidRequest }
        }
        let fields: Set<String>
        switch operation {
        case "handshake": fields = ["op", "version"]
        case "catalog": fields = ["op", "version", "session", "revision", "offset"]
        case "openFace", "closeFace", "cancel": fields = ["op", "version", "session", "revision", "id"]
        case "readChunk": fields = ["op", "version", "session", "revision", "id", "offset", "length"]
        default: throw StudioFontError.invalidRequest
        }
        guard Set(message.keys).isSubset(of: fields),
              let version = message["version"] as? NSNumber,
              CFGetTypeID(version) != CFBooleanGetTypeID(), version.doubleValue == 1
        else { throw StudioFontError.invalidRequest }
        guard pending < 8 else { throw StudioFontError.busy }
        pending += 1; defer { pending -= 1 }
        if operation == "handshake" {
            // 이미 시작한 handshake를 새 요청이 덮지 않도록 최초 준비를 직렬화한다.
            guard pending == 1 else { throw StudioFontError.busy }
            if snapshot == nil {
                let expected = epoch
                let next = try await supply.snapshot()
                guard expected == epoch else { await next.release(); throw StudioFontError.staleSession }
                snapshot = next
            }
            startExpiry()
            return ["version": 1, "session": session, "revision": revision]
        }
        guard message["session"] as? String == session else { throw StudioFontError.staleSession }
        guard message["revision"] as? String == revision, let snapshot else { throw StudioFontError.staleGeneration }
        let expectedEpoch = epoch
        let current = try await snapshot.current()
        guard expectedEpoch == epoch else { throw StudioFontError.staleSession }
        guard current else { invalidate(); throw StudioFontError.staleGeneration }
        await expireTransfers()
        guard expectedEpoch == epoch else { throw StudioFontError.staleSession }
        switch operation {
        case "catalog":
            let offset = try integer(message["offset"], default: 0)
            guard offset <= snapshot.faces.count else { throw StudioFontError.invalidRequest }
            var rows: [[String: Any]] = []
            for face in snapshot.faces.dropFirst(offset).prefix(128) {
                let data = try JSONEncoder().encode(face)
                guard let row = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                let candidate = rows + [row]
                if try JSONSerialization.data(withJSONObject: candidate).count > 250 * 1024 { break }
                rows = candidate
            }
            return ["revision": revision, "faces": rows, "nextOffset": offset + rows.count,
                    "total": snapshot.faces.count, "omitted": snapshot.omitted, "identity": snapshot.identity,
                    "failure": snapshot.failure as Any? ?? NSNull()]
        case "openFace":
            guard let id = message["id"] as? String,
                  let face = snapshot.faces.first(where: { $0.id == id }) else { throw StudioFontError.invalidRequest }
            guard face.limitation == nil else { throw StudioFontError.unavailable }
            guard !opening.contains(id) else { throw StudioFontError.busy }
            opening.insert(id)
            defer { if expectedEpoch == epoch { opening.remove(id) } }
            let slot = try await budget.acquire()
            guard expectedEpoch == epoch else { await budget.release(slot); throw StudioFontError.staleSession }
            let task = Task { try await snapshot.read(id) }
            reads[id] = task
            do {
                let timeout = Task {
                    do { try await Task.sleep(nanoseconds: 30_000_000_000); task.cancel() } catch {}
                }
                defer { timeout.cancel() }
                let bytes = try await task.value
                guard !task.isCancelled else { throw StudioFontError.cancelled }
                guard expectedEpoch == epoch else { throw StudioFontError.staleSession }
                guard !bytes.data.isEmpty, bytes.data.count <= 64 * 1024 * 1024 else { throw StudioFontError.tooLarge }
                guard try await snapshot.current(), expectedEpoch == epoch else { throw StudioFontError.staleGeneration }
                let token = UUID().uuidString
                transfers[token] = Transfer(bytes: bytes, slot: slot, touched: now())
                reads[id] = nil
                return ["id": token, "byteCount": bytes.data.count, "sha256": bytes.face.id.objectHash,
                        "postScriptName": bytes.face.postScriptName, "faceIndex": bytes.face.id.sfntIndex,
                        "weight": Int(bytes.face.weightClass), "revision": revision]
            } catch {
                if expectedEpoch == epoch { reads[id] = nil }
                await budget.release(slot)
                throw error
            }
        case "readChunk":
            guard let id = message["id"] as? String, var transfer = transfers[id] else { throw StudioFontError.invalidRequest }
            let offset = try integer(message["offset"])
            let length = try integer(message["length"])
            guard length > 0, length <= 256 * 1024, offset <= transfer.bytes.data.count,
                  length <= transfer.bytes.data.count - offset else { throw StudioFontError.invalidRequest }
            transfer.touched = now(); transfers[id] = transfer
            return ["id": id, "offset": offset, "data": transfer.bytes.data.subdata(in: offset..<(offset + length)).base64EncodedString(), "revision": revision]
        case "closeFace", "cancel":
            guard let id = message["id"] as? String else { throw StudioFontError.invalidRequest }
            if let transfer = transfers.removeValue(forKey: id) { await budget.release(transfer.slot) }
            reads[id]?.cancel()
            return ["closed": true]
        default: throw StudioFontError.invalidRequest
        }
    }

    private func integer(_ value: Any?, default fallback: Int? = nil) throws -> Int {
        if value == nil, let fallback { return fallback }
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue.isFinite, number.doubleValue >= 0,
              number.doubleValue < Double(Int.max), number.doubleValue.rounded() == number.doubleValue
        else { throw StudioFontError.invalidRequest }
        return number.intValue
    }

    func expireTransfers() async {
        let expired = transfers.filter { now().timeIntervalSince($0.value.touched) >= 30 }.map(\.key)
        for key in expired {
            if let transfer = transfers.removeValue(forKey: key) { await budget.release(transfer.slot) }
        }
    }

    private func startExpiry() {
        guard expiry == nil else { return }
        expiry = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 5_000_000_000) } catch { return }
                await self?.expireTransfers()
            }
        }
    }
}
