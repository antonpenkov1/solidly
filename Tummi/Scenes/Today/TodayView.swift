import SwiftUI

final class TodayStore: ObservableObject, TodayDisplayLogic {
    @Published private(set) var viewModel: Today.Load.ViewModel = .empty
    private var interactor: TodayBusinessLogic?

    init() {
        let presenter = TodayPresenter()
        interactor = TodayInteractor(presenter: presenter)
        presenter.view = self
    }

    func load() { interactor?.load(request: .init()) }

    func displayToday(viewModel: Today.Load.ViewModel) {
        self.viewModel = viewModel
    }
}

struct TodayView: View {
    @StateObject private var store = TodayStore()
    @ObservedObject private var deepLink = DeepLink.shared
    @State private var sheetKind: FeedKind?
    @State private var showsSettings = false
    @State private var showsDiaper = false

    private var child: Child? { StorageWorker.shared.activeChild() }
    private var units: UnitSystem { StorageWorker.shared.settings().units }

    var body: some View {
        let model = store.viewModel

        ScreenScaffold(
            title: model.childName.isEmpty ? String(localized: "Today") : model.childName,
            subtitle: model.isEmpty ? nil : "\(model.ageText) · \(model.stageTitle)"
        ) {
            if model.isEmpty {
                EmptyStateView(
                    symbol: "sun.max",
                    title: String(localized: "No child yet"),
                    message: String(localized: "Add a baby in Settings to start tracking.")
                )
            } else {
                stageCard(model)
                quickActions
                if !model.metrics.isEmpty { metricsCard(model) }
                if let note = model.newFoodNote { newFoodBanner(note) }
                allergenCard(model)
                EvidenceCard(
                    title: model.focusTitle,
                    body: model.focusBody,
                    sources: model.focusSources.map {
                        .init(id: $0.id, label: $0.label, urlString: $0.urlString)
                    },
                    accentSymbol: "lightbulb"
                )
                recentCard(model)
                milestoneCard(model)
            }
        } trailing: {
            Button { showsSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.secondary)
            }
        }
        .onAppear {
            store.load()
            sheetKind = deepLink.consumeLogKind()
        }
        .onChange(of: deepLink.pendingLogKind) { _, kind in
            if kind != nil { sheetKind = deepLink.consumeLogKind() }
        }
        .sheet(item: $sheetKind) { kind in
            if let child {
                LogEntrySheet(
                    childId: child.id, units: units,
                    ageMonths: child.ageMonths(), initialKind: kind
                ) { store.load() }
            }
        }
        .sheet(isPresented: $showsDiaper) {
            if let child {
                DiaperSheet(childId: child.id) { store.load() }
            }
        }
        .sheet(isPresented: $showsSettings) {
            SettingsView { store.load() }
        }
    }

    // MARK: - Cards

    private func stageCard(_ model: Today.Load.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            FlowLayout(spacing: 8, lineSpacing: 6) {
                Chip(title: model.stageRange, systemImage: "calendar")
                if let sleep = model.sleepRunningText {
                    Chip(title: sleep, systemImage: "moon.zzz.fill",
                         tint: Theme.indigo, background: Theme.indigoSoft)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(model.headline)
                .font(Theme.serif(19, .regular))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let note = model.overrideNote {
                HStack(spacing: 6) {
                    Image(systemName: "stethoscope")
                        .font(.system(size: 11, weight: .semibold))
                    Text(note).font(Theme.rounded(12, .medium))
                }
                .foregroundStyle(Theme.indigo)
            }
        }
        .cardStyle()
    }

    private var quickActions: some View {
        HStack(spacing: 9) {
            quickButton("drop.fill", String(localized: "Breast")) { sheetKind = .breast }
            quickButton("waterbottle", String(localized: "Bottle")) { sheetKind = .bottle }
            quickButton("fork.knife", String(localized: "Food")) { sheetKind = .solid }
            quickButton("cup.and.saucer", String(localized: "Water")) { sheetKind = .water }
            quickButton("hare", String(localized: "Nappy")) { showsDiaper = true }
        }
    }

    private func quickButton(_ symbol: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .medium))
                Text(title)
                    .font(Theme.rounded(11, .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.accentSoft))
        }
        .buttonStyle(.plain)
    }

    private func metricsCard(_ model: Today.Load.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionLabel("Today so far")
                Spacer()
                Text("guidance range")
                    .font(Theme.rounded(11, .medium))
                    .foregroundStyle(Theme.faint)
            }
            ForEach(model.metrics) { metric in
                MetricTile(
                    title: metric.title,
                    valueText: metric.valueText,
                    targetText: metric.targetText,
                    fraction: metric.fraction,
                    isWithin: metric.isWithin,
                    tint: tint(for: metric.tint)
                )
            }
        }
        .cardStyle()
    }

    private func newFoodBanner(_ note: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
            Text(note)
                .font(Theme.rounded(13, .medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Theme.accent)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Theme.accentSoft))
    }

    @ViewBuilder
    private func allergenCard(_ model: Today.Load.ViewModel) -> some View {
        if let title = model.allergenTitle, let detail = model.allergenDetail {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.amber)
                    Text(title)
                        .font(Theme.rounded(16, .semibold))
                        .foregroundStyle(Theme.ink)
                }
                Text(detail)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                SourceChipsRow(items: Evidence
                    .sources(["niaid.peanut2017", "leap2015"])
                    .map { .init(id: $0.id, label: $0.citation, urlString: $0.urlString) })
            }
            .cardStyle()
        }
    }

    private func recentCard(_ model: Today.Load.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Recent")
            if model.recentRows.isEmpty {
                Text("Nothing logged today yet.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.faint)
            } else {
                VStack(spacing: 0) {
                    ForEach(model.recentRows) { row in
                        HStack(spacing: 12) {
                            Image(systemName: row.symbol)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.accent)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.title)
                                    .font(Theme.rounded(15, .medium))
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(1)
                                if let detail = row.detail {
                                    Text(detail)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.faint)
                                }
                            }
                            Spacer()
                            if row.hasReaction {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.amber)
                            }
                            Text(row.timeText)
                                .font(Theme.rounded(12, .medium))
                                .foregroundStyle(Theme.faint)
                        }
                        .padding(.vertical, 9)
                        if row.id != model.recentRows.last?.id { Hairline() }
                    }
                }
            }
        }
        .cardStyle()
    }

    @ViewBuilder
    private func milestoneCard(_ model: Today.Load.ViewModel) -> some View {
        if let title = model.milestoneTitle, let detail = model.milestoneDetail {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionLabel("Coming up")
                    Spacer()
                    if let when = model.milestoneWhen {
                        Text(when)
                            .font(Theme.rounded(11, .semibold))
                            .foregroundStyle(Theme.faint)
                    }
                }
                Text(title)
                    .font(Theme.rounded(16, .semibold))
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .cardStyle()
        }
    }

    private func tint(for tint: Today.Load.ViewModel.Metric.Tint) -> Color {
        switch tint {
        case .accent: return Theme.accent
        case .indigo: return Theme.indigo
        case .amber: return Theme.amber
        }
    }
}

extension FeedKind: Identifiable {
    public var id: String { rawValue }
}
