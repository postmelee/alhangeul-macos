#!/usr/bin/env swift

import AppKit
import Foundation

private let canvasSize = NSSize(width: 720, height: 460)

private func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

private func drawText(
    _ text: String,
    in rect: NSRect,
    font: NSFont,
    color: NSColor,
    alignment: NSTextAlignment = .center,
    lineHeight: CGFloat? = nil,
    verticallyCentered: Bool = false
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    if let lineHeight {
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
    }

    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]

    var drawRect = rect
    if verticallyCentered {
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let measured = attributed.boundingRect(
            with: rect.size,
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let measuredHeight = ceil(measured.height)
        drawRect.origin.y = rect.origin.y + floor((rect.height - measuredHeight) / 2)
        drawRect.size.height = measuredHeight
    }

    text.draw(in: drawRect, withAttributes: attributes)
}

private func roundedRect(_ rect: NSRect, radius: CGFloat, fill: NSColor, stroke: NSColor? = nil) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()
    if let stroke {
        stroke.setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

private func drawArrow(from start: NSPoint, to tip: NSPoint) {
    let controlPoint1 = NSPoint(x: 320, y: 255)
    let controlPoint2 = NSPoint(x: 400, y: 255)
    let tangent = NSPoint(x: tip.x - controlPoint2.x, y: tip.y - controlPoint2.y)
    let tangentLength = hypot(tangent.x, tangent.y)
    let unit = NSPoint(x: tangent.x / tangentLength, y: tangent.y / tangentLength)
    let normal = NSPoint(x: -unit.y, y: unit.x)
    let headLength: CGFloat = 24
    let headWidth: CGFloat = 20
    let baseCenter = NSPoint(
        x: tip.x - (unit.x * headLength),
        y: tip.y - (unit.y * headLength)
    )

    let line = NSBezierPath()
    line.move(to: start)
    line.curve(to: baseCenter, controlPoint1: controlPoint1, controlPoint2: controlPoint2)
    color(38, 116, 204).setStroke()
    line.lineWidth = 4
    line.lineCapStyle = .round
    line.stroke()

    let head = NSBezierPath()
    head.move(to: tip)
    head.line(to: NSPoint(
        x: baseCenter.x + (normal.x * headWidth / 2),
        y: baseCenter.y + (normal.y * headWidth / 2)
    ))
    head.line(to: NSPoint(
        x: baseCenter.x - (normal.x * headWidth / 2),
        y: baseCenter.y - (normal.y * headWidth / 2)
    ))
    head.close()
    color(38, 116, 204).setFill()
    head.fill()
}

private func drawScene() {
    color(247, 249, 252).setFill()
    NSBezierPath(rect: NSRect(origin: .zero, size: canvasSize)).fill()

    roundedRect(
        NSRect(x: 34, y: 374, width: 652, height: 58),
        radius: 16,
        fill: .white,
        stroke: color(222, 228, 238)
    )

    drawText(
        "알한글.app을 Applications로 드래그해 설치하세요.",
        in: NSRect(x: 74, y: 374, width: 572, height: 58),
        font: .boldSystemFont(ofSize: 21),
        color: color(22, 29, 43),
        verticallyCentered: true
    )

    drawArrow(from: NSPoint(x: 258, y: 214), to: NSPoint(x: 462, y: 214))

    roundedRect(
        NSRect(x: 48, y: 52, width: 624, height: 54),
        radius: 14,
        fill: color(232, 241, 252),
        stroke: color(196, 216, 242)
    )
    drawText(
        "설치 후 앱을 한 번 실행해야 Quick Look/Thumbnail이 활성화됩니다.",
        in: NSRect(x: 72, y: 52, width: 576, height: 54),
        font: .systemFont(ofSize: 15, weight: .semibold),
        color: color(37, 70, 112),
        verticallyCentered: true
    )
}

private func renderBitmap() throws -> NSBitmapImageRep {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvasSize.width),
        pixelsHigh: Int(canvasSize.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "CreateDmgBackground", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "failed to allocate DMG background bitmap"
        ])
    }

    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "CreateDmgBackground", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "failed to create DMG background graphics context"
        ])
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.setAllowsAntialiasing(true)
    context.cgContext.setShouldAntialias(true)
    context.cgContext.interpolationQuality = .high

    drawScene()

    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    return bitmap
}

private func drawBackground(to outputURL: URL) throws {
    let bitmap = try renderBitmap()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "CreateDmgBackground", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "failed to render DMG background PNG"
        ])
    }

    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try png.write(to: outputURL, options: .atomic)
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: create-dmg-background.swift <output.png>\n".utf8))
    exit(2)
}

do {
    try drawBackground(to: URL(fileURLWithPath: CommandLine.arguments[1]))
} catch {
    FileHandle.standardError.write(Data("ERROR: \(error.localizedDescription)\n".utf8))
    exit(1)
}
