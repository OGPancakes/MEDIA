import AppKit
import CoreGraphics
import ImageIO
import Foundation

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    fputs("Usage: generate_app_icon.swift <input> <output>\n", stderr)
    exit(1)
}

let inputURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments[2])

guard let sourceImage = NSImage(contentsOf: inputURL) else {
    fputs("Could not read source image at \(inputURL.path)\n", stderr)
    exit(1)
}

let canvasSize = CGSize(width: 1024, height: 1024)
let outputImage = NSImage(size: canvasSize)

outputImage.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else {
    fputs("Could not create graphics context\n", stderr)
    exit(1)
}

context.interpolationQuality = .high

let colorSpace = CGColorSpaceCreateDeviceRGB()
let colors = [NSColor(calibratedRed: 0.02, green: 0.05, blue: 0.12, alpha: 1).cgColor,
              NSColor(calibratedRed: 0.08, green: 0.17, blue: 0.36, alpha: 1).cgColor,
              NSColor(calibratedRed: 0.68, green: 0.08, blue: 0.17, alpha: 1).cgColor] as CFArray
let locations: [CGFloat] = [0.0, 0.58, 1.0]
let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations)!
context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 1024, y: 0), options: [])

context.setFillColor(NSColor(calibratedWhite: 1, alpha: 0.08).cgColor)
context.fillEllipse(in: CGRect(x: 650, y: 700, width: 320, height: 320))

context.setFillColor(NSColor(calibratedWhite: 1, alpha: 0.05).cgColor)
context.fillEllipse(in: CGRect(x: 60, y: 60, width: 260, height: 260))

let frameRect = CGRect(x: 132, y: 132, width: 760, height: 760)
let framePath = NSBezierPath(roundedRect: frameRect, xRadius: 180, yRadius: 180)
NSColor(calibratedWhite: 1, alpha: 0.1).setFill()
framePath.fill()

context.setShadow(offset: CGSize(width: 0, height: -18), blur: 36, color: NSColor(calibratedWhite: 0, alpha: 0.35).cgColor)

let logoMaxWidth: CGFloat = 670
let logoMaxHeight: CGFloat = 670
let sourceSize = sourceImage.size
let scale = min(logoMaxWidth / sourceSize.width, logoMaxHeight / sourceSize.height)
let logoSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
let logoRect = CGRect(
    x: (canvasSize.width - logoSize.width) / 2,
    y: (canvasSize.height - logoSize.height) / 2 - 18,
    width: logoSize.width,
    height: logoSize.height
)

sourceImage.draw(in: logoRect, from: .zero, operation: .sourceOver, fraction: 1)

outputImage.unlockFocus()

guard
    let tiffData = outputImage.tiffRepresentation,
    let bitmapRep = NSBitmapImageRep(data: tiffData),
    let pngData = bitmapRep.representation(using: .png, properties: [:])
else {
    fputs("Could not encode PNG\n", stderr)
    exit(1)
}

try pngData.write(to: outputURL)
print("Wrote \(outputURL.path)")
