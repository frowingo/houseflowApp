// Fause Bloom ebru texture: warped fractal Perlin noise banded into rose veins on a transparent
// background. Generates `BloomMarble` (iOS asset catalog) and Android's `bloom_marble`:
//   swiftc -O Design/Themes/BloomMarble.swift -o /tmp/bloom-marble
//   /tmp/bloom-marble FausCrew/Assets.xcassets/BloomMarble.imageset/BloomMarble@2x.png 390 844 2 4
//   /tmp/bloom-marble FausCrew/Assets.xcassets/BloomMarble.imageset/BloomMarble@3x.png 390 844 3 4
// usage: bloom-marble <out.png> <widthPt> <heightPt> <scale> <seed> [previewOut.png]
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
let out = args[1]
let wPt = Double(args[2])!, hPt = Double(args[3])!, scale = Double(args[4])!
let seed = UInt64(args[5])!
let preview = args.count > 6 ? args[6] : nil

struct Perlin {
    var p = [Int](repeating: 0, count: 512)
    init(seed: UInt64) {
        var perm = Array(0..<256)
        var s = seed &* 6364136223846793005 &+ 1442695040888963407
        for i in stride(from: 255, to: 0, by: -1) {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            let j = Int((s >> 33) % UInt64(i + 1))
            perm.swapAt(i, j)
        }
        for i in 0..<512 { p[i] = perm[i & 255] }
    }
    @inline(__always) func fade(_ t: Double) -> Double { t * t * t * (t * (t * 6 - 15) + 10) }
    @inline(__always) func grad(_ h: Int, _ x: Double, _ y: Double) -> Double {
        switch h & 7 {
        case 0: return x + y; case 1: return -x + y; case 2: return x - y; case 3: return -x - y
        case 4: return x; case 5: return -x; case 6: return y; default: return -y
        }
    }
    func noise(_ x: Double, _ y: Double) -> Double {
        let xi = Int(floor(x)) & 255, yi = Int(floor(y)) & 255
        let xf = x - floor(x), yf = y - floor(y)
        let u = fade(xf), v = fade(yf)
        let aa = p[p[xi] + yi], ab = p[p[xi] + yi + 1], ba = p[p[xi + 1] + yi], bb = p[p[xi + 1] + yi + 1]
        let x1 = grad(aa, xf, yf) + u * (grad(ba, xf - 1, yf) - grad(aa, xf, yf))
        let x2 = grad(ab, xf, yf - 1) + u * (grad(bb, xf - 1, yf - 1) - grad(ab, xf, yf - 1))
        return x1 + v * (x2 - x1)
    }
    /// feTurbulence-style fractalNoise, 0...1 centred on 0.5.
    func fbm(_ x: Double, _ y: Double, fx: Double, fy: Double, octaves: Int) -> Double {
        var sum = 0.0, amp = 1.0, mx = fx, my = fy
        for _ in 0..<octaves {
            sum += amp * noise(x * mx, y * my)
            amp *= 0.5; mx *= 2; my *= 2
        }
        return (sum + 1) / 2
    }
}

let warpX = Perlin(seed: seed &+ 11), warpY = Perlin(seed: seed &+ 29), base = Perlin(seed: seed)
let table: [Double] = [0, 0, 0, 0.6, 0.6, 0, 0, 0, 0, 0, 0, 0.5, 0.5, 0, 0, 0, 0]
@inline(__always) func lookup(_ a: Double) -> Double {
    let t = min(max(a, 0), 1) * Double(table.count - 1)
    let i = min(Int(t), table.count - 2)
    return table[i] + (t - Double(i)) * (table[i + 1] - table[i])
}
@inline(__always) func vein(_ x: Double, _ y: Double) -> Double {
    let dx = (warpX.fbm(x, y, fx: 0.0035, fy: 0.009, octaves: 2) - 0.5) * 200
    let dy = (warpY.fbm(x, y, fx: 0.0035, fy: 0.009, octaves: 2) - 0.5) * 200
    let b = base.fbm(x + dx, y + dy, fx: 0.003, fy: 0.010, octaves: 4)
    return lookup(1.6 * (b - 0.5) * 2.2 + 0.5)
}

let W = Int(wPt * scale), H = Int(hPt * scale)
var alpha = [Double](repeating: 0, count: W * H)
let ss = 2  // 2x2 supersampling for smooth vein edges
DispatchQueue.concurrentPerform(iterations: H) { py in
    alpha.withUnsafeMutableBufferPointer { buf in
        for px in 0..<W {
            var acc = 0.0
            for sy in 0..<ss { for sx in 0..<ss {
                let x = (Double(px) + (Double(sx) + 0.5) / Double(ss)) / scale
                let y = (Double(py) + (Double(sy) + 0.5) / Double(ss)) / scale
                acc += vein(x, y)
            } }
            buf[py * W + px] = acc / Double(ss * ss)
        }
    }
}

func write(_ path: String, w: Int, h: Int, pixel: (Int, Int) -> (UInt8, UInt8, UInt8, UInt8)) {
    var data = [UInt8](repeating: 0, count: w * h * 4)
    for y in 0..<h { for x in 0..<w {
        let (r, g, b, a) = pixel(x, y); let i = (y * w + x) * 4
        data[i] = r; data[i + 1] = g; data[i + 2] = b; data[i + 3] = a
    } }
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let img = ctx.makeImage()!
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil); CGImageDestinationFinalize(dest)
}

// Vein color #C98399, premultiplied.
let vr = 0.79, vg = 0.51, vb = 0.60
write(out, w: W, h: H) { x, y in
    let a = alpha[y * W + x]
    return (UInt8(vr * a * 255), UInt8(vg * a * 255), UInt8(vb * a * 255), UInt8(a * 255))
}
if let preview {
    // 1x preview over the pink base at the 32% the screens use.
    write(preview, w: Int(wPt), h: Int(hPt)) { x, y in
        let a = alpha[Int(Double(y) * scale) * W + Int(Double(x) * scale)] * 0.32
        let t = Double(y) / hPt
        let br = (0xFA + (0xF6 - 0xFA) * t) / 255, bg = (0xF0 + (0xE7 - 0xF0) * t) / 255, bb = (0xF3 + (0xEC - 0xF3) * t) / 255
        func mix(_ c: Double, _ v: Double) -> UInt8 { UInt8((c * (1 - a) + v * a) * 255) }
        return (mix(br, vr), mix(bg, vg), mix(bb, vb), 255)
    }
}
