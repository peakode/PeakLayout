import SwiftUI

struct MenuContentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.screen?.name ?? "Ekran bulunamadı").font(.headline)
                HStack(spacing: 6) {
                    Text(model.screen?.resolutionText ?? "")
                    Text("·")
                    Text(model.activeProfile?.title ?? "Profil yok (varsayılan ölçüler)")
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
                Label(model.statusMessage, systemImage: "checkmark.circle")
                    .lineLimit(2)
                if let date = model.lastApplied {
                    Text("Son uygulama: \(date.formatted(date: .omitted, time: .shortened))")
                        .foregroundStyle(.secondary)
                }
                if model.overflowCount > 0 {
                    Label("\(model.overflowCount) dosya ekrana sığmadı", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                if let error = model.lastError {
                    Label(error, systemImage: "xmark.octagon")
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .font(.callout)

            Divider()

            HStack {
                Button("Şimdi uygula") { model.applyLayout(reason: "Elle") }
                    .keyboardShortcut(.defaultAction)
                Button("Boşlukları kapat") { model.compactSlots() }
            }
            Toggle("Duraklat", isOn: $model.isPaused)
                .onChange(of: model.isPaused) { _, paused in
                    if !paused { model.applyLayout(reason: "Devam") }
                }

            Divider()

            HStack {
                Button("Ayarlar…") {
                    openWindow(id: "settings")
                    NSApp.activate()
                }
                Spacer()
                Button("Çıkış") { NSApp.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 340)
    }
}
