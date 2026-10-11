import Foundation
import CoreGraphics
import CoreText
import CryptoKit

actor Meter {
    var reads: [String] = []
    var releases = 0
    func read(_ id: String) { reads.append(id) }
    func release() { releases += 1 }
}
actor Gate {
    var entered = false
    var waiter: CheckedContinuation<Void, Never>?
    func wait() async { entered = true; await withCheckedContinuation { waiter = $0 } }
    func finish() { waiter?.resume(); waiter = nil }
}
func tracked(_ original: StudioFontSupplySnapshot, _ meter: Meter, gate: Gate? = nil) -> StudioFontSupplySnapshot {
    .init(identity: original.identity, faces: original.faces, omitted: original.omitted, failure: original.failure,
        read: { id in await meter.read(id); let value = try await original.read(id); if let gate { await gate.wait() }; return value },
        current: original.current, release: { await original.release(); await meter.release() })
}
func verify(_ condition: Bool, line: UInt = #line) { precondition(condition, "수용 조건 실패: \(line)") }
func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format:"%02x",$0) }.joined() }
func reject(line: UInt = #line, _ block: () async throws -> HwpNativeFontPageResult) async -> String {
    do { _ = try await block(); preconditionFailure("거부해야 할 요청이 성공했습니다: \(line)") }
    catch { return String(describing:error) }
}

@main struct Acceptance {
    static func main() async throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let out = URL(fileURLWithPath: CommandLine.arguments[2])
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let fonts = root.appendingPathComponent("build.noindex/task567/fonts/gowun-batang")
        let regularData = try Data(contentsOf: root.appendingPathComponent("build.noindex/task568/stage4/regular-control.hwpx"))
        let fullData = try Data(contentsOf: root.appendingPathComponent("build.noindex/task568/stage3/fixtures/gowun-document.hwpx"))
        let libraryRoot = out.appendingPathComponent("library-\(UUID().uuidString)")
        let library = FontLibraryService(store: FontLibraryStore(rootURL: libraryRoot))
        // 실제 사용자 설치 목록을 바꾸지 않는 process-scope 시험 source다.
        let regularURL = fonts.appendingPathComponent("GowunBatang-Regular.ttf")
        var registrationError: Unmanaged<CFError>?
        let processRegistered = CTFontManagerRegisterFontsForURL(regularURL as CFURL, .process, &registrationError)
        defer { if processRegistered { CTFontManagerUnregisterFontsForURL(regularURL as CFURL, .process, nil) } }
        let installed = try InstalledFontCatalogService(persistence: .file(at: out.appendingPathComponent("installed-\(UUID().uuidString)")), observeChanges: false)
        _ = try await installed.prepare(); _ = try await installed.setEnabled(true)
        let catalog = await installed.snapshot()
        verify(catalog.records.contains { $0.postScriptName == "GowunBatang-Regular" && $0.failure == nil })
        let provider = InstalledFontServiceProvider(factory: { installed })
        let realInstalled = try Data(contentsOf:root.appendingPathComponent("build.noindex/task568/stage4/installed-wide.hwpx"))
        let realSupply = StudioFontSupply.using(installed:provider,library:{library})
        var realInstalledProof: [[String:Any]] = []
        for policy in [HwpPageRenderPolicy.coreGraphicsOnly,.skiaOptIn] {
            let result = try await realSupply.renderNativePage(data:realInstalled,filename:"installed.hwpx",policy:policy)
            verify(result.selectedFaces == ["ArialUnicodeMS"] && result.sourceReads == 1)
            if policy == .skiaOptIn { verify(result.page.diagnostics.backendUsed == .skia) }
            let png = try HwpPageImageRenderer.encodePNG(result.page.image)
            try png.write(to:out.appendingPathComponent("real-installed-\(policy.identifier).png"))
            realInstalledProof.append(["backend":policy.identifier,"faces":result.selectedFaces,"bytes":result.sourceBytes,"imageSHA256":digest(png)])
        }
        let supply = StudioFontSupply.using(installed: provider, library: { library })
        let before = try await supply.renderNativePage(data: regularData, filename: "control.hwpx", policy: .skiaOptIn)
        verify(before.selectedFaces == ["GowunBatang-Regular"] && before.sourceReads == 1 && before.page.diagnostics.backendUsed == .skia)
        let installedPNG = try HwpPageImageRenderer.encodePNG(before.page.image)
        try installedPNG.write(to: out.appendingPathComponent("installed-skia.png"))
        let installedCG = try await supply.renderNativePage(data: regularData, filename: "control.hwpx", policy: .coreGraphicsOnly)
        verify(installedCG.selectedFaces == before.selectedFaces)
        try HwpPageImageRenderer.encodePNG(installedCG.page.image).write(to: out.appendingPathComponent("installed-cg.png"))

