import AppKit

let destination = CommandLine.arguments[1]
var chunks = Data()
func bigEndian(_ value: UInt32) -> Data {
    var value = value.bigEndian
    return withUnsafeBytes(of: &value) { Data($0) }
}
for (pixels, code) in [(16, "icp4"), (32, "icp5"), (64, "icp6"), (128, "ic07"), (256, "ic08"), (512, "ic09"), (1024, "ic10")] {
    let representation = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)
    let p = CGFloat(pixels)
    let rect = NSRect(x: p * 0.08, y: p * 0.08, width: p * 0.84, height: p * 0.84)
    NSColor(calibratedRed: 0.13, green: 0.37, blue: 0.91, alpha: 1).setFill()
    NSBezierPath(roundedRect: rect, xRadius: p * 0.19, yRadius: p * 0.19).fill()
    if let symbol = NSImage(systemSymbolName: "network", accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: p * 0.53, weight: .medium)) {
        let tinted = NSImage(size: symbol.size)
        tinted.lockFocus()
        symbol.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
        NSColor.white.setFill()
        NSRect(origin: .zero, size: symbol.size).fill(using: .sourceAtop)
        tinted.unlockFocus()
        tinted.draw(in: NSRect(x: p * 0.23, y: p * 0.23, width: p * 0.54, height: p * 0.54))
    }
    NSGraphicsContext.restoreGraphicsState()
    let png = representation.representation(using: .png, properties: [:])!
    chunks.append(Data(code.utf8))
    chunks.append(bigEndian(UInt32(png.count + 8)))
    chunks.append(png)
}
var icon = Data("icns".utf8)
icon.append(bigEndian(UInt32(chunks.count + 8)))
icon.append(chunks)
try icon.write(to: URL(fileURLWithPath: destination).appendingPathComponent("AppIcon.icns"))
