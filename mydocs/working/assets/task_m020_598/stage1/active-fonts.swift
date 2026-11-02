import Foundation
import CoreText
let collection = CTFontCollectionCreateFromAvailableFonts(nil)
let descriptors = CTFontCollectionCreateMatchingFontDescriptors(collection) as? [CTFontDescriptor] ?? []
var matches: [[String: String]] = []
for d in descriptors {
    if (CTFontDescriptorCopyAttribute(d, kCTFontEnabledAttribute) as? NSNumber)?.boolValue == false { continue }
    let f = CTFontCreateWithFontDescriptor(d, 16, nil)
    let values = ["family": CTFontCopyFamilyName(f) as String, "fullName": CTFontCopyFullName(f) as String,
                  "postScriptName": CTFontCopyPostScriptName(f) as String,
                  "localizedFamily": CTFontCopyLocalizedName(f, kCTFontFamilyNameKey, nil) as String? ?? "",
                  "style": CTFontDescriptorCopyAttribute(d, kCTFontStyleNameAttribute) as? String ?? ""]
    if values.values.contains(where: { $0.localizedCaseInsensitiveContains("딸기") || $0.localizedCaseInsensitiveContains("strawberry") || $0.localizedCaseInsensitiveContains("hgstrb") }) { matches.append(values) }
}
let data = try JSONSerialization.data(withJSONObject: ["scope":"unsigned-cli-active-CoreText", "matches":matches], options:[.prettyPrinted,.sortedKeys])
print(String(decoding:data,as:UTF8.self))
