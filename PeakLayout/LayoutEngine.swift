import CoreGraphics

/// Finder ızgarasının ölçüleri. Tüm değerler point cinsinden ve Finder'ın
/// `desktop position` koordinat sistemindedir (ana ekranın sol üstü = 0,0).
struct LayoutMetrics: Codable, Equatable {
    /// Sağdaki sabit sütunun ekranın sağ kenarına mesafesi.
    var rightInset: Double = 160
    /// İlk satırın y değeri.
    var topY: Double = 83
    /// Sütunlar arası yatay adım.
    var columnStep: Double = 108
    /// Satırlar arası dikey adım.
    var rowStep: Double = 126
    /// Son satırın alt kenara en az mesafesi (etiket payı).
    var bottomInset: Double = 100
    /// Soldaki son sütunun sol kenara en az mesafesi.
    var leftInset: Double = 60
    /// Sabit klasörlerle diğer dosyalar arasında boş bırakılan sütun sayısı.
    var gapColumns: Int = 1
}

/// Ekran boyutu + ölçülerden hücre koordinatlarını hesaplar. Yan etkisiz.
struct LayoutEngine {
    let screenSize: CGSize
    let metrics: LayoutMetrics

    var pinnedColumnX: Double { screenSize.width - metrics.rightInset }

    var rows: Int {
        let usable = screenSize.height - metrics.bottomInset - metrics.topY
        return max(1, Int((usable / metrics.rowStep).rounded(.down)) + 1)
    }

    /// Serbest dosyalar için sütun sayısı (boşluk sütunu hariç).
    var freeColumns: Int {
        let firstX = pinnedColumnX - Double(metrics.gapColumns + 1) * metrics.columnStep
        guard firstX >= metrics.leftInset else { return 0 }
        return Int(((firstX - metrics.leftInset) / metrics.columnStep).rounded(.down)) + 1
    }

    var capacity: Int { rows * freeColumns }

    func pinnedPosition(index: Int) -> CGPoint {
        CGPoint(x: pinnedColumnX, y: metrics.topY + Double(index) * metrics.rowStep)
    }

    /// Slot 0 boşluk sütununun solundaki sütunun tepesidir; aşağı dolar, sonra sola geçer.
    func slotPosition(_ slot: Int) -> CGPoint? {
        guard slot >= 0, slot < capacity else { return nil }
        let column = slot / rows
        let row = slot % rows
        let x = pinnedColumnX - Double(metrics.gapColumns + 1 + column) * metrics.columnStep
        return CGPoint(x: x, y: metrics.topY + Double(row) * metrics.rowStep)
    }
}

/// Dosya → slot eşlemesi. "Sona ekle" kuralı: yeni gelen, en büyük slotun bir sonrasına gider;
/// silinenlerin boşluğu `compact()` çağrılana kadar kalır.
struct SlotAssignments: Codable, Equatable {
    private(set) var slots: [String: Int] = [:]

    var isEmpty: Bool { slots.isEmpty }

    /// `presentKeys` sıralıdır; ilk kurulumda bu sıra slot sırası olur.
    /// Artık olmayan anahtarlar silinir, yeni anahtarlar sona eklenir.
    mutating func sync(presentKeys: [String]) {
        let present = Set(presentKeys)
        slots = slots.filter { present.contains($0.key) }
        var next = (slots.values.max() ?? -1) + 1
        for key in presentKeys where slots[key] == nil {
            slots[key] = next
            next += 1
        }
    }

    /// Mevcut sırayı koruyarak boşlukları kapatır.
    mutating func compact() {
        let ordered = slots.sorted { $0.value < $1.value }.map(\.key)
        slots = Dictionary(uniqueKeysWithValues: ordered.enumerated().map { ($1, $0) })
    }

    subscript(key: String) -> Int? { slots[key] }
}
