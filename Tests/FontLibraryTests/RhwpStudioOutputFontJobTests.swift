import Foundation
import XCTest

private actor OutputFontMeter {
    var reads = 0, releases = 0, valid = true
    func read() { reads += 1 }
    func release() { releases += 1 }
    func current() -> Bool { valid }
    func invalidate() { valid = false }
}
private actor OutputReadGate {
    var entered = false
    var start: CheckedContinuation<Void, Never>?
    var finish: CheckedContinuation<Void, Never>?
    func waitForEntry() async { if !entered { await withCheckedContinuation { start = $0 } } }
    func read() async { entered = true; start?.resume(); start = nil; await withCheckedContinuation { finish = $0 } }
    func open() { finish?.resume(); finish = nil }
}

@MainActor
final class RhwpStudioOutputFontJobTests: XCTestCase {
    private func bytes(_ name: String = "regular.ttf", flags: UInt16? = nil, version: UInt16? = nil,
                       evidence: FontUsageEvidence? = nil) throws -> StudioFontBytes {
        let folder = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Fixtures", withExtension: nil))
        var data = try Data(contentsOf: folder.appendingPathComponent(name))
        if flags != nil || version != nil {
            func u16(_ i: Int) -> Int { Int(data[i]) << 8 | Int(data[i+1]) }
            func u32(_ i: Int) -> Int { u16(i) << 16 | u16(i+2) }
            let record = try XCTUnwrap((0..<u16(4)).map { 12 + $0 * 16 }.first {
                String(data: data[$0..<($0+4)], encoding: .ascii) == "OS/2"
            })
            let offset = u32(record+8)
            for (index, value) in [(offset, version), (offset+8, flags)] {
                if let value { data[index] = UInt8(value >> 8); data[index+1] = UInt8(value & 255) }
            }
        }
        let face = try XCTUnwrap(FontFileInspector().inspect(data, filename: name).faces.first)
        return .init(data: data, face: face, usageEvidence: evidence)
    }
    private func request(_ key: String = "one", weight: Int = 400, stroke: Bool = false) -> RhwpStudioOutputFontRequest {
        .init(key: key, family: "Fixture", weight: weight, slant: "normal", hasStroke: stroke)
    }
    private func job(_ value: StudioFontBytes, meter: OutputFontMeter = .init(), budget: StudioFontTransferBudget = .init(),
                     gate: OutputReadGate? = nil, limits: RhwpStudioOutputFontLimits = .init(),
                     document: @escaping @MainActor () async throws -> Bool = { true },
                     resolution: RhwpStudioOutputFontJob.Resolver? = nil) -> RhwpStudioOutputFontJob {
        let face = StudioFontFace(id: "font", source: "managed", postScriptName: value.face.postScriptName,
            family: "Fixture", fullName: "Fixture Regular", style: "Regular", aliases: [],
            weight: Int(value.face.weightClass), traits: 0, limitation: nil)
        let snapshot = StudioFontSupplySnapshot(identity: "native", faces: [face], omitted: 0, failure: nil,
            read: { _ in await meter.read(); await gate?.read(); return value },
            current: { await meter.current() }, release: { await meter.release() })
        return .init(document: .init(loadToken: "doc", epoch: 1, revision: 2), snapshot: snapshot,
            budget: budget, limits: limits, documentIsCurrent: document, resolve: resolution ?? { requests in
                .init(identity: "native", revision: "provider-1", generation: 1, selections: requests.map {
                    .init(key: $0.key, status: "selected", id: "font", postscriptName: value.face.postScriptName,
                          weight: Int(value.face.weightClass), slant: "normal")
                })
            })
    }
    private func rejects(_ expected: RhwpStudioOutputFontError, _ body: () async throws -> Void) async {
        do { try await body(); XCTFail("expected \(expected)") }
        catch { XCTAssertEqual(error as? RhwpStudioOutputFontError, expected) }
    }

    func testPreparedBytesUseExactOpaqueRouteAndOneReadPerJob() async throws {
        let value = try bytes(), meter = OutputFontMeter(), output = job(value, meter: meter)
        let firstRows = try await output.prepare([request()]), secondRows = try await output.prepare([request("two")])
        let first = try XCTUnwrap(firstRows.first?.font), second = try XCTUnwrap(secondRows.first?.font)
        XCTAssertEqual(first.url, second.url)
        XCTAssertEqual(try output.resource(for: URL(string: first.url)!).data, value.data)
        let count = await meter.reads; XCTAssertEqual(count, 1)
        XCTAssertEqual(output.residentBytes, value.data.count)
        for url in [first.url + "?q=1", first.url + "#x", first.url.replacingOccurrences(of: output.token, with: "wrong"),
                    first.url.replacingOccurrences(of: "://snapshot/", with: "://user@snapshot/"),
                    first.url.replacingOccurrences(of: "://snapshot/", with: "://snapshot:443/")] {
            XCTAssertThrowsError(try output.resource(for: URL(string: url)!))
        }
        await output.close(); await output.close()
        XCTAssertThrowsError(try output.resource(for: URL(string: first.url)!))
        let released = await meter.releases; XCTAssertEqual(released, 1)
    }

