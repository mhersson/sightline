#!/usr/bin/env swift

import AppKit

// Generate Transformers-themed app icon
func generateIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    let s = CGFloat(size)

    image.lockFocus()

    let bounds = NSRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = s * 0.22

    // Background - dramatic red to blue split (Autobot vs Decepticon style)
    let bgPath = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)

    // Diagonal split gradient - Optimus Prime colors
    let gradient = NSGradient(colorsAndLocations:
        (NSColor(red: 0.9, green: 0.1, blue: 0.15, alpha: 1.0), 0.0),    // Autobot red
        (NSColor(red: 0.7, green: 0.05, blue: 0.1, alpha: 1.0), 0.3),   // Darker red
        (NSColor(red: 0.15, green: 0.1, blue: 0.4, alpha: 1.0), 0.7),   // Transition to blue
        (NSColor(red: 0.1, green: 0.2, blue: 0.7, alpha: 1.0), 1.0)     // Autobot blue
    )!
    gradient.draw(in: bgPath, angle: -45)

    // Add metallic sheen overlay
    let sheenGradient = NSGradient(colorsAndLocations:
        (NSColor.white.withAlphaComponent(0.3), 0.0),
        (NSColor.white.withAlphaComponent(0.0), 0.3),
        (NSColor.white.withAlphaComponent(0.1), 0.7),
        (NSColor.white.withAlphaComponent(0.2), 1.0)
    )!
    sheenGradient.draw(in: bgPath, angle: 90)

    // Energon glow effect - cyan/electric blue accents
    let glowColor = NSColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 1.0)
    let glowColorFade = NSColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 0.0)

    // Screen region - angular, mechanical style
    let inset = s * 0.18
    let rectBounds = bounds.insetBy(dx: inset, dy: inset * 1.2)

    // Outer glow for the rectangle
    let glowRect = rectBounds.insetBy(dx: -s * 0.02, dy: -s * 0.02)
    let glowPath = NSBezierPath(roundedRect: glowRect, xRadius: 6, yRadius: 6)
    glowColor.withAlphaComponent(0.4).setStroke()
    glowPath.lineWidth = s * 0.06
    glowPath.stroke()

    // Main rectangle - energon cyan with glow
    let rectPath = NSBezierPath(roundedRect: rectBounds, xRadius: 4, yRadius: 4)
    glowColor.setStroke()
    rectPath.lineWidth = s * 0.035
    let dashLength = s * 0.1
    rectPath.setLineDash([dashLength, dashLength * 0.5], count: 2, phase: 0)
    rectPath.stroke()

    // === CROSSHAIR - Central targeting system ===
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

    // Main crosshair - bright orange/yellow (energon power)
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

    // Center dot - targeting lock
    let dotRadius = s * 0.025
    let dotPath = NSBezierPath(ovalIn: NSRect(
        x: centerX - dotRadius,
        y: centerY - dotRadius,
        width: dotRadius * 2,
        height: dotRadius * 2
    ))
    NSColor(red: 1.0, green: 0.9, blue: 0.0, alpha: 1.0).setFill()
    dotPath.fill()

    // Outer targeting circle
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

    // Corner brackets - mechanical/angular style
    let bracketSize = s * 0.1
    let bracketInset = inset + s * 0.01

    // Yellow/gold brackets for that Bumblebee accent
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

    // Small accent triangles in corners (Transformers angular style)
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

    image.unlockFocus()
    return image
}

func saveAsPNG(_ image: NSImage, to path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG data")
        return
    }

    do {
        try pngData.write(to: URL(fileURLWithPath: path))
    } catch {
        print("Failed to write PNG: \(error)")
    }
}

// Icon sizes needed for .icns
let sizes = [16, 32, 64, 128, 256, 512, 1024]
let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/sightline-icon.iconset"

// Create iconset directory
let fileManager = FileManager.default
try? fileManager.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

for size in sizes {
    let image = generateIcon(size: size)

    // Standard resolution
    if size <= 512 {
        saveAsPNG(image, to: "\(outputDir)/icon_\(size)x\(size).png")
    }

    // @2x resolution (Retina)
    if size >= 32 {
        let halfSize = size / 2
        if halfSize >= 16 {
            saveAsPNG(image, to: "\(outputDir)/icon_\(halfSize)x\(halfSize)@2x.png")
        }
    }
}

print("Icon set generated at: \(outputDir)")
