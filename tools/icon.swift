// Renders the app icon from macarchy/resources/logo.svg. Used by tools/make-icon.sh.
// Usage: icon <logo.svg> <out.png> <pixels> <strokeWidth>
import AppKit

let args = CommandLine.arguments
var svg = try String(contentsOfFile: args[1], encoding: .utf8)
// A bright outline reads against the dark tile; the hairline original does not.
svg = svg.replacingOccurrences(of: "stroke-width=\"7\"", with: "stroke-width=\"\(args[4])\"")
svg = svg.replacingOccurrences(of: "#4A90DB", with: "#6CB4FF")
let px = CGFloat(Int(args[3])!)
// Larger, wider-spaced window lights. At large sizes they fit the title bar
// strip the outline leaves open; small icons enlarge them over the lines,
// because three distinct dots matter more there than the exact spacing.
let small = px <= 256
let radius = small ? 15.0 : 9.5
let centres = small ? ["88", "120", "152"] : ["84.2", "108.2", "132.2"]
for (old, new) in zip(["85.2", "104.2", "123.2"], centres) {
    svg = svg.replacingOccurrences(of: "cx=\"\(old)\"", with: "cx=\"\(new)\"")
}
svg = svg.replacingOccurrences(of: "r=\"6.5\"", with: "r=\"\(radius)\"")
let logo = NSImage(data: Data(svg.utf8))!

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(px), pixelsHigh: Int(px), bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Apple's macOS icon grid: an 824/1024 body with a 185/1024 corner radius.
let inset = px * 100 / 1024
let body = px * 824 / 1024
let tile = NSRect(x: inset, y: inset, width: body, height: body)
let shape = NSBezierPath(roundedRect: tile, xRadius: px * 185 / 1024, yRadius: px * 185 / 1024)
let top = NSColor(srgbRed: 34 / 255, green: 36 / 255, blue: 42 / 255, alpha: 1)
let bottom = NSColor(srgbRed: 12 / 255, green: 12 / 255, blue: 16 / 255, alpha: 1)
NSGradient(starting: top, ending: bottom)!.draw(in: shape, angle: -90)

let width = body * 0.84
let height = width * logo.size.height / logo.size.width
let rect = NSRect(x: (px - width) / 2, y: (px - height) / 2, width: width, height: height)
NSGraphicsContext.saveGraphicsState()
shape.addClip()
let glow = NSShadow()
glow.shadowColor = NSColor(srgbRed: 80 / 255, green: 160 / 255, blue: 1, alpha: 0.8)
glow.shadowBlurRadius = px * 18 / 512
glow.set()
logo.draw(in: rect)
NSGraphicsContext.restoreGraphicsState()
logo.draw(in: rect)

NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
