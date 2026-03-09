#!/usr/bin/env swift
import Cocoa

let width = 660
let height = 400
let retina = 2 // @2x for Retina displays

let pxW = width * retina
let pxH = height * retina

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pxW,
    pixelsHigh: pxH,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
rep.size = NSSize(width: width, height: height)

NSGraphicsContext.saveGraphicsState()
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = ctx

// Background gradient
let gradient = NSGradient(
    starting: NSColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0),
    ending: NSColor(red: 0.90, green: 0.92, blue: 0.95, alpha: 1.0)
)!
gradient.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: 270)

// Arrow (drawn between the two icon positions)
// App icon at x=176, Applications at x=484 (centered in 660px window)
let arrowY = CGFloat(height) / 2 + 20 // slightly above center
let arrowStartX: CGFloat = 240
let arrowEndX: CGFloat = 420
let arrowColor = NSColor(red: 0.55, green: 0.60, blue: 0.68, alpha: 0.7)
arrowColor.setStroke()
arrowColor.setFill()

let arrowPath = NSBezierPath()
arrowPath.lineWidth = 3.0
arrowPath.lineCapStyle = .round

// Shaft
arrowPath.move(to: NSPoint(x: arrowStartX, y: arrowY))
arrowPath.line(to: NSPoint(x: arrowEndX - 15, y: arrowY))
arrowPath.stroke()

// Arrowhead
let headPath = NSBezierPath()
headPath.move(to: NSPoint(x: arrowEndX, y: arrowY))
headPath.line(to: NSPoint(x: arrowEndX - 20, y: arrowY + 12))
headPath.line(to: NSPoint(x: arrowEndX - 20, y: arrowY - 12))
headPath.close()
headPath.fill()

// Instruction text
let paragraphStyle = NSMutableParagraphStyle()
paragraphStyle.alignment = .center
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 14, weight: .medium),
    .foregroundColor: NSColor(red: 0.40, green: 0.45, blue: 0.52, alpha: 0.9),
    .paragraphStyle: paragraphStyle
]
let text = "Drag to Applications to install"
let textRect = NSRect(x: 0, y: 50, width: CGFloat(width), height: 30)
text.draw(in: textRect, withAttributes: attrs)

NSGraphicsContext.restoreGraphicsState()

// Save as PNG
let data = rep.representation(using: .png, properties: [:])!
let url = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg-background.png")
try! data.write(to: url)
print("Generated: \(url.path)")
