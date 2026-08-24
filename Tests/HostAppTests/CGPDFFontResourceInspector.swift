import CoreGraphics
import PDFKit

struct CGPDFFontResourceRecord: Equatable {
    let pageIndex: Int
    let resourceName: String
    let baseFont: String
    let subtype: String
    let hasToUnicode: Bool
}

struct CGPDFResourceTraversalState {
    let maximumDepth: Int
    private(set) var visitedDictionaryAddresses: Set<UInt> = []

    mutating func shouldVisit(dictionaryAddress: UInt, depth: Int) -> Bool {
        guard depth <= maximumDepth,
              visitedDictionaryAddresses.insert(dictionaryAddress).inserted
        else {
            return false
        }
        return true
    }
}

enum CGPDFFontResourceInspector {
    static let maximumNestedResourceDepth = 16

    static func records(in document: PDFDocument) -> [CGPDFFontResourceRecord] {
        var records: [CGPDFFontResourceRecord] = []

        for pageIndex in 0..<document.pageCount {
            guard let pageReference = document.page(at: pageIndex)?.pageRef,
                  let pageDictionary = pageReference.dictionary
            else {
                continue
            }

            var resources: CGPDFDictionaryRef?
            guard CGPDFDictionaryGetDictionary(pageDictionary, "Resources", &resources),
                  let resources
            else {
                continue
            }

            var traversal = CGPDFResourceTraversalState(
                maximumDepth: maximumNestedResourceDepth
            )
            inspect(
                resources: resources,
                pageIndex: pageIndex,
                depth: 0,
                traversal: &traversal,
                records: &records
            )
        }

        return records
    }

    private static func inspect(
        resources: CGPDFDictionaryRef,
        pageIndex: Int,
        depth: Int,
        traversal: inout CGPDFResourceTraversalState,
        records: inout [CGPDFFontResourceRecord]
    ) {
        let dictionaryAddress: UInt = unsafeBitCast(resources, to: UInt.self)
        guard traversal.shouldVisit(
            dictionaryAddress: dictionaryAddress,
            depth: depth
        ) else {
            return
        }

        var fontResources: CGPDFDictionaryRef?
        if CGPDFDictionaryGetDictionary(resources, "Font", &fontResources),
           let fontResources {
            for entry in entries(in: fontResources) {
                var fontDictionary: CGPDFDictionaryRef?
                guard CGPDFObjectGetValue(entry.object, .dictionary, &fontDictionary),
                      let fontDictionary
                else {
                    continue
                }

                var baseFontName: UnsafePointer<CChar>?
                var subtypeName: UnsafePointer<CChar>?
                var toUnicodeStream: CGPDFStreamRef?
                let baseFont = CGPDFDictionaryGetName(
                    fontDictionary,
                    "BaseFont",
                    &baseFontName
                ) && baseFontName != nil
                    ? String(cString: baseFontName!)
                    : ""
                let subtype = CGPDFDictionaryGetName(
                    fontDictionary,
                    "Subtype",
                    &subtypeName
                ) && subtypeName != nil
                    ? String(cString: subtypeName!)
                    : ""

                records.append(CGPDFFontResourceRecord(
                    pageIndex: pageIndex,
                    resourceName: entry.key,
                    baseFont: baseFont,
                    subtype: subtype,
                    hasToUnicode: CGPDFDictionaryGetStream(
                        fontDictionary,
                        "ToUnicode",
                        &toUnicodeStream
                    )
                ))
            }
        }

        guard depth < maximumNestedResourceDepth else {
            return
        }

        var xObjectResources: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(resources, "XObject", &xObjectResources),
              let xObjectResources
        else {
            return
        }

        for entry in entries(in: xObjectResources) {
            var stream: CGPDFStreamRef?
            guard CGPDFObjectGetValue(entry.object, .stream, &stream),
                  let stream,
                  let streamDictionary = CGPDFStreamGetDictionary(stream)
            else {
                continue
            }

            var subtypeName: UnsafePointer<CChar>?
            guard CGPDFDictionaryGetName(streamDictionary, "Subtype", &subtypeName),
                  let subtypeName,
                  String(cString: subtypeName) == "Form"
            else {
                continue
            }

            var nestedResources: CGPDFDictionaryRef?
            guard CGPDFDictionaryGetDictionary(
                streamDictionary,
                "Resources",
                &nestedResources
            ), let nestedResources else {
                continue
            }

            inspect(
                resources: nestedResources,
                pageIndex: pageIndex,
                depth: depth + 1,
                traversal: &traversal,
                records: &records
            )
        }
    }

    private static func entries(in dictionary: CGPDFDictionaryRef) -> [CGPDFDictionaryEntry] {
        let box = CGPDFDictionaryEntryBox()
        CGPDFDictionaryApplyFunction(
            dictionary,
            collectCGPDFDictionaryEntry,
            Unmanaged.passUnretained(box).toOpaque()
        )
        return box.entries
    }
}

private struct CGPDFDictionaryEntry {
    let key: String
    let object: CGPDFObjectRef
}

private final class CGPDFDictionaryEntryBox {
    var entries: [CGPDFDictionaryEntry] = []
}

private let collectCGPDFDictionaryEntry: CGPDFDictionaryApplierFunction = {
    key,
    object,
    info in
    guard let info else {
        return
    }

    let box = Unmanaged<CGPDFDictionaryEntryBox>
        .fromOpaque(info)
        .takeUnretainedValue()
    box.entries.append(CGPDFDictionaryEntry(
        key: String(cString: key),
        object: object
    ))
}
