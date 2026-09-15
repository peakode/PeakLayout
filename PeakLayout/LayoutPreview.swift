import SwiftUI

/// Ekranın küçültülmüş hali: sabit sütun, boşluk sütunu ve dolu slotlar.
struct LayoutPreview: View {
    let engine: LayoutEngine
    let pinned: [String]
    let loose: [DesktopItem]
    let assignments: SlotAssignments
    var showLabels = false

    var body: some View {
        GeometryReader { geo in
            let size = engine.screenSize
            let scale = min(geo.size.width / size.width, geo.size.height / size.height)
            let canvas = CGSize(width: size.width * scale, height: size.height * scale)
            let m = engine.metrics
            let cell = CGSize(width: m.columnStep * scale * 0.86, height: m.rowStep * scale * 0.8)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))

                // Boşluk sütunu
                ForEach(0..<m.gapColumns, id: \.self) { g in
                    let x = engine.pinnedColumnX - Double(g + 1) * m.columnStep
                    Rectangle()
                        .fill(Color.secondary.opacity(0.06))
                        .frame(width: m.columnStep * scale, height: canvas.height)
                        .offset(x: (x - m.columnStep / 2) * scale)
                }

                ForEach(Array(pinned.enumerated()), id: \.offset) { index, name in
                    cellView(name: name, at: engine.pinnedPosition(index: index), color: .accentColor,
                             scale: scale, cell: cell)
                }

                ForEach(loose, id: \.key) { item in
                    if let slot = assignments[item.key], let p = engine.slotPosition(slot) {
                        cellView(name: item.name, at: p, color: .gray, scale: scale, cell: cell)
                    }
                }
            }
            .frame(width: canvas.width, height: canvas.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func cellView(name: String, at point: CGPoint, color: Color, scale: Double, cell: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color.opacity(0.55))
            .overlay {
                if showLabels {
                    Text(name)
                        .font(.system(size: 9))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(2)
                }
            }
            .frame(width: cell.width, height: cell.height)
            .help(name)
            .offset(x: point.x * scale - cell.width / 2, y: point.y * scale - cell.height / 2)
    }
}
