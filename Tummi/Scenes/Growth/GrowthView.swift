import SwiftUI
import Charts

final class GrowthStore: ObservableObject, GrowthDisplayLogic {
    @Published private(set) var viewModel: Growth.Load.ViewModel = .empty
    @Published var indicator: GrowthIndicator = .weight { didSet { load() } }

    private var interactor: GrowthBusinessLogic?

    init() {
        let presenter = GrowthPresenter()
        interactor = GrowthInteractor(presenter: presenter)
        presenter.view = self
    }

    func load() { interactor?.load(request: .init(indicator: indicator)) }

    func save(date: Date, weightKg: Double?, lengthCm: Double?, headCm: Double?) {
        interactor?.save(request: .init(date: date, weightKg: weightKg,
                                        lengthCm: lengthCm, headCm: headCm))
    }

    func delete(id: UUID) { interactor?.delete(id: id) }

    func displayGrowth(viewModel: Growth.Load.ViewModel) {
        self.viewModel = viewModel
    }
}

struct GrowthView: View {
    @StateObject private var store = GrowthStore()
    @State private var showsAdd = false

    var body: some View {
        let model = store.viewModel

        ScreenScaffold(
            title: String(localized: "Growth"),
            subtitle: String(localized: "WHO Child Growth Standards")
        ) {
            indicatorPicker

            if model.isEmpty {
                EmptyStateView(
                    symbol: "chart.xyaxis.line",
                    title: String(localized: "No measurements yet"),
                    message: String(localized: "Add a weight or a length and Tummi will plot it against the WHO curves for your baby's age and sex."),
                    actionTitle: String(localized: "Add a measurement"),
                    action: { showsAdd = true }
                )
                whoExplainer
            } else {
                latestCard(model)
                chartCard(model)
                historyCard(model)
                whoExplainer
            }
        } trailing: {
            Button { showsAdd = true } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.accent)
            }
        }
        .onAppear { store.load() }
        .sheet(isPresented: $showsAdd) {
            AddMeasurementSheet(units: StorageWorker.shared.settings().units) { date, weight, length, head in
                store.save(date: date, weightKg: weight, lengthCm: length, headCm: head)
            }
        }
    }

    private var indicatorPicker: some View {
        Picker("", selection: $store.indicator) {
            Text("Weight").tag(GrowthIndicator.weight)
            Text("Length").tag(GrowthIndicator.length)
            Text("Head").tag(GrowthIndicator.head)
        }
        .pickerStyle(.segmented)
    }

    private func latestCard(_ model: Growth.Load.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(model.latestValueText ?? "—")
                    .font(Theme.serif(32, .medium))
                    .foregroundStyle(Theme.ink)
                if let percentile = model.latestPercentileText {
                    Chip(title: percentile, systemImage: "chart.dots.scatter",
                         tint: model.bandKind == .watch ? Theme.amber : Theme.accent,
                         background: model.bandKind == .watch ? Theme.amberSoft : Theme.accentSoft)
                }
                Spacer()
                if let z = model.latestZText {
                    Text(z)
                        .font(Theme.rounded(12, .semibold))
                        .foregroundStyle(Theme.faint)
                }
            }
            if let band = model.bandText {
                Text(band)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .cardStyle()
    }

    private func chartCard(_ model: Growth.Load.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel("Against the WHO curves")
                Spacer()
                Text(model.axisLabel)
                    .font(Theme.rounded(11, .semibold))
                    .foregroundStyle(Theme.faint)
            }
            Chart {
                ForEach(model.curvePoints) { point in
                    LineMark(
                        x: .value("Month", point.month),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(by: .value("Series", point.series))
                    .lineStyle(StrokeStyle(lineWidth: point.series == String(localized: "median") ? 1.4 : 1,
                                           dash: point.series == String(localized: "median") ? [] : [4, 3]))
                }
                ForEach(model.childPoints) { point in
                    PointMark(
                        x: .value("Month", point.month),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(Theme.accent)
                    .symbolSize(60)
                }
                if model.childPoints.count > 1 {
                    ForEach(model.childPoints) { point in
                        LineMark(
                            x: .value("Month", point.month),
                            y: .value("Value", point.value),
                            series: .value("Series", "child")
                        )
                        .foregroundStyle(Theme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
            }
            .chartForegroundStyleScale(range: [Theme.hairline, Theme.faint, Theme.hairline])
            .chartLegend(.hidden)
            .chartXAxisLabel(String(localized: "months"), alignment: .trailing)
            .frame(height: 230)
        }
        .cardStyle()
    }

    private func historyCard(_ model: Growth.Load.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("History")
            VStack(spacing: 0) {
                ForEach(model.rows) { row in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.valueText)
                                .font(Theme.rounded(15, .medium))
                                .foregroundStyle(Theme.ink)
                            Text("\(row.dateText) · \(row.ageText)")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.faint)
                        }
                        Spacer()
                        if let percentile = row.percentileText {
                            Text(percentile)
                                .font(Theme.rounded(13, .semibold))
                                .foregroundStyle(Theme.secondary)
                        }
                    }
                    .padding(.vertical, 9)
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button(role: .destructive) { store.delete(id: row.id) } label: {
                            Label(String(localized: "Delete"), systemImage: "trash")
                        }
                    }
                    if row.id != model.rows.last?.id { Hairline() }
                }
            }
        }
        .cardStyle()
    }

    private var whoExplainer: some View {
        EvidenceCard(
            title: String(localized: "What a percentile means"),
            body: String(localized: "The 30th percentile means 30 of 100 healthy babies of the same age and sex weigh less. There is no good or bad number — a baby tracking steadily along the 15th is thriving, and a baby dropping from the 75th to the 25th is worth a conversation even though both numbers look fine."),
            sources: Evidence.sources(["who.growth2006"])
                .map { .init(id: $0.id, label: $0.citation, urlString: $0.urlString) },
            accentSymbol: "questionmark.circle"
        )
    }
}

