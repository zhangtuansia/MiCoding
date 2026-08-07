import AppKit
import Foundation

private struct IconSpec {
    let name: String
    let pixels: Int
}

private let specs = [
    IconSpec(name: "icon_16x16.png", pixels: 16),
    IconSpec(name: "icon_16x16@2x.png", pixels: 32),
    IconSpec(name: "icon_32x32.png", pixels: 32),
    IconSpec(name: "icon_32x32@2x.png", pixels: 64),
    IconSpec(name: "icon_128x128.png", pixels: 128),
    IconSpec(name: "icon_128x128@2x.png", pixels: 256),
    IconSpec(name: "icon_256x256.png", pixels: 256),
    IconSpec(name: "icon_256x256@2x.png", pixels: 512),
    IconSpec(name: "icon_512x512.png", pixels: 512),
    IconSpec(name: "icon_512x512@2x.png", pixels: 1024)
]

private let projectURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
private let outputURL = projectURL.appendingPathComponent("Resources/AppIcon-official.iconset", isDirectory: true)
private let sourceURL = projectURL.appendingPathComponent(
    "Sources/XiaomiRemoteStudio/Resources/remote-product-v5-premium.png"
)

guard let remoteImage = NSImage(contentsOf: sourceURL) else {
    fatalError("无法读取遥控器产品图：\(sourceURL.path)")
}

try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

private func squirclePath(in rect: CGRect, exponent: CGFloat = 5.2) -> NSBezierPath {
    let path = NSBezierPath()
    let a = rect.width / 2
    let b = rect.height / 2
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let steps = 240

    for step in 0...steps {
        let angle = CGFloat(step) / CGFloat(steps) * .pi * 2
        let cosine = cos(angle)
        let sine = sin(angle)
        let x = center.x + a * (cosine >= 0 ? 1 : -1) * pow(abs(cosine), 2 / exponent)
        let y = center.y + b * (sine >= 0 ? 1 : -1) * pow(abs(sine), 2 / exponent)
        if step == 0 {
            path.move(to: CGPoint(x: x, y: y))
        } else {
            path.line(to: CGPoint(x: x, y: y))
        }
    }
    path.close()
    return path
}

private func drawBase(size: CGFloat, path: NSBezierPath) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.27)
    shadow.shadowBlurRadius = size * 0.047
    shadow.shadowOffset = CGSize(width: 0, height: -size * 0.024)
    shadow.set()
    NSColor(calibratedWhite: 0.98, alpha: 1).setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    let baseGradient = NSGradient(colors: [
        NSColor(calibratedRed: 1.00, green: 0.995, blue: 0.985, alpha: 1),
        NSColor(calibratedRed: 0.935, green: 0.925, blue: 0.965, alpha: 1)
    ])!
    baseGradient.draw(in: path, angle: -82)

    NSGraphicsContext.saveGraphicsState()
    path.addClip()

    let glowRect = CGRect(
        x: size * 0.17,
        y: size * 0.15,
        width: size * 0.70,
        height: size * 0.70
    )
    let glowPath = NSBezierPath(ovalIn: glowRect)
    let glow = NSGradient(colorsAndLocations:
        (NSColor(calibratedRed: 0.49, green: 0.31, blue: 0.96, alpha: 0.34), 0),
        (NSColor(calibratedRed: 0.49, green: 0.31, blue: 0.96, alpha: 0.11), 0.52),
        (NSColor(calibratedRed: 0.49, green: 0.31, blue: 0.96, alpha: 0), 1)
    )!
    glow.draw(in: glowPath, relativeCenterPosition: CGPoint(x: -0.06, y: 0.02))

    let orbitRect = glowRect.insetBy(dx: size * 0.075, dy: size * 0.075)
    let orbit = NSBezierPath(ovalIn: orbitRect)
    orbit.lineWidth = max(0.7, size * 0.003)
    NSColor(calibratedRed: 0.49, green: 0.31, blue: 0.96, alpha: 0.26).setStroke()
    orbit.stroke()
    NSGraphicsContext.restoreGraphicsState()

    path.lineWidth = max(0.7, size * 0.0022)
    NSColor.white.withAlphaComponent(0.58).setStroke()
    path.stroke()
}

private func drawPhotorealRemote(size: CGFloat, clipPath: NSBezierPath) {
    NSGraphicsContext.saveGraphicsState()
    clipPath.addClip()

    let context = NSGraphicsContext.current!.cgContext
    let center = CGPoint(x: size * 0.50, y: size * 0.50)
    context.translateBy(x: center.x, y: center.y)
    context.rotate(by: -8.5 * .pi / 180)
    context.translateBy(x: -center.x, y: -center.y)

    let width = size * 0.52
    let height = width * remoteImage.size.height / remoteImage.size.width
    let imageRect = CGRect(
        x: size * 0.50 - width / 2,
        y: size * 0.95 - height,
        width: width,
        height: height
    )

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.34)
    shadow.shadowBlurRadius = size * 0.032
    shadow.shadowOffset = CGSize(width: size * 0.018, height: -size * 0.022)
    shadow.set()
    remoteImage.draw(
        in: imageRect,
        from: .zero,
        operation: .sourceOver,
        fraction: 1,
        respectFlipped: true,
        hints: [.interpolation: NSImageInterpolation.high]
    )
    NSGraphicsContext.restoreGraphicsState()
}

