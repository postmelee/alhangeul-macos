import CoreText
import CryptoKit
import Foundation

struct FontFileInspector {
    static let validationVersion = 1
    let limits: FontInspectionLimits

    init(limits: FontInspectionLimits = FontInspectionLimits()) {
        self.limits = limits
    }

    // 호출자가 같은 핸들에서 읽은 bytes를 검사하고 이후 그대로 저장한다.
    // 시스템 등록이나 원본 경로 재열기는 하지 않는다.
    func inspect(_ data: Data, filename: String) throws -> InspectedFont {
        guard !data.isEmpty else { throw FontInspectionError.emptyFile }
        guard data.count <= limits.maximumFileBytes else { throw FontInspectionError.fileTooLarge }
        let file = FontBytes(bytes: Array(data))
        let signature = try file.u32(0)
        let format: FontFileFormat
        var offsets: [Int]
        var directories: [Range<Int>] = []
        switch signature {
        case 0x00010000: format = .trueType; offsets = [0]
        case 0x4F54544F: format = .openTypeCFF; offsets = [0]
        case 0x74746366:
            format = .collection
            let version = try file.u32(4)
            guard version == 0x00010000 || version == 0x00020000 else {
                throw FontInspectionError.unsupportedStructure
            }
            let count = Int(try file.u32(8))
            guard count > 0, count <= limits.maximumFaces else {
                throw FontInspectionError.metadataLimitExceeded
            }
            let headerSize = 12 + count * 4 + (version == 0x00020000 ? 12 : 0)
            try file.check(0, headerSize)
            directories.append(0..<headerSize)
            offsets = try (0..<count).map { Int(try file.u32(12 + $0 * 4)) }
            guard Set(offsets).count == count else { throw FontInspectionError.malformedStructure }
            if version == 0x00020000 {
                let dsigLength = Int(try file.u32(12 + count * 4 + 4))
                let dsigOffset = Int(try file.u32(12 + count * 4 + 8))
                try file.check(dsigOffset, dsigLength)
            }
        default: throw FontInspectionError.unsupportedFormat
        }
        var faceTables: [[String: FontBytes]] = []
        var faceSignatures: [UInt32] = []
        for offset in offsets {
            let sfnt = try file.u32(offset)
            guard sfnt == 0x00010000 || sfnt == 0x4F54544F else {
                throw FontInspectionError.unsupportedStructure
            }
            let count = Int(try file.u16(offset + 4))
            guard count > 0, count <= limits.maximumTablesPerFace else {
                throw FontInspectionError.metadataLimitExceeded
            }
            let end = offset + 12 + count * 16
            try file.check(offset, end - offset)
            guard !directories.contains(where: { $0.overlaps(offset..<end) }) else {
                throw FontInspectionError.malformedStructure
            }
            directories.append(offset..<end)
            var tables: [String: FontBytes] = [:]
            var spans: [Range<Int>] = []
            for index in 0..<count {
                let record = offset + 12 + index * 16
                let tag = try file.tag(record)
                let start = Int(try file.u32(record + 8))
                let length = Int(try file.u32(record + 12))
                let table = try file.slice(start, length)
                let range = start..<(start + length)
                guard tables[tag] == nil, start % 4 == 0,
                      !spans.contains(where: { $0.overlaps(range) }) else {
                    throw FontInspectionError.malformedStructure
                }
                tables[tag] = table
                if length > 0 { spans.append(range) }
            }
            faceTables.append(tables)
            faceSignatures.append(sfnt)
        }
        // TTC의 다른 face 디렉터리를 가리키는 table도 거부한다.
        for tables in faceTables {
            for table in tables.values where table.count > 0 {
                guard !directories.contains(where: { $0.overlaps(table.range) }) else {
                    throw FontInspectionError.malformedStructure
                }
            }
        }
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        var remainingNameBytes = limits.maximumNameBytes
        var remainingInstances = limits.maximumInstances
        var faces: [FontFace] = []
        for (index, tables) in faceTables.enumerated() {
            let names = try readNames(required("name", in: tables), budget: &remainingNameBytes)
            guard let ps = preferredName(6, in: names), !ps.isEmpty else {
                throw FontInspectionError.missingPostScriptName
            }
            let head = try required("head", in: tables)
            try head.check(0, 54)
            guard try head.u32(12) == 0x5F0F3CF5, (16...16384).contains(try head.u16(18)) else {
                throw FontInspectionError.malformedStructure
            }
            let maxp = try required("maxp", in: tables)
            let glyphCount = try maxp.u16(4)
            guard glyphCount > 0 else { throw FontInspectionError.malformedStructure }
            let hhea = try required("hhea", in: tables)
            try hhea.check(0, 36)
            let metrics = Int(try hhea.u16(34))
            guard metrics > 0, metrics <= Int(glyphCount) else {
                throw FontInspectionError.malformedStructure
            }
            try required("hmtx", in: tables).check(0, metrics * 4 + (Int(glyphCount) - metrics) * 2)
            if faceSignatures[index] == 0x00010000 {
                guard try maxp.u32(0) == 0x00010000 else { throw FontInspectionError.malformedStructure }
                try maxp.check(0, 32)
                try checkLocations(head: head, glyphCount: glyphCount, tables: tables)
            } else {
                guard try maxp.u32(0) == 0x00005000,
                      tables["CFF "] != nil || tables["CFF2"] != nil else {
                    throw FontInspectionError.malformedStructure
                }
            }
            try checkCmap(required("cmap", in: tables))
            let os2 = try required("OS/2", in: tables)
            let os2Version = try os2.u16(0)
            guard os2Version <= 5 else { throw FontInspectionError.unsupportedStructure }
            try os2.check(0, os2Version == 0 ? 78 : (os2Version == 1 ? 86 : (os2Version == 5 ? 100 : 96)))
            let weight = try os2.u16(4), width = try os2.u16(6)
            guard (1...1000).contains(weight), (1...9).contains(width) else {
                throw FontInspectionError.malformedStructure
            }
            let post = try required("post", in: tables)
            try post.check(0, 32)
            let variation = try tables["fvar"].map { try readVariations($0, budget: &remainingInstances) }
            if let variation {
                let nameIDs = Set(names.map(\.nameID))
                guard variation.0.allSatisfy({ nameIDs.contains($0.nameID) }),
                      variation.1.allSatisfy({ instance in
                          nameIDs.contains(instance.subfamilyNameID)
                              && (instance.postScriptNameID.map { nameIDs.contains($0) } ?? true)
                      }) else { throw FontInspectionError.malformedStructure }
            }
            faces.append(FontFace(
                id: FontFaceID(objectHash: hash, sfntIndex: index), names: names,
                familyName: preferredName(16, in: names) ?? preferredName(1, in: names),
                subfamilyName: preferredName(17, in: names) ?? preferredName(2, in: names),
                fullName: preferredName(4, in: names), postScriptName: ps,
                version: preferredName(5, in: names), weightClass: weight, widthClass: width,
                selectionFlags: try os2.u16(62), italicAngle: try post.fixed(4), glyphCount: glyphCount,
                declaredUnicodeRanges: try (0..<4).map { try os2.u32(42 + $0 * 4) },
                embeddingFlags: try os2.u16(8), axes: variation?.0 ?? [], namedInstances: variation?.1 ?? [],
                applicationSupport: format == .collection ? .collectionFaceSelectionUnverified
                    : (variation == nil ? .staticCandidate : .variableSelectionUnverified)
            ))
        }
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromData(data as CFData) as? [CTFontDescriptor],
              !descriptors.isEmpty else { throw FontInspectionError.coreTextRejected }
        let descriptorNames = Set(descriptors.compactMap {
            CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String
        })
        guard faces.allSatisfy({ descriptorNames.contains($0.postScriptName) }) else {
            throw FontInspectionError.coreTextRejected
        }
        let ext = (filename as NSString).pathExtension.lowercased()
        let expected: Set<String> = format == .collection ? ["ttc", "otc"]
            : (format == .trueType ? ["ttf"] : ["otf"])
        return InspectedFont(
            object: FontObject(sha256: hash, byteCount: data.count, format: format,
                               faceCount: faces.count, validationVersion: Self.validationVersion),
            faces: faces, filenameExtensionMismatch: !expected.contains(ext)
        )
    }

