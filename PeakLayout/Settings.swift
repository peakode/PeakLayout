import AppKit

/// Bir monitör için ölçü seti. Ada göre, bulunamazsa çözünürlüğe göre eşleşir.
struct DisplayProfile: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    /// `NSScreen.localizedName` içinde aranacak parça (boşsa sadece çözünürlük).
    var nameMatch: String
    var width: Int
    var height: Int
    /// MacBook'un kendi ekranı (ad dile göre değiştiği için ayrı bayrak).
    var builtIn = false
    var metrics = LayoutMetrics()

    func matches(_ screen: ScreenInfo) -> Bool {
        if builtIn { return screen.isBuiltIn }
        if !nameMatch.isEmpty { return screen.name.localizedCaseInsensitiveContains(nameMatch) }
        return Int(screen.size.width) == width && Int(screen.size.height) == height
    }

    static let defaults: [DisplayProfile] = [
        DisplayProfile(title: "Samsung Odyssey 49\"", nameMatch: "Odyssey G9", width: 5120, height: 1440),
        DisplayProfile(title: "Samsung 27\"", nameMatch: "", width: 2560, height: 1440),
        DisplayProfile(title: String(localized: "MacBook built-in display"), nameMatch: "", width: 1512, height: 982, builtIn: true),
    ]
}

struct AppSettings: Codable, Equatable {
    /// Sağ sütunda yukarıdan aşağı sabit duran öğeler (Finder adı). Ayarlar penceresinden seçilir.
    var pinned: [String] = []
    var profiles: [DisplayProfile] = DisplayProfile.defaults
    var moveDownloads = true
    var guardPinned = true
    /// Downloads taşıma bu tarihten sonra eklenenler için çalışır.
    var downloadsBaseline = Date()
    var assignments = SlotAssignments()
    /// İlk açılışta "oturum açılınca başlat" bir kez otomatik açılır; sonra kullanıcının seçimi korunur.
    var loginItemConfigured = false
    /// Pencere bölgeleri (ekranı dikey dilimlere böler) ve uygulama kuralları.
    var windowZonesEnabled = false
    var zones: [WindowZone] = WindowZone.defaults
    var windowRules: [WindowRule] = []
    /// Pencereler arası boşluk (point).
    var windowGap: Double = 0

    private static let key = "AppSettings.v1"

    init() {}

    // Sonradan eklenen alanlar eski kayıtları bozmasın diye eksik anahtarlar varsayılana düşer.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        pinned = try c.decodeIfPresent([String].self, forKey: .pinned) ?? d.pinned
        profiles = try c.decodeIfPresent([DisplayProfile].self, forKey: .profiles) ?? d.profiles
        moveDownloads = try c.decodeIfPresent(Bool.self, forKey: .moveDownloads) ?? d.moveDownloads
        guardPinned = try c.decodeIfPresent(Bool.self, forKey: .guardPinned) ?? d.guardPinned
        downloadsBaseline = try c.decodeIfPresent(Date.self, forKey: .downloadsBaseline) ?? d.downloadsBaseline
        assignments = try c.decodeIfPresent(SlotAssignments.self, forKey: .assignments) ?? d.assignments
        loginItemConfigured = try c.decodeIfPresent(Bool.self, forKey: .loginItemConfigured) ?? false
        windowZonesEnabled = try c.decodeIfPresent(Bool.self, forKey: .windowZonesEnabled) ?? d.windowZonesEnabled
        zones = try c.decodeIfPresent([WindowZone].self, forKey: .zones) ?? d.zones
        windowRules = try c.decodeIfPresent([WindowRule].self, forKey: .windowRules) ?? d.windowRules
        windowGap = try c.decodeIfPresent(Double.self, forKey: .windowGap) ?? d.windowGap
    }

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}

/// Konum yedekleri: her uygulamadan önce Finder'daki mevcut hal saklanır.
enum BackupStore {
    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("PeakLayout/Backups", isDirectory: true)
    }

    static func save(_ icons: [DesktopIcon]) {
        let fm = FileManager.default
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let url = directory.appendingPathComponent("\(stamp).json")
        guard let data = try? JSONEncoder().encode(icons) else { return }
        try? data.write(to: url)

        // Son 20 yedeği tut.
        let all = (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for old in all.sorted(by: { $0.lastPathComponent > $1.lastPathComponent }).dropFirst(20) {
            try? fm.removeItem(at: old)
        }
    }

    static func latest() -> [DesktopIcon]? {
        let all = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        let newest = all.filter { $0.pathExtension == "json" }.max { $0.lastPathComponent < $1.lastPathComponent }
        guard let newest, let data = try? Data(contentsOf: newest) else { return nil }
        return try? JSONDecoder().decode([DesktopIcon].self, from: data)
    }

    static func revealInFinder() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([directory])
    }
}
