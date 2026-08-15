import SwiftUI

final class LogStore: ObservableObject, LogDisplayLogic {
    @Published private(set) var viewModel: Log.Load.ViewModel = .empty
    private var interactor: LogBusinessLogic?

    init() {
        let presenter = LogPresenter()
        interactor = LogInteractor(presenter: presenter)
        presenter.view = self
    }

    func load() { interactor?.load(request: .init()) }
    func toggleSleep() { interactor?.toggleSleep() }
    func delete(_ row: Log.Load.ViewModel.Row) { interactor?.delete(row: row) }

    func displayLog(viewModel: Log.Load.ViewModel) {
        self.viewModel = viewModel
    }
}

struct LogView: View {
    @StateObject private var store = LogStore()
    @State private var showsNewEntry = false
    @State private var editing: FeedEntry?

    private var child: Child? { StorageWorker.shared.activeChild() }
    private var units: UnitSystem { StorageWorker.shared.settings().units }

    var body: some View {
        let model = store.viewModel

        ScreenScaffold(title: String(localized: "Log"), subtitle: String(localized: "Last 30 days")) {
            sleepButton(model)

            if model.isEmpty {
                EmptyStateView(
                    symbol: "list.bullet",
                    title: String(localized: "Nothing logged yet"),
                    message: String(localized: "Tap the plus to record a feed, a nappy or a nap.")
                )
            } else {
                ForEach(model.sections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(section.title)
                                .font(Theme.rounded(15, .bold))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Text(section.summary)
                                .font(Theme.rounded(12, .medium))
                                .foregroundStyle(Theme.faint)
                        }
                        VStack(spacing: 0) {
                            ForEach(section.rows) { row in
                                rowView(row)
                                if row.id != section.rows.last?.id { Hairline() }
                            }
                        }
                        .cardStyle(padding: 0)
                    }
                }
            }
        } trailing: {
            Button { showsNewEntry = true } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.accent)
            }
        }
        .onAppear { store.load() }
        .sheet(isPresented: $showsNewEntry) {
            if let child {
                LogEntrySheet(childId: child.id, units: units,
                              ageMonths: child.ageMonths()) { store.load() }
            }
        }
        .sheet(item: $editing) { entry in
            if let child {
                LogEntrySheet(childId: child.id, units: units,
                              ageMonths: child.ageMonths(), existing: entry) { store.load() }
            }
        }
    }

    private func sleepButton(_ model: Log.Load.ViewModel) -> some View {
        Button {
            store.toggleSleep()
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: model.runningSleepText == nil ? "moon.zzz" : "sun.max")
                    .font(.system(size: 16, weight: .medium))
                Text(model.runningSleepText ?? String(localized: "Start a nap"))
                    .font(Theme.rounded(15, .semibold))
                Spacer()
                if model.runningSleepText != nil {
                    Text("Wake up")
                        .font(Theme.rounded(13, .semibold))
                }
            }
            .foregroundStyle(Theme.indigo)
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.indigoSoft))
        }
        .buttonStyle(.plain)
    }

    private func rowView(_ row: Log.Load.ViewModel.Row) -> some View {
        HStack(spacing: 12) {
            Image(systemName: row.symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(Theme.rounded(15, .medium))
                    .foregroundStyle(Theme.ink)
                if let detail = row.detail {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.faint)
                        .lineLimit(2)
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
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .onTapGesture {
            if case .feed(let id) = row.source, let child {
                editing = StorageWorker.shared
                    .recentFeedEntries(childId: child.id, limit: 500)
                    .first { $0.id == id }
            }
        }
        .contextMenu {
            Button(role: .destructive) { store.delete(row) } label: {
                Label(String(localized: "Delete"), systemImage: "trash")
            }
        }
    }
}
