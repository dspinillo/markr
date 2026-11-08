import AppKit

func renderIcon(size: Int) -> NSBitmapImageRep {
    let s = CGFloat(size)
    let scale = s / 1024.0

    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    let rect = CGRect(x: 100 * scale, y: 100 * scale, width: 824 * scale, height: 824 * scale)
    let cornerRadius = 185 * scale
    let squirclePath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -18 * scale),
        blur: 36 * scale,
        color: NSColor(calibratedWhite: 0, alpha: 0.48).cgColor
    )
    ctx.addPath(squirclePath)
    ctx.setFillColor(NSColor(calibratedRed: 0.04, green: 0.045, blue: 0.055, alpha: 1.0).cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        NSColor(calibratedRed: 0.11, green: 0.13, blue: 0.15, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.035, green: 0.04, blue: 0.05, alpha: 1.0).cgColor
    ] as CFArray
    let locations: [CGFloat] = [0.0, 1.0]
    if let grad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: locations) {
        ctx.drawRadialGradient(
            grad,
            startCenter: CGPoint(x: 340 * scale, y: 740 * scale),
            startRadius: 20 * scale,
            endCenter: CGPoint(x: 512 * scale, y: 512 * scale),
            endRadius: 620 * scale,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }

    ctx.addPath(squirclePath)
    ctx.setStrokeColor(NSColor(calibratedWhite: 1.0, alpha: 0.14).cgColor)
    ctx.setLineWidth(6 * scale)
    ctx.strokePath()

    let mutedBarColor = NSColor(calibratedRed: 0.20, green: 0.22, blue: 0.25, alpha: 1.0).cgColor
    let emerald = NSColor(calibratedRed: 0.349, green: 0.831, blue: 0.600, alpha: 1.0)
    let emeraldFill = NSColor(calibratedRed: 0.349, green: 0.831, blue: 0.600, alpha: 0.22).cgColor

    let topLine = CGPath(
        roundedRect: CGRect(x: 260 * scale, y: 670 * scale, width: 390 * scale, height: 56 * scale),
        cornerWidth: 28 * scale,
        cornerHeight: 28 * scale,
        transform: nil
    )
    ctx.addPath(topLine)
    ctx.setFillColor(mutedBarColor)
    ctx.fillPath()

    let bottomLine = CGPath(
        roundedRect: CGRect(x: 260 * scale, y: 298 * scale, width: 290 * scale, height: 56 * scale),
        cornerWidth: 28 * scale,
        cornerHeight: 28 * scale,
        transform: nil
    )
    ctx.addPath(bottomLine)
    ctx.setFillColor(mutedBarColor)
    ctx.fillPath()

    let hlBoxRect = CGRect(x: 236 * scale, y: 422 * scale, width: 552 * scale, height: 180 * scale)
    let hlBoxPath = CGPath(
        roundedRect: hlBoxRect,
        cornerWidth: 42 * scale,
        cornerHeight: 42 * scale,
        transform: nil
    )
    ctx.addPath(hlBoxPath)
    ctx.setFillColor(emeraldFill)
    ctx.fillPath()

    ctx.addPath(hlBoxPath)
    ctx.setStrokeColor(emerald.cgColor)
    ctx.setLineWidth(18 * scale)
    ctx.strokePath()

    let midBar = CGPath(
        roundedRect: CGRect(x: 296 * scale, y: 482 * scale, width: 432 * scale, height: 60 * scale),
        cornerWidth: 30 * scale,
        cornerHeight: 30 * scale,
        transform: nil
    )
    ctx.addPath(midBar)
    ctx.setFillColor(emerald.cgColor)
    ctx.fillPath()

    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.setLineWidth(26 * scale)
    ctx.setLineCap(.round)

    let leftX = 236 * scale
    ctx.move(to: CGPoint(x: leftX, y: 422 * scale))
    ctx.addLine(to: CGPoint(x: leftX, y: 656 * scale))
    ctx.strokePath()

    let knobR = 38 * scale
    ctx.fillEllipse(in: CGRect(x: leftX - knobR, y: 664 * scale - knobR, width: knobR * 2, height: knobR * 2))

    let rightX = 788 * scale
    ctx.move(to: CGPoint(x: rightX, y: 602 * scale))
    ctx.addLine(to: CGPoint(x: rightX, y: 368 * scale))
    ctx.strokePath()

    ctx.fillEllipse(in: CGRect(x: rightX - knobR, y: 360 * scale - knobR, width: knobR * 2, height: knobR * 2))

    ctx.restoreGState()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let projectDir = FileManager.default.currentDirectoryPath
let iconsetDir = "\(projectDir)/build/AppIcon.iconset"
let resourcesDir = "\(projectDir)/Resources"
let icnsPath = "\(resourcesDir)/AppIcon.icns"

let fm = FileManager.default
try? fm.removeItem(atPath: iconsetDir)
try fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)
try fm.createDirectory(atPath: resourcesDir, withIntermediateDirectories: true)

let specs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (filename, px) in specs {
    let rep = renderIcon(size: px)
    if let pngData = rep.representation(using: .png, properties: [:]) {
        try pngData.write(to: URL(fileURLWithPath: "\(iconsetDir)/\(filename)"))
    }
}

let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconsetDir, "-o", icnsPath]
try proc.run()
proc.waitUntilExit()
try? fm.removeItem(atPath: iconsetDir)
print("✅ Gerado: \(icnsPath)")