    func testUnavailableFamiliesAreCollectedWithoutTreatingStaleAsFallback() async throws {
        let meter = OutputFontMeter()
        let output = job(try bytes(),meter:meter,resolution:{ requests in
            .init(identity:"native",revision:"r1",generation:1,selections:requests.map {
                .init(key:$0.key,status:"unavailable",id:nil,postscriptName:nil,weight:nil,slant:nil)
            })
        })
        await rejects(.unavailable) {
            _ = try await output.prepare([.init(key:"a",family:"Font A",weight:400,slant:"normal"),
                .init(key:"b",family:"Font B",weight:400,slant:"normal")])
        }
        XCTAssertEqual(output.failures.map(\.family),["Font A","Font B"])
        let reads = await meter.reads; XCTAssertEqual(reads,0)
        await meter.invalidate()
        await rejects(.stale) { _ = try await output.prepare([self.request()]) }
        XCTAssertEqual(output.failures.count,2)
        await output.close()
    }

    func testBoldRequestNeverSilentlyUsesExactRegularFace() async throws {
        let meter = OutputFontMeter(), output = job(try bytes(),meter:meter)
        await rejects(.unavailable) { _ = try await output.prepare([self.request(weight:700)]) }
        let reads = await meter.reads; XCTAssertEqual(reads,0)
        XCTAssertEqual(output.failures.map(\.family),["Fixture"])
        await output.close()
    }

    func testConcurrentSameFaceReadIsJoined() async throws {
        let gate = OutputReadGate(), meter = OutputFontMeter(), output = job(try bytes(), meter: meter, gate: gate)
        let first = Task { try await output.prepare([self.request("a")]) }
        await gate.waitForEntry()
        let second = Task { try await output.prepare([self.request("b")]) }
        for _ in 0..<10 { await Task.yield() }
        await gate.open()
        let (a, b) = try await (first.value, second.value)
        XCTAssertEqual(a[0].font?.url, b[0].font?.url)
        let count = await meter.reads; XCTAssertEqual(count, 1)
        await output.close()
    }

    func testCancellationRetainsLeaseAndBudgetUntilIgnoredIOCompletes() async throws {
        let gate = OutputReadGate(), meter = OutputFontMeter(), budget = StudioFontTransferBudget()
        let other = try await budget.acquire()
        let output = job(try bytes(), meter: meter, budget: budget, gate: gate)
        let reading = Task { try await output.prepare([self.request()]) }
        await gate.waitForEntry(); output.cancel()
        let before = await meter.releases; XCTAssertEqual(before, 0)
        do { _ = try await budget.acquire(); XCTFail("cancelled IO slot released early") }
        catch { XCTAssertEqual(error as? StudioFontError, .busy) }
        await gate.open()
        do { _ = try await reading.value; XCTFail("late bytes published") } catch {}
        await output.close()
        let after = await meter.releases; XCTAssertEqual(after, 1)
        let available = try await budget.acquire()
        await budget.release(available); await budget.release(other)
    }

    func testCatalogAndDocumentChangesRejectJob() async throws {
        let meter = OutputFontMeter(), output = job(try bytes(), meter: meter)
        _ = try await output.prepare([request()]); await meter.invalidate()
        await rejects(.stale) { try await output.validate() }; await output.close()
        let changed = job(try bytes(), document: { false })
        await rejects(.stale) { _ = try await changed.prepare([self.request()]) }; await changed.close()
    }

    func testProviderGenerationCannotMixAcrossPages() async throws {
        let value = try bytes(); var generation = 1
        let output = job(value, resolution: { requests in
            .init(identity: "native", revision: "provider", generation: generation, selections: requests.map {
                .init(key: $0.key, status: "absent", id: nil, postscriptName: nil, weight: nil, slant: nil)
            })
        })
        let nodes = try await output.prepare([request()]); XCTAssertNil(nodes[0].font)
        generation = 2
        await rejects(.stale) { _ = try await output.prepare([self.request("next")]) }; await output.close()
    }

