// 폰트 폴백 매핑 — HWP 폰트명 → 번들 오픈 라이선스 폰트 / Apple 플랫폼 시스템 폰트
// 참조: mydocs/tech/font_fallback_strategy.md

import CoreText
import Foundation

/// HWP 폰트명을 Apple 플랫폼에서 사용 가능한 폰트명으로 변환한다.
func resolveAppleFont(hwpFontFamily: String, bold: Bool, italic: Bool) -> CTFont {
    resolveAppleFont(hwpFontFamily: hwpFontFamily, bold: bold, italic: italic, size: 1.0)
}

/// HWP 폰트명을 Apple 플랫폼에서 사용 가능한 CoreText font로 변환한다.
func resolveAppleFont(hwpFontFamily: String, bold: Bool, italic: Bool, size: CGFloat) -> CTFont {
    HwpBundledFontRegistry.ensureRegistered()

    let policy = HwpFontFallbackPolicy.policy(for: hwpFontFamily)
    if let font = HwpFontFallbackPolicy.makeFont(from: policy.faces, size: size, bold: bold, italic: italic) {
        return font
    }

    return HwpFontFallbackPolicy.defaultFont(size: size, bold: bold, italic: italic)
}

/// HWP 폰트명 → Apple 플랫폼 폰트명 매핑
func mapHWPFontToApple(_ hwpFont: String) -> String {
    HwpBundledFontRegistry.ensureRegistered()

    let policy = HwpFontFallbackPolicy.policy(for: hwpFont)
    return policy.faces.first?.regular ?? HwpFontFallbackPolicy.defaultSans.regular
}

private struct HwpFontFallbackPolicy {
    let faces: [HwpFontFace]

    static let pretendard = HwpFontFace(
        regular: "Pretendard-Regular",
        bold: "Pretendard-Bold",
        italic: nil,
        boldItalic: nil
    )
    static let notoSansKR = HwpFontFace(
        regular: "NotoSansKRThin-Regular",
        bold: "NotoSansKRThin-Bold",
        italic: nil,
        boldItalic: nil
    )
    static let nanumGothic = HwpFontFace(
        regular: "NanumGothic",
        bold: "NanumGothicBold",
        italic: nil,
        boldItalic: nil
    )
    static let gowunDodum = HwpFontFace(
        regular: "GowunDodum-Regular",
        bold: nil,
        italic: nil,
        boldItalic: nil
    )
    static let spoqaHanSans = HwpFontFace(
        regular: "SpoqaHanSans-Regular",
        bold: nil,
        italic: nil,
        boldItalic: nil
    )
    static let defaultSans = HwpFontFace(
        regular: "AppleSDGothicNeo-Regular",
        bold: "AppleSDGothicNeo-Bold",
        italic: nil,
        boldItalic: nil
    )

    static let notoSerifKR = HwpFontFace(
        regular: "NotoSerifKRExtraLight-Regular",
        bold: "NotoSerifKRExtraLight-Bold",
        italic: nil,
        boldItalic: nil
    )
    static let nanumMyeongjo = HwpFontFace(
        regular: "NanumMyeongjo",
        bold: "NanumMyeongjoBold",
        italic: nil,
        boldItalic: nil
    )
    static let gowunBatang = HwpFontFace(
        regular: "GowunBatang-Regular",
        bold: "GowunBatang-Bold",
        italic: nil,
        boldItalic: nil
    )
    static let defaultSerif = HwpFontFace(
        regular: "AppleMyungjo",
        bold: nil,
        italic: nil,
        boldItalic: nil
    )

    static let d2Coding = HwpFontFace(
        regular: "D2Coding",
        bold: "D2CodingBold",
        italic: nil,
        boldItalic: nil
    )
    static let nanumGothicCoding = HwpFontFace(
        regular: "NanumGothicCoding",
        bold: "NanumGothicCoding-Bold",
        italic: nil,
        boldItalic: nil
    )
    static let defaultMono = HwpFontFace(
        regular: "CourierNewPSMT",
        bold: "CourierNewPS-BoldMT",
        italic: "CourierNewPS-ItalicMT",
        boldItalic: "CourierNewPS-BoldItalicMT"
    )

    static let arial = HwpFontFace(
        regular: "ArialMT",
        bold: "Arial-BoldMT",
        italic: "Arial-ItalicMT",
        boldItalic: "Arial-BoldItalicMT"
    )
    static let timesNewRoman = HwpFontFace(
        regular: "TimesNewRomanPSMT",
        bold: "TimesNewRomanPS-BoldMT",
        italic: "TimesNewRomanPS-ItalicMT",
        boldItalic: "TimesNewRomanPS-BoldItalicMT"
    )
    static let verdana = HwpFontFace(
        regular: "Verdana",
        bold: "Verdana-Bold",
        italic: "Verdana-Italic",
        boldItalic: "Verdana-BoldItalic"
    )
    static let helveticaNeue = HwpFontFace(
        regular: "HelveticaNeue",
        bold: "HelveticaNeue-Bold",
        italic: "HelveticaNeue-Italic",
        boldItalic: "HelveticaNeue-BoldItalic"
    )

