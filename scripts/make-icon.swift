import AppKit
import Foundation
// Original vector artwork, rendered locally. No external image or font assets.
let destination = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = destination.appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
func render(_ pixels: Int) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    let frame = NSRect(x: 74, y: 74, width: 876, height: 876)
    let shape = NSBezierPath(roundedRect: frame, xRadius: 198, yRadius: 198)
    let shadow = NSShadow()
    shadow.shadowBlurRadius = 40
    shadow.shadowOffset = NSSize(width: 0, height: -16)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.set()
    NSColor(calibratedWhite: 0.93, alpha: 1).setFill()
    shape.fill()
    NSShadow().set()
    NSGradient(starting: NSColor(calibratedRed: 0.99, green: 0.99, blue: 1, alpha: 1),
               ending: NSColor(calibratedRed: 0.79, green: 0.85, blue: 0.94, alpha: 1))!.draw(in: shape, angle: -80)
    NSColor.white.withAlphaComponent(0.95).setStroke()
    shape.lineWidth = 4
    shape.stroke()
    let key = NSBezierPath(roundedRect: NSRect(x: 245, y: 240, width: 534, height: 534), xRadius: 115, yRadius: 115)
    NSColor.white.withAlphaComponent(0.75).setFill()
    key.fill()
    NSColor(calibratedRed: 0.47, green: 0.57, blue: 0.73, alpha: 0.23).setStroke()
    key.lineWidth = 4
    key.stroke()
    NSColor(calibratedRed: 0.14, green: 0.31, blue: 0.53, alpha: 1).setFill()
    let pin = NSBezierPath()
    pin.move(to: NSPoint(x: 425, y: 666))
    pin.line(to: NSPoint(x: 599, y: 666))
    pin.line(to: NSPoint(x: 586, y: 612))
    pin.line(to: NSPoint(x: 576, y: 505))
    pin.line(to: NSPoint(x: 632, y: 448))
    pin.curve(to: NSPoint(x: 620, y: 422), controlPoint1: NSPoint(x: 642, y: 432), controlPoint2: NSPoint(x: 634, y: 422))
    pin.line(to: NSPoint(x: 527, y: 422))
    pin.line(to: NSPoint(x: 512, y: 310))
    pin.line(to: NSPoint(x: 497, y: 422))
    pin.line(to: NSPoint(x: 404, y: 422))
    pin.curve(to: NSPoint(x: 392, y: 448), controlPoint1: NSPoint(x: 390, y: 422), controlPoint2: NSPoint(x: 382, y: 432))
    pin.line(to: NSPoint(x: 448, y: 505))
    pin.line(to: NSPoint(x: 438, y: 612))
    pin.close()
    pin.fill()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}
for size in [16, 32, 128, 256, 512] {
    try render(size).write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size * 2).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", destination.appendingPathComponent("AppIcon.icns").path]
try task.run()
task.waitUntilExit()
guard task.terminationStatus == 0 else { exit(1) }