        let installedOnly = try await supply.snapshot()
        let installedRow = installedOnly.faces.first { $0.postScriptName == "GowunBatang-Regular" }!
        let duplicate = StudioFontFace(id:"installed:ambiguous-fixture",source:"installed",postScriptName:installedRow.postScriptName,
            family:installedRow.family,fullName:installedRow.fullName,style:installedRow.style,aliases:installedRow.aliases,
            weight:installedRow.weight,traits:installedRow.traits,limitation:nil)
        let ambiguous = StudioFontSupplySnapshot(identity:installedOnly.identity,faces:installedOnly.faces+[duplicate],
            omitted:0,failure:nil,read:installedOnly.read,current:installedOnly.current,release:installedOnly.release)
        let ambiguousMeter = Meter()
        let ambiguousFailure = await reject { try await HwpNativeFontPageRenderer.render(data:regularData,filename:"control.hwpx",snapshot:tracked(ambiguous,ambiguousMeter)) }
        verify(ambiguousFailure == "unavailable"); verify(await ambiguousMeter.reads.isEmpty); verify(await ambiguousMeter.releases == 1)
        _ = try await installed.setEnabled(false)
        let disabledMeter = Meter()
        let disabled = await reject { try await HwpNativeFontPageRenderer.render(data:regularData,filename:"control.hwpx",snapshot:tracked(try await supply.snapshot(),disabledMeter)) }
        verify(disabled == "unavailable"); verify(await disabledMeter.reads.isEmpty); verify(await disabledMeter.releases == 1)
        _ = try await installed.setEnabled(true)

        let added = await library.importFonts(.init(candidates: ["Regular","Bold"].map {
            .init(sourceURL: fonts.appendingPathComponent("GowunBatang-\($0).ttf")) }, accessURLs: []))
        verify(added.allSatisfy { $0.status == .added })
        var rendered: [[String: Any]] = []
        for ext in ["hwpx", "hwp"] {
            let doc = try Data(contentsOf: root.appendingPathComponent("build.noindex/task568/stage3/fixtures/gowun-document.\(ext)"))
            for policy in [HwpPageRenderPolicy.coreGraphicsOnly, .skiaOptIn] {
                let meter = Meter()
                let result = try await HwpNativeFontPageRenderer.render(data: doc, filename: "probe.\(ext)",
                    snapshot: tracked(try await supply.snapshot(), meter), policy: policy)
                verify(result.selectedFaces == ["GowunBatang-Bold", "GowunBatang-Regular"] && result.sourceReads == 2)
                verify(await meter.reads.allSatisfy { $0.hasPrefix("managed:") })
                verify(await meter.releases == 1)
                if policy == .skiaOptIn { verify(result.page.diagnostics.backendUsed == .skia) }
                let png = try HwpPageImageRenderer.encodePNG(result.page.image)
                try png.write(to: out.appendingPathComponent("managed-\(ext)-\(policy.identifier).png"))
                rendered.append(["format":ext,"backend":policy.identifier,"faces":result.selectedFaces,
                    "reads":result.sourceReads,"bytes":result.sourceBytes,"imageSHA256":digest(png),"managedPriority":true])
            }
        }
        let managedOriginal = try await supply.renderNativePage(data: regularData, filename: "control.hwpx", policy: .skiaOptIn)
        let originalPNG = try HwpPageImageRenderer.encodePNG(managedOriginal.page.image)
        let oldSnapshot = try await supply.snapshot()
        _ = try await installed.setEnabled(false)
        let staleMeter = Meter()
        let stale = await reject { try await HwpNativeFontPageRenderer.render(data: fullData, filename:"probe.hwpx", snapshot:tracked(oldSnapshot,staleMeter)) }
        verify(stale == "stale"); verify(await staleMeter.reads.isEmpty); verify(await staleMeter.releases == 1)
        // 관리 원본은 설치 감지를 끈 상태에도 읽을 수 있다.
        let managedDisabled = try await supply.renderNativePage(data: fullData, filename:"probe.hwpx", policy:.skiaOptIn)
        verify(managedDisabled.selectedFaces.count == 2)
        _ = try await installed.setEnabled(true)