    static let latinModernMath = HwpFontFace(
        regular: "LatinModernMath-Regular",
        bold: nil,
        italic: nil,
        boldItalic: nil
    )
    static let cafe24Ssurround = HwpFontFace(
        regular: "Cafe24Ssurround",
        bold: nil,
        italic: nil,
        boldItalic: nil
    )
    static let cafe24Supermagic = HwpFontFace(
        regular: "Cafe24Supermagic-Regular",
        bold: nil,
        italic: nil,
        boldItalic: nil
    )
    static let happinessSans = HwpFontFace(
        regular: "Happiness-Sans-Regular",
        bold: "Happiness-Sans-Bold",
        italic: nil,
        boldItalic: nil
    )

    static func policy(for hwpFontFamily: String) -> HwpFontFallbackPolicy {
        let trimmed = hwpFontFamily.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = normalizedKey(trimmed)

        switch key {
        case "함초롬바탕", "한컴바탕", "hbatang", "hbatangb", "바탕", "batang":
            return HwpFontFallbackPolicy(faces: [defaultSerif, notoSerifKR, nanumMyeongjo, gowunBatang, timesNewRoman])
        case "바탕체", "batangche", "새바탕체":
            return HwpFontFallbackPolicy(faces: [defaultSerif, d2Coding, nanumGothicCoding, defaultMono, notoSerifKR])
        case "새바탕":
            return HwpFontFallbackPolicy(faces: [defaultSerif, notoSerifKR, nanumMyeongjo, timesNewRoman])
        case "궁서", "궁서체", "gungsuh", "gungsuhche":
            return HwpFontFallbackPolicy(faces: [defaultSerif, gowunBatang, nanumMyeongjo, notoSerifKR])
        case "hy신명조", "hysinmyeongjo", "hysinmyeongjomedium", "hy견명조", "hygyeonmyeongjo",
             "hy명조", "hymyeongjo", "hymjre", "휴먼명조", "humanmyeongjo", "나눔명조", "nanummyeongjo":
            return HwpFontFallbackPolicy(faces: [defaultSerif, nanumMyeongjo, notoSerifKR, timesNewRoman])
        case "notoserifkr", "notoserifkorean", "notoserif":
            return HwpFontFallbackPolicy(faces: [notoSerifKR, nanumMyeongjo, defaultSerif])
        case "gowunbatang", "고운바탕":
            return HwpFontFallbackPolicy(faces: [gowunBatang, nanumMyeongjo, defaultSerif])

        case "함초롬돋움", "hamchoromdotum", "hamchoromdodum", "맑은고딕", "malgungothic",
             "calibri", "tahoma":
            return HwpFontFallbackPolicy(faces: [defaultSans, pretendard, helveticaNeue])
        case "verdana":
            return HwpFontFallbackPolicy(faces: [verdana, defaultSans, pretendard, helveticaNeue])
        case "한컴돋움", "hdotum", "hdotumb", "돋움", "dotum", "굴림", "gulim",
             "새돋움", "새굴림":
            return HwpFontFallbackPolicy(faces: [defaultSans, notoSansKR, pretendard, nanumGothic, helveticaNeue])
        case "돋움체", "dotumche", "굴림체", "gulimche", "새돋움체":
            return HwpFontFallbackPolicy(faces: [defaultSans, d2Coding, nanumGothicCoding, defaultMono, notoSansKR])
        case "hy고딕", "hygothic", "hy중고딕", "hyjunggothic", "hyjunggothicmedium",
             "hy견고딕", "hygyeongothic", "hy그래픽", "hygraphic", "hygraphicmedium",
             "hy헤드라인m", "hyheadlinem", "hyheadlinemedium":
            return HwpFontFallbackPolicy(faces: [defaultSans, pretendard, gowunDodum, notoSansKR])
        case "나눔고딕", "nanumgothic":
            return HwpFontFallbackPolicy(faces: [nanumGothic, notoSansKR, pretendard, defaultSans])
        case "notosanskr", "notosanskorean", "notosans":
            return HwpFontFallbackPolicy(faces: [notoSansKR, pretendard, defaultSans])
        case "pretendard":
            return HwpFontFallbackPolicy(faces: [pretendard, defaultSans])
        case "gowundodum", "고운돋움":
            return HwpFontFallbackPolicy(faces: [gowunDodum, pretendard, defaultSans])
        case "spoqahansans", "스포카한산스":
            return HwpFontFallbackPolicy(faces: [spoqaHanSans, pretendard, defaultSans])

        case "d2coding", "d2코딩", "나눔고딕코딩", "nanumgothiccoding", "consolas", "couriernew":
            return HwpFontFallbackPolicy(faces: [d2Coding, nanumGothicCoding, defaultMono, defaultSans])

        case "arial":
            return HwpFontFallbackPolicy(faces: [arial, defaultSans, helveticaNeue])
        case "timesnewroman":
            return HwpFontFallbackPolicy(faces: [timesNewRoman, defaultSerif, notoSerifKR])
        case "helvetica", "helveticaneue":
            return HwpFontFallbackPolicy(faces: [helveticaNeue, defaultSans])

        case "latinmodernmath", "latinmodernmathregular":
            return HwpFontFallbackPolicy(faces: [latinModernMath, timesNewRoman, defaultSerif])
        case "hy바다", "hy바다l", "hybadal":
            return HwpFontFallbackPolicy(faces: [cafe24Ssurround, happinessSans, pretendard, defaultSans])
        case "한컴소망", "한컴소망b", "hancomsomang", "hancomsomangb":
            return HwpFontFallbackPolicy(faces: [cafe24Supermagic, happinessSans, pretendard, defaultSans])
        case "한컴쿨재즈", "한컴쿨재즈b", "hancomcooljazz", "hancomcooljazzb":
            return HwpFontFallbackPolicy(faces: [cafe24Ssurround, cafe24Supermagic, happinessSans, pretendard, defaultSans])
        case "cafe24ssurround", "카페24써라운드":
            return HwpFontFallbackPolicy(faces: [cafe24Ssurround, pretendard, defaultSans])
        case "cafe24supermagic", "카페24슈퍼매직":
            return HwpFontFallbackPolicy(faces: [cafe24Supermagic, pretendard, defaultSans])
        case "happinesssans", "행복고딕":
            return HwpFontFallbackPolicy(faces: [happinessSans, pretendard, defaultSans])
        default:
            var faces = [HwpFontFace(regular: trimmed.isEmpty ? defaultSans.regular : trimmed)]
            faces.append(contentsOf: [defaultSans, pretendard, helveticaNeue])
            return HwpFontFallbackPolicy(faces: faces)
        }
    }

