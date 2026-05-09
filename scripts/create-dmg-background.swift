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
    lineHeight: CGFloat? = nil
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
    text.draw(in: rect, withAttributes: attributes)
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

private func drawArrow(from start: NSPoint, to end: NSPoint) {
    let line = NSBezierPath()
    line.move(to: start)
    line.curve(to: end, controlPoint1: NSPoint(x: 320, y: 255), controlPoint2: NSPoint(x: 400, y: 255))
    color(38, 116, 204).setStroke()
    line.lineWidth = 4
    line.lineCapStyle = .round
    line.stroke()

    let head = NSBezierPath()
    head.move(to: end)
    head.line(to: NSPoint(x: end.x - 18, y: end.y + 11))
    head.line(to: NSPoint(x: end.x - 18, y: end.y - 11))
    head.close()
    color(38, 116, 204).setFill()
    head.fill()
}

private func drawBackground(to outputURL: URL) throws {
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

    color(247, 249, 252).setFill()
    NSBezierPath(rect: NSRect(origin: .zero, size: canvasSize)).fill()

    roundedRect(
        NSRect(x: 34, y: 304, width: 652, height: 108),
        radius: 18,
        fill: .white,
        stroke: color(222, 228, 238)
    )

    drawText(
        "Alhangeul.app을 Applications로 드래그해 설치하세요.",
        in: NSRect(x: 74, y: 362, width: 572, height: 34),
        font: .boldSystemFont(ofSize: 23),
        color: color(22, 29, 43)
    )
    drawText(
        "Drag Alhangeul.app to Applications.",
        in: NSRect(x: 74, y: 330, width: 572, height: 24),
        font: .systemFont(ofSize: 16, weight: .medium),
        color: color(82, 93, 112)
    )

    drawArrow(from: NSPoint(x: 258, y: 214), to: NSPoint(x: 462, y: 214))

    drawText(
        "Alhangeul.app",
        in: NSRect(x: 94, y: 118, width: 172, height: 24),
        font: .systemFont(ofSize: 15, weight: .semibold),
        color: color(45, 55, 72)
    )
    drawText(
        "Applications",
        in: NSRect(x: 456, y: 118, width: 172, height: 24),
        font: .systemFont(ofSize: 15, weight: .semibold),
        color: color(45, 55, 72)
    )

    roundedRect(
        NSRect(x: 48, y: 36, width: 624, height: 72),
        radius: 14,
        fill: color(232, 241, 252),
        stroke: color(196, 216, 242)
    )
    drawText(
        "설치 후 앱을 한 번 실행하면 Quick Look/Thumbnail이 활성화됩니다.\nLaunch once after installing to enable Quick Look and thumbnails.",
        in: NSRect(x: 72, y: 54, width: 576, height: 42),
        font: .systemFont(ofSize: 14, weight: .medium),
        color: color(37, 70, 112),
        lineHeight: 20
    )

    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

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
