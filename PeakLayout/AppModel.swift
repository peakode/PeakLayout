import AppKit
import ServiceManagement
import os

private let log = Logger(subsystem: "com.peakode.PeakLayout", category: "layout")

@MainActor
final class AppModel: ObservableObject {
    @Published var settings: AppSettings {
        didSet { if settings != oldValue { settings.save() } }
    }
    @Published private(set) var screen: ScreenInfo?
    @Published private(set) var icons: [DesktopIcon] = []
    @Published private(set) var looseItems: [DesktopItem] = []
    @Published private(set) var lastApplied: Date?
    @Published private(set) var statusMessage = "Hazır" {
        didSet { log.info("\(self.statusMessage, privacy: .public)") }
    }
    @Published private(set) var lastError: String? {
        didSet { if let lastError { log.error("\(lastError, privacy: .public)") } }
    }
    @Published private(set) var overflowCount = 0
    @Published var isPaused = false

    private var desktopWatcher: DirectoryWatcher?
    private var downloadsMover: DownloadsMover?
    private var displayMonitor: DisplayMonitor?
    private var guardTimer: Timer?
    private var lastFileSystemNames: Set<String> = []
    private var retryCount = 0
    private var isApplying = false

    init() {
        settings = AppSettings.load()
        screen = ScreenInfo.main()
    }

    var activeProfile: DisplayProfile? {
        guard let screen else { return nil }
        return settings.profiles.first { $0.matches(screen) }
    }

    var activeMetrics: LayoutMetrics { activeProfile?.metrics ?? LayoutMetrics() }

    var engine: LayoutEngine? {
        screen.map { LayoutEngine(screenSize: $0.size, metrics: activeMetrics) }
    }

    // MARK: - Yaşam döngüsü

    func start() {
        let watcher = DirectoryWatcher(url: DesktopScanner.desktopURL) { [weak self] in self?.desktopChanged() }
        watcher.start()
        desktopWatcher = watcher

        let monitor = DisplayMonitor { [weak self] in self?.applyLayout(reason: "Ekran değişti") }
        monitor.start()
        displayMonitor = monitor

        updateDownloadsMover()
        updateGuardTimer()

        if !settings.loginItemConfigured {
            launchAtLogin = true
            settings.loginItemConfigured = true
        }
        log.info("Oturum açılınca başlat: \(String(describing: SMAppService.mainApp.status.rawValue), privacy: .public)")

        lastFileSystemNames = DesktopScanner.fileSystemNames()
        applyLayout(reason: "Başlangıç")
    }

    func updateDownloadsMover() {
        downloadsMover?.stop()
        downloadsMover = nil
        guard settings.moveDownloads else { return }
        let mover = DownloadsMover(
            baseline: settings.downloadsBaseline,
            onMoved: { [weak self] names in
                self?.statusMessage = "Downloads'tan taşındı: \(names.joined(separator: ", "))"
            },
            onError: { [weak self] message in self?.lastError = message }
        )
        mover.start()
        downloadsMover = mover
    }

