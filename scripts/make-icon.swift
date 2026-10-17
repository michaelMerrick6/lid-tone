import AppKit
import Foundation

let destination = CommandLine.arguments[1]
let temporary = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".iconset")
try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: temporary) }
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let p = CGFloat(pixels)
        NSColor(calibratedRed: 0.90, green: 0.89, blue: 0.83, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: p, height: p), xRadius: p * 0.22, yRadius: p * 0.22).fill()
        let door = NSBezierPath(roundedRect: NSRect(x: p * 0.24, y: p * 0.20, width: p * 0.47, height: p * 0.62), xRadius: p * 0.035, yRadius: p * 0.035)
        NSColor(calibratedRed: 0.30, green: 0.39, blue: 0.29, alpha: 1).setFill(); door.fill()
        NSColor(calibratedRed: 0.89, green: 0.77, blue: 0.52, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: p * 0.59, y: p * 0.48, width: p * 0.045, height: p * 0.045)).fill()
        let base = NSBezierPath(roundedRect: NSRect(x: p * 0.13, y: p * 0.14, width: p * 0.74, height: p * 0.055), xRadius: p * 0.02, yRadius: p * 0.02)
        base.fill()
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: temporary.appendingPathComponent(name))
    }
}
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", temporary.path, "-o", destination]
try task.run(); task.waitUntilExit()
exit(task.terminationStatus)
