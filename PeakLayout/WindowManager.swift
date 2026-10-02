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

    /// Uygulamanın taşınabilir pencereleri. Küçültülmüş, tam ekran ve diyalog türü pencereler atlanır.
    static func windows(of app: NSRunningApplication) -> [AXUIElement] {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        guard let windows = attribute(axApp, kAXWindowsAttribute) as? [AXUIElement] else { return [] }
        return windows.filter { window in
            attribute(window, kAXSubroleAttribute) as? String == (kAXStandardWindowSubrole as String)
                && attribute(window, kAXMinimizedAttribute) as? Bool != true
                && attribute(window, "AXFullScreen") as? Bool != true
        }
    }

    /// Pencerenin şu anki konumu ve boyutu (Accessibility koordinatları: ana ekranın sol üstü 0,0).
    static func frame(of window: AXUIElement) -> CGRect? {
        guard let position = attribute(window, kAXPositionAttribute),
              let size = attribute(window, kAXSizeAttribute) else { return nil }
        var origin = CGPoint.zero
        var dimensions = CGSize.zero
        // AXValue her zaman CFTypeRef olarak gelir; tür kontrolü AXValueGetValue'da yapılır.
        guard AXValueGetValue(position as! AXValue, .cgPoint, &origin),
              AXValueGetValue(size as! AXValue, .cgSize, &dimensions) else { return nil }
        return CGRect(origin: origin, size: dimensions)
    }

    @discardableResult
    static func move(_ window: AXUIElement, to rect: CGRect) -> Bool {
        var origin = rect.origin
        var size = rect.size
        guard let position = AXValueCreate(.cgPoint, &origin), let dimensions = AXValueCreate(.cgSize, &size) else {
            return false
        }
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, position)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, dimensions)
        // Pencere başka ekrandan geliyorsa önce eski ekrana göre kırpılabilir; konumu tekrar yazmak düzeltir.
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, position)
        return true
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
}
