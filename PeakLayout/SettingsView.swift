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
                            model.settings.pinned.removeAll { $0 == name }
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
                    Text(verbatim: active ? "\(profile.displayTitle)  ● \(String(localized: "active"))" : profile.displayTitle).tag(Optional(profile.id))
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
                Text("Name")
                TextField("", text: Binding(get: { profile.wrappedValue.displayTitle },
                                            set: { profile.wrappedValue.title = $0 }))
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

// Bölge ve kurallar her zaman ID ile bulunur, sıra numarasıyla değil: bölge sayısı azaldığında
// SwiftUI eski satırları bir kez daha okuyabilir ve sıra numarası dizinin dışına düşer.
extension SettingsView {
    /// Düzenlenen ekran profili; varsayılan olarak ana ekran.
    private var editedProfileID: UUID? {
        windowProfileID ?? model.activeProfile?.id ?? model.settings.profiles.first?.id
    }

    private var editedProfile: DisplayProfile? {
        model.settings.profiles.first { $0.id == editedProfileID }
    }

    /// Düzenlenen profili güvenle değiştirir; profil silinmişse hiçbir şey yapmaz.
    private func updateProfile(_ change: (inout DisplayProfile) -> Void) {
        guard let index = model.settings.profiles.firstIndex(where: { $0.id == editedProfileID }) else { return }
        change(&model.settings.profiles[index])
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
                    Text("Every connected screen uses its own zones. A window follows the rules of the screen it is on. Apps without a rule are never moved.")
                }

