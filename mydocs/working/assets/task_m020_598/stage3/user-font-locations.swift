// 대상 CoreText descriptor의 위치 분류·opaque ID만 기록한다. 경로·bytes는 출력하지 않는다.
import Foundation
import CoreText
import CryptoKit

let targets: Set<String> = ["Pretendard-Regular", "Hack-Regular", "Hack-Bold", "Hack-Italic", "Hack-BoldItalic"]
let userFonts = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Fonts").standardizedFileURL
let collection = CTFontCollectionCreateFromAvailableFonts(nil)
let descriptors = CTFontCollectionCreateMatchingFontDescriptors(collection) as? [CTFontDescriptor] ?? []
var matches: [[String: String]] = []
for descriptor in descriptors {
    guard (CTFontDescriptorCopyAttribute(descriptor, kCTFontEnabledAttribute) as? NSNumber)?.boolValue != false,
          let ps = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String,
          targets.contains(ps),
          let url = CTFontDescriptorCopyAttribute(descriptor, kCTFontURLAttribute) as? URL else { continue }
    let font = CTFontCreateWithFontDescriptor(descriptor, 16, nil)
    guard (CTFontCopyVariationAxes(font) as? [Any] ?? []).isEmpty else { continue }
    let source = url.standardizedFileURL
    // InstalledFontSystem의 static face identity 직렬화와 대조한다.
    let identity = try JSONEncoder().encode([source.path, ps, ""])
    let id = SHA256.hash(data: identity).map { String(format: "%02x", $0) }.joined()
    matches.append(["postScriptName": ps, "opaqueID": "installed:" + id,
                    "locationClass": source.deletingLastPathComponent() == userFonts ? "user-Library-Fonts" : "other"])
}
let result = try JSONSerialization.data(withJSONObject: matches.sorted { $0["postScriptName"]! < $1["postScriptName"]! }, options: [.prettyPrinted, .sortedKeys])
print(String(decoding: result, as: UTF8.self))