    private func required(_ tag: String, in tables: [String: FontBytes]) throws -> FontBytes {
        guard let result = tables[tag] else { throw FontInspectionError.malformedStructure }
        return result
    }

    private func preferredName(_ id: UInt16, in names: [FontNameRecord]) -> String? {
        let matches = names.filter { $0.nameID == id && $0.value?.isEmpty == false }
        // 표시 대표 이름일 뿐 resolver/동일성 판정이 아니다. 모든 원본 레코드는 유지한다.
        return (matches.first { $0.platformID == 3 && $0.languageID == 0x0409 }
            ?? matches.first { $0.platformID == 0 } ?? matches.first)?.value
    }

    private func readNames(_ table: FontBytes, budget: inout Int) throws -> [FontNameRecord] {
        let version = try table.u16(0)
        guard version <= 1 else { throw FontInspectionError.unsupportedStructure }
        let count = Int(try table.u16(2)), storage = Int(try table.u16(4))
        guard count <= limits.maximumNameRecords else { throw FontInspectionError.metadataLimitExceeded }
        var headerEnd = 6 + count * 12
        try table.check(0, headerEnd)
        var languageTags: [String] = []
        if version == 1 {
            let tagCount = Int(try table.u16(headerEnd))
            guard tagCount <= limits.maximumNameRecords else { throw FontInspectionError.metadataLimitExceeded }
            let tagStart = headerEnd + 2
            headerEnd = tagStart + tagCount * 4
            try table.check(0, headerEnd)
            for i in 0..<tagCount {
                let length = Int(try table.u16(tagStart + i * 4))
                try consume(length, budget: &budget)
                let bytes = try table.data(storage + Int(table.u16(tagStart + i * 4 + 2)), length)
                guard length % 2 == 0, let tag = String(data: bytes, encoding: .utf16BigEndian) else {
                    throw FontInspectionError.malformedStructure
                }
                languageTags.append(tag)
            }
        }
        guard storage >= headerEnd, storage <= table.count else { throw FontInspectionError.malformedStructure }
        return try (0..<count).map { i in
            let record = 6 + i * 12
            let platform = try table.u16(record), encoding = try table.u16(record + 2)
            let language = try table.u16(record + 4), name = try table.u16(record + 6)
            let length = Int(try table.u16(record + 8))
            try consume(length, budget: &budget)
            let bytes = try table.data(storage + Int(table.u16(record + 10)), length)
            let text: String?
            if platform == 0 || (platform == 3 && [0, 1, 10].contains(encoding)) {
                guard length % 2 == 0 else { throw FontInspectionError.malformedStructure }
                text = String(data: bytes, encoding: .utf16BigEndian)
            } else if platform == 1 && encoding == 0 {
                text = String(data: bytes, encoding: .macOSRoman)
            } else { text = nil }
            var languageTag: String?
            if language >= 0x8000 {
                let index = Int(language) - 0x8000
                guard version == 1, index < languageTags.count else {
                    throw FontInspectionError.malformedStructure
                }
                languageTag = languageTags[index]
            }
            return FontNameRecord(platformID: platform, encodingID: encoding, languageID: language,
                                  nameID: name, languageTag: languageTag, bytes: bytes, value: text)
        }
    }