                Section {
                    Picker("Zones for", selection: windowProfileBinding) {
                        ForEach(model.settings.profiles) { profile in
                            Text(verbatim: profileLabel(profile)).tag(Optional(profile.id))
                        }
                    }
                    if let profile = editedProfile {
                        Stepper(zoneCountLabel(profile), value: zoneCount, in: 0...4)
                        ForEach(profile.windowZones) { zone in
                            HStack {
                                TextField("", text: zoneTitle(zone.id))
                                Spacer()
                                Text(verbatim: "\(zone.widthPercent)%")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                Stepper("", value: zoneWidth(zone.id), in: 10...100, step: 5).labelsHidden()
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
                } header: {
                    Text("Screen")
                }

                if let profile = editedProfile, !profile.windowZones.isEmpty {
                    Section {
                        if profile.windowRules.isEmpty {
                            Text("No rules yet").foregroundStyle(.secondary)
                        }
                        ForEach(profile.windowRules) { rule in
                            HStack {
                                Text(verbatim: rule.appName)
                                Spacer()
                                Picker("", selection: ruleZone(rule.id)) {
                                    ForEach(profile.windowZones) { zone in
                                        Text(verbatim: zone.displayTitle).tag(zone.id)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 130)
                                Button {
                                    updateProfile { $0.windowRules.removeAll { $0.id == rule.id } }
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
                        Menu("Copy rules from another screen") {
                            ForEach(model.settings.profiles.filter { $0.id != profile.id && !$0.windowRules.isEmpty }) { source in
                                Button(source.displayTitle) { copyRules(from: source) }
                            }
                        }
                    } header: {
                        Text("App rules")
                    }
                }
            }
            .formStyle(.grouped)
            .frame(minWidth: 380, idealWidth: 420)

            VStack(alignment: .leading, spacing: 8) {
                if let profile = editedProfile {
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

    /// Bağlı ekranlar "● bağlı", ana ekran ayrıca "ana" diye işaretlenir.
    private func profileLabel(_ profile: DisplayProfile) -> String {
        guard model.connectedProfileIDs.contains(profile.id) else { return profile.displayTitle }
        let isMain = profile.id == model.activeProfile?.id
        let tag = isMain ? String(localized: "connected, main") : String(localized: "connected")
        return "\(profile.displayTitle)  ● \(tag)"
    }

    private var windowProfileBinding: Binding<UUID?> {
        Binding(get: { editedProfileID }, set: { windowProfileID = $0 })
    }

    private func zoneCountLabel(_ profile: DisplayProfile) -> String {
        switch profile.windowZones.count {
        case 0: return String(localized: "Leave windows alone")
        case 1: return String(localized: "1 full-screen zone")
        default: return String(localized: "\(profile.windowZones.count) equal columns")
        }
    }

    private var zoneCount: Binding<Int> {
        Binding(
            get: { editedProfile?.windowZones.count ?? 0 },
            set: { count in
                updateProfile { profile in
                    let existing = profile.windowZones
                    guard count > 0 else {
                        profile.windowZones = []
                        profile.windowRules = []
                        return
                    }
                    let defaults = ["Left", "Center", "Right"]
                    let titles = (0..<count).map { position -> String in
                        if count == 1 { return "Full screen" }
                        if position < existing.count, existing.count > 1 { return existing[position].title }
                        return position < defaults.count ? defaults[position] : "\(position + 1)"
                    }
                    var zones = WindowZone.equalColumns(titles)
                    for position in zones.indices where position < existing.count { zones[position].id = existing[position].id }
                    profile.windowZones = zones
                    // Bölgesi kalmayan kurallar son bölgeye kaydırılır.
                    if let last = zones.last {
                        for ruleIndex in profile.windowRules.indices
                        where !zones.contains(where: { $0.id == profile.windowRules[ruleIndex].zoneID }) {
                            profile.windowRules[ruleIndex].zoneID = last.id
                        }
                    }
                }
            }
        )
    }

    private func zoneTitle(_ zoneID: UUID) -> Binding<String> {
        Binding(
            get: { editedProfile?.windowZones.first { $0.id == zoneID }?.displayTitle ?? "" },
            set: { title in
                updateProfile { profile in
                    guard let index = profile.windowZones.firstIndex(where: { $0.id == zoneID }) else { return }
                    profile.windowZones[index].title = title
                }
            }
        )
    }

    /// Bir bölgenin genişliğini değiştirir; farkı komşusundan alır, toplam hep %100 kalır.
    private func zoneWidth(_ zoneID: UUID) -> Binding<Int> {
        Binding(
            get: { editedProfile?.windowZones.first { $0.id == zoneID }?.widthPercent ?? 100 },
            set: { percent in
                updateProfile { profile in
                    var zones = profile.windowZones
                    guard zones.count > 1, let index = zones.firstIndex(where: { $0.id == zoneID }) else { return }
                    let neighbour = index == zones.count - 1 ? index - 1 : index + 1
                    let delta = Double(percent) / 100 - (zones[index].end - zones[index].start)
                    guard (zones[neighbour].end - zones[neighbour].start) - delta >= 0.1 else { return }
                    if neighbour > index { zones[index].end += delta } else { zones[index].start -= delta }
                    for position in zones.indices.dropFirst() { zones[position].start = zones[position - 1].end }
                    profile.windowZones = zones
                }
            }
        )
    }

    private func ruleZone(_ ruleID: UUID) -> Binding<UUID> {
        Binding(
            get: {
                let profile = editedProfile
                return profile?.windowRules.first { $0.id == ruleID }?.zoneID
                    ?? profile?.windowZones.first?.id ?? UUID()
            },
            set: { zoneID in
                updateProfile { profile in
                    guard let index = profile.windowRules.firstIndex(where: { $0.id == ruleID }) else { return }
                    profile.windowRules[index].zoneID = zoneID
                }
            }
        )
    }

    var addableApps: [(bundleID: String, name: String)] {
        let used = Set(editedProfile?.windowRules.map(\.bundleID) ?? [])
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
        guard let app = addableApps.first(where: { $0.bundleID == newRuleApp }) else { return }
        updateProfile { profile in
            guard !profile.windowZones.isEmpty else { return }
            let middle = profile.windowZones[profile.windowZones.count / 2]
            profile.windowRules.append(WindowRule(bundleID: app.bundleID, appName: app.name, zoneID: middle.id))
        }
        newRuleApp = ""
    }

    /// Başka bir ekranın kurallarını bu ekrana kopyalar; bölge sırası korunur.
    private func copyRules(from source: DisplayProfile) {
        updateProfile { profile in
            let zones = profile.windowZones
            guard !zones.isEmpty else { return }
            profile.windowRules = source.windowRules.map { rule in
                let position = source.windowZones.firstIndex { $0.id == rule.zoneID } ?? 0
                return WindowRule(bundleID: rule.bundleID, appName: rule.appName,
                                  zoneID: zones[min(position, zones.count - 1)].id)
            }
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
                                Text(verbatim: zone.displayTitle).font(.caption).bold()
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
