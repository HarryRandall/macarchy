// Renders the app icon from macarchy/resources/logo.svg. Used by tools/make-icon.sh.
import AppKit
// Usage: icon <logo.svg> <out.png> <pixels> <strokeWidth>
let args = CommandLine.arguments
var svg = try! String(contentsOfFile: args[1], encoding: .utf8)
svg = svg.replacingOccurrences(of: "stroke-width=\"7\"", with: "stroke-width=\"\(args[4])\"")
let logo = NSImage(data: svg.data(using: .utf8)!)!
let px = CGFloat(Int(args[3])!)
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(px), pixelsHigh: Int(px), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
// Apple's macOS icon grid: an 824/1024 body with a 185/1024 corner radius.
let inset = px * 100 / 1024, body = px * 824 / 1024
let tile = NSRect(x: inset, y: inset, width: body, height: body)
let path = NSBezierPath(roundedRect: tile, xRadius: px * 185 / 1024, yRadius: px * 185 / 1024)
NSGradient(starting: NSColor(srgbRed: 0.13, green: 0.14, blue: 0.16, alpha: 1), ending: NSColor(srgbRed: 0.06, green: 0.06, blue: 0.08, alpha: 1))!.draw(in: path, angle: -90)
NSColor(white: 1, alpha: 0.08).setStroke(); path.lineWidth = max(1, px / 512); path.stroke()
let width = body * 0.74, height = width * logo.size.height / logo.size.width
logo.draw(in: NSRect(x: (px - width) / 2, y: (px - height) / 2, width: width, height: height))
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
