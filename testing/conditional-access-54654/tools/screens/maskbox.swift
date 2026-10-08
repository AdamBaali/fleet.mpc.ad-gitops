import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
// usage: maskbox file.png x y w h [x y w h ...]   (top-left origin, pixels)
let a = CommandLine.arguments; let p = a[1]
let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: p) as CFURL, nil)!
let im = CGImageSourceCreateImageAtIndex(src, 0, nil)!
let w = im.width, h = im.height
let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(im, in: CGRect(x: 0, y: 0, width: w, height: h))
ctx.setFillColor(CGColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1))
var i = 2
while i + 3 < a.count { ctx.fill(CGRect(x: Double(a[i])!, y: Double(h) - Double(a[i+1])! - Double(a[i+3])!, width: Double(a[i+2])!, height: Double(a[i+3])!)); i += 4 }
let out = CGImageDestinationCreateWithURL(URL(fileURLWithPath: p) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(out, ctx.makeImage()!, nil); CGImageDestinationFinalize(out)
