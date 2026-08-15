import SwiftUI

final class FoodsStore: ObservableObject, FoodsDisplayLogic {
    @Published private(set) var viewModel: Foods.Load.ViewModel = .empty
    @Published var query = "" { didSet { load() } }
    @Published var filter: Foods.Filter = .all { didSet { load() } }

    private var interactor: FoodsBusinessLogic?

    init() {
        let presenter = FoodsPresenter()
        interactor = FoodsInteractor(presenter: presenter)
        presenter.view = self
    }

    func load() {
        interactor?.load(request: .init(query: query, filter: filter))
    }

    func displayFoods(viewModel: Foods.Load.ViewModel) {
        self.viewModel = viewModel
    }
}

struct FoodsView: View {
    @StateObject private var store = FoodsStore()
    @State private var selectedFoodId: String?

    var body: some View {
        NavigationStack {
            let model = store.viewModel

            ScreenScaffold(title: String(localized: "Foods"), subtitle: model.progressText) {
                filterRow
                if !model.allergenPills.isEmpty && store.filter == .all && store.query.isEmpty {
                    allergenTracker(model)
                }
                if model.isEmpty {
                    EmptyStateView(
                        symbol: "magnifyingglass",
                        title: String(localized: "Nothing here"),
                        message: String(localized: "Try another search or filter.")
                    )
                } else {
                    ForEach(model.sections) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(LocalizedStringKey(section.title))
                            VStack(spacing: 0) {
                                ForEach(section.rows) { row in
                                    Button { selectedFoodId = row.id } label: { rowView(row) }
                                        .buttonStyle(.plain)
                                    if row.id != section.rows.last?.id { Hairline() }
                                }
                            }
                            .cardStyle(padding: 0)
                        }
                    }
                }
            }
            .searchable(text: $store.query, prompt: String(localized: "Search foods"))
            .navigationDestination(item: $selectedFoodId) { id in
                if let food = FoodLibrary.food(id) {
                    FoodDetailView(food: food) { store.load() }
                }
            }
        }
        .onAppear {
            store.load()
            applyLaunchArguments()
        }
    }

    /// `-OpenFood peanut` jumps straight to a food's detail screen, for screenshots and
    /// for checking the citation layout without tapping through the library.
    private func applyLaunchArguments() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-OpenFood"), index + 1 < arguments.count,
           FoodLibrary.food(arguments[index + 1]) != nil {
            selectedFoodId = arguments[index + 1]
        }
        #endif
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Foods.Filter.allCases, id: \.self) { filter in
                    let isSelected = store.filter == filter
                    Button { store.filter = filter } label: {
                        Text(filter.title.text)
                            .font(Theme.rounded(13, .semibold))
                            .foregroundStyle(isSelected ? Theme.bg : Theme.secondary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(isSelected ? Theme.accent : Theme.card))
                            .overlay(Capsule().stroke(Theme.hairline, lineWidth: isSelected ? 0 : 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func allergenTracker(_ model: Foods.Load.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Allergen exposure")
            Text("Regular repeat exposure is what the prevention trials tested — roughly twice a week, not one taste.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(model.allergenPills) { pill in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(pill.title)
                                .font(Theme.rounded(13, .semibold))
                            Text(pill.detail)
                                .font(Theme.rounded(11, .medium))
                                .opacity(0.75)
                        }
                        .foregroundStyle(pillTint(pill.state))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(pillBackground(pill.state)))
                    }
                }
                .padding(.vertical, 2)
            }
            SourceChipsRow(items: Evidence
                .sources(["niaid.peanut2017", "leap2015", "espghan.cf2017"])
                .map { .init(id: $0.id, label: $0.citation, urlString: $0.urlString) })
        }
        .cardStyle()
    }

    private func rowView(_ row: Foods.Load.ViewModel.Row) -> some View {
        HStack(spacing: 12) {
            Text(row.emoji).font(.system(size: 22))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(row.name)
                        .font(Theme.rounded(15, .medium))
                        .foregroundStyle(Theme.ink)
                    if row.isIntroduced {
                        Image(systemName: row.hadReaction
                              ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(row.hadReaction ? Theme.amber : Theme.accent)
                    }
                }
                if !row.badges.isEmpty {
                    FlowLayout(spacing: 5, lineSpacing: 4) {
                        ForEach(Array(row.badges.enumerated()), id: \.offset) { _, badge in
                            badgeView(badge)
                        }
                    }
                }
            }
            Spacer()
            if let exposures = row.exposuresText {
                Text(exposures)
                    .font(Theme.rounded(11, .medium))
                    .foregroundStyle(Theme.faint)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.hairline)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func badgeView(_ badge: Foods.Load.ViewModel.Row.Badge) -> some View {
        switch badge {
        case .notYet(let text):
            Chip(title: text, systemImage: "hand.raised.fill", tint: Theme.clay, background: Theme.claySoft)
        case .soon(let text):
            Chip(title: text, systemImage: "clock", tint: Theme.amber, background: Theme.amberSoft)
        case .allergen(let text):
            Chip(title: text, systemImage: "exclamationmark.circle", tint: Theme.amber, background: Theme.amberSoft)
        case .choking(let text):
            Chip(title: text, systemImage: "scissors", tint: Theme.clay, background: Theme.claySoft)
        case .pediatrician(let text):
            Chip(title: text, systemImage: "stethoscope", tint: Theme.indigo, background: Theme.indigoSoft)
        }
    }

    private func pillTint(_ state: Foods.Load.ViewModel.AllergenPill.State) -> Color {
        switch state {
        case .notStarted: return Theme.secondary
        case .introduced: return Theme.amber
        case .maintained: return Theme.accent
        case .reacted: return Theme.clay
        }
    }

    private func pillBackground(_ state: Foods.Load.ViewModel.AllergenPill.State) -> Color {
        switch state {
        case .notStarted: return Theme.card
        case .introduced: return Theme.amberSoft
        case .maintained: return Theme.accentSoft
        case .reacted: return Theme.claySoft
        }
    }
}
