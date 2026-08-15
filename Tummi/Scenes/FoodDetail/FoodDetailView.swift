import SwiftUI

final class FoodDetailStore: ObservableObject, FoodDetailDisplayLogic {
    @Published private(set) var viewModel: FoodDetail.Load.ViewModel = .empty
    private var interactor: FoodDetailBusinessLogic?

    init() {
        let presenter = FoodDetailPresenter()
        interactor = FoodDetailInteractor(presenter: presenter)
        presenter.view = self
    }

    func load(foodId: String) { interactor?.load(request: .init(foodId: foodId)) }

    func setOverride(foodId: String, month: Double?, attribution: String) {
        interactor?.setOverride(request: .init(foodId: foodId, month: month, attribution: attribution))
    }

    func displayFood(viewModel: FoodDetail.Load.ViewModel) {
        self.viewModel = viewModel
    }
}

struct FoodDetailView: View {
    let food: Food
    let onChange: () -> Void

    @StateObject private var store = FoodDetailStore()
    @State private var showsOverride = false
    @State private var showsLog = false
    @Environment(\.openURL) private var openURL

    private var child: Child? { StorageWorker.shared.activeChild() }

    var body: some View {
        let model = store.viewModel

        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header(model)
                    statusCard(model)
                    servingCard(model)
                    if let allergen = model.allergenText { flagCard("exclamationmark.circle", allergen, Theme.amber, Theme.amberSoft) }
                    if let choking = model.chokingText { flagCard("scissors", choking, Theme.clay, Theme.claySoft) }
                    if let caution = model.cautionText { cautionCard(caution) }
                    if !model.nutrientTitles.isEmpty { nutrientsCard(model) }
                    if let history = model.historyText { historyCard(history) }
                    sourcesCard(model)
                    actions
                }
                .padding(Theme.gutter)
                .padding(.bottom, 30)
                .readableWidth()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.load(foodId: food.id) }
        .sheet(isPresented: $showsOverride) {
            OverrideSheet(
                title: String(localized: "When may we start \(food.name.text)?"),
                explanation: String(localized: "If your paediatrician gave you a different age, put it here. Tummi will use your date and still show you what the published guidance says."),
                unitLabel: String(localized: "months"),
                initialValue: Double(food.earliestMonth),
                onSave: { month, attribution in
                    store.setOverride(foodId: food.id, month: month, attribution: attribution)
                    onChange()
                },
                onClear: {
                    store.setOverride(foodId: food.id, month: nil, attribution: "")
                    onChange()
                }
            )
        }
        .sheet(isPresented: $showsLog) {
            if let child {
                LogEntrySheet(
                    childId: child.id,
                    units: StorageWorker.shared.settings().units,
                    ageMonths: child.ageMonths(),
                    existing: FeedEntry(childId: child.id, kind: .solid, foodIds: [food.id]),
                    initialKind: .solid
                ) {
                    store.load(foodId: food.id)
                    onChange()
                }
            }
        }
    }

    // MARK: - Sections

    private func header(_ model: FoodDetail.Load.ViewModel) -> some View {
        HStack(spacing: 14) {
            Text(model.emoji).font(.system(size: 44))
            VStack(alignment: .leading, spacing: 3) {
                Text(model.name)
                    .font(Theme.serif(28, .semibold))
                    .foregroundStyle(Theme.ink)
                Text(model.groupTitle)
                    .font(Theme.rounded(13, .medium))
                    .foregroundStyle(Theme.faint)
            }
            Spacer()
        }
    }

    private func statusCard(_ model: FoodDetail.Load.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: statusSymbol(model.statusKind))
                    .font(.system(size: 14, weight: .semibold))
                Text(model.statusText)
                    .font(Theme.rounded(17, .semibold))
            }
            .foregroundStyle(statusTint(model.statusKind))
            Text(model.statusDetail)
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let override = model.overrideText {
                HStack(spacing: 6) {
                    Image(systemName: "stethoscope").font(.system(size: 11, weight: .semibold))
                    Text(override).font(Theme.rounded(12, .semibold))
                }
                .foregroundStyle(Theme.indigo)
                .padding(.top, 2)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
            .fill(statusBackground(model.statusKind)))
    }

    private func servingCard(_ model: FoodDetail.Load.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(LocalizedStringKey(model.servingTitle))
                Text(model.servingText)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Hairline()
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(LocalizedStringKey(model.otherServingTitle))
                Text(model.otherServingText)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .cardStyle()
    }

    private func flagCard(_ symbol: String, _ text: String, _ tint: Color, _ background: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(background))
    }

    private func cautionCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("Worth knowing")
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle()
    }

    private func nutrientsCard(_ model: FoodDetail.Load.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Rich in")
            FlowLayout(spacing: 7, lineSpacing: 6) {
                ForEach(model.nutrientTitles, id: \.self) { title in
                    Chip(title: title, systemImage: "leaf")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .cardStyle()
    }

    private func historyCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("Your baby's history")
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondary)
        }
        .cardStyle()
    }

    private func sourcesCard(_ model: FoodDetail.Load.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel("Where this comes from")
            ForEach(model.sources) { source in
                Button {
                    if let url = URL(string: source.urlString) { openURL(url) }
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text(source.citation)
                                .font(Theme.rounded(13, .bold))
                                .foregroundStyle(Theme.accent)
                            Text(source.kindLabel)
                                .font(Theme.rounded(10, .semibold))
                                .foregroundStyle(Theme.faint)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Theme.bg))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Theme.faint)
                        }
                        Text(source.takeaway)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(source.title)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.faint)
                            .multilineTextAlignment(.leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if source.id != model.sources.last?.id { Hairline() }
            }
        }
        .cardStyle()
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if !food.isAvoid {
                Button { showsLog = true } label: {
                    Label(String(localized: "Log this food"), systemImage: "plus")
                        .font(Theme.rounded(16, .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(Theme.accent))
                        .foregroundStyle(Theme.bg)
                }
                .buttonStyle(.plain)
            }
            Button { showsOverride = true } label: {
                Label(String(localized: "My paediatrician said otherwise"), systemImage: "stethoscope")
                    .font(Theme.rounded(15, .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(Theme.indigoSoft))
                    .foregroundStyle(Theme.indigo)
            }
            .buttonStyle(.plain)
        }
    }

    private func statusSymbol(_ kind: FoodDetail.Load.ViewModel.StatusKind) -> String {
        switch kind {
        case .ready: return "checkmark.circle.fill"
        case .soon: return "clock.fill"
        case .blocked: return "hand.raised.fill"
        }
    }

    private func statusTint(_ kind: FoodDetail.Load.ViewModel.StatusKind) -> Color {
        switch kind {
        case .ready: return Theme.accent
        case .soon: return Theme.amber
        case .blocked: return Theme.clay
        }
    }

    private func statusBackground(_ kind: FoodDetail.Load.ViewModel.StatusKind) -> Color {
        switch kind {
        case .ready: return Theme.accentSoft
        case .soon: return Theme.amberSoft
        case .blocked: return Theme.claySoft
        }
    }
}
