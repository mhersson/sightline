#!/usr/bin/env swift

import AppKit

// Generates Sightline.iconset for iconutil. Usage: generate-icon.swift <output-dir>

/// Draws the icon into a bitmap of exactly `size`×`size` pixels, independent of the screen's backing scale.
func renderIcon(size: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    drawIcon(size: CGFloat(size))
    return rep
}

func drawIcon(size s: CGFloat) {
    let bounds = NSRect(x: 0, y: 0, width: s, height: s)
    let cornerRadius = s * 0.22

    // Background: diagonal red-to-blue gradient
    let bgPath = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)

    let gradient = NSGradient(colorsAndLocations:
        (NSColor(red: 0.9, green: 0.1, blue: 0.15, alpha: 1.0), 0.0),
        (NSColor(red: 0.7, green: 0.05, blue: 0.1, alpha: 1.0), 0.3),
        (NSColor(red: 0.15, green: 0.1, blue: 0.4, alpha: 1.0), 0.7),
        (NSColor(red: 0.1, green: 0.2, blue: 0.7, alpha: 1.0), 1.0)
    )!
    gradient.draw(in: bgPath, angle: -45)

    // Sheen overlay
    let sheenGradient = NSGradient(colorsAndLocations:
        (NSColor.white.withAlphaComponent(0.3), 0.0),
        (NSColor.white.withAlphaComponent(0.0), 0.3),
        (NSColor.white.withAlphaComponent(0.1), 0.7),
        (NSColor.white.withAlphaComponent(0.2), 1.0)
    )!
    sheenGradient.draw(in: bgPath, angle: 90)

    let glowColor = NSColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 1.0)

    // Dashed selection rectangle with a soft glow
    let inset = s * 0.18
    let rectBounds = bounds.insetBy(dx: inset, dy: inset * 1.2)

    let glowRect = rectBounds.insetBy(dx: -s * 0.02, dy: -s * 0.02)
    let glowPath = NSBezierPath(roundedRect: glowRect, xRadius: 6, yRadius: 6)
    glowColor.withAlphaComponent(0.4).setStroke()
    glowPath.lineWidth = s * 0.06
    glowPath.stroke()

    let rectPath = NSBezierPath(roundedRect: rectBounds, xRadius: 4, yRadius: 4)
    glowColor.setStroke()
    rectPath.lineWidth = s * 0.035
    let dashLength = s * 0.1
    rectPath.setLineDash([dashLength, dashLength * 0.5], count: 2, phase: 0)
    rectPath.stroke()

    // Crosshair
    let centerX = s / 2
    let centerY = s / 2
    let crossSize = s * 0.22
    let innerGap = s * 0.06

    // Crosshair glow
    NSColor(red: 1.0, green: 0.3, blue: 0.1, alpha: 0.5).setStroke()
    let glowCross = NSBezierPath()
    glowCross.lineWidth = s * 0.05

    // Horizontal
    glowCross.move(to: NSPoint(x: centerX - crossSize, y: centerY))
    glowCross.line(to: NSPoint(x: centerX - innerGap, y: centerY))
    glowCross.move(to: NSPoint(x: centerX + innerGap, y: centerY))
    glowCross.line(to: NSPoint(x: centerX + crossSize, y: centerY))

    // Vertical
    glowCross.move(to: NSPoint(x: centerX, y: centerY - crossSize))
    glowCross.line(to: NSPoint(x: centerX, y: centerY - innerGap))
    glowCross.move(to: NSPoint(x: centerX, y: centerY + innerGap))
    glowCross.line(to: NSPoint(x: centerX, y: centerY + crossSize))

    glowCross.setLineDash([], count: 0, phase: 0)
    glowCross.stroke()

    let orangeGlow = NSColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)
    orangeGlow.setStroke()

    let crossPath = NSBezierPath()
    crossPath.lineWidth = s * 0.03

    // Horizontal lines with gap in center
    crossPath.move(to: NSPoint(x: centerX - crossSize, y: centerY))
    crossPath.line(to: NSPoint(x: centerX - innerGap, y: centerY))
    crossPath.move(to: NSPoint(x: centerX + innerGap, y: centerY))
    crossPath.line(to: NSPoint(x: centerX + crossSize, y: centerY))

    // Vertical lines with gap in center
    crossPath.move(to: NSPoint(x: centerX, y: centerY - crossSize))
    crossPath.line(to: NSPoint(x: centerX, y: centerY - innerGap))
    crossPath.move(to: NSPoint(x: centerX, y: centerY + innerGap))
    crossPath.line(to: NSPoint(x: centerX, y: centerY + crossSize))

    crossPath.stroke()

    // Center dot and ring
    let dotRadius = s * 0.025
    let dotPath = NSBezierPath(ovalIn: NSRect(
        x: centerX - dotRadius,
        y: centerY - dotRadius,
        width: dotRadius * 2,
        height: dotRadius * 2
    ))
    NSColor(red: 1.0, green: 0.9, blue: 0.0, alpha: 1.0).setFill()
    dotPath.fill()

    let circleRadius = s * 0.08
    let circlePath = NSBezierPath(ovalIn: NSRect(
        x: centerX - circleRadius,
        y: centerY - circleRadius,
        width: circleRadius * 2,
        height: circleRadius * 2
    ))
    orangeGlow.setStroke()
    circlePath.lineWidth = s * 0.015
    circlePath.stroke()

    // Corner brackets
    let bracketSize = s * 0.1
    let bracketInset = inset + s * 0.01

    NSColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 0.9).setStroke()
    let bracketPath = NSBezierPath()
    bracketPath.lineWidth = s * 0.025
    bracketPath.lineCapStyle = .square

    // Top-left
    bracketPath.move(to: NSPoint(x: bracketInset, y: s - bracketInset - bracketSize))
    bracketPath.line(to: NSPoint(x: bracketInset, y: s - bracketInset))
    bracketPath.line(to: NSPoint(x: bracketInset + bracketSize, y: s - bracketInset))

    // Top-right
    bracketPath.move(to: NSPoint(x: s - bracketInset - bracketSize, y: s - bracketInset))
    bracketPath.line(to: NSPoint(x: s - bracketInset, y: s - bracketInset))
    bracketPath.line(to: NSPoint(x: s - bracketInset, y: s - bracketInset - bracketSize))

    // Bottom-left
    bracketPath.move(to: NSPoint(x: bracketInset, y: bracketInset + bracketSize))
    bracketPath.line(to: NSPoint(x: bracketInset, y: bracketInset))
    bracketPath.line(to: NSPoint(x: bracketInset + bracketSize, y: bracketInset))

    // Bottom-right
    bracketPath.move(to: NSPoint(x: s - bracketInset - bracketSize, y: bracketInset))
    bracketPath.line(to: NSPoint(x: s - bracketInset, y: bracketInset))
    bracketPath.line(to: NSPoint(x: s - bracketInset, y: bracketInset + bracketSize))

    bracketPath.stroke()

    // Corner accent triangles
    let triSize = s * 0.04
    NSColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 0.7).setFill()

    for corner in [(s * 0.08, s * 0.92), (s * 0.92, s * 0.92), (s * 0.08, s * 0.08), (s * 0.92, s * 0.08)] {
        let triPath = NSBezierPath()
        triPath.move(to: NSPoint(x: corner.0, y: corner.1))
        triPath.line(to: NSPoint(x: corner.0 + triSize, y: corner.1))
        triPath.line(to: NSPoint(x: corner.0, y: corner.1 - triSize))
        triPath.close()
        triPath.fill()
    }
}

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/sightline-icon.iconset"
try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

// The point sizes iconutil expects, each at 1x and 2x.
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        let png = renderIcon(size: points * scale).representation(using: .png, properties: [:])!
        try png.write(to: URL(fileURLWithPath: outputDir).appending(path: name))
    }
}

print("Icon set generated at: \(outputDir)")