struct AddMeasurementSheet: View {
    let units: UnitSystem
    let onSave: (Date, Double?, Double?, Double?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var weightText = ""
    @State private var lengthText = ""
    @State private var headText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel("Date")
                            DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                        }
                        field(String(localized: "Weight"),
                              units == .metric ? String(localized: "kg") : String(localized: "lb"),
                              $weightText)
                        field(String(localized: "Length"),
                              units == .metric ? String(localized: "cm") : String(localized: "in"),
                              $lengthText)
                        field(String(localized: "Head circumference"),
                              units == .metric ? String(localized: "cm") : String(localized: "in"),
                              $headText)

                        Text("Leave a field blank if you did not measure it. Length is measured lying down until 2 years.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.faint)

                        Button {
                            onSave(date, metric(weightText, isWeight: true),
                                   metric(lengthText, isWeight: false),
                                   metric(headText, isWeight: false))
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            dismiss()
                        } label: {
                            Text("Save")
                                .font(Theme.rounded(17, .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(Capsule().fill(Theme.accent))
                                .foregroundStyle(Theme.bg)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(Theme.gutter)
                }
            }
            .navigationTitle(String(localized: "Measurement"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
            }
            .keyboardDoneButton()
        }
    }

    private func field(_ title: String, _ suffix: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(LocalizedStringKey(title))
            HStack(spacing: 8) {
                TextField("—", text: text)
                    .keyboardType(.decimalPad)
                    .font(Theme.serif(26, .medium))
                    .frame(maxWidth: 130)
                Text(suffix)
                    .font(Theme.rounded(15, .medium))
                    .foregroundStyle(Theme.faint)
                Spacer()
            }
            Hairline()
        }
    }

    /// Everything is stored metric so that a later switch of unit preference does not
    /// silently reinterpret old measurements.
    private func metric(_ text: String, isWeight: Bool) -> Double? {
        guard let value = Double(text.replacingOccurrences(of: ",", with: ".")), value > 0 else {
            return nil
        }
        guard units == .imperial else { return value }
        return isWeight ? value / 2.20462 : value * 2.54
    }
}