    private func consume(_ amount: Int, budget: inout Int) throws {
        guard amount <= budget else { throw FontInspectionError.metadataLimitExceeded }
        budget -= amount
    }

    private func readVariations(_ table: FontBytes, budget: inout Int) throws
        -> ([FontVariationAxis], [FontNamedInstance]) {
        guard try table.u32(0) == 0x00010000 else { throw FontInspectionError.unsupportedStructure }
        let start = Int(try table.u16(4)), axisCount = Int(try table.u16(8))
        let axisSize = Int(try table.u16(10)), instanceCount = Int(try table.u16(12))
        let instanceSize = Int(try table.u16(14))
        guard axisCount > 0, axisCount <= limits.maximumAxes else {
            throw FontInspectionError.metadataLimitExceeded
        }
        try consume(instanceCount, budget: &budget)
        guard try table.u16(6) == 2, start >= 16, axisSize == 20,
              instanceSize == 4 + axisCount * 4 || instanceSize == 6 + axisCount * 4 else {
            throw FontInspectionError.malformedStructure
        }
        try table.check(start, axisCount * axisSize + instanceCount * instanceSize)
        var axes: [FontVariationAxis] = []
        for i in 0..<axisCount {
            let offset = start + i * axisSize
            let tag = try table.tag(offset)
            let minimum = try table.fixed(offset + 4), defaultValue = try table.fixed(offset + 8)
            let maximum = try table.fixed(offset + 12)
            guard minimum <= defaultValue, defaultValue <= maximum,
                  !axes.contains(where: { $0.tag == tag }) else { throw FontInspectionError.malformedStructure }
            axes.append(FontVariationAxis(tag: tag, minimum: minimum, defaultValue: defaultValue,
                                          maximum: maximum, flags: try table.u16(offset + 16),
                                          nameID: try table.u16(offset + 18)))
        }
        let instanceStart = start + axisCount * axisSize
        let instances: [FontNamedInstance] = try (0..<instanceCount).map { i in
            let offset = instanceStart + i * instanceSize
            guard try table.u16(offset + 2) == 0 else { throw FontInspectionError.malformedStructure }
            var coordinates: [String: Double] = [:]
            for (axisIndex, axis) in axes.enumerated() {
                let value = try table.fixed(offset + 4 + axisIndex * 4)
                guard value >= axis.minimum, value <= axis.maximum else { throw FontInspectionError.malformedStructure }
                coordinates[axis.tag] = value
            }
            let ps = instanceSize == 6 + axisCount * 4 ? try table.u16(offset + 4 + axisCount * 4) : nil
            return FontNamedInstance(subfamilyNameID: try table.u16(offset),
                                     postScriptNameID: ps == 0xFFFF ? nil : ps, coordinates: coordinates)
        }
        return (axes, instances)
    }

