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
                        Text(verbatim: "\(index + 1).").monospacedDigit().foregroundStyle(.secondary)
                        Text(verbatim: name)
                        Spacer()
                        if !model.icons.contains(where: { $0.name == name }) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                                .help("Not found on desktop")
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
                Picker("Add", selection: $newPinnedName) {
                    Text("Choose from desktop…").tag("")
                    ForEach(unpinnedDesktopNames, id: \.self) { Text(verbatim: $0).tag($0) }
                }
                Button("Add") {
                    model.settings.pinned.append(newPinnedName)
                    newPinnedName = ""
                }
                .disabled(newPinnedName.isEmpty)
            }
        } header: {
            Text("Right column (top to bottom)")
        } footer: {
            Text("Drag to reorder. Changes take effect on the next layout pass.")
        }
    }

    private var unpinnedDesktopNames: [String] {
        model.icons.map(\.name)
            .filter { !model.settings.pinned.contains($0) && !DesktopScanner.isIgnored($0) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    // MARK: - Davranış

    private var behaviourSection: some View {
        Section("Behavior") {
            Toggle("Move new downloads to the desktop", isOn: $model.settings.moveDownloads)
                .onChange(of: model.settings.moveDownloads) { model.updateDownloadsMover() }
            Toggle("Protect pinned folders (check every 20 s)", isOn: $model.settings.guardPinned)
                .onChange(of: model.settings.guardPinned) { model.updateGuardTimer() }
            Toggle("Launch at login", isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.launchAtLogin = $0 }
            ))
            Button("Apply now") { model.applyLayout(reason: String(localized: "Manual")) }
        }
    }

    private var backupSection: some View {
        Section {
            Button("Restore last backup") { model.restoreLastBackup() }
            Button("Open backup folder") { BackupStore.revealInFinder() }
        } header: {
            Text("Backups")
        } footer: {
            Text("Current Finder positions are saved before every layout pass (last 20).")
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
            Picker("Display profile", selection: $selectedProfileID) {
                ForEach(model.settings.profiles) { profile in
                    let active = profile.id == model.activeProfile?.id
                    Text(verbatim: active ? "\(profile.title)  ● \(String(localized: "active"))" : profile.title).tag(Optional(profile.id))
                }
            }
            Button("Measure from current positions") {
                model.calibrateFromCurrentPositions()
                selectedProfileID = model.activeProfile?.id
            }
            .help("Press when pinned folders are in place; right inset, first row and row step are measured.")
        }
    }

    private func metricsEditor(_ profile: Binding<DisplayProfile>) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
            GridRow {
                Text("Name"); TextField("", text: profile.title)
            }
            GridRow {
                Text("Display name contains"); TextField("empty = match by resolution", text: profile.nameMatch)
            }
            GridRow {
                Text("Resolution")
                HStack {
                    TextField("", value: profile.width, format: .number.grouping(.never)).frame(width: 70)
                    Text(verbatim: "×")
                    TextField("", value: profile.height, format: .number.grouping(.never)).frame(width: 70)
                }
            }
            Divider().gridCellColumns(2)
            metricRow("Right inset", profile.metrics.rightInset)
            metricRow("First row y", profile.metrics.topY)
            metricRow("Column step", profile.metrics.columnStep)
            metricRow("Row step", profile.metrics.rowStep)
            metricRow("Bottom inset", profile.metrics.bottomInset)
            GridRow {
                Text("Gap columns")
                Stepper(value: profile.metrics.gapColumns, in: 0...4) {
                    Text(verbatim: "\(profile.wrappedValue.metrics.gapColumns)")
                }
            }
        }
    }

    private func metricRow(_ title: LocalizedStringKey, _ value: Binding<Double>) -> some View {
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
            Text("\(engine.rows) rows · \(engine.freeColumns) free columns · capacity \(engine.capacity) files")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
