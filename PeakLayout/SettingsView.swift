import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedProfileID: DisplayProfile.ID?
    @State private var newPinnedName = ""
    @State private var newRuleApp = ""
    @State private var windowProfileID: UUID?

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
    /// Düzenlenen ekran profili; varsayılan olarak şu an bağlı olan ekran.
    private var profileIndex: Int? {
        let id = windowProfileID ?? model.activeProfile?.id
        return model.settings.profiles.firstIndex { $0.id == id }
    }

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

                Section("Screen") {
                    Picker("Zones for", selection: windowProfileBinding) {
                        ForEach(model.settings.profiles) { profile in
                            let active = profile.id == model.activeProfile?.id
                            Text(verbatim: active ? "\(profile.title)  ● \(String(localized: "active"))" : profile.title)
                                .tag(profile.id)
                        }
                    }
                    if let index = profileIndex {
                        let profile = model.settings.profiles[index]
                        Stepper(zoneCountLabel, value: zoneCount, in: 0...4)
                        ForEach(Array(profile.windowZones.enumerated()), id: \.element.id) { zoneIndex, zone in
                            HStack {
                                TextField("", text: zoneTitle(zoneIndex))
                                Spacer()
                                Text(verbatim: "\(zone.widthPercent)%")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                Stepper("", value: zoneWidth(zoneIndex), in: 10...100, step: 5).labelsHidden()
                            }
                        }
                        if profile.windowZones.isEmpty {
                            Text("No zones: windows are left alone on this screen.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        Text("Gap between windows")
                        Spacer()
                        Stepper("\(Int(model.settings.windowGap)) pt", value: $model.settings.windowGap, in: 0...40, step: 2)
                    }
                }

                if let index = profileIndex, !model.settings.profiles[index].windowZones.isEmpty {
                    Section {
                        if model.settings.profiles[index].windowRules.isEmpty {
                            Text("No rules yet").foregroundStyle(.secondary)
                        }
                        ForEach(Array(model.settings.profiles[index].windowRules.enumerated()), id: \.element.id) { ruleIndex, rule in
                            HStack {
                                Text(verbatim: rule.appName)
                                Spacer()
                                Picker("", selection: ruleZone(ruleIndex)) {
                                    ForEach(model.settings.profiles[index].windowZones) { zone in
                                        Text(verbatim: zone.title).tag(zone.id)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 130)
                                Button {
                                    model.settings.profiles[index].windowRules.remove(at: ruleIndex)
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
                        Button("Copy rules from the active screen") { copyRulesFromActiveScreen() }
                            .disabled(model.activeProfile == nil || model.activeProfile?.id == model.settings.profiles[index].id)
                    } header: {
                        Text("App rules")
                    }
                }
            }
            .formStyle(.grouped)
            .frame(minWidth: 380, idealWidth: 420)

            VStack(alignment: .leading, spacing: 8) {
                if let index = profileIndex {
                    let profile = model.settings.profiles[index]
                    ZonePreview(zones: profile.windowZones, rules: profile.windowRules)
                        .frame(maxHeight: 260)
                    let widths = profile.windowZones.map { zone in
                        Int((Double(profile.width) * (zone.end - zone.start) - model.settings.windowGap).rounded())
                    }
                    Text(verbatim: "\(profile.width)×\(profile.height) · "
                         + (widths.isEmpty ? "—" : widths.map { "\($0) pt" }.joined(separator: " + ")))
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

    private var windowProfileBinding: Binding<UUID?> {
        Binding(get: { windowProfileID ?? model.activeProfile?.id ?? model.settings.profiles.first?.id },
                set: { windowProfileID = $0 })
    }

    private var zoneCountLabel: String {
        let count = profileIndex.map { model.settings.profiles[$0].windowZones.count } ?? 0
        switch count {
        case 0: return String(localized: "Leave windows alone")
        case 1: return String(localized: "1 full-screen zone")
        default: return String(localized: "\(count) equal columns")
        }
    }

    private var zoneCount: Binding<Int> {
        Binding(
            get: { profileIndex.map { model.settings.profiles[$0].windowZones.count } ?? 0 },
            set: { count in
                guard let index = profileIndex else { return }
                let existing = model.settings.profiles[index].windowZones
                guard count > 0 else {
                    model.settings.profiles[index].windowZones = []
                    model.settings.profiles[index].windowRules = []
                    return
                }
                let defaults = [String(localized: "Left"), String(localized: "Center"), String(localized: "Right")]
                let titles = (0..<count).map { position -> String in
                    if position < existing.count { return existing[position].title }
                    if count == 1 { return String(localized: "Full screen") }
                    return position < defaults.count ? defaults[position] : "\(position + 1)"
                }
                var zones = WindowZone.equalColumns(titles)
                for position in zones.indices where position < existing.count { zones[position].id = existing[position].id }
                model.settings.profiles[index].windowZones = zones
                // Bölgesi kalmayan kurallar sonuncuya kaydırılır.
                for ruleIndex in model.settings.profiles[index].windowRules.indices {
                    let zoneID = model.settings.profiles[index].windowRules[ruleIndex].zoneID
                    if !zones.contains(where: { $0.id == zoneID }), let last = zones.last {
                        model.settings.profiles[index].windowRules[ruleIndex].zoneID = last.id
                    }
                }
            }
        )
    }

    private func zoneTitle(_ zoneIndex: Int) -> Binding<String> {
        Binding(get: { profileIndex.map { model.settings.profiles[$0].windowZones[zoneIndex].title } ?? "" },
                set: { if let index = profileIndex { model.settings.profiles[index].windowZones[zoneIndex].title = $0 } })
    }

    /// Bir bölgenin genişliğini değiştirir; farkı komşusundan alır, toplam hep %100 kalır.
    private func zoneWidth(_ zoneIndex: Int) -> Binding<Int> {
        Binding(
            get: { profileIndex.map { model.settings.profiles[$0].windowZones[zoneIndex].widthPercent } ?? 100 },
            set: { percent in
                guard let index = profileIndex else { return }
                var zones = model.settings.profiles[index].windowZones
                guard zones.count > 1 else { return }
                let neighbour = zoneIndex == zones.count - 1 ? zoneIndex - 1 : zoneIndex + 1
                let delta = Double(percent) / 100 - (zones[zoneIndex].end - zones[zoneIndex].start)
                guard (zones[neighbour].end - zones[neighbour].start) - delta >= 0.1 else { return }
                if neighbour > zoneIndex {
                    zones[zoneIndex].end += delta
                } else {
                    zones[zoneIndex].start -= delta
                }
                for position in zones.indices.dropFirst() { zones[position].start = zones[position - 1].end }
                model.settings.profiles[index].windowZones = zones
            }
        )
    }

    private func ruleZone(_ ruleIndex: Int) -> Binding<UUID> {
        Binding(get: { profileIndex.map { model.settings.profiles[$0].windowRules[ruleIndex].zoneID } ?? UUID() },
                set: { if let index = profileIndex { model.settings.profiles[index].windowRules[ruleIndex].zoneID = $0 } })
    }

    var addableApps: [(bundleID: String, name: String)] {
        let used = Set(profileIndex.map { model.settings.profiles[$0].windowRules.map(\.bundleID) } ?? [])
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in
                guard let id = app.bundleIdentifier, let name = app.localizedName,
                      !used.contains(id), id != Bundle.main.bundleIdentifier else { return nil }
                return (id, name)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Yeni kural ortadaki bölgeye düşer.
    private func addRule() {
        guard let index = profileIndex, let app = addableApps.first(where: { $0.bundleID == newRuleApp }) else { return }
        let zones = model.settings.profiles[index].windowZones
        guard !zones.isEmpty else { return }
        let middle = zones[zones.count / 2]
        model.settings.profiles[index].windowRules.append(
            WindowRule(bundleID: app.bundleID, appName: app.name, zoneID: middle.id)
        )
        newRuleApp = ""
    }

    /// Aktif ekranın kurallarını bu profile kopyalar; bölge sırası korunur.
    private func copyRulesFromActiveScreen() {
        guard let index = profileIndex, let source = model.activeProfile else { return }
        let zones = model.settings.profiles[index].windowZones
        guard !zones.isEmpty else { return }
        model.settings.profiles[index].windowRules = source.windowRules.map { rule in
            let position = source.windowZones.firstIndex { $0.id == rule.zoneID } ?? 0
            return WindowRule(bundleID: rule.bundleID, appName: rule.appName,
                              zoneID: zones[min(position, zones.count - 1)].id)
        }
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
