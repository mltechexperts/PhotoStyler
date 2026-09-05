#!/usr/bin/env swift
// Generates PhotoStyler's app icons.
//
// Placeholder identity: a camera iris, drawn once and exported for the light,
// dark and tinted slots iOS 26 asks for. Replace with a designed mark when
// Murali has one — this exists so the app never ships the blank default.
//
// Usage:  swift tools/generate_icon.swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024.0
let outDir = "PhotoStyler/Assets.xcassets/AppIcon.appiconset"

enum Variant {
    case light, dark, tinted

    /// Background is drawn for the opaque slots; the tinted slot is masked by
    /// the system, so it stays greyscale on black.
    var background: (CGColor, CGColor)? {
        switch self {
        case .light: (CGColor(red: 0.99, green: 0.93, blue: 0.85, alpha: 1),
                      CGColor(red: 0.93, green: 0.74, blue: 0.53, alpha: 1))
        case .dark:  (CGColor(red: 0.11, green: 0.12, blue: 0.15, alpha: 1),
                      CGColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 1))
        case .tinted: nil
        }
    }

    var iris: CGColor {
        switch self {
        case .light:  CGColor(red: 0.16, green: 0.17, blue: 0.20, alpha: 1)
        case .dark:   CGColor(red: 0.96, green: 0.80, blue: 0.60, alpha: 1)
        case .tinted: CGColor(gray: 1, alpha: 1)
        }
    }

    var fileName: String {
        switch self {
        case .light: "AppIcon-light.png"
        case .dark: "AppIcon-dark.png"
        case .tinted: "AppIcon-tinted.png"
        }
    }
}

func hexagon(center c: CGPoint, radius r: Double, rotation: Double) -> CGPath {
    let path = CGMutablePath()
    for i in 0..<6 {
        let a = rotation + Double(i) * .pi / 3
        let p = CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
        if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
    }
    path.closeSubpath()
    return path
}

func draw(_ variant: Variant) {
    let space = CGColorSpaceCreateDeviceRGB()

    // The iris is drawn into its own transparent layer so the blade separators
    // can be cut out of it. Erasing them directly in the final context would
    // punch holes through to transparency, and app icons must be opaque.
    guard let irisCtx = CGContext(
        data: nil, width: Int(size), height: Int(size),
        bitsPerComponent: 8, bytesPerRow: 0, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fatalError("iris context") }

    // Opaque final canvas.
    guard let ctx = CGContext(
        data: nil, width: Int(size), height: Int(size),
        bitsPerComponent: 8, bytesPerRow: 0, space: space,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { fatalError("context") }

    // Background
    if let (top, bottom) = variant.background {
        let gradient = CGGradient(
            colorsSpace: space, colors: [top, bottom] as CFArray, locations: [0, 1]
        )!
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0),
            options: []
        )
    } else {
        ctx.setFillColor(CGColor(gray: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
    }

    let c = CGPoint(x: size / 2, y: size / 2)
    let outer = size * 0.34
    let inner = size * 0.155

    irisCtx.setFillColor(variant.iris)
    irisCtx.setStrokeColor(variant.iris)

    // Iris ring: outer circle with a hexagonal opening.
    let ring = CGMutablePath()
    ring.addEllipse(in: CGRect(x: c.x - outer, y: c.y - outer, width: outer * 2, height: outer * 2))
    ring.addPath(hexagon(center: c, radius: inner, rotation: .pi / 6))
    irisCtx.addPath(ring)
    irisCtx.fillPath(using: .evenOdd)

    // Blade separators, cut out so the background shows through as edges.
    irisCtx.setBlendMode(.clear)
    irisCtx.setLineWidth(size * 0.018)
    irisCtx.setLineCap(.round)
    for i in 0..<6 {
        let a = .pi / 6 + Double(i) * .pi / 3
        let from = CGPoint(x: c.x + inner * cos(a), y: c.y + inner * sin(a))
        let to = CGPoint(x: c.x + (outer + 4) * cos(a - 0.42),
                         y: c.y + (outer + 4) * sin(a - 0.42))
        irisCtx.move(to: from)
        irisCtx.addLine(to: to)
    }
    irisCtx.strokePath()
    irisCtx.setBlendMode(.normal)

    guard let iris = irisCtx.makeImage() else { fatalError("iris") }
    ctx.draw(iris, in: CGRect(x: 0, y: 0, width: size, height: size))

    guard let image = ctx.makeImage() else { fatalError("image") }
    let url = URL(fileURLWithPath: "\(outDir)/\(variant.fileName)")
    guard let dest = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else { fatalError("dest") }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    print("wrote \(variant.fileName)")
}

for variant in [Variant.light, .dark, .tinted] { draw(variant) }
