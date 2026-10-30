#!/usr/bin/swift
// 生成 NetSpeed 应用图标（NetSpeed.icns）
// 用法: swift Scripts/make-icon.swift <输出.icns 路径>

import AppKit
import Foundation

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "NetSpeed.icns"
let workDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("NetSpeedIcon-\(UUID().uuidString)")
try? FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)

let size = 1024

// MARK: - 画一个图标页

func renderIcon() -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let squircle = NSBezierPath(roundedRect: rect.insetBy(dx: 44, dy: 44), xRadius: 190, yRadius: 190)

    // 背景渐变（深蓝 → 青蓝）
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.16, green: 0.55, blue: 0.96, alpha: 1),
        NSColor(calibratedRed: 0.05, green: 0.20, blue: 0.52, alpha: 1)
    ])!
    gradient.draw(in: squircle, angle: -90)

    // 顶部高光
    NSGraphicsContext.current?.saveGraphicsState()
    squircle.addClip()
    let gloss = NSGradient(colors: [
        NSColor(white: 1, alpha: 0.28),
        NSColor(white: 1, alpha: 0.0)
    ])!
    gloss.draw(in: NSRect(x: 44, y: 560, width: size - 88, height: 420), angle: -90)
    NSGraphicsContext.current?.restoreGraphicsState()

    // 白色下行箭头（SF Symbol）
    if let symbol = NSImage(systemSymbolName: "arrow.down",
                             accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: 520, weight: .bold)) {
        let config = NSImage.SymbolConfiguration(paletteColors: [.white])
        let tinted = symbol.withSymbolConfiguration(config) ?? symbol
        tinted.draw(in: NSRect(x: 252, y: 250, width: 520, height: 520),
                    from: .zero,
                    operation: .sourceOver,
                    fraction: 1.0)
    }

    // 箭头下方的“地面”横条
    let bar = NSBezierPath(roundedRect: NSRect(x: 252, y: 218, width: 520, height: 62),
                           xRadius: 31, yRadius: 31)
    NSColor.white.setFill()
    bar.fill()

    image.unlockFocus()
    return image
}

let base = renderIcon()

// MARK: - 生成 iconset

let iconset = workDir.appendingPathComponent("NetSpeed.iconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let variants: [(Int, Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)
]

for (points, scale) in variants {
    let px = points * scale
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    base.draw(in: NSRect(x: 0, y: 0, width: px, height: px),
              from: NSRect(origin: .zero, size: base.size),
              operation: .copy,
              fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()

    let name = scale == 1
        ? "icon_\(points)x\(points).png"
        : "icon_\(points)x\(points)@2x.png"
    try! rep.representation(using: .png, properties: [:])!
        .write(to: iconset.appendingPathComponent(name))
}

// iconutil 生成 .icns
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", outPath]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    FileHandle.standardError.write(Data("iconutil 失败\n".utf8))
    exit(1)
}
print("已生成图标: \(outPath)")
