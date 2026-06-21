#!/usr/bin/env swift
// Draws Folio's app icon (1024×1024 PNG) with AppKit — no design assets needed.
// Usage: swift scripts/make_icon.swift <output.png>
import AppKit

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let side: CGFloat = 1024
let image = NSImage(size: NSSize(width: side, height: side))

func rrect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: r, yRadius: r)
}

image.lockFocus()
let ctx = NSGraphicsContext.current!
ctx.imageInterpolation = .high

// Rounded-square background with an indigo→blue gradient.
let margin: CGFloat = 96
let bg = rrect(margin, margin, side - 2 * margin, side - 2 * margin, 200)
let gradient = NSGradient(
    starting: NSColor(srgbRed: 0.36, green: 0.36, blue: 0.87, alpha: 1),
    ending:   NSColor(srgbRed: 0.23, green: 0.47, blue: 0.98, alpha: 1)
)!
gradient.draw(in: bg, angle: -90)

// White "document" card with a soft drop shadow.
let docX: CGFloat = 322, docY: CGFloat = 268, docW: CGFloat = 380, docH: CGFloat = 488
ctx.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.shadowBlurRadius = 34
shadow.set()
NSColor.white.setFill()
rrect(docX, docY, docW, docH, 40).fill()
ctx.restoreGraphicsState()

// Accent heading bar + body lines (a "Markdown" document).
let accent = NSColor(srgbRed: 0.23, green: 0.47, blue: 0.98, alpha: 1)
let line = NSColor(white: 0.82, alpha: 1)
let leftX = docX + 44
let barW = docW - 88

accent.setFill();  rrect(leftX, docY + docH - 96, barW, 50, 14).fill()
line.setFill()
rrect(leftX, docY + docH - 176, barW, 28, 12).fill()
rrect(leftX, docY + docH - 234, barW, 28, 12).fill()
rrect(leftX, docY + docH - 292, barW, 28, 12).fill()
rrect(leftX, docY + docH - 350, barW * 0.55, 28, 12).fill()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("Failed to render icon\n".utf8))
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("Wrote \(outPath)")
