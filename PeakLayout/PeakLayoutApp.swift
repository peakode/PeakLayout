import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor let model = AppModel()

    @MainActor func applicationDidFinishLaunching(_ notification: Notification) {
        model.start()
    }
}

@main
struct PeakLayoutApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(delegate.model)
        } label: {
            MenuBarLabel(model: delegate.model)
        }
        .menuBarExtraStyle(.window)

        Window("PeakLayout", id: "settings") {
            SettingsView()
                .environmentObject(delegate.model)
                .frame(minWidth: 820, minHeight: 620)
        }
        .windowResizability(.contentMinSize)
    }
}

private struct MenuBarLabel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if model.isPaused {
            Image(systemName: "pause.rectangle")
        } else {
            Image("MenuBarIcon")
        }
    }
}
