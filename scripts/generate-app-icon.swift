#!/usr/bin/env swift  //
// generate-app-icon.swift
// Generates the Whisp app icon programmatically.
//
// Usage: swift scripts/generate-app-icon.swift
// Output: WhispIcon.png (1024x1024) in the repo root.
//         Also copies resized variants into Sources/Assets.xcassets/AppIcon.appiconset/
//
// Design: Deep charcoal background with warm amber waveform bars.
//         Five asymmetric rounded bars suggest voice/speech.

import AppKit
import CoreGraphics
import Foundation

let canvasSize: CGFloat = 1024
let image = NSImage(size: NSSize(width: canvasSize, height: canvasSize))

image.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else {
    fatalError("Failed to get graphics context")
}

// ── Background: rich warm gradient (deep charcoal with amber warmth) ──
let bgColors: [CGFloat] = [
    // Color 1 (top): warm dark gray
    0.16, 0.14, 0.12, 1.0,
    // Color 2 (bottom): near-black with warm tint
    0.08, 0.07, 0.06, 1.0,
]

let colorSpace = CGColorSpaceCreateDeviceRGB()
let bgGradient = CGGradient(
    colorSpace: colorSpace,
    colorComponents: bgColors,
    locations: [0.0, 1.0],
    count: 2
)!

context.drawLinearGradient(
    bgGradient,
    start: CGPoint(x: canvasSize / 2, y: canvasSize),  // top
    end: CGPoint(x: canvasSize / 2, y: 0),  // bottom
    options: []
)

// ── Subtle radial highlight at center-top for depth ──
let highlightColors: [CGFloat] = [
    0.22, 0.19, 0.16, 1.0,  // lighter warm center
    0.16, 0.14, 0.12, 0.0,  // fade to transparent
]
let highlightGradient = CGGradient(
    colorSpace: colorSpace,
    colorComponents: highlightColors,
    locations: [0.0, 1.0],
    count: 2
)!

context.drawRadialGradient(
    highlightGradient,
    startCenter: CGPoint(x: canvasSize / 2, y: canvasSize * 0.62),
    startRadius: 0,
    endCenter: CGPoint(x: canvasSize / 2, y: canvasSize * 0.62),
    endRadius: canvasSize * 0.45,
    options: []
)

// ── Waveform bars: warm amber with subtle gradient per bar ──
let barWidth: CGFloat = 42
let gap: CGFloat = 44
let cornerRadius: CGFloat = 21
let heights: [CGFloat] = [220, 360, 500, 310, 190]
let numBars = heights.count
let totalWidth = CGFloat(numBars) * barWidth + CGFloat(numBars - 1) * gap
let startX = (canvasSize - totalWidth) / 2
let centerY = canvasSize / 2

// Shadow behind bars
context.setShadow(
    offset: CGSize(width: 0, height: -8),
    blur: 24,
    color: CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.4)
)

for (i, height) in heights.enumerated() {
    let x = startX + CGFloat(i) * (barWidth + gap)
    let y = centerY - height / 2
    let rect = CGRect(x: x, y: y, width: barWidth, height: height)
    let path = CGPath(
        roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    // Per-bar gradient: lighter amber at top, deeper at bottom
    context.saveGState()
    context.addPath(path)
    context.clip()

    let barColors: [CGFloat] = [
        0.95, 0.75, 0.28, 1.0,  // bright amber (top of bar)
        0.82, 0.55, 0.14, 1.0,  // deep amber (bottom of bar)
    ]
    let barGradient = CGGradient(
        colorSpace: colorSpace,
        colorComponents: barColors,
        locations: [0.0, 1.0],
        count: 2
    )!

    context.drawLinearGradient(
        barGradient,
        start: CGPoint(x: x, y: y + height),  // top of bar
        end: CGPoint(x: x, y: y),  // bottom of bar
        options: []
    )

    context.restoreGState()
}

// Remove shadow for the highlight pass
context.setShadow(offset: .zero, blur: 0, color: nil)

// ── Subtle highlight on top edge of each bar ──
for (i, height) in heights.enumerated() {
    let x = startX + CGFloat(i) * (barWidth + gap)
    let y = centerY - height / 2
    let highlightRect = CGRect(x: x + 2, y: y + height - 6, width: barWidth - 4, height: 3)
    let highlightPath = CGPath(
        roundedRect: highlightRect,
        cornerWidth: 1.5, cornerHeight: 1.5, transform: nil
    )

    context.setFillColor(CGColor(red: 1.0, green: 0.92, blue: 0.65, alpha: 0.35))
    context.addPath(highlightPath)
    context.fillPath()
}

image.unlockFocus()

// ── Export ──
guard let tiffData = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiffData),
    let pngData = bitmap.representation(using: .png, properties: [:])
else {
    fatalError("Failed to generate PNG data")
}

let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceIconPath = repoRoot.appendingPathComponent("WhispIcon.png")
try! pngData.write(to: sourceIconPath)
print("Generated \(sourceIconPath.path) (1024x1024)")

// ── Resize and copy to Assets.xcassets ──
let assetDir =
    repoRoot
    .appendingPathComponent("Sources")
    .appendingPathComponent("Assets.xcassets")
    .appendingPathComponent("AppIcon.appiconset")

struct IconSize {
    let name: String
    let pixels: Int
}

let sizes: [IconSize] = [
    IconSize(name: "icon_16x16.png", pixels: 16),
    IconSize(name: "icon_16x16@2x.png", pixels: 32),
    IconSize(name: "icon_32x32.png", pixels: 32),
    IconSize(name: "icon_32x32@2x.png", pixels: 64),
    IconSize(name: "icon_128x128.png", pixels: 128),
    IconSize(name: "icon_128x128@2x.png", pixels: 256),
    IconSize(name: "icon_256x256.png", pixels: 256),
    IconSize(name: "icon_256x256@2x.png", pixels: 512),
    IconSize(name: "icon_512x512.png", pixels: 512),
    IconSize(name: "icon_512x512@2x.png", pixels: 1024),
]

if FileManager.default.fileExists(atPath: assetDir.path) {
    print("Copying resized icons to Assets.xcassets...")
    for size in sizes {
        let resized = NSImage(size: NSSize(width: size.pixels, height: size.pixels))
        resized.lockFocus()
        image.draw(
            in: NSRect(x: 0, y: 0, width: size.pixels, height: size.pixels),
            from: NSRect(x: 0, y: 0, width: canvasSize, height: canvasSize),
            operation: .copy,
            fraction: 1.0
        )
        resized.unlockFocus()

        if let tiff = resized.tiffRepresentation,
            let bmp = NSBitmapImageRep(data: tiff),
            let png = bmp.representation(using: .png, properties: [:])
        {
            let dest = assetDir.appendingPathComponent(size.name)
            try! png.write(to: dest)
            print("  \(size.name) (\(size.pixels)x\(size.pixels))")
        }
    }
    print("Done.")
} else {
    print("Assets directory not found at \(assetDir.path). Run from repo root.")
}
