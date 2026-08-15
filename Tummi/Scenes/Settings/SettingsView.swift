import SwiftUI

struct SettingsView: View {
    let onChange: () -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearance") private var appearanceRaw = AppearanceMode.system.rawValue

    @State private var settings = StorageWorker.shared.settings()
    @State private var child = StorageWorker.shared.activeChild()
    @State private var name = ""
    @State private var birthDate = Date()
    @State private var sex: ChildSex = .girl
    @State private var showsExport = false
    @State private var exportURL: URL?
    @State private var showsDeleteConfirm = false
    @State private var permissionDenied = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        childCard
                        preferencesCard
                        remindersCard
                        pediatricianCard
                        dataCard
                        aboutCard
                        disclaimerCard
                    }
                    .padding(Theme.gutter)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle(String(localized: "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) { persist(); dismiss() }
                        .font(Theme.rounded(16, .semibold))
                }
            }
            .keyboardDoneButton()
            .onAppear(perform: loadChild)
            .sheet(isPresented: $showsExport) {
                if let exportURL {
                    ShareSheet(items: [exportURL])
                }
            }
            .alert(String(localized: "Delete all data?"), isPresented: $showsDeleteConfirm) {
                Button(String(localized: "Cancel"), role: .cancel) {}
                Button(String(localized: "Delete"), role: .destructive) {
                    if let child { StorageWorker.shared.deleteChild(id: child.id) }
                    onChange()
                    dismiss()
                }
            } message: {
                Text("Every feed, measurement and note for this child will be removed from this device. This cannot be undone.")
            }
        }
    }

    // MARK: - Cards

    private var childCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel("Your baby")
            VStack(alignment: .leading, spacing: 6) {
                Text("Name").font(Theme.rounded(13, .medium)).foregroundStyle(Theme.secondary)
                TextField(String(localized: "Baby"), text: $name)
                    .font(Theme.rounded(16, .medium))
                Hairline()
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Date of birth").font(Theme.rounded(13, .medium)).foregroundStyle(Theme.secondary)
                DatePicker("", selection: $birthDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Sex").font(Theme.rounded(13, .medium)).foregroundStyle(Theme.secondary)
                Picker("", selection: $sex) {
                    Text("Girl").tag(ChildSex.girl)
                    Text("Boy").tag(ChildSex.boy)
                }
                .pickerStyle(.segmented)
            }
        }
        .cardStyle()
    }

    private var preferencesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel("Preferences")
            VStack(alignment: .leading, spacing: 6) {
                Text("Units").font(Theme.rounded(13, .medium)).foregroundStyle(Theme.secondary)
                Picker("", selection: $settings.units) {
                    Text("Metric").tag(UnitSystem.metric)
                    Text("Imperial").tag(UnitSystem.imperial)
                }
                .pickerStyle(.segmented)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Appearance").font(Theme.rounded(13, .medium)).foregroundStyle(Theme.secondary)
                Picker("", selection: Binding(
                    get: { AppearanceMode(rawValue: appearanceRaw) ?? .system },
                    set: { mode in appearanceRaw = mode.rawValue; mode.apply() }
                )) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .cardStyle()
    }

    private var remindersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Reminders")
            Text("Three reminders, and nothing else. Tummi will never nag you about feeds — you already know when your baby is hungry.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.secondary)

            reminderToggle(
                title: String(localized: "Allergen upkeep"),
                detail: String(localized: "Weekly, only when something introduced has been quietly dropped"),
                isOn: $settings.allergenReminders
            )
            Hairline()
            reminderToggle(
                title: String(localized: "Weigh-in nudge"),
                detail: String(localized: "When it has been a while since the last measurement"),
                isOn: $settings.growthReminders
            )
            Hairline()
            reminderToggle(
                title: String(localized: "New stage"),
                detail: String(localized: "At 4, 6, 9, 12 and 24 months, when the guidance changes"),
                isOn: $settings.stageReminders
            )

            if permissionDenied {
                Text("Notifications are turned off for Tummi in iOS Settings, so these will not appear.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.clay)
            }
        }
        .cardStyle()
    }

    private func reminderToggle(
        title: String, detail: String, isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: Binding(
            get: { isOn.wrappedValue },
            set: { newValue in
                isOn.wrappedValue = newValue
                if newValue { requestPermissionIfNeeded() }
                persistRemindersOnly()
            }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.rounded(15, .medium))
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.faint)
            }
        }
    }

    private var pediatricianCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Your paediatrician's plan")
            Toggle(isOn: $settings.showsPediatricianPlan) {
                Text("Follow my doctor's numbers")
                    .font(Theme.rounded(15, .medium))
            }
            Text("When this is on, the amounts and introduction ages you entered replace the published ranges throughout the app. The guidance stays visible underneath so you always see both.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.secondary)
            Button {
                if let child { StorageWorker.shared.clearAllOverrides(childId: child.id) }
                onChange()
            } label: {
                Text("Reset all my overrides")
                    .font(Theme.rounded(14, .medium))
                    .foregroundStyle(Theme.indigo)
            }
            .buttonStyle(.plain)
        }
        .cardStyle()
    }

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Your data")
            Text("Tummi has no account and no server. Everything lives in this app's storage on this device, and nothing is sent anywhere unless you export it yourself.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.secondary)
            Button(action: export) {
                Label(String(localized: "Export as JSON"), systemImage: "square.and.arrow.up")
                    .font(Theme.rounded(15, .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
            Hairline()
            Button { showsDeleteConfirm = true } label: {
                Label(String(localized: "Delete all data"), systemImage: "trash")
                    .font(Theme.rounded(15, .medium))
                    .foregroundStyle(Theme.clay)
            }
            .buttonStyle(.plain)
        }
        .cardStyle()
    }

    private var aboutCard: some View {
        NavigationLink {
            EvidenceLibraryView()
        } label: {
            HStack {
                Image(systemName: "text.book.closed")
                Text("Every source Tummi uses")
                    .font(Theme.rounded(15, .semibold))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Theme.accent)
            .padding(15)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.accentSoft))
        }
        .buttonStyle(.plain)
    }

    private var disclaimerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Important")
            Text("Tummi summarises published infant feeding guidance. It is not a medical device, it does not diagnose, and it cannot examine your baby. Always check with your paediatrician before making decisions about feeding, supplements or allergen introduction — and seek urgent care for breathing difficulty, facial swelling, repeated vomiting after a food, or a baby who stops feeding.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle()
    }

    // MARK: - Actions

    private func loadChild() {
        settings = StorageWorker.shared.settings()
        child = StorageWorker.shared.activeChild()
        if let child {
            name = child.name
            birthDate = child.birthDate
            sex = child.sex
        }
        Task { permissionDenied = await Reminders.authorizationStatus() == .denied }
    }

    private func persist() {
        if var child {
            child.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            child.birthDate = birthDate
            child.sex = sex
            StorageWorker.shared.save(child: child)
        }
        StorageWorker.shared.save(settings: settings)
        Reminders.reschedule()
        onChange()
    }

    /// Toggles take effect immediately rather than on Done: flipping a switch and seeing
    /// nothing happen until you leave the screen reads as a bug.
    private func persistRemindersOnly() {
        var stored = StorageWorker.shared.settings()
        stored.allergenReminders = settings.allergenReminders
        stored.growthReminders = settings.growthReminders
        stored.stageReminders = settings.stageReminders
        StorageWorker.shared.save(settings: stored)
        Reminders.reschedule()
    }

    private func requestPermissionIfNeeded() {
        Task {
            let status = await Reminders.authorizationStatus()
            switch status {
            case .notDetermined:
                _ = await Reminders.requestAuthorization()
                permissionDenied = await Reminders.authorizationStatus() == .denied
            case .denied:
                permissionDenied = true
            default:
                permissionDenied = false
            }
            Reminders.reschedule()
        }
    }

    private func export() {
        guard let child, let data = StorageWorker.shared.exportJSON(childId: child.id) else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tummi-export.json")
        try? data.write(to: url)
        exportURL = url
        showsExport = true
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
