#!/usr/bin/swift
import AppKit

let iconsetDir = "/tmp/AppIcon.iconset"
try! FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let specs: [(Int, String)] = [
    (16,   "icon_16x16"),
    (32,   "icon_16x16@2x"),
    (32,   "icon_32x32"),
    (64,   "icon_32x32@2x"),
    (128,  "icon_128x128"),
    (256,  "icon_128x128@2x"),
    (256,  "icon_256x256"),
    (512,  "icon_256x256@2x"),
    (512,  "icon_512x512"),
    (1024, "icon_512x512@2x"),
]

for (sz, name) in specs {
    let s = CGFloat(sz)

    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: sz, pixelsHigh: sz,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // 蓝色圆角背景
    let radius = s * 0.22
    let bgRect = NSRect(x: 0, y: 0, width: s, height: s)
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: radius, yRadius: radius)
    NSColor(red: 0.18, green: 0.45, blue: 0.98, alpha: 1.0).setFill()
    bgPath.fill()

    // 白色 character.bubble 图标
    let symPt = s * 0.58
    let cfg = NSImage.SymbolConfiguration(pointSize: symPt, weight: .regular)
    if let sym = NSImage(systemSymbolName: "character.bubble", accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) {
        let off = (s - symPt) / 2.0
        let symRect = NSRect(x: off, y: off, width: symPt, height: symPt)
        NSColor.white.set()
        sym.draw(in: symRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    NSGraphicsContext.restoreGraphicsState()

    if let png = rep.representation(using: .png, properties: [:]) {
        let path = "\(iconsetDir)/\(name).png"
        try! png.write(to: URL(fileURLWithPath: path))
        print("  \(name).png")
    }
}

print("iconset 生成完毕，运行 iconutil...")