    func testUnresolvedAndUnsupportedRequestsDoNotReadBytes() async throws {
        for (weight, stroke) in [(500, false), (400, true)] {
            let meter = OutputFontMeter(), output = job(try bytes(), meter: meter)
            await rejects(.unavailable) { _ = try await output.prepare([self.request(weight: weight, stroke: stroke)]) }
            let count = await meter.reads; XCTAssertEqual(count, 0); await output.close()
        }
        let value = try bytes(), output = job(value, resolution: { requests in
            .init(identity: "other-native", revision: "provider", generation: 1, selections: [])
        })
        await rejects(.stale) { _ = try await output.prepare([self.request()]) }; await output.close()
        let angled = job(value)
        let angleRequest = try JSONDecoder().decode(RhwpStudioOutputFontRequest.self,
            from: Data(#"{"key":"angle","family":"Fixture","weight":400,"slant":"oblique","hasUnsupportedStyle":true}"#.utf8))
        await rejects(.unavailable) { _ = try await angled.prepare([angleRequest]) }; await angled.close()
    }

    func testStaleOrFailedReadDoesNotPublishAndAlwaysReleasesLease() async throws {
        let value = try bytes(), meter = OutputFontMeter(), gate = OutputReadGate()
        let output = job(value, meter: meter, gate: gate)
        let reading = Task { try await output.prepare([self.request()]) }
        await gate.waitForEntry(); await meter.invalidate(); await gate.open()
        await rejects(.stale) { _ = try await reading.value }
        XCTAssertEqual(output.residentBytes, 0)
        await output.close()
        let released = await meter.releases; XCTAssertEqual(released, 1)

        let broken = StudioFontBytes(data: Data([0,1,2]), face: value.face)
        let failed = job(broken)
        do { _ = try await failed.prepare([request()]); XCTFail("partial bytes accepted") } catch {}
        XCTAssertEqual(failed.residentBytes, 0); await failed.close()
    }

    func testBusyReadDoesNotConsumeOrReleaseAnotherConsumersSlots() async throws {
        let budget = StudioFontTransferBudget(), meter = OutputFontMeter()
        let slots = try await [budget.acquire(), budget.acquire()]
        let output = job(try bytes(), meter: meter, budget: budget)
        do { _ = try await output.prepare([request()]); XCTFail("busy read succeeded") }
        catch { XCTAssertEqual(error as? StudioFontError, .busy) }
        let reads = await meter.reads; XCTAssertEqual(reads, 0)
        await output.close()
        do { _ = try await budget.acquire(); XCTFail("another consumer's slot released") } catch {}
        for slot in slots { await budget.release(slot) }
    }

    func testInputAndByteCapacityAreExplicitFailures() async throws {
        let value = try bytes()
        for limits in [RhwpStudioOutputFontLimits(faces: 0), RhwpStudioOutputFontLimits(fileBytes: value.data.count - 1),
                       RhwpStudioOutputFontLimits(residentBytes: 1)] {
            let output = job(value, limits: limits)
            await rejects(.tooLarge) { _ = try await output.prepare([self.request()]) }; await output.close()
        }
        let output = job(value)
        await rejects(.invalidRequest) { _ = try await output.prepare([self.request(), self.request()]) }
        await output.close()
    }

    func testSealExpiresRoutesButHoldsLeaseUntilPrintPanelOwnerCloses() async throws {
        let meter = OutputFontMeter(), output = job(try bytes(), meter: meter)
        let rows = try await output.prepare([request()])
        let font = try XCTUnwrap(rows.first?.font)
        try await output.seal()
        XCTAssertThrowsError(try output.resource(for: URL(string: font.url)!))
        let held = await meter.releases; XCTAssertEqual(held, 0)
        await output.close()
        let released = await meter.releases; XCTAssertEqual(released, 1)
    }

    func testEmbeddingDeclarationsRespectVersionAndPreserveUnknownEvidence() throws {
        for permission: UInt16 in [0,4,8] { XCTAssertNoThrow(try RhwpStudioOutputFontPolicy.validate(bytes(flags: permission))) }
        for flags: UInt16 in [1,12,0x100,0x200,0x10] {
            XCTAssertThrowsError(try RhwpStudioOutputFontPolicy.validate(bytes(flags: flags)))
        }
        XCTAssertThrowsError(try RhwpStudioOutputFontPolicy.validate(bytes(flags: 2))) { error in
            XCTAssertEqual(error as? RhwpStudioOutputFontError, .restricted)
        }
        XCTAssertNoThrow(try RhwpStudioOutputFontPolicy.validate(bytes(flags: 0x100, version: 1)))
        let unknown = FontUsageEvidence(localCopy: .unknown, embedding: .unknown, note: nil, licenseResourceID: nil)
        let value = try bytes(evidence: unknown)
        XCTAssertNoThrow(try RhwpStudioOutputFontPolicy.validate(value)); XCTAssertEqual(value.usageEvidence, unknown)
        let restricted = FontUsageEvidence(localCopy: .allowed, embedding: .restricted, note: nil, licenseResourceID: nil)
        XCTAssertThrowsError(try RhwpStudioOutputFontPolicy.validate(bytes(evidence: restricted)))
        XCTAssertThrowsError(try RhwpStudioOutputFontPolicy.validate(bytes("variable.ttf")))
        XCTAssertThrowsError(try RhwpStudioOutputFontPolicy.validate(bytes("two-face.ttc")))
    }
}
