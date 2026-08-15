import Foundation

protocol LogBusinessLogic {
    func load(request: Log.Load.Request)
    func toggleSleep()
    func delete(row: Log.Load.ViewModel.Row)
}

final class LogInteractor: LogBusinessLogic {
    private let presenter: LogPresentationLogic
    private let worker: StorageWorker
    private var lastRequest = Log.Load.Request()

    init(presenter: LogPresentationLogic, worker: StorageWorker = .shared) {
        self.presenter = presenter
        self.worker = worker
    }

    func load(request: Log.Load.Request) {
        lastRequest = request
        guard let child = worker.activeChild() else {
            presenter.presentEmpty()
            return
        }
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
        let start = calendar.date(byAdding: .day, value: -request.days, to: end) ?? end

        presenter.presentLog(response: .init(
            child: child,
            units: worker.settings().units,
            feeds: worker.feedEntries(childId: child.id, from: start, to: end),
            diapers: worker.diaperEntries(childId: child.id, from: start, to: end),
            sleeps: worker.sleepEntries(childId: child.id, from: start, to: end),
            runningSleep: worker.runningSleep(childId: child.id)
        ))
    }

    /// One button for both ends of a nap: an open entry closes, otherwise a new one opens.
    func toggleSleep() {
        guard let child = worker.activeChild() else { return }
        if var running = worker.runningSleep(childId: child.id) {
            running.end = Date()
            worker.save(sleep: running)
        } else {
            worker.save(sleep: SleepEntry(childId: child.id, start: Date()))
        }
        load(request: lastRequest)
    }

    func delete(row: Log.Load.ViewModel.Row) {
        switch row.source {
        case .feed(let id): worker.deleteFeed(id: id)
        case .diaper(let id): worker.deleteDiaper(id: id)
        case .sleep(let id): worker.deleteSleep(id: id)
        }
        load(request: lastRequest)
    }
}
