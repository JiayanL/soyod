#!/usr/bin/env swift
// Renders the Atlas mark into app-icon PNGs and LaunchMark PNGs.
// Usage: swift scripts/render-icon.swift   (run from repo root)
import Foundation
import CoreGraphics
import ImageIO
import CoreImage
import UniformTypeIdentifiers

// MARK: - Atlas mark geometry (1024x1024 canvas, y-down)

func hex(_ r: Int, _ g: Int, _ b: Int, _ a: Double = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: a)
}

/// Draws the Atlas mark (globe resting on shoulders arc) into `ctx`.
/// `size` is the canvas pixel size; geometry is defined in a 1024 space.
func drawMark(in ctx: CGContext, size: CGFloat, color: CGColor, glow: Bool) {
    let s = size / 1024
    ctx.saveGState()
    ctx.scaleBy(x: s, y: s)

    // Globe: center (512, 380), r 150.
    let globeCenter = CGPoint(x: 512, y: 380)
    let globeR: CGFloat = 150

    if glow {
        // Faint volt halo behind the globe: concentric circles, decreasing alpha.
        let volt = CGColor(srgbRed: 0xD4 / 255, green: 1.0, blue: 0x3F / 255, alpha: 1)
        for i in stride(from: 12, through: 0, by: -1) {
            let r = globeR + CGFloat(12 - i) * 16
            let alpha = 0.22 * Double(i) / 12.0
            ctx.setFillColor(volt.copy(alpha: alpha)!)
            ctx.fillEllipse(in: CGRect(x: globeCenter.x - r, y: globeCenter.y - r, width: r * 2, height: r * 2))
        }
    }

    // Shoulders arc: circle center (512, 1060), r 470, stroke 64.
    // Endpoints x=232 / x=792 -> angle = acos(280/470) ~= 53.5 deg.
    let theta = acos(280.0 / 470.0) // radians
    let start = Double.pi + theta           // left endpoint
    let end = 2 * Double.pi - theta         // right endpoint (through top)
    ctx.setStrokeColor(color)
    ctx.setLineWidth(64)
    ctx.setLineCap(.round)
    ctx.addArc(center: CGPoint(x: 512, y: 1060), radius: 470,
               startAngle: start, endAngle: end, clockwise: false)
    ctx.strokePath()

    // Globe fill on top.
    ctx.setFillColor(color)
    ctx.fillEllipse(in: CGRect(x: globeCenter.x - globeR, y: globeCenter.y - globeR,
                               width: globeR * 2, height: globeR * 2))
    ctx.restoreGState()
}

func makeContext(size: Int, alpha: Bool) -> CGContext {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let info: CGImageAlphaInfo = alpha ? .premultipliedLast : .noneSkipLast
    return CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                     bytesPerRow: 0, space: colorSpace, bitmapInfo: info.rawValue)!
}

func writePNG(_ image: CGImage, to path: String) throws {
    let url = URL(fileURLWithPath: path)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "render-icon", code: 1, userInfo: [NSLocalizedDescriptionKey: "dest failed \(path)"])
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else {
        throw NSError(domain: "render-icon", code: 2, userInfo: [NSLocalizedDescriptionKey: "finalize failed \(path)"])
    }
    print("wrote \(path)")
}

// MARK: - Variants

/// Default icon: radial gradient bg #161A24 -> #0B0D12, warm-white mark, volt glow. No alpha.
func renderDefaultIcon(size: Int) -> CGImage {
    let ctx = makeContext(size: size, alpha: false)
    let s = size
    let center = CGPoint(x: CGFloat(s) / 2, y: CGFloat(s) * 0.42)
    let colors = [hex(0x16, 0x1A, 0x24), hex(0x0B, 0x0D, 0x12)] as CFArray
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let grad = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1])!
    ctx.drawRadialGradient(grad, startCenter: center, startRadius: 0,
                           endCenter: center, endRadius: CGFloat(s) * 0.85, options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
    drawMark(in: ctx, size: CGFloat(s), color: hex(0xF5, 0xF5, 0xF2), glow: true)
    return ctx.makeImage()!
}

/// Dark variant: mark + glow on transparent.
func renderDarkIcon(size: Int) -> CGImage {
    let ctx = makeContext(size: size, alpha: true)
    drawMark(in: ctx, size: CGFloat(size), color: hex(0xF5, 0xF5, 0xF2), glow: true)
    return ctx.makeImage()!
}

/// Tinted variant: white mark on black.
func renderTintedIcon(size: Int) -> CGImage {
    let ctx = makeContext(size: size, alpha: false)
    ctx.setFillColor(hex(0, 0, 0))
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
    drawMark(in: ctx, size: CGFloat(size), color: hex(0xFF, 0xFF, 0xFF), glow: false)
    return ctx.makeImage()!
}

/// Launch mark only, transparent.
func renderLaunchMark(size: Int, color: CGColor) -> CGImage {
    let ctx = makeContext(size: size, alpha: true)
    drawMark(in: ctx, size: CGFloat(size), color: color, glow: false)
    return ctx.makeImage()!
}

// MARK: - Main

let fm = FileManager.default
let root = fm.currentDirectoryPath
let iconSet = "\(root)/Atlas/Resources/Assets.xcassets/AppIcon.appiconset"
let markSet = "\(root)/Atlas/Resources/Assets.xcassets/LaunchMark.imageset"
try fm.createDirectory(atPath: iconSet, withIntermediateDirectories: true)
try fm.createDirectory(atPath: markSet, withIntermediateDirectories: true)

try writePNG(renderDefaultIcon(size: 1024), to: "\(iconSet)/AppIcon.png")
try writePNG(renderDarkIcon(size: 1024), to: "\(iconSet)/AppIcon-Dark.png")
try writePNG(renderTintedIcon(size: 1024), to: "\(iconSet)/AppIcon-Tinted.png")

let lightMark = hex(0x0E, 0x0F, 0x12)
let darkMark = hex(0xF5, 0xF5, 0xF2)
for (scale, px) in [(1, 200), (2, 400), (3, 600)] {
    try writePNG(renderLaunchMark(size: px, color: lightMark), to: "\(markSet)/LaunchMark-Light@\(scale)x.png")
    try writePNG(renderLaunchMark(size: px, color: darkMark), to: "\(markSet)/LaunchMark-Dark@\(scale)x.png")
}
print("done")
