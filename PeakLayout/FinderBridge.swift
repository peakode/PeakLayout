import AppKit

struct DesktopIcon: Codable, Equatable {
    var name: String
    var x: Double
    var y: Double
}

enum FinderError: LocalizedError {
    case script(String)

    var errorDescription: String? {
        switch self {
        case .script(let message): return String(localized: "Finder script failed: \(message)")
        }
    }
}

/// Finder ile AppleScript üzerinden konuşur. NSAppleScript ana thread'de çalıştırılmalı.
@MainActor
enum FinderBridge {
    /// Masaüstünde Finder'ın gösterdiği tüm öğeler (diskler dahil) ve konumları.
    static func readIcons() throws -> [DesktopIcon] {
        let result = try run("""
        tell application "Finder"
            set theNames to name of every item of desktop
            set thePositions to desktop position of every item of desktop
            return {theNames, thePositions}
        end tell
        """)
        guard result.numberOfItems == 2,
              let names = result.atIndex(1), let positions = result.atIndex(2) else { return [] }

        // Tek öğe varsa AppleScript liste yerine tekil değer döndürebilir.
        if names.numberOfItems == 0 {
            guard let single = names.stringValue, let point = point(from: positions) else { return [] }
            return [DesktopIcon(name: single, x: point.x, y: point.y)]
        }

        var icons: [DesktopIcon] = []
        for i in 1...names.numberOfItems {
            guard let name = names.atIndex(i)?.stringValue,
                  let posDesc = positions.atIndex(i),
                  let point = point(from: posDesc) else { continue }
            icons.append(DesktopIcon(name: name, x: point.x, y: point.y))
        }
        return icons
    }

    /// Konumları tek betikte uygular. Finder'ın henüz tanımadığı öğelerin adlarını döndürür.
    @discardableResult
    static func apply(_ placements: [DesktopIcon]) throws -> [String] {
        guard !placements.isEmpty else { return [] }
        var lines = ["tell application \"Finder\"", "set failedNames to {}"]
        for p in placements {
            let name = quoted(p.name)
            lines.append("""
            try
                set desktop position of item \(name) of desktop to {\(Int(p.x.rounded())), \(Int(p.y.rounded()))}
            on error
                set end of failedNames to \(name)
            end try
            """)
        }
        lines.append("return failedNames")
        lines.append("end tell")

        let result = try run(lines.joined(separator: "\n"))
        guard result.numberOfItems > 0 else { return [] }
        return (1...result.numberOfItems).compactMap { result.atIndex($0)?.stringValue }
    }

    private static func run(_ source: String) throws -> NSAppleEventDescriptor {
        guard let script = NSAppleScript(source: source) else {
            throw FinderError.script(String(localized: "could not create script"))
        }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            let message = error[NSAppleScript.errorMessage] as? String ?? "\(error)"
            let number = error[NSAppleScript.errorNumber] as? Int ?? 0
            throw FinderError.script("\(message) (\(number))")
        }
        return result
    }

    private static func point(from descriptor: NSAppleEventDescriptor) -> CGPoint? {
        guard descriptor.numberOfItems == 2,
              let x = descriptor.atIndex(1)?.int32Value,
              let y = descriptor.atIndex(2)?.int32Value else { return nil }
        return CGPoint(x: Double(x), y: Double(y))
    }

    private static func quoted(_ s: String) -> String {
        let escaped = s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
