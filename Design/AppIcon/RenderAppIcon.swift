// Renders an app icon SVG from this folder to an opaque PNG. AppKit's SVG support skips filters,
// so the `<g filter="url(#shadow)">` group (the mark) is drawn separately with the icons' drop
// shadow (dy 16, σ 18, #1B2236 at 38% on a 1024 canvas):
//   swiftc -O Design/AppIcon/RenderAppIcon.swift -o /tmp/render-app-icon
//   /tmp/render-app-icon Design/AppIcon/FausCrew-AppIcon-Bloom.svg \
//       FausCrew/Assets.xcassets/AppIconBloom.appiconset/appstore-bloom.png 1024
// usage: render-app-icon <icon.svg> <out.png> <pixels>
import AppKit

let args = CommandLine.arguments
let svg = try! String(contentsOfFile: args[1], encoding: .utf8)
let px = Int(args[3])!
let k = CGFloat(px) / 1024

// Split the shadowed mark from the rest of the icon.
let open = svg.range(of: "  <g filter=\"url(#shadow)\">")!
let close = svg.range(of: "\n  </g>\n", range: open.upperBound..<svg.endIndex)!
let mark = String(svg[open.lowerBound..<close.upperBound])
let background = svg.replacingOccurrences(of: mark, with: "")
let header = String(svg[..<svg.range(of: "<defs>")!.lowerBound])
let foreground = header + mark.replacingOccurrences(of: " filter=\"url(#shadow)\"", with: "") + "</svg>\n"

func image(_ source: String) -> NSImage { NSImage(data: Data(source.utf8))! }

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
let rect = NSRect(x: 0, y: 0, width: px, height: px)
image(background).draw(in: rect)
context.setShadow(offset: CGSize(width: 0, height: -16 * k), blur: 36 * k,
                  color: CGColor(srgbRed: 0x1B / 255, green: 0x22 / 255, blue: 0x36 / 255, alpha: 0.38))
context.beginTransparencyLayer(auxiliaryInfo: nil)
image(foreground).draw(in: rect)
context.endTransparencyLayer()

let png = NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: args[2]))
