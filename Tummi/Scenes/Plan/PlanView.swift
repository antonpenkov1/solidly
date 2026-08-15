import SwiftUI

final class PlanStore: ObservableObject, PlanDisplayLogic {
    @Published private(set) var viewModel: Plan.Load.ViewModel = .empty
    private var interactor: PlanBusinessLogic?

    init() {
        let presenter = PlanPresenter()
        interactor = PlanInteractor(presenter: presenter)
        presenter.view = self
    }

    func load() { interactor?.load(request: .init()) }

    func togglePlan(_ enabled: Bool) {
        interactor?.togglePediatricianPlan(request: .init(enabled: enabled))
    }

    func setTarget(_ key: OverrideKey, value: Double?, attribution: String) {
        interactor?.setTarget(request: .init(key: key, value: value, attribution: attribution))
    }

    func displayPlan(viewModel: Plan.Load.ViewModel) {
        self.viewModel = viewModel
    }
}

struct PlanView: View {
    @StateObject private var store = PlanStore()
    @State private var editingTarget: Plan.Load.ViewModel.TargetRow?
    @State private var showsEvidenceLibrary = false

    var body: some View {
        NavigationStack {
            let model = store.viewModel

            ScreenScaffold(
                title: String(localized: "Plan"),
                subtitle: model.isEmpty ? nil : "\(model.stageTitle) · \(model.stageRange)"
            ) {
                if model.isEmpty {
                    EmptyStateView(
                        symbol: "checklist",
                        title: String(localized: "No plan yet"),
                        message: String(localized: "Add a baby to see the guidance for their age.")
                    )
                } else {
                    headlineCard(model)
                    targetsCard(model)
                    ForEach(model.cards) { card in
                        EvidenceCard(
                            title: card.title,
                            body: card.body,
                            sources: card.sources.map {
                                .init(id: $0.id, label: $0.label, urlString: $0.urlString)
                            }
                        )
                    }
                    milestonesCard(model)
                    evidenceLibraryButton
                }
            } trailing: {
                Button { showsEvidenceLibrary = true } label: {
                    Image(systemName: "text.book.closed")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Theme.secondary)
                }
            }
            .navigationDestination(isPresented: $showsEvidenceLibrary) {
                EvidenceLibraryView()
            }
        }
        .onAppear {
            store.load()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-OpenSources") {
                showsEvidenceLibrary = true
            }
            #endif
        }
        .sheet(item: $editingTarget) { row in
            OverrideSheet(
                title: row.title,
                explanation: String(localized: "Enter the number your paediatrician gave you. Tummi will use it as the plan and keep showing the published range alongside, so you always know both."),
                unitLabel: unitLabel(row),
                initialValue: 0,
                onSave: { value, attribution in
                    if let key = overrideKey(row) {
                        store.setTarget(key, value: value, attribution: attribution)
                    }
                },
                onClear: {
                    if let key = overrideKey(row) {
                        store.setTarget(key, value: nil, attribution: "")
                    }
                }
            )
        }
    }

    // MARK: - Cards

    private func headlineCard(_ model: Plan.Load.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Chip(title: model.stageRange, systemImage: "calendar")
            Text(model.headline)
                .font(Theme.serif(19, .regular))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle()
    }

    private func targetsCard(_ model: Plan.Load.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                SectionLabel("Daily targets")
                Spacer()
                Toggle("", isOn: Binding(
                    get: { model.usesPediatricianPlan },
                    set: { store.togglePlan($0) }
                ))
                .labelsHidden()
                .scaleEffect(0.85)
            }

            Text("Follow my paediatrician's numbers")
                .font(Theme.rounded(13, .medium))
                .foregroundStyle(Theme.secondary)

            if let banner = model.overrideBanner {
                HStack(spacing: 7) {
                    Image(systemName: "stethoscope").font(.system(size: 11, weight: .semibold))
                    Text(banner).font(Theme.rounded(12, .medium))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Theme.indigo)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.indigoSoft))
            }

            VStack(spacing: 0) {
                ForEach(model.targetRows) { row in
                    Button {
                        if row.overrideKind != .none && model.usesPediatricianPlan {
                            editingTarget = row
                        }
                    } label: {
                        HStack {
                            Text(row.title)
                                .font(Theme.rounded(15, .medium))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Text(row.valueText)
                                .font(Theme.serif(16, .medium))
                                .foregroundStyle(row.isOverridden ? Theme.indigo : Theme.secondary)
                            if row.overrideKind != .none && model.usesPediatricianPlan {
                                Image(systemName: row.isOverridden ? "stethoscope" : "pencil")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(row.isOverridden ? Theme.indigo : Theme.hairline)
                            }
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if row.id != model.targetRows.last?.id { Hairline() }
                }
            }

            SourceChipsRow(items: model.targetSources.map {
                .init(id: $0.id, label: $0.label, urlString: $0.urlString)
            })
        }
        .cardStyle()
    }

    private func milestonesCard(_ model: Plan.Load.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel("Timeline")
            ForEach(model.milestones) { milestone in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: milestone.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 15))
                        .foregroundStyle(milestone.isDone ? Theme.accent : Theme.hairline)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(milestone.title)
                                .font(Theme.rounded(15, .semibold))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Text(milestone.whenText)
                                .font(Theme.rounded(11, .semibold))
                                .foregroundStyle(Theme.faint)
                        }
                        Text(milestone.detail)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        SourceChipsRow(items: milestone.sources.map {
                            .init(id: $0.id, label: $0.label, urlString: $0.urlString)
                        })
                    }
                }
                if milestone.id != model.milestones.last?.id { Hairline() }
            }
        }
        .cardStyle()
    }

    private var evidenceLibraryButton: some View {
        Button { showsEvidenceLibrary = true } label: {
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

    private func unitLabel(_ row: Plan.Load.ViewModel.TargetRow) -> String {
        switch row.overrideKind {
        case .dailyMilkMl: return String(localized: "ml")
        case .mealsPerDay: return String(localized: "meals")
        case .perMealGrams: return String(localized: "g")
        case .none: return ""
        }
    }

    private func overrideKey(_ row: Plan.Load.ViewModel.TargetRow) -> OverrideKey? {
        switch row.overrideKind {
        case .dailyMilkMl: return .dailyMilkMl
        case .mealsPerDay: return .mealsPerDay
        case .perMealGrams: return .perMealGrams
        case .none: return nil
        }
    }
}

/// Every source in one place, so a parent can read the whole basis of the app in one sitting
/// — and hand the list to a doctor.
struct EvidenceLibraryView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Tummi does not have opinions of its own. Everything it says traces to one of these.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.secondary)
                        .padding(.top, 6)

                    ForEach(Evidence.all) { source in
                        Button {
                            if let url = source.url { openURL(url) }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Text(source.citation)
                                        .font(Theme.rounded(14, .bold))
                                        .foregroundStyle(Theme.accent)
                                    Text(source.kind.label.text)
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
                                Text(source.title)
                                    .font(Theme.rounded(14, .semibold))
                                    .foregroundStyle(Theme.ink)
                                    .multilineTextAlignment(.leading)
                                Text(source.takeaway.text)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.secondary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .cardStyle()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Theme.gutter)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle(String(localized: "Sources"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