    private func checkLocations(head: FontBytes, glyphCount: UInt16, tables: [String: FontBytes]) throws {
        let loca = try required("loca", in: tables), glyf = try required("glyf", in: tables)
        let format = try head.u16(50)
        guard format <= 1 else { throw FontInspectionError.malformedStructure }
        let width = format == 0 ? 2 : 4
        try loca.check(0, (Int(glyphCount) + 1) * width)
        var previous = 0
        for i in 0...Int(glyphCount) {
            let offset = format == 0 ? Int(try loca.u16(i * 2)) * 2 : Int(try loca.u32(i * 4))
            guard offset >= previous, offset <= glyf.count else { throw FontInspectionError.malformedStructure }
            previous = offset
        }
    }

    private func checkCmap(_ table: FontBytes) throws {
        guard try table.u16(0) == 0 else { throw FontInspectionError.malformedStructure }
        let count = Int(try table.u16(2))
        guard count > 0, count <= 256 else { throw FontInspectionError.metadataLimitExceeded }
        try table.check(0, 4 + count * 8)
        for i in 0..<count {
            let start = Int(try table.u32(4 + i * 8 + 4))
            guard start >= 4 + count * 8 else { throw FontInspectionError.malformedStructure }
            let format = try table.u16(start)
            let length: Int
            switch format {
            case 0, 2, 4, 6: length = Int(try table.u16(start + 2))
            case 8, 10, 12, 13: length = Int(try table.u32(start + 4))
            case 14: length = Int(try table.u32(start + 2))
            default: throw FontInspectionError.unsupportedStructure
            }
            let minimum = format == 14 ? 10 : ([8, 10, 12, 13].contains(format) ? 16 : 6)
            guard length >= minimum else { throw FontInspectionError.malformedStructure }
            try table.check(start, length)
        }
    }
}

// 모든 접근에 table 단위 경계 검사를 적용한다. 비정렬 load와 미검사 포인터를 사용하지 않는다.
private struct FontBytes {
    let bytes: [UInt8]
    let range: Range<Int>
    var count: Int { range.count }

    init(bytes: [UInt8]) { self.bytes = bytes; self.range = 0..<bytes.count }
    private init(bytes: [UInt8], range: Range<Int>) { self.bytes = bytes; self.range = range }

    func check(_ offset: Int, _ length: Int) throws {
        guard offset >= 0, length >= 0, offset <= count, length <= count - offset else {
            throw FontInspectionError.malformedStructure
        }
    }
    func slice(_ offset: Int, _ length: Int) throws -> FontBytes {
        try check(offset, length)
        let start = range.lowerBound + offset
        return FontBytes(bytes: bytes, range: start..<(start + length))
    }
    func data(_ offset: Int, _ length: Int) throws -> Data {
        let slice = try slice(offset, length)
        return Data(bytes[slice.range])
    }
    func u16(_ offset: Int) throws -> UInt16 {
        try check(offset, 2)
        let start = range.lowerBound + offset
        return UInt16(bytes[start]) << 8 | UInt16(bytes[start + 1])
    }
    func u32(_ offset: Int) throws -> UInt32 {
        try check(offset, 4)
        return UInt32(try u16(offset)) << 16 | UInt32(try u16(offset + 2))
    }
    func fixed(_ offset: Int) throws -> Double { Double(Int32(bitPattern: try u32(offset))) / 65536 }
    func tag(_ offset: Int) throws -> String {
        let data = try data(offset, 4)
        guard data.allSatisfy({ (32...126).contains($0) }), let tag = String(data: data, encoding: .ascii) else {
            throw FontInspectionError.malformedStructure
        }
        return tag
    }
}
