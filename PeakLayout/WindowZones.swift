import AppKit

/// Ekran genişliğinin bir dilimi. Oran olarak saklanır; her monitörde aynı düzen çıkar.
struct WindowZone: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    /// 0...1 aralığında, ekranın solundan itibaren.
    var start: Double
    var end: Double

    var widthPercent: Int { Int(((end - start) * 100).rounded()) }

    /// Varsayılan bölge adları uygulamanın dilinde gösterilir; kullanıcının verdiği adlar olduğu gibi kalır.
    /// Eski sürümlerin Türkçe kaydettiği adlar da tanınır.
    var displayTitle: String {
        switch title {
        case "Left", "Sol": return String(localized: "Left")
        case "Center", "Orta": return String(localized: "Center")
        case "Right", "Sağ": return String(localized: "Right")
        case "Full screen", "Tam ekran": return String(localized: "Full screen")
        default: return title
        }
    }

    static func equalColumns(_ titles: [String]) -> [WindowZone] {
        let step = 1.0 / Double(titles.count)
        return titles.enumerated().map { index, title in
            WindowZone(title: title, start: Double(index) * step, end: Double(index + 1) * step)
        }
    }

    static var defaults: [WindowZone] { equalColumns(["Left", "Center", "Right"]) }
}

/// "Şu uygulama şu bölgede açılsın" kuralı. Uygulama kimliğiyle eşleşir, adı değişse de bozulmaz.
struct WindowRule: Codable, Identifiable, Equatable {
    var id = UUID()
    var bundleID: String
    var appName: String
    var zoneID: UUID
}

/// Bölgeleri ekranın kullanılabilir alanına (menü çubuğu ve Dock hariç) oturtur.
struct ZoneLayout {
    let screen: NSScreen
    /// Pencereler arası ve kenarlardaki boşluk.
    var gap: Double = 0

    /// Ekranın tamamı, Accessibility koordinatlarında.
    var screenRect: CGRect {
        let mainTop = (NSScreen.screens.first ?? screen).frame.maxY
        return CGRect(x: screen.frame.minX, y: mainTop - screen.frame.maxY,
                      width: screen.frame.width, height: screen.frame.height)
    }

    /// Accessibility koordinatları ana ekranın SOL ÜSTÜNDEN başlar ve aşağı doğru artar.
    func frame(for zone: WindowZone) -> CGRect {
        let visible = screen.visibleFrame
        let mainTop = (NSScreen.screens.first ?? screen).frame.maxY
        let width = visible.width * (zone.end - zone.start)
        return CGRect(
            x: visible.minX + visible.width * zone.start + gap / 2,
            y: mainTop - visible.maxY + gap / 2,
            width: width - gap,
            height: visible.height - gap
        )
    }
}
