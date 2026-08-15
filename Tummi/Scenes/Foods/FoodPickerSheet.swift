import SwiftUI

struct FoodPickerSheet: View {
    @Binding var selected: [String]
    let ageMonths: Double

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [Food] {
        FoodLibrary.search(query).filter { !$0.isAvoid || !query.isEmpty }
    }

    private var grouped: [(group: FoodGroup, foods: [Food])] {
        FoodGroup.allCases.compactMap { group in
            let foods = results.filter { $0.group == group }
            return foods.isEmpty ? nil : (group, foods)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18, pinnedViews: [.sectionHeaders]) {
                        if !selected.isEmpty {
                            selectedSummary
                        }
                        ForEach(grouped, id: \.group) { section in
                            Section {
                                VStack(spacing: 0) {
                                    ForEach(section.foods) { food in
                                        row(food)
                                        if food.id != section.foods.last?.id { Hairline() }
                                    }
                                }
                                .cardStyle(padding: 0)
                            } header: {
                                Text(section.group.title.text)
                                    .font(Theme.rounded(12, .bold))
                                    .tracking(0.8)
                                    .textCase(.uppercase)
                                    .foregroundStyle(Theme.faint)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 6)
                                    .background(Theme.bg)
                            }
                        }
                    }
                    .padding(Theme.gutter)
                }
            }
            .searchable(text: $query, prompt: String(localized: "Search foods"))
            .navigationTitle(String(localized: "Foods"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) { dismiss() }
                        .font(Theme.rounded(16, .semibold))
                }
            }
        }
    }

    private var selectedSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("In this meal")
            FlowChips(items: FoodLibrary.foods(selected)) { food in
                selected.removeAll { $0 == food.id }
            }
        }
    }

    private func row(_ food: Food) -> some View {
        let isSelected = selected.contains(food.id)
        let availability = food.availability(atMonths: ageMonths, overrideMonth: nil)

        return Button {
            if isSelected {
                selected.removeAll { $0 == food.id }
            } else {
                selected.append(food.id)
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 12) {
                Text(food.emoji).font(.system(size: 22))
                VStack(alignment: .leading, spacing: 3) {
                    Text(food.name.text)
                        .font(Theme.rounded(15, .medium))
                        .foregroundStyle(Theme.ink)
                    FlowLayout(spacing: 6, lineSpacing: 4) {
                        switch availability {
                        case .notYet:
                            Chip(title: String(localized: "Not before \(food.hardLimitMonth ?? 12) mo"),
                                 systemImage: "hand.raised.fill",
                                 tint: Theme.clay, background: Theme.claySoft)
                        case .soon:
                            Chip(title: String(localized: "Usually from \(food.earliestMonth) mo"),
                                 systemImage: "clock",
                                 tint: Theme.amber, background: Theme.amberSoft)
                        case .ready:
                            EmptyView()
                        }
                        if let allergen = food.allergen {
                            Chip(title: allergen.title.text, systemImage: "exclamationmark.circle",
                                 tint: Theme.amber, background: Theme.amberSoft)
                        }
                        if food.choking == .high {
                            Chip(title: String(localized: "Cut safely"), systemImage: "scissors",
                                 tint: Theme.clay, background: Theme.claySoft)
                        }
                    }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.hairline)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Wrapping row of removable food chips.
struct FlowChips: View {
    let items: [Food]
    let onRemove: (Food) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items) { food in
                    Button { onRemove(food) } label: {
                        HStack(spacing: 5) {
                            Text("\(food.emoji) \(food.name.text)")
                                .font(Theme.rounded(13, .semibold))
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Theme.accentSoft))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
}
