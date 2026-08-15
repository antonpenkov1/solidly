import SwiftUI

/// The single place a feed is created or edited. Shared by Today's quick actions and the
/// Log tab so that a meal logged in a hurry and one edited later go through the same rules.
struct LogEntrySheet: View {
    let childId: UUID
    let units: UnitSystem
    let ageMonths: Double
    var existing: FeedEntry?
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var kind: FeedKind
    @State private var date: Date
    @State private var milkType: MilkType
    @State private var side: BreastSide
    @State private var amountText: String
    @State private var durationText: String
    @State private var foodIds: [String]
    @State private var acceptance: Acceptance
    @State private var reaction: ReactionSeverity
    @State private var note: String
    @State private var showsFoodPicker = false

    init(childId: UUID, units: UnitSystem, ageMonths: Double,
         existing: FeedEntry? = nil, initialKind: FeedKind = .solid,
         onSaved: @escaping () -> Void) {
        self.childId = childId
        self.units = units
        self.ageMonths = ageMonths
        self.existing = existing
        self.onSaved = onSaved

        _kind = State(initialValue: existing?.kind ?? initialKind)
        _date = State(initialValue: existing?.date ?? Date())
        _milkType = State(initialValue: existing?.milkType ?? .formula)
        _side = State(initialValue: existing?.side ?? .both)
        _amountText = State(initialValue: Self.initialAmount(existing, units: units))
        _durationText = State(initialValue: existing?.durationMin.map { String(format: "%.0f", $0) } ?? "")
        _foodIds = State(initialValue: existing?.foodIds ?? [])
        _acceptance = State(initialValue: existing?.acceptance ?? .ate)
        _reaction = State(initialValue: existing?.reaction ?? .noReaction)
        _note = State(initialValue: existing?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        kindPicker
                        timeRow
                        kindFields
                        noteField
                        saveButton
                        if existing != nil { deleteButton }
                    }
                    .padding(Theme.gutter)
                }
            }
            .navigationTitle(existing == nil ? String(localized: "Log") : String(localized: "Edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
            }
            .keyboardDoneButton()
            .sheet(isPresented: $showsFoodPicker) {
                FoodPickerSheet(selected: $foodIds, ageMonths: ageMonths)
            }
        }
    }

    // MARK: - Sections

    private var kindPicker: some View {
        Picker("", selection: $kind) {
            Text("Breast").tag(FeedKind.breast)
            Text("Bottle").tag(FeedKind.bottle)
            Text("Food").tag(FeedKind.solid)
            Text("Water").tag(FeedKind.water)
        }
        .pickerStyle(.segmented)
    }

    private var timeRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("When")
            DatePicker("", selection: $date, in: ...Date())
                .datePickerStyle(.compact)
                .labelsHidden()
        }
    }

    @ViewBuilder
    private var kindFields: some View {
        switch kind {
        case .breast:
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Side")
                    Picker("", selection: $side) {
                        Text("Left").tag(BreastSide.left)
                        Text("Right").tag(BreastSide.right)
                        Text("Both").tag(BreastSide.both)
                    }
                    .pickerStyle(.segmented)
                }
                numberField(title: String(localized: "Duration"),
                            suffix: String(localized: "min"),
                            text: $durationText,
                            chips: [5, 10, 15, 20, 30])
            }

        case .bottle:
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("What's in it")
                    Picker("", selection: $milkType) {
                        Text("Formula").tag(MilkType.formula)
                        Text("Expressed milk").tag(MilkType.breastMilk)
                    }
                    .pickerStyle(.segmented)
                }
                numberField(title: String(localized: "Amount"),
                            suffix: units == .metric ? String(localized: "ml") : String(localized: "fl oz"),
                            text: $amountText,
                            chips: units == .metric ? [60, 90, 120, 150, 180] : [2, 3, 4, 5, 6])
            }

        case .solid:
            VStack(alignment: .leading, spacing: 18) {
                foodsField
                numberField(title: String(localized: "Amount eaten"),
                            suffix: units == .metric ? String(localized: "g") : String(localized: "oz"),
                            text: $amountText,
                            chips: units == .metric ? [15, 30, 60, 90, 120] : [0.5, 1, 2, 3, 4])
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("How it went")
                    Picker("", selection: $acceptance) {
                        Text("Loved it").tag(Acceptance.loved)
                        Text("Ate it").tag(Acceptance.ate)
                        Text("Tasted").tag(Acceptance.tasted)
                        Text("Refused").tag(Acceptance.refused)
                    }
                    .pickerStyle(.segmented)
                    Text("Refusing is normal — it can take 10–15 offers of a new food before a child accepts it.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.faint)
                }
                reactionField
            }

        case .water:
            numberField(title: String(localized: "Amount"),
                        suffix: units == .metric ? String(localized: "ml") : String(localized: "fl oz"),
                        text: $amountText,
                        chips: units == .metric ? [20, 40, 60, 100] : [1, 2, 3, 4])

        case .supplement:
            EmptyView()
        }
    }

    private var foodsField: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Foods")
            Button {
                showsFoodPicker = true
            } label: {
                HStack {
                    if foodIds.isEmpty {
                        Text("Choose foods")
                            .foregroundStyle(Theme.faint)
                    } else {
                        Text(FoodLibrary.foods(foodIds).map { "\($0.emoji) \($0.name.text)" }
                            .joined(separator: ", "))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.faint)
                }
                .font(Theme.rounded(15, .medium))
                .cardStyle(padding: 13)
            }
            .buttonStyle(.plain)
        }
    }

    private var reactionField: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Any reaction")
            Picker("", selection: $reaction) {
                Text("None").tag(ReactionSeverity.noReaction)
                Text("Mild").tag(ReactionSeverity.mild)
                Text("Notable").tag(ReactionSeverity.notable)
            }
            .pickerStyle(.segmented)
            if reaction != .noReaction {
                Text("Trouble breathing, swelling of the face or lips, or repeated vomiting needs emergency care now — not a log entry.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.clay)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.claySoft))
            }
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Note")
            TextField(String(localized: "Optional"), text: $note, axis: .vertical)
                .font(.system(size: 15))
                .lineLimit(1...4)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: 1))
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("Save")
                .font(Theme.rounded(17, .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Capsule().fill(Theme.accent))
                .foregroundStyle(Theme.bg)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            if let existing { StorageWorker.shared.deleteFeed(id: existing.id) }
            onSaved()
            dismiss()
        } label: {
            Text("Delete entry")
                .font(Theme.rounded(15, .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.clay)
    }

    // MARK: - Field builder

    private func numberField(
        title: String, suffix: String, text: Binding<String>, chips: [Double]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(LocalizedStringKey(title))
            HStack(spacing: 6) {
                TextField("0", text: text)
                    .keyboardType(.decimalPad)
                    .font(Theme.serif(30, .medium))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: 130)
                Text(suffix)
                    .font(Theme.rounded(15, .medium))
                    .foregroundStyle(Theme.faint)
                Spacer()
            }
            Hairline()
            HStack(spacing: 8) {
                ForEach(chips, id: \.self) { chip in
                    Button {
                        text.wrappedValue = chip == chip.rounded()
                            ? String(format: "%.0f", chip)
                            : String(format: "%.1f", chip)
                    } label: {
                        Text(chip == chip.rounded()
                             ? String(format: "%.0f", chip)
                             : String(format: "%.1f", chip))
                            .font(Theme.rounded(14, .semibold))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Theme.accentSoft))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Save

    private func save() {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: "."))
        let duration = Double(durationText.replacingOccurrences(of: ",", with: "."))

        var entry = existing ?? FeedEntry(childId: childId, kind: kind)
        entry.childId = childId
        entry.kind = kind
        entry.date = date
        entry.note = note

        // Every stored amount is metric. Imperial is a display concern only, so a family
        // that switches units later still sees a consistent history.
        switch kind {
        case .breast:
            entry.side = side
            entry.durationMin = duration
            entry.volumeMl = nil
            entry.grams = nil
            entry.milkType = .breastMilk
            entry.foodIds = []
            entry.acceptance = nil
            entry.reaction = .noReaction
        case .bottle:
            entry.milkType = milkType
            entry.volumeMl = amount.map { units == .metric ? $0 : $0 * 29.5735 }
            entry.grams = nil
            entry.durationMin = nil
            entry.side = nil
            entry.foodIds = []
            entry.acceptance = nil
            entry.reaction = .noReaction
        case .solid:
            entry.grams = amount.map { units == .metric ? $0 : $0 * 28.3495 }
            entry.volumeMl = nil
            entry.durationMin = nil
            entry.side = nil
            entry.milkType = nil
            entry.foodIds = foodIds
            entry.acceptance = acceptance
            entry.reaction = reaction
        case .water:
            entry.volumeMl = amount.map { units == .metric ? $0 : $0 * 29.5735 }
            entry.grams = nil
            entry.durationMin = nil
            entry.side = nil
            entry.milkType = nil
            entry.foodIds = []
            entry.acceptance = nil
            entry.reaction = .noReaction
        case .supplement:
            break
        }

        StorageWorker.shared.save(feed: entry)
        AppRefresh.run()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onSaved()
        dismiss()
    }

    private static func initialAmount(_ entry: FeedEntry?, units: UnitSystem) -> String {
        guard let entry else { return "" }
        if let volume = entry.volumeMl {
            let value = units == .metric ? volume : volume / 29.5735
            return units == .metric ? String(format: "%.0f", value) : String(format: "%.1f", value)
        }
        if let grams = entry.grams {
            let value = units == .metric ? grams : grams / 28.3495
            return units == .metric ? String(format: "%.0f", value) : String(format: "%.1f", value)
        }
        return ""
    }
}
