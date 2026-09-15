import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedProfileID: DisplayProfile.ID?
    @State private var newPinnedName = ""

    var body: some View {
        HSplitView {
            Form {
                pinnedSection
                behaviourSection
                backupSection
            }
            .formStyle(.grouped)
            .frame(minWidth: 320, idealWidth: 360)

            VStack(alignment: .leading, spacing: 12) {
                profilePicker
                if let binding = selectedProfileBinding {
                    metricsEditor(binding)
                    previewFor(binding.wrappedValue)
                }
            }
            .padding()
            .frame(minWidth: 460)
        }
        .onAppear {
            model.refreshIcons()
            selectedProfileID = model.activeProfile?.id ?? model.settings.profiles.first?.id
        }
    }

    // MARK: - Sabit öğeler

    private var pinnedSection: some View {
        Section {
            List {
                ForEach(Array(model.settings.pinned.enumerated()), id: \.element) { index, name in
                    HStack {
                        Text("\(index + 1).").monospacedDigit().foregroundStyle(.secondary)
                        Text(name)
                        Spacer()
                        if !model.icons.contains(where: { $0.name == name }) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                                .help("Masaüstünde bulunamadı")
                        }
                        Button {
                            model.settings.pinned.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .onMove { model.settings.pinned.move(fromOffsets: $0, toOffset: $1) }
            }
            .frame(minHeight: 220)

            HStack {
                Picker("Ekle", selection: $newPinnedName) {
                    Text("Masaüstünden seç…").tag("")
                    ForEach(unpinnedDesktopNames, id: \.self) { Text($0).tag($0) }
                }
                Button("Ekle") {
                    model.settings.pinned.append(newPinnedName)
                    newPinnedName = ""
                }
                .disabled(newPinnedName.isEmpty)
            }
        } header: {
            Text("Sağ sütun (yukarıdan aşağı)")
        } footer: {
            Text("Sırayı değiştirmek için sürükle. Değişiklik bir sonraki uygulamada yerleşir.")
        }
    }

    private var unpinnedDesktopNames: [String] {
        model.icons.map(\.name)
            .filter { !model.settings.pinned.contains($0) && !DesktopScanner.isIgnored($0) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    // MARK: - Davranış

    private var behaviourSection: some View {
        Section("Davranış") {
            Toggle("Downloads'a gelenleri masaüstüne taşı", isOn: $model.settings.moveDownloads)
                .onChange(of: model.settings.moveDownloads) { model.updateDownloadsMover() }
            Toggle("Sabit klasörleri koru (20 sn'de bir kontrol)", isOn: $model.settings.guardPinned)
                .onChange(of: model.settings.guardPinned) { model.updateGuardTimer() }
            Toggle("Oturum açılınca başlat", isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.launchAtLogin = $0 }
            ))
            Button("Şimdi uygula") { model.applyLayout(reason: "Elle") }
        }
    }

    private var backupSection: some View {
        Section {
            Button("Son yedeğe geri dön") { model.restoreLastBackup() }
            Button("Yedek klasörünü aç") { BackupStore.revealInFinder() }
        } header: {
            Text("Yedekler")
        } footer: {
            Text("Her yerleşimden önce Finder'daki mevcut konumlar kaydedilir (son 20).")
        }
    }

    // MARK: - Profiller

    private var selectedProfileBinding: Binding<DisplayProfile>? {
        guard let id = selectedProfileID,
              let index = model.settings.profiles.firstIndex(where: { $0.id == id }) else { return nil }
        return $model.settings.profiles[index]
    }

    private var profilePicker: some View {
        HStack {
            Picker("Ekran profili", selection: $selectedProfileID) {
                ForEach(model.settings.profiles) { profile in
                    let active = profile.id == model.activeProfile?.id
                    Text(active ? "\(profile.title)  ● aktif" : profile.title).tag(Optional(profile.id))
                }
            }
            Button("Şu anki konumlardan ölç") {
                model.calibrateFromCurrentPositions()
                selectedProfileID = model.activeProfile?.id
            }
            .help("Sabit klasörler doğru yerdeyken bas; sağ boşluk, üst boşluk ve satır aralığı ölçülür.")
        }
    }

    private func metricsEditor(_ profile: Binding<DisplayProfile>) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
            GridRow {
                Text("Ad"); TextField("", text: profile.title)
            }
            GridRow {
                Text("Ekran adı içerir"); TextField("boşsa çözünürlükle eşleşir", text: profile.nameMatch)
            }
            GridRow {
                Text("Çözünürlük")
                HStack {
                    TextField("", value: profile.width, format: .number.grouping(.never)).frame(width: 70)
                    Text("×")
                    TextField("", value: profile.height, format: .number.grouping(.never)).frame(width: 70)
                }
            }
            Divider().gridCellColumns(2)
            metricRow("Sağ kenar boşluğu", profile.metrics.rightInset)
            metricRow("İlk satır y", profile.metrics.topY)
            metricRow("Sütun aralığı", profile.metrics.columnStep)
            metricRow("Satır aralığı", profile.metrics.rowStep)
            metricRow("Alt boşluk", profile.metrics.bottomInset)
            GridRow {
                Text("Boş sütun sayısı")
                Stepper("\(profile.wrappedValue.metrics.gapColumns)", value: profile.metrics.gapColumns, in: 0...4)
            }
        }
    }

    private func metricRow(_ title: String, _ value: Binding<Double>) -> some View {
        GridRow {
            Text(title)
            HStack {
                TextField("", value: value, format: .number.precision(.fractionLength(0))).frame(width: 70)
                Stepper("", value: value, step: 1).labelsHidden()
            }
        }
    }

    private func previewFor(_ profile: DisplayProfile) -> some View {
        let engine = LayoutEngine(
            screenSize: CGSize(width: profile.width, height: profile.height),
            metrics: profile.metrics
        )
        return VStack(alignment: .leading, spacing: 6) {
            LayoutPreview(engine: engine, pinned: model.settings.pinned, loose: model.looseItems,
                          assignments: model.settings.assignments, showLabels: true)
                .frame(maxHeight: .infinity)
            Text("\(engine.rows) satır · \(engine.freeColumns) serbest sütun · \(engine.capacity) dosya kapasitesi")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