        let variant = root.appendingPathComponent("build.noindex/task568/stage4/GowunBatang-Regular-outline.ttf")
        let collision = await library.importFonts(.init(candidates:[.init(sourceURL:variant)],accessURLs:[]))
        verify(collision[0].status == .selectionRequired)
        // 이미 선택한 원본은 같은 PS를 추가해도 보존된다.
        let preserved = try await supply.renderNativePage(data:regularData,filename:"control.hwpx",policy:.skiaOptIn)
        verify(try HwpPageImageRenderer.encodePNG(preserved.page.image) == originalPNG)
        // 미해결 충돌 DTO를 실제 native 진입점에 넣는 별도 실패 시험이다.
        let conflictSnapshot = try await supply.snapshot()
        let conflicted = StudioFontSupplySnapshot(identity:conflictSnapshot.identity,faces:conflictSnapshot.faces.map { row in
            guard row.source == "managed" && row.postScriptName == "GowunBatang-Regular" else { return row }
            return StudioFontFace(id:row.id,source:row.source,postScriptName:row.postScriptName,family:row.family,
                fullName:row.fullName,style:row.style,aliases:row.aliases,weight:row.weight,traits:row.traits,limitation:"conflict")
        },omitted:0,failure:nil,read:conflictSnapshot.read,current:conflictSnapshot.current,release:conflictSnapshot.release)
        let conflictMeter = Meter()
        let conflict = await reject { try await HwpNativeFontPageRenderer.render(data:regularData,filename:"control.hwpx",
            snapshot:tracked(conflicted,conflictMeter),policy:.skiaOptIn) }
        verify(conflict == "unavailable"); verify(await conflictMeter.reads.isEmpty); verify(await conflictMeter.releases == 1)
        let manifest = try await library.list()
        let variantHash = digest(try Data(contentsOf:variant))
        let variantFace = manifest.entries.first { $0.object.sha256 == variantHash }!.faces[0]
        let group = manifest.conflictGroups.first { $0.members.contains(variantFace.id) }!
        _ = try await library.selectActive(groupID:group.id,faceID:variantFace.id,expectedGeneration:manifest.generation)
        let changed = try await supply.renderNativePage(data:regularData,filename:"control.hwpx",policy:.skiaOptIn)
        let changedPNG = try HwpPageImageRenderer.encodePNG(changed.page.image)
        verify(changed.selectedFaces == managedOriginal.selectedFaces && changed.cacheIdentity != managedOriginal.cacheIdentity && changedPNG != originalPNG)
        try changedPNG.write(to:out.appendingPathComponent("changed-source-skia.png"))
        let changedCG = try await supply.renderNativePage(data:regularData,filename:"control.hwpx",policy:.coreGraphicsOnly)
        verify(try HwpPageImageRenderer.encodePNG(changedCG.page.image) != HwpPageImageRenderer.encodePNG(installedCG.page.image))
        let newManifest = try await library.list()
        let oldFace = newManifest.entries.first { $0.object.sha256 != variantHash && $0.faces[0].postScriptName == "GowunBatang-Regular" }!.faces[0]
        _ = try await library.selectActive(groupID:group.id,faceID:oldFace.id,expectedGeneration:newManifest.generation)
        let restored = try await supply.renderNativePage(data:regularData,filename:"control.hwpx",policy:.skiaOptIn)
        verify(try HwpPageImageRenderer.encodePNG(restored.page.image) == originalPNG && restored.cacheIdentity != changed.cacheIdentity)

        let changeMeter = Meter(), changeGate = Gate()
        let inFlight = tracked(try await supply.snapshot(),changeMeter,gate:changeGate)
        let changing = Task { try await HwpNativeFontPageRenderer.render(data:regularData,filename:"control.hwpx",snapshot:inFlight) }
        while !(await changeGate.entered) { try await Task.sleep(nanoseconds:10_000_000) }
        _ = try await installed.setEnabled(false)
        await changeGate.finish()
        do { _ = try await changing.value; preconditionFailure("읽기 중 세대 변경이 성공했습니다") }
        catch { verify(error as? HwpNativeFontSupplyError == .stale) }
        verify(await changeMeter.releases == 1)
        _ = try await installed.setEnabled(true)
        let documentMeter = Meter()
        let documentStale = await reject { try await HwpNativeFontPageRenderer.render(data:regularData,filename:"control.hwpx",
            snapshot:tracked(try await supply.snapshot(),documentMeter),documentIsCurrent:{false}) }
        verify(documentStale == "stale"); verify(await documentMeter.reads.isEmpty); verify(await documentMeter.releases == 1)

