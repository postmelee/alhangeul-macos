import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// 독립 upstream PDF와 실제 출력의 영역별 누락 검사. 픽셀 동일성 판정은 아니다.
let output = URL(fileURLWithPath: CommandLine.arguments[1])

func load(_ name: String) -> CGImage {
    let source = CGImageSourceCreateWithURL(output.appendingPathComponent(name) as CFURL, nil)!
    return CGImageSourceCreateImageAtIndex(source, 0, nil)!
}
func write(_ image: CGImage, _ name: String) {
    let target = CGImageDestinationCreateWithURL(output.appendingPathComponent(name) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(target, image, nil)
    precondition(CGImageDestinationFinalize(target))
}
let after = load("after.png"), before = load("before.png")
let w = after.width, h = after.height
// Poppler로 별도 래스터화한 기준. CoreGraphics PDF 해석의 mask 차이를 제품 회귀와 섞지 않는다.
let reference = load("reference.png")
precondition(reference.width == w && reference.height == h)
func counts(_ image: CGImage) -> [String: Int] {
    let c = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
        bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    let bytes = c.data!.assumingMemoryBound(to: UInt8.self)
    var ink = 0, green = 0
    for i in stride(from: 0, to: image.width * image.height * 4, by: 4) {
        let r = Int(bytes[i]), g = Int(bytes[i+1]), b = Int(bytes[i+2])
        if min(r, g, b) < 180 { ink += 1 }
        if g > 90 && g > r + 35 && g > b + 15 { green += 1 }
    }
    return ["inkPixels": ink, "greenPixels": green]
}
let regions: [(String, CGRect)] = [
    ("overview", CGRect(x: 110, y: 135, width: 650, height: 337)),
    ("chart", CGRect(x: 110, y: 135, width: 650, height: 302)),
    ("axis-y", CGRect(x: 115, y: 185, width: 52, height: 185)),
    ("axis-x", CGRect(x: 170, y: 370, width: 590, height: 28)),
    ("legend", CGRect(x: 150, y: 400, width: 600, height: 35)),
    ("caption", CGRect(x: 110, y: 438, width: 650, height: 34))
]
var report: [String: Any] = [:]
for (name, region) in regions {
    var result: [String: Any] = [:]
    for (label, image) in [("before", before), ("after", after), ("reference", reference)] {
        let crop = image.cropping(to: region)!
        write(crop, "\(name)-\(label).png")
        result[label] = counts(crop)
    }
    let actual = result["after"] as! [String: Int]
    let expected = result["reference"] as! [String: Int]
    precondition(actual["inkPixels"]! > 100 && expected["inkPixels"]! > 100, "missing \(name)")
    report[name] = result
}
func barCount(_ image: CGImage) -> Int {
    let crop = image.cropping(to: CGRect(x: 170, y: 270, width: 580, height: 60))!
    var bars = 0, run = 0
    for x in 0..<crop.width {
        let column = crop.cropping(to: CGRect(x: x, y: 0, width: 1, height: crop.height))!
        if counts(column)["greenPixels"]! > 20 { run += 1 }
        else { if run >= 10 { bars += 1 }; run = 0 }
    }
    if run >= 10 { bars += 1 }
    return bars
}
let actualBars = barCount(after), referenceBars = barCount(reference)
precondition(actualBars == 6 && referenceBars == 6 && barCount(before) == 0, "six chart bars")
report["bars"] = ["before": 0, "after": actualBars, "reference": referenceBars]
let actual = counts(after), expected = counts(reference)
precondition(actual["greenPixels"]! > 5000 && expected["greenPixels"]! > 5000)
let ratio = Double(actual["greenPixels"]!) / Double(expected["greenPixels"]!)
precondition((0.8...1.2).contains(ratio), "chart bar area changed")
report["greenAreaRatio"] = ratio
report["meaning"] = "영역별 누락 검사이며 글꼴·픽셀 동등성을 보증하지 않음"
let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
try data.write(to: output.appendingPathComponent("reference-comparison.json"))
print("PASS reference: chart/axis/legend/caption non-empty; green area ratio=\(ratio)")
