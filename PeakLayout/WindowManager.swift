import ApplicationServices
import AppKit

/// Pencereleri Accessibility API ile taşır. Erişilebilirlik izni gerektirir.
@MainActor
enum WindowManager {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// macOS'un kendi izin penceresini gösterir (izin zaten varsa sessiz kalır).
    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    static func runningApp(bundleID: String) -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
    }

    /// Uygulamanın taşınabilir tüm pencerelerini bölgeye oturtur; yerleştirilen pencere sayısını döndürür.
    @discardableResult
    static func place(app: NSRunningApplication, in rect: CGRect) -> Int {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        guard let windows = attribute(axApp, kAXWindowsAttribute) as? [AXUIElement] else { return 0 }
        return windows.filter(isPlaceable).reduce(0) { $0 + (set(window: $1, to: rect) ? 1 : 0) }
    }

    /// Küçültülmüş, tam ekran ve diyalog türü pencereler atlanır.
    private static func isPlaceable(_ window: AXUIElement) -> Bool {
        attribute(window, kAXSubroleAttribute) as? String == (kAXStandardWindowSubrole as String)
            && attribute(window, kAXMinimizedAttribute) as? Bool != true
            && attribute(window, "AXFullScreen") as? Bool != true
    }

    private static func set(window: AXUIElement, to rect: CGRect) -> Bool {
        var origin = rect.origin
        var size = rect.size
        guard let position = AXValueCreate(.cgPoint, &origin), let dimensions = AXValueCreate(.cgSize, &size) else {
            return false
        }
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, position)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, dimensions)
        // Bazı uygulamalar önce eski konuma göre kırpar; konumu tekrar yazmak sonucu düzeltir.
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, position)
        return true
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> Any? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
}
