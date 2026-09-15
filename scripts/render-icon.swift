// PeakLayout uygulama ikonunu çizer: swift scripts/render-icon.swift <çıktı.png>
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

let space = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
// Üst-sol orijin
ctx.translateBy(x: 0, y: size); ctx.scaleBy(x: 1, y: -1)

func linear(_ rect: CGRect, _ top: UInt32, _ bottom: UInt32, clip: CGPath) {
    ctx.saveGState()
    ctx.addPath(clip); ctx.clip()
    let g = CGGradient(colorsSpace: space, colors: [rgb(top), rgb(bottom)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: rect.midX, y: rect.minY), end: CGPoint(x: rect.midX, y: rect.maxY), options: [])
    ctx.restoreGState()
}

// macOS ikon ızgarası: 824'lük squircle, 100 px kenar boşluğu
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 12), blur: 28, color: rgb(0x000000, 0.35))
ctx.addPath(bodyPath); ctx.setFillColor(rgb(0x0E1F3F)); ctx.fillPath()
ctx.restoreGState()
linear(body, 0x24508F, 0x0A1733, clip: bodyPath)

// Hafif ufuk parıltısı
ctx.saveGState()
ctx.addPath(bodyPath); ctx.clip()
let glow = CGGradient(colorsSpace: space, colors: [rgb(0x6FB6FF, 0.28), rgb(0x6FB6FF, 0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 430, y: 330), startRadius: 0,
                       endCenter: CGPoint(x: 430, y: 330), endRadius: 420, options: [])
ctx.restoreGState()

// Izgara: 7 sütun × 7 satır
let columns = 7, rows = 7
let grid = body.insetBy(dx: 118, dy: 118)
let pitch = grid.width / CGFloat(columns)
let tile = pitch * 0.86
let radius = tile * 0.22

func tileRect(col: Int, row: Int) -> CGRect {
    CGRect(x: grid.minX + CGFloat(col) * pitch + (pitch - tile) / 2,
           y: grid.minY + CGFloat(row) * pitch + (pitch - tile) / 2, width: tile, height: tile)
}

func drawTile(_ r: CGRect, top: UInt32, bottom: UInt32, alpha: CGFloat = 1) {
    let p = CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.saveGState()
    ctx.setAlpha(alpha)
    ctx.setShadow(offset: CGSize(width: 0, height: 4), blur: 8, color: rgb(0x000000, 0.25))
    ctx.addPath(p); ctx.setFillColor(rgb(bottom)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState(); ctx.setAlpha(alpha)
    linear(r, top, bottom, clip: p)
    ctx.restoreGState()
}

// Sağ sütun: sabit klasörler (turuncu)
for row in 0..<rows {
    drawTile(tileRect(col: 6, row: row), top: 0xFFC25C, bottom: 0xFF7A3D)
}

// Sütun 5: boşluk — sadece silik yer tutucular
for row in 0..<rows {
    let r = tileRect(col: 5, row: row).insetBy(dx: tile * 0.34, dy: tile * 0.34)
    ctx.addPath(CGPath(ellipseIn: r, transform: nil)); ctx.setFillColor(rgb(0xFFFFFF, 0.10)); ctx.fillPath()
}

// Sütun 0–4: zirve. Dağ silüeti ızgara karelerine bölünür; kenar kareler eğimle kesilir.
func gp(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: grid.minX + x * pitch, y: grid.minY + y * pitch) }
func polygon(_ pts: [(CGFloat, CGFloat)]) -> CGPath {
    let path = CGMutablePath()
    path.addLines(between: pts.map { gp($0.0, $0.1) })
    path.closeSubpath()
    return path
}
let mountain = polygon([(0, 7.2), (0, 4.9), (2.5, 0.15), (3.55, 2.55), (4.1, 2.12), (5.0, 3.3), (5.0, 7.2)])
let snow = polygon([(-1, -1), (6, -1), (6, 1.95), (3.4, 1.95), (2.95, 1.55),
                    (2.5, 2.0), (2.05, 1.5), (1.55, 1.95), (-1, 1.95)])

for col in 0..<5 {
    for row in 0..<rows {
        let r = tileRect(col: col, row: row)
        let cell = CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
        // Gökyüzü: silik boş kare
        ctx.addPath(cell); ctx.setFillColor(rgb(0xFFFFFF, 0.05)); ctx.fillPath()

        ctx.saveGState()
        ctx.addPath(cell); ctx.clip()
        ctx.addPath(mountain); ctx.clip()
        let g = CGGradient(colorsSpace: space, colors: [rgb(0x8CC2FF), rgb(0x2F66C4)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(g, start: gp(0, 0.5), end: gp(0, 7), options: [])
        ctx.addPath(snow)
        ctx.setFillColor(rgb(0xF4F9FF)); ctx.fillPath()
        ctx.restoreGState()
    }
}

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("yazıldı:", out)
