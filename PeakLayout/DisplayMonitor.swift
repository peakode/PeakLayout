import AppKit

/// Finder masaüstü koordinatlarının referansı olan ana ekran.
struct ScreenInfo: Equatable {
    var name: String
    var size: CGSize
    var isBuiltIn: Bool

    var resolutionText: String { "\(Int(size.width))×\(Int(size.height))" }

    /// Menü çubuğunun olduğu ekran; masaüstü ikonları burada durur.
    static func main() -> ScreenInfo? {
        guard let screen = NSScreen.screens.first else { return nil }
        let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        return ScreenInfo(
            name: screen.localizedName,
            size: screen.frame.size,
            isBuiltIn: displayID.map { CGDisplayIsBuiltin($0) != 0 } ?? false
        )
    }
}

/// Monitör takma/çıkarma, çözünürlük değişimi ve uykudan uyanmayı bildirir.
@MainActor
final class DisplayMonitor {
    private var observers: [NSObjectProtocol] = []
    private var pending: [DispatchWorkItem] = []
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    func start() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.schedule() } })

        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.schedule() } })
    }

    /// Finder ekran değişince ikonları önce kendisi dizer; onu bekleyip iki kez uygularız.
    private func schedule() {
        pending.forEach { $0.cancel() }
        pending = [3.0, 8.0].map { delay in
            let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.onChange() } }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
            return work
        }
    }
}