    static func makeFont(from faces: [HwpFontFace], size: CGFloat, bold: Bool, italic: Bool) -> CTFont? {
        for face in faces {
            let selected = face.selection(bold: bold, italic: italic)
            guard var font = makeAvailableFont(named: selected.name, size: size) else {
                continue
            }

            let needsSyntheticBold = bold && !selected.providesBold
            let needsSyntheticItalic = italic && !selected.providesItalic
            let requestedTraits = requestedTraits(bold: bold, italic: italic)
            if !requestedTraits.isEmpty && (needsSyntheticBold || needsSyntheticItalic),
               let traitFont = CTFontCreateCopyWithSymbolicTraits(
                font,
                size,
                nil,
                requestedTraits,
                [.boldTrait, .italicTrait]
               ) {
                font = traitFont
            }
            return font
        }
        return nil
    }

    static func defaultFont(size: CGFloat, bold: Bool, italic: Bool) -> CTFont {
        makeFont(from: [defaultSans, helveticaNeue], size: size, bold: bold, italic: italic)
            ?? CTFontCreateWithName(defaultSans.regular as CFString, size, nil)
    }

    private static func makeAvailableFont(named name: String, size: CGFloat) -> CTFont? {
        let descriptor = CTFontDescriptorCreateWithNameAndSize(name as CFString, size)
        guard let matches = CTFontDescriptorCreateMatchingFontDescriptors(descriptor, nil) as? [CTFontDescriptor],
              !matches.isEmpty else {
            return nil
        }
        return CTFontCreateWithName(name as CFString, size, nil)
    }

    private static func requestedTraits(bold: Bool, italic: Bool) -> CTFontSymbolicTraits {
        var traits = CTFontSymbolicTraits()
        if bold {
            traits.insert(.boldTrait)
        }
        if italic {
            traits.insert(.italicTrait)
        }
        return traits
    }

    private static func normalizedKey(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .filter { !$0.isWhitespace && $0 != "-" && $0 != "_" }
    }
}

private struct HwpFontFace {
    let regular: String
    let bold: String?
    let italic: String?
    let boldItalic: String?

    init(regular: String, bold: String? = nil, italic: String? = nil, boldItalic: String? = nil) {
        self.regular = regular
        self.bold = bold
        self.italic = italic
        self.boldItalic = boldItalic
    }

    func selection(bold requestedBold: Bool, italic requestedItalic: Bool) -> HwpFontSelection {
        if requestedBold && requestedItalic, let boldItalic {
            return HwpFontSelection(name: boldItalic, providesBold: true, providesItalic: true)
        }
        if requestedBold, let bold {
            return HwpFontSelection(name: bold, providesBold: true, providesItalic: false)
        }
        if requestedItalic, let italic {
            return HwpFontSelection(name: italic, providesBold: false, providesItalic: true)
        }
        return HwpFontSelection(name: regular, providesBold: false, providesItalic: false)
    }
}

private struct HwpFontSelection {
    let name: String
    let providesBold: Bool
    let providesItalic: Bool
}
