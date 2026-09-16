import SwiftUI

struct MenuContentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if let name = model.screen?.name {
                    Text(verbatim: name).font(.headline)
                } else {
                    Text("No display found").font(.headline)
                }
                HStack(spacing: 6) {
                    Text(verbatim: model.screen?.resolutionText ?? "")
                    Text(verbatim: "·")
                    if let title = model.activeProfile?.title {
                        Text(verbatim: title)
                    } else {
                        Text("No profile (default metrics)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if let engine = model.engine {
                LayoutPreview(engine: engine, pinned: model.settings.pinned,
                              loose: model.looseItems, assignments: model.settings.assignments)
                    .frame(height: 110)
            }

            VStack(alignment: .leading, spacing: 4) {
                Label { Text(verbatim: model.statusMessage) } icon: { Image(systemName: "checkmark.circle") }
                    .lineLimit(2)
                if let date = model.lastApplied {
                    Text("Last applied: \(date.formatted(date: .omitted, time: .shortened))")
                        .foregroundStyle(.secondary)
                }
                if model.overflowCount > 0 {
                    Label("\(model.overflowCount) files didn't fit on screen", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                if let error = model.lastError {
                    Label { Text(verbatim: error) } icon: { Image(systemName: "xmark.octagon") }
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .font(.callout)

            Divider()

            HStack {
                Button("Apply now") { model.applyLayout(reason: String(localized: "Manual")) }
                    .keyboardShortcut(.defaultAction)
                Button("Close gaps") { model.compactSlots() }
            }
            if model.settings.windowZonesEnabled {
                Button("Arrange windows") { model.arrangeWindows(reason: String(localized: "Manual")) }
            }
            Toggle("Pause", isOn: $model.isPaused)
                .onChange(of: model.isPaused) { _, paused in
                    if !paused { model.applyLayout(reason: String(localized: "Resumed")) }
                }

            Divider()

            HStack {
                Button("Settings…") {
                    openWindow(id: "settings")
                    NSApp.activate()
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 340)
    }
}