private func drawSimplifiedRemote(size: CGFloat, clipPath: NSBezierPath) {
    NSGraphicsContext.saveGraphicsState()
    clipPath.addClip()

    let context = NSGraphicsContext.current!.cgContext
    let center = CGPoint(x: size * 0.50, y: size * 0.50)
    context.translateBy(x: center.x, y: center.y)
    context.rotate(by: -8.5 * .pi / 180)
    context.translateBy(x: -center.x, y: -center.y)

    let bodyRect = CGRect(x: size * 0.285, y: -size * 0.11, width: size * 0.43, height: size * 1.18)
    let body = NSBezierPath(roundedRect: bodyRect, xRadius: size * 0.065, yRadius: size * 0.065)
    let bodyGradient = NSGradient(colors: [
        NSColor(calibratedWhite: 0.99, alpha: 1),
        NSColor(calibratedWhite: 0.70, alpha: 1),
        NSColor(calibratedWhite: 0.93, alpha: 1)
    ])!

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowBlurRadius = size * 0.028
    shadow.shadowOffset = CGSize(width: size * 0.015, height: -size * 0.018)
    shadow.set()
    bodyGradient.draw(in: body, angle: 0)

    let outerPad = NSBezierPath(ovalIn: CGRect(x: size * 0.335, y: size * 0.395, width: size * 0.33, height: size * 0.33))
    NSColor(calibratedWhite: 0.08, alpha: 1).setFill()
    outerPad.fill()

    let innerPad = NSBezierPath(ovalIn: CGRect(x: size * 0.413, y: size * 0.473, width: size * 0.174, height: size * 0.174))
    NSColor(calibratedWhite: 0.13, alpha: 1).setFill()
    innerPad.fill()

    for centerX in [0.385, 0.615] {
        let button = NSBezierPath(ovalIn: CGRect(
            x: size * (centerX - 0.042),
            y: size * 0.77,
            width: size * 0.084,
            height: size * 0.084
        ))
        NSColor(calibratedWhite: 0.18, alpha: 1).setFill()
        button.fill()
    }

    NSGraphicsContext.restoreGraphicsState()
}

private func drawAccentRing(size: CGFloat, clipPath: NSBezierPath, simplified: Bool) {
    NSGraphicsContext.saveGraphicsState()
    clipPath.addClip()
    let ringRect = CGRect(
        x: size * 0.414,
        y: size * (simplified ? 0.472 : 0.357),
        width: size * 0.172,
        height: size * 0.172
    )
    let ring = NSBezierPath(ovalIn: ringRect)
    ring.lineWidth = max(0.9, size * 0.007)
    NSColor(calibratedRed: 0.49, green: 0.31, blue: 0.96, alpha: 0.92).setStroke()
    ring.stroke()
    NSGraphicsContext.restoreGraphicsState()
}

private func renderIcon(pixels: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("无法创建 \(pixels) px 位图")
    }

    bitmap.size = CGSize(width: pixels, height: pixels)
    let previousContext = NSGraphicsContext.current
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    defer { NSGraphicsContext.current = previousContext }

    NSColor.clear.setFill()
    CGRect(x: 0, y: 0, width: pixels, height: pixels).fill()
    NSGraphicsContext.current?.imageInterpolation = .high
    NSGraphicsContext.current?.shouldAntialias = true

    let size = CGFloat(pixels)
    let baseRect = CGRect(x: size * 0.082, y: size * 0.092, width: size * 0.836, height: size * 0.836)
    let basePath = squirclePath(in: baseRect)

    drawBase(size: size, path: basePath)
    let simplified = pixels <= 64
    if simplified {
        drawSimplifiedRemote(size: size, clipPath: basePath)
    } else {
        drawPhotorealRemote(size: size, clipPath: basePath)
    }
    drawAccentRing(size: size, clipPath: basePath, simplified: simplified)

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("无法编码 \(pixels) px PNG")
    }
    return data
}

var largestIcon: Data?
for spec in specs {
    let data = try renderIcon(pixels: spec.pixels)
    try data.write(to: outputURL.appendingPathComponent(spec.name), options: .atomic)
    if spec.pixels == 1024 { largestIcon = data }
}

if let largestIcon {
    let previewURL = projectURL.appendingPathComponent("Resources/DesignSources/app-icon-v3.png")
    try largestIcon.write(to: previewURL, options: .atomic)
}

print("Generated \(specs.count) app icon assets in \(outputURL.path)")