        // 취소한 실제 I/O가 반환하기 전에는 budget/lease를 풀면 안 된다.
        let cancelMeter = Meter(), gate = Gate(), budget = StudioFontTransferBudget()
        let cancelSnapshot = tracked(try await supply.snapshot(),cancelMeter,gate:gate)
        let operation = Task { try await HwpNativeFontPageRenderer.render(data:regularData,filename:"control.hwpx",snapshot:cancelSnapshot,budget:budget) }
        while !(await gate.entered) { try await Task.sleep(nanoseconds:10_000_000) }
        operation.cancel()
        let secondSlot = try await budget.acquire()
        do { _ = try await budget.acquire(); preconditionFailure("취소한 I/O의 슬롯을 너무 일찍 해제했습니다") }
        catch { verify(error as? StudioFontError == .busy) }
        verify(await cancelMeter.releases == 0)
        await gate.finish()
        do { _ = try await operation.value; preconditionFailure("취소가 렌더 결과를 반환했습니다") }
        catch { verify(error is CancellationError) }
        verify(await cancelMeter.releases == 1)
        await budget.release(secondSlot)
        let firstFree = try await budget.acquire(), secondFree = try await budget.acquire()
        await budget.release(firstFree); await budget.release(secondFree)

        let limitMeter = Meter()
        let limit = await reject { try await HwpNativeFontPageRenderer.render(data:regularData,filename:"control.hwpx",
            snapshot:tracked(try await supply.snapshot(),limitMeter),limits:.init(faces:1,fileBytes:1,residentBytes:1)) }
        verify(limit == "tooLarge"); verify(await limitMeter.releases == 1)
        let beforeMissing = try await library.list()
        let unused = beforeMissing.entries.first { $0.faces[0].postScriptName == "GowunBatang-Bold" }!
        try FileManager.default.removeItem(at:libraryRoot.appendingPathComponent("objects/\(unused.object.sha256).font"))
        let noUnusedRead = try await supply.renderNativePage(data:regularData,filename:"control.hwpx",policy:.skiaOptIn)
        verify(noUnusedRead.sourceReads == 1 && noUnusedRead.selectedFaces == ["GowunBatang-Regular"])
        let missingMeter = Meter()
        let missingSnapshot = tracked(try await supply.snapshot(),missingMeter)
        try FileManager.default.removeItem(at:libraryRoot.appendingPathComponent("objects/\(oldFace.id.objectHash).font"))
        let missing = await reject { try await HwpNativeFontPageRenderer.render(data:regularData,filename:"control.hwpx",snapshot:missingSnapshot,policy:.skiaOptIn) }
        verify(await missingMeter.releases == 1)
        let report: [String: Any] = ["passed":true,"kind":"real services with process-scope installed fixture and isolated persistence/library; Finder not connected",
            "officialMatcherCommit":RhwpNativeFontMatcherSource.commit,"realUserInstalledReadOnly":realInstalledProof,"installedCatalogCount":catalog.records.count,
            "installedReads":before.sourceReads,"installedFaces":before.selectedFaces,"installedCGAndSkia":true,
            "managed":rendered,"staleRejected":stale,"disabledInstalledRejectedWithoutReads":true,"ambiguousInstalledDTORejectedWithoutReads":true,"managedWithInstalledDisabled":true,
            "previousActiveSelectionPreservedOnCollision":true,"unresolvedConflictDTORejectedWithoutReads":conflict,"samePSChangedOutlinePNGChanged":true,"sourceRestoredPNGEqual":true,
            "cacheIdentityChanged":true,"changedSourceCGAndSkiaBothChanged":true,"cancelWaitedForActualIOAndReleasedOnce":true,"sharedBudgetHeldUntilIOCompleted":true,
            "unneededManagedObjectNotRead":true,"staleDuringReadRejected":true,"staleDocumentRejectedWithoutReads":true,"fileLimitRejected":limit,"managedSourceMissingRejected":missing,
            "userSettingsChanged":false,"userSourceFilesChanged":false,"userFontPersistentOSRegistration":false,"testSourceProcessRegistered":processRegistered,
            "bundledProcessRegisteredCount":HwpBundledFontRegistry.registrationStatus().registeredCount]
        try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent("result.json"))
        print("native supply acceptance passed")
    }
}
