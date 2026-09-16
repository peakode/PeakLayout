import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedProfileID: DisplayProfile.ID?
    @State private var newPinnedName = ""
    @State private var newRuleApp = ""

    var body: some View {
        TabView {
            desktopTab.tabItem { Label("Desktop", systemImage: "square.grid.3x3") }
            windowsTab.tabItem { Label("Windows", systemImage: "rectangle.split.3x1") }
        }
        .padding(.top, 8)
    }

    private var desktopTab: some View {
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


// MARK: - Pencere bölgeleri sekmesi

extension SettingsView {
    var windowsTab: some View {
        HSplitView {
            Form {
                Section {
                    Toggle("Arrange windows in zones", isOn: $model.settings.windowZonesEnabled)
                        .onChange(of: model.settings.windowZonesEnabled) { _, on in
                            model.updateLaunchObserver()
                            if on { WindowManager.requestPermission() }
                        }
                    if model.settings.windowZonesEnabled && !model.accessibilityGranted {
                        HStack {
                            Label("Accessibility permission missing", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                            Button("Open settings") { WindowManager.openAccessibilitySettings() }
                        }
                    }
                    Button("Arrange now") { model.arrangeWindows(reason: String(localized: "Manual")) }
                        .disabled(!model.settings.windowZonesEnabled)
                } header: {
                    Text("Window zones")
                } footer: {
                    Text("Rules are applied when the app launches, when the display changes and when you press Arrange now. Apps without a rule are never moved.")
                }

                Section("Zones") {
                    Stepper("\(model.settings.zones.count) equal columns", value: zoneCount, in: 2...4)
                    ForEach(Array(model.settings.zones.enumerated()), id: \.element.id) { index, zone in
                        HStack {
                            TextField("", text: zoneTitle(index))
                            Spacer()
                            Text(verbatim: "\(zone.widthPercent)%")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            Stepper("", value: zoneWidth(index), in: 10...80, step: 5).labelsHidden()
                        }
                    }
                    HStack {
                        Text("Gap between windows")
                        Spacer()
                        Stepper("\(Int(model.settings.windowGap)) pt", value: $model.settings.windowGap, in: 0...40, step: 2)
                    }
                }

                Section {
                    if model.settings.windowRules.isEmpty {
                        Text("No rules yet").foregroundStyle(.secondary)
                    }
                    ForEach(Array(model.settings.windowRules.enumerated()), id: \.element.id) { index, rule in
                        HStack {
                            Text(verbatim: rule.appName)
                            Spacer()
                            Picker("", selection: ruleZone(index)) {
                                ForEach(model.settings.zones) { zone in
                                    Text(verbatim: zone.title).tag(zone.id)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 130)
                            Button {
                                model.settings.windowRules.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    HStack {
                        Picker("Add app", selection: $newRuleApp) {
                            Text("Choose a running app…").tag("")
                            ForEach(addableApps, id: \.bundleID) { app in
                                Text(verbatim: app.name).tag(app.bundleID)
                            }
                        }
                        Button("Add") { addRule() }.disabled(newRuleApp.isEmpty)
                    }
                } header: {
                    Text("App rules")
                }
            }
            .formStyle(.grouped)
            .frame(minWidth: 380, idealWidth: 420)

            VStack(alignment: .leading, spacing: 8) {
                ZonePreview(zones: model.settings.zones, rules: model.settings.windowRules)
                    .frame(maxHeight: 260)
                if let screen = model.screen, let layout = model.zoneLayout {
                    Text(verbatim: screen.resolutionText + " · " + model.settings.zones
                        .map { "\(Int(layout.frame(for: $0).width)) pt" }
                        .joined(separator: " + "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .frame(minWidth: 400)
        }
    }

    // MARK: Bağlamalar

    private var zoneCount: Binding<Int> {
        Binding(
            get: { model.settings.zones.count },
            set: { count in
                let titles = (0..<count).map { index in
                    index < model.settings.zones.count ? model.settings.zones[index].title : "\(index + 1)"
                }
                let ids = model.settings.zones.map(\.id)
                var zones = WindowZone.equalColumns(titles)
                for i in zones.indices where i < ids.count { zones[i].id = ids[i] }
                model.settings.zones = zones
                model.settings.windowRules.removeAll { rule in !zones.contains { $0.id == rule.zoneID } }
            }
        )
    }

    private func zoneTitle(_ index: Int) -> Binding<String> {
        Binding(get: { model.settings.zones[index].title },
                set: { model.settings.zones[index].title = $0 })
    }

    /// Bir bölgenin genişliğini değiştirir; farkı komşusundan alır, toplam hep %100 kalır.
    private func zoneWidth(_ index: Int) -> Binding<Int> {
        Binding(
            get: { model.settings.zones[index].widthPercent },
            set: { percent in
                var zones = model.settings.zones
                let neighbour = index == zones.count - 1 ? index - 1 : index + 1
                guard zones.indices.contains(neighbour) else { return }
                let delta = Double(percent) / 100 - (zones[index].end - zones[index].start)
                let neighbourWidth = zones[neighbour].end - zones[neighbour].start
                guard neighbourWidth - delta >= 0.1 else { return }
                zones[index].end += delta
                if neighbour > index {
                    zones[neighbour].start += delta
                } else {
                    zones[index].start += delta
                    zones[index].end -= delta
                    zones[neighbour].end += delta
                }
                // Sınırları yeniden zincirle: her bölge bir öncekinin bittiği yerden başlar.
                for i in zones.indices.dropFirst() { zones[i].start = zones[i - 1].end }
                model.settings.zones = zones
            }
        )
    }

    private func ruleZone(_ index: Int) -> Binding<UUID> {
        Binding(get: { model.settings.windowRules[index].zoneID },
                set: { model.settings.windowRules[index].zoneID = $0 })
    }

    var addableApps: [(bundleID: String, name: String)] {
        let used = Set(model.settings.windowRules.map(\.bundleID))
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in
                guard let id = app.bundleIdentifier, let name = app.localizedName,
                      !used.contains(id), id != Bundle.main.bundleIdentifier else { return nil }
                return (id, name)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Yeni kural varsayılan olarak ortadaki bölgeye düşer.
    private func addRule() {
        guard let app = addableApps.first(where: { $0.bundleID == newRuleApp }),
              !model.settings.zones.isEmpty else { return }
        let middle = model.settings.zones[model.settings.zones.count / 2]
        model.settings.windowRules.append(WindowRule(bundleID: app.bundleID, appName: app.name, zoneID: middle.id))
        newRuleApp = ""
    }
}

/// Bölgeleri ve hangi uygulamanın nereye gideceğini gösteren küçük şema.
private struct ZonePreview: View {
    let zones: [WindowZone]
    let rules: [WindowRule]

    var body: some View {
        GeometryReader { geo in
            let height = min(geo.size.height, geo.size.width * 9 / 32)
            HStack(spacing: 4) {
                ForEach(zones) { zone in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.15))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor.opacity(0.5)))
                        .overlay(alignment: .top) {
                            VStack(spacing: 4) {
                                Text(verbatim: zone.title).font(.caption).bold()
                                ForEach(rules.filter { $0.zoneID == zone.id }) { rule in
                                    Text(verbatim: rule.appName).font(.caption2).lineLimit(1)
                                }
                            }
                            .padding(6)
                        }
                        .frame(width: max(20, (geo.size.width - 8) * (zone.end - zone.start)))
                }
            }
            .frame(height: height)
        }
    }
}
