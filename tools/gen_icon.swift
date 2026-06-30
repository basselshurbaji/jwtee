import AppKit

// Renders a 1024×1024 "geeky JWT" app icon: a glowing key (auth / signature)
// over a deep gradient, with the universal JWT prefix `eyJ` in monospace.

let S = 1024.0

func c(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> NSColor {
    NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

let cyan = c(34, 211, 238)
let magenta = c(251, 1, 91)
let purple = c(177, 75, 255)

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else { fatalError("no rep") }

let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = ctx
let full = NSRect(x: 0, y: 0, width: S, height: S)

// Background: rounded square with a vertical indigo → near-black gradient.
let margin = S * 0.07
let bgRect = NSRect(x: margin, y: margin, width: S - 2 * margin, height: S - 2 * margin)
let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: bgRect.width * 0.23, yRadius: bgRect.width * 0.23)
NSGraphicsContext.saveGraphicsState()
bgPath.addClip()
NSGradient(colors: [c(10, 9, 24), c(46, 26, 82)])!.draw(in: full, angle: 90)
// faint top sheen
NSGradient(colors: [c(255, 255, 255, 0.10), c(255, 255, 255, 0)])!
    .draw(in: NSRect(x: margin, y: S * 0.55, width: S - 2 * margin, height: S * 0.40), angle: -90)
NSGraphicsContext.restoreGraphicsState()

// subtle inner border
c(255, 255, 255, 0.08).setStroke()
bgPath.lineWidth = 3
bgPath.stroke()

// Fills a path with the cyan → magenta gradient, clipped, with a soft glow.
func fillKey(_ path: NSBezierPath) {
    NSGraphicsContext.saveGraphicsState()
    let glow = NSShadow()
    glow.shadowColor = cyan.withAlphaComponent(0.55)
    glow.shadowBlurRadius = 38
    glow.shadowOffset = .zero
    glow.set()
    path.addClip()
    NSGradient(colors: [magenta, cyan])!.draw(in: full, angle: 90)
    NSGraphicsContext.restoreGraphicsState()
}

// Key head (ring) — outer circle minus inner hole via even-odd.
let headCy = 648.0, outerR = 138.0, innerR = 70.0, cx = S / 2
let head = NSBezierPath()
head.windingRule = .evenOdd
head.appendOval(in: NSRect(x: cx - outerR, y: headCy - outerR, width: 2 * outerR, height: 2 * outerR))
head.appendOval(in: NSRect(x: cx - innerR, y: headCy - innerR, width: 2 * innerR, height: 2 * innerR))

// Key blade: shaft + two teeth (separate non-zero path, overlaps head cleanly).
let blade = NSBezierPath()
let shaftW = 66.0
blade.append(NSBezierPath(roundedRect: NSRect(x: cx - shaftW / 2, y: 250, width: shaftW, height: 360),
                          xRadius: shaftW / 2, yRadius: shaftW / 2))
blade.append(NSBezierPath(roundedRect: NSRect(x: cx + shaftW / 2 - 2, y: 300, width: 96, height: 50),
                          xRadius: 12, yRadius: 12))
blade.append(NSBezierPath(roundedRect: NSRect(x: cx + shaftW / 2 - 2, y: 405, width: 66, height: 46),
                          xRadius: 12, yRadius: 12))

fillKey(head)
fillKey(blade)

// Geeky tell: the universal JWT prefix in monospace, dim cyan, centered low.
let text = "eyJ" as NSString
let font = NSFont.monospacedSystemFont(ofSize: 150, weight: .heavy)
let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: cyan.withAlphaComponent(0.92),
]
let tsize = text.size(withAttributes: attrs)
text.draw(at: NSPoint(x: cx - tsize.width / 2, y: 132), withAttributes: attrs)

// Three JWT-part dots beneath the prefix (header • payload • signature).
for (i, col) in [magenta, purple, cyan].enumerated() {
    col.setFill()
    let r = 17.0, gap = 70.0
    let x = cx - gap + Double(i) * gap
    NSBezierPath(ovalIn: NSRect(x: x - r, y: 92, width: 2 * r, height: 2 * r)).fill()
}

// Write the master PNG.
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("no png") }
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