    func updateGuardTimer() {
        guardTimer?.invalidate()
        guardTimer = nil
        guard settings.guardPinned else { return }
        guardTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyLayout(reason: "Sabit klasör kontrolü", pinnedOnly: true) }
        }
    }

    private func desktopChanged() {
        let names = DesktopScanner.fileSystemNames()
        // Finder'ın .DS_Store yazmaları da olay üretir; sadece dosya listesi değişince uygula.
        guard names != lastFileSystemNames else { return }
        lastFileSystemNames = names
        applyLayout(reason: "Masaüstü değişti")
    }

    // MARK: - Yerleşim

    func applyLayout(reason: String, pinnedOnly: Bool = false) {
        guard !isPaused, !isApplying else { return }
        isApplying = true
        defer { isApplying = false }

        screen = ScreenInfo.main()
        guard let engine else { return }

        do {
            let current = try FinderBridge.readIcons()
            icons = current
            lastError = nil

            let pinnedSet = Set(settings.pinned)
            let loose = DesktopScanner.items(finderNames: current.map(\.name).filter { !pinnedSet.contains($0) })
                .sorted { ($0.addedDate ?? .distantFuture) < ($1.addedDate ?? .distantFuture) }
            looseItems = loose
            settings.assignments.sync(presentKeys: loose.map(\.key))

            var targets: [DesktopIcon] = []
            for (index, name) in settings.pinned.enumerated() {
                let p = engine.pinnedPosition(index: index)
                targets.append(DesktopIcon(name: name, x: p.x, y: p.y))
            }
            var overflow = 0
            if !pinnedOnly {
                for item in loose {
                    guard let slot = settings.assignments[item.key] else { continue }
                    guard let p = engine.slotPosition(slot) else { overflow += 1; continue }
                    targets.append(DesktopIcon(name: item.name, x: p.x, y: p.y))
                }
                overflowCount = overflow
            }

            let byName = Dictionary(current.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
            let moves = targets.filter { target in
                guard let now = byName[target.name] else { return false }
                return abs(now.x - target.x) > 2 || abs(now.y - target.y) > 2
            }
            guard !moves.isEmpty else {
                if !pinnedOnly { statusMessage = "\(reason): yerleşim zaten doğru" }
                return
            }

            BackupStore.save(current)
            let failed = try FinderBridge.apply(moves)
            lastApplied = Date()
            statusMessage = "\(reason): \(moves.count - failed.count) öğe yerleştirildi"
            if !failed.isEmpty { scheduleRetry(failed: failed) } else { retryCount = 0 }
        } catch {
            lastError = Self.describe(error)
        }
    }

    /// Finder yeni dosyayı birkaç saniye geç tanıyabilir.
    private func scheduleRetry(failed: [String]) {
        guard retryCount < 3 else {
            lastError = "Yerleştirilemedi: \(failed.joined(separator: ", "))"
            retryCount = 0
            return
        }
        retryCount += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.applyLayout(reason: "Tekrar deneme")
        }
    }

    func compactSlots() {
        settings.assignments.compact()
        applyLayout(reason: "Boşluklar kapatıldı")
    }

    func restoreLastBackup() {
        guard let backup = BackupStore.latest() else {
            lastError = "Yedek bulunamadı"
            return
        }
        isPaused = true
        do {
            try FinderBridge.apply(backup)
            statusMessage = "Son yedek geri yüklendi, otomatik düzen duraklatıldı"
        } catch {
            lastError = Self.describe(error)
        }
    }

    /// Sabit öğelerin şu anki konumlarından aktif profilin ölçülerini çıkarır.
    func calibrateFromCurrentPositions() {
        guard let screen else { return }
        do {
            let current = try FinderBridge.readIcons()
            let byName = Dictionary(current.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
            let pinned = settings.pinned.compactMap { byName[$0] }
            guard pinned.count >= 2, let first = pinned.first, let last = pinned.last else {
                lastError = "Kalibrasyon için en az 2 sabit öğe masaüstünde olmalı"
                return
            }
            var metrics = activeMetrics
            metrics.rightInset = screen.size.width - first.x
            metrics.topY = first.y
            metrics.rowStep = ((last.y - first.y) / Double(pinned.count - 1)).rounded()

            if let index = settings.profiles.firstIndex(where: { $0.matches(screen) }) {
                settings.profiles[index].metrics = metrics
            } else {
                settings.profiles.append(DisplayProfile(
                    title: screen.name, nameMatch: "",
                    width: Int(screen.size.width), height: Int(screen.size.height), metrics: metrics
                ))
            }
            statusMessage = "Kalibre edildi: sağ boşluk \(Int(metrics.rightInset)), satır \(Int(metrics.rowStep))"
        } catch {
            lastError = Self.describe(error)
        }
    }

    func refreshIcons() {
        screen = ScreenInfo.main()
        icons = (try? FinderBridge.readIcons()) ?? icons
    }

    // MARK: - Oturum açılışında başlat

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                lastError = "Oturum açılış ayarı değiştirilemedi: \(error.localizedDescription)"
            }
            objectWillChange.send()
        }
    }

    private static func describe(_ error: Error) -> String {
        let text = error.localizedDescription
        if text.contains("-1743") || text.localizedCaseInsensitiveContains("not authorized") {
            return "Finder'ı kontrol izni yok. Sistem Ayarları › Gizlilik ve Güvenlik › Otomasyon'dan PeakLayout için Finder'ı aç."
        }
        return text
    }
}
