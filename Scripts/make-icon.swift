#!/usr/bin/env swift
// Genera AppIcon.icns: botón de encendido sobre ventanas apiladas, en el morado del pack.
// Uso: swift Scripts/make-icon.swift Resources/AppIcon.icns
import AppKit
import CoreGraphics

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let s = CGFloat(px) / 1024
    ctx.scaleBy(x: s, y: s)

    // fondo: squircle con degradado morado
    let bg = CGPath(roundedRect: CGRect(x: 40, y: 40, width: 944, height: 944), cornerWidth: 215, cornerHeight: 215, transform: nil)
    ctx.saveGState(); ctx.addPath(bg); ctx.clip()
    let cs = CGColorSpaceCreateDeviceRGB()
    let grad = CGGradient(colorsSpace: cs, colors: [CGColor(red: 0.62, green: 0.38, blue: 0.98, alpha: 1), CGColor(red: 0.33, green: 0.20, blue: 0.80, alpha: 1)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 100, y: 1000), end: CGPoint(x: 900, y: 40), options: [])
    ctx.restoreGState()

    // ventanas apiladas que «se van»
    for (i, a) in [(0, 0.22), (1, 0.38)] {
        let off = CGFloat(i) * 46
        let r = CGRect(x: 190 + off, y: 330 - off, width: 470, height: 360)
        ctx.setFillColor(CGColor(gray: 1, alpha: a))
        ctx.addPath(CGPath(roundedRect: r, cornerWidth: 44, cornerHeight: 44, transform: nil)); ctx.fillPath()
    }

    // botón de encendido blanco
    let c = CGPoint(x: 540, y: 490), rad: CGFloat = 215
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: CGColor(gray: 0, alpha: 0.28))
    ctx.setFillColor(CGColor(gray: 1, alpha: 1))
    ctx.addEllipse(in: CGRect(x: c.x - rad, y: c.y - rad, width: rad * 2, height: rad * 2)); ctx.fillPath()
    ctx.restoreGState()
    ctx.setStrokeColor(CGColor(red: 0.45, green: 0.27, blue: 0.90, alpha: 1))
    ctx.setLineWidth(44); ctx.setLineCap(.round)
    let r2: CGFloat = 112
    ctx.addArc(center: c, radius: r2, startAngle: .pi / 2 + 0.62, endAngle: .pi / 2 - 0.62, clockwise: false)
    ctx.strokePath()
    ctx.move(to: CGPoint(x: c.x, y: c.y + 10)); ctx.addLine(to: CGPoint(x: c.x, y: c.y + 140)); ctx.strokePath()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.icns"
let set = (out as NSString).deletingLastPathComponent + "/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: set)
try! FileManager.default.createDirectory(atPath: set, withIntermediateDirectories: true)
let sizes: [(String, Int)] = [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128), ("128x128@2x", 256),
                               ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)]
for (n, px) in sizes { try! render(px).write(to: URL(fileURLWithPath: "\(set)/icon_\(n).png")) }
let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil"); p.arguments = ["-c", "icns", set, "-o", out]
try! p.run(); p.waitUntilExit()
try? FileManager.default.removeItem(atPath: set)
print("OK", out)
