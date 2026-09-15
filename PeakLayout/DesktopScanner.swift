import Foundation

/// Finder'ın gösterdiği bir masaüstü öğesi + kalıcı kimliği.
struct DesktopItem: Equatable {
    /// Finder'daki ad (uzantı dahil).
    let name: String
    /// Yeniden adlandırmada değişmeyen anahtar: dosyalar için inode, diskler için ad.
    let key: String
    /// Masaüstüne eklenme tarihi; ilk kurulumdaki sıralama için.
    let addedDate: Date?
}

enum DesktopScanner {
    static let desktopURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Desktop", isDirectory: true)

    /// Finder bu adları gizli işaretli olmasa da gösterebilir; Windows/Office artığıdır.
    private static let ignoredNames: Set<String> = ["$RECYCLE.BIN", "Thumbs.db", "desktop.ini"]

    static func isIgnored(_ name: String) -> Bool {
        name.hasPrefix(".") || name.hasPrefix("~$") || ignoredNames.contains(name)
    }

    /// Finder ad listesini dosya sistemiyle eşleştirir.
    static func items(finderNames: [String]) -> [DesktopItem] {
        finderNames.filter { !isIgnored($0) }.map { name in
            let url = desktopURL.appendingPathComponent(name)
            let values = try? url.resourceValues(forKeys: [.addedToDirectoryDateKey, .creationDateKey])
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let inode = attrs[.systemFileNumber] as? NSNumber {
                return DesktopItem(
                    name: name,
                    key: "ino:\(inode)",
                    addedDate: values?.addedToDirectoryDate ?? values?.creationDate
                )
            }
            // ~/Desktop'ta karşılığı yok: disk, bağlı sunucu vb.
            return DesktopItem(name: name, key: "vol:\(name)", addedDate: nil)
        }
    }

    /// Dosya sisteminde görünen (gizli olmayan) masaüstü adları.
    static func fileSystemNames() -> Set<String> {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: desktopURL,
            includingPropertiesForKeys: [.isHiddenKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return Set(urls.map(\.lastPathComponent).filter { !isIgnored($0) })
    }
}
