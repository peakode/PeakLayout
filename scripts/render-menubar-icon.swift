// Menü çubuğu şablon ikonu (siyah + saydam; macOS açık/koyu temaya göre boyar).
// swift scripts/render-menubar-icon.swift <klasör>
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let base: CGFloat = 18

func render(scale: CGFloat) -> Data {
    let px = Int(base * scale)
    let space = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: CGFloat(px)); ctx.scaleBy(x: scale, y: -scale)
    let black = CGColor(red: 0, green: 0, blue: 0, alpha: 1)

    // 18 pt: 3 sütun zirve + boşluk + sabit sütun, 4 satır. Tüm kenarlar tam sayı → 1x ekranda da keskin.
    let pitch: CGFloat = 4, tile: CGFloat = 3, corner: CGFloat = 0.5
    let left: CGFloat = 0, top: CGFloat = 2
    let pinnedX: CGFloat = left + 3 * pitch + 2
    func cell(x: CGFloat, row: Int) -> CGRect {
        CGRect(x: x, y: top + CGFloat(row) * pitch, width: tile, height: tile)
    }

    for row in 0..<4 {
        ctx.addPath(CGPath(roundedRect: cell(x: pinnedX, row: row), cornerWidth: corner, cornerHeight: corner, transform: nil))
    }
    ctx.setFillColor(black); ctx.fillPath()

    let apex = CGPoint(x: left + 1.5 * pitch - 0.5, y: top - 0.5)
    let mountain = CGMutablePath()
    mountain.addLines(between: [
        CGPoint(x: left - 1, y: 18), CGPoint(x: left - 1, y: top + 2.2 * pitch),
        apex,
        CGPoint(x: left + 3 * pitch, y: top + 2.2 * pitch), CGPoint(x: left + 3 * pitch, y: 18),
    ])
    mountain.closeSubpath()
    for col in 0..<3 {
        for row in 0..<4 {
            ctx.saveGState()
            let r = cell(x: left + CGFloat(col) * pitch, row: row)
            ctx.addPath(CGPath(roundedRect: r, cornerWidth: corner, cornerHeight: corner, transform: nil))
            ctx.clip()
            ctx.addPath(mountain); ctx.setFillColor(black); ctx.fillPath()
            ctx.restoreGState()
        }
    }

    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    return rep.representation(using: .png, properties: [:])!
}

for scale in [1, 2, 3] as [CGFloat] {
    let name = scale == 1 ? "menubar.png" : "menubar@\(Int(scale))x.png"
    try! render(scale: scale).write(to: URL(fileURLWithPath: outDir).appendingPathComponent(name))
}
print("yazıldı:", outDir)
