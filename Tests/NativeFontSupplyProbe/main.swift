import Foundation
import CoreText
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import CryptoKit

// 지정한 원본 bytes의 기초 구성 실험이며 제품 renderer/Skia/FFI 수용이 아니다.
let out = URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
let fonts = URL(fileURLWithPath:CommandLine.arguments[2],isDirectory:true)
let text = "한글 가나다 ABC 0123 고운바탕 글꼴"
var rows: [[String:Any]] = []
let colorSpace = CGColorSpaceCreateDeviceRGB()
let context = CGContext(data:nil,width:1100,height:420,bitsPerComponent:8,bytesPerRow:0,space:colorSpace,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
context.setFillColor(CGColor(gray:1,alpha:1));context.fill(CGRect(x:0,y:0,width:1100,height:420))
for (index, style) in ["Regular","Bold"].enumerated() {
    let data = try Data(contentsOf:fonts.appendingPathComponent("GowunBatang-\(style).ttf"))
    let hash = SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined()
    let expected = style == "Regular" ? "466c593e7147412e748af4856d5ad14709b5a860bdf62b9c2546f2c5874e9849" : "dbfcaa646e5831e7478524924f02906f550285a5050699b4e38c9950b3ec4b94"
    precondition(hash == expected)
    let provider = CGDataProvider(data:data as CFData)!
    let graphic = CGFont(provider)!
    let font = CTFontCreateWithGraphicsFont(graphic,40,nil,nil)
    let ps = CTFontCopyPostScriptName(font) as String
    precondition(ps == "GowunBatang-\(style)")
    let characters = Array(text.utf16)
    var glyphs = [CGGlyph](repeating:0,count:characters.count)
    precondition(CTFontGetGlyphsForCharacters(font,characters,&glyphs,characters.count))
    let attrs: [NSAttributedString.Key:Any] = [NSAttributedString.Key(kCTFontAttributeName as String):font,NSAttributedString.Key(kCTForegroundColorAttributeName as String):CGColor(gray:0,alpha:1)]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string:text,attributes:attrs))
    context.textPosition=CGPoint(x:30,y:CGFloat(290-index*140));CTLineDraw(line,context)
    rows.append(["ps":ps,"sha256":hash,"bytes":data.count,"glyphCount":glyphs.count,"glyphs":glyphs.map(Int.init),"pathBasedRegistration":false])
    if style == "Regular" {
        var alternate = data;alternate.append(contentsOf:[0,0,0,0])
        let otherHash=SHA256.hash(data:alternate).map {String(format:"%02x",$0)}.joined()
        let other = CTFontCreateWithGraphicsFont(CGFont(CGDataProvider(data:alternate as CFData)!)!,40,nil,nil)
        precondition(CTFontCopyPostScriptName(other) as String == ps && otherHash != hash)
    }
}
let image=context.makeImage()!
let dest=CGImageDestinationCreateWithURL(out.appendingPathComponent("native-bytes.png") as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(dest,image,nil);precondition(CGImageDestinationFinalize(dest))
let proof:[String:Any] = ["passed":true,"kind":"CoreText bytes prototype, product renderer unconnected","text":text,"fonts":rows,"samePSDistinctBytesConstructed":true,"OSFontRegistration":false,"FFIChanged":false]
try JSONSerialization.data(withJSONObject:proof,options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent("result.json"))
print("PASS: CoreText direct bytes Regular/Bold·한국어/ASCII glyph·같은 PS의 다른 bytes; OS 등록/제품 연결/FFI 변경 없음")
