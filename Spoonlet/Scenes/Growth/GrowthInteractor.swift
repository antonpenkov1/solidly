import Foundation

protocol GrowthBusinessLogic {
    func load(request: Growth.Load.Request)
    func save(request: Growth.Save.Request)
    func delete(id: UUID)
}

final class GrowthInteractor: GrowthBusinessLogic {
    private let presenter: GrowthPresentationLogic
    private let worker: StorageWorker
    private var indicator: GrowthIndicator = .weight

    init(presenter: GrowthPresentationLogic, worker: StorageWorker = .shared) {
        self.presenter = presenter
        self.worker = worker
    }

    func load(request: Growth.Load.Request) {
        indicator = request.indicator
        guard let child = worker.activeChild() else {
            presenter.presentEmpty()
            return
        }
        presenter.presentGrowth(response: .init(
            child: child,
            indicator: request.indicator,
            units: worker.settings().units,
            points: worker.growthPoints(childId: child.id),
            ageMonths: child.ageMonths()
        ))
    }

    func save(request: Growth.Save.Request) {
        guard let child = worker.activeChild() else { return }
        let point = GrowthPoint(
            childId: child.id, date: request.date,
            weightKg: request.weightKg, lengthCm: request.lengthCm, headCm: request.headCm
        )
        guard !point.isEmpty else { return }
        worker.save(growth: point)
        // A new weight moves the millilitres-per-kilogram milk range, which the widget shows.
        AppRefresh.run(worker: worker)
        load(request: .init(indicator: indicator))
    }

    func delete(id: UUID) {
        worker.deleteGrowth(id: id)
        load(request: .init(indicator: indicator))
    }
}
