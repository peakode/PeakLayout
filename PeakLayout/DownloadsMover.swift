import Foundation

/// ~/Downloads'a yeni gelen, indirmesi bitmiş dosyaları masaüstüne taşır.
@MainActor
final class DownloadsMover {
    static let downloadsURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Downloads", isDirectory: true)

    /// Tarayıcıların yarım indirme uzantıları.
    private static let partialExtensions: Set<String> = [
        "crdownload", "download", "part", "partial", "tmp", "opdownload", "filepart",
    ]

    /// Boyutu bu kadar süre sabit kalan dosya "bitmiş" sayılır.
    private let stableInterval: TimeInterval = 2

    /// Bu tarihten önce Downloads'a eklenmiş dosyalara dokunulmaz.
    private let baseline: Date
    private var lastSizes: [String: (size: Int64, seen: Date)] = [:]
    private var watcher: DirectoryWatcher?
    private var recheck: Timer?
    private let onMoved: ([String]) -> Void
    private let onError: (String) -> Void

    init(baseline: Date, onMoved: @escaping ([String]) -> Void, onError: @escaping (String) -> Void) {
        self.baseline = baseline
        self.onMoved = onMoved
        self.onError = onError
    }

    func start() {
        let watcher = DirectoryWatcher(url: Self.downloadsURL, debounce: 1) { [weak self] in self?.scan() }
        watcher.start()
        self.watcher = watcher
        scan()
    }

    func stop() {
        watcher?.stop()
        watcher = nil
        recheck?.invalidate()
        recheck = nil
    }

    private func scan() {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.addedToDirectoryDateKey, .creationDateKey, .fileSizeKey, .isDirectoryKey]
        guard let urls = try? fm.contentsOfDirectory(
            at: Self.downloadsURL, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
        ) else { return }

        let now = Date()
        var moved: [String] = []
        var waiting = false

        for url in urls {
            let name = url.lastPathComponent
            guard !Self.partialExtensions.contains(url.pathExtension.lowercased()),
                  !DesktopScanner.isIgnored(name),
                  let values = try? url.resourceValues(forKeys: Set(keys)),
                  let added = values.addedToDirectoryDate ?? values.creationDate,
                  added > baseline else { continue }

            let size = Self.size(of: url, isDirectory: values.isDirectory ?? false)
            if let previous = lastSizes[name], previous.size == size {
                guard now.timeIntervalSince(previous.seen) >= stableInterval else { waiting = true; continue }
            } else {
                lastSizes[name] = (size, now)
                waiting = true
                continue
            }

            let destination = Self.uniqueDestination(for: name)
            do {
                try fm.moveItem(at: url, to: destination)
                moved.append(destination.lastPathComponent)
                lastSizes[name] = nil
            } catch {
                onError("\(name) taşınamadı: \(error.localizedDescription)")
                lastSizes[name] = nil
            }
        }

        // Klasör olayı gelmese de boyut kontrolünü tamamlamak için yeniden bak.
        recheck?.invalidate()
        if waiting {
            recheck = Timer.scheduledTimer(withTimeInterval: stableInterval, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.scan() }
            }
        }
        if !moved.isEmpty { onMoved(moved) }
    }

    private static func size(of url: URL, isDirectory: Bool) -> Int64 {
        guard isDirectory else {
            return Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey])
        var total: Int64 = 0
        while let child = enumerator?.nextObject() as? URL {
            total += Int64((try? child.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }

    private static func uniqueDestination(for name: String) -> URL {
        let desktop = DesktopScanner.desktopURL
        var candidate = desktop.appendingPathComponent(name)
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var counter = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            let newName = ext.isEmpty ? "\(base) (\(counter))" : "\(base) (\(counter)).\(ext)"
            candidate = desktop.appendingPathComponent(newName)
            counter += 1
        }
        return candidate
    }
}
