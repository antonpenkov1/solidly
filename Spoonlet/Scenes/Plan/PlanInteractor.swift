import Foundation

protocol PlanBusinessLogic {
    func load(request: Plan.Load.Request)
    func togglePediatricianPlan(request: Plan.Toggle.Request)
    func setTarget(request: Plan.SetTarget.Request)
}

final class PlanInteractor: PlanBusinessLogic {
    private let presenter: PlanPresentationLogic
    private let worker: StorageWorker

    init(presenter: PlanPresentationLogic, worker: StorageWorker = .shared) {
        self.presenter = presenter
        self.worker = worker
    }

    func load(request: Plan.Load.Request) {
        guard let child = worker.activeChild() else {
            presenter.presentEmpty()
            return
        }
        let settings = worker.settings()
        let months = child.ageMonths()
        let stage = AgeStage.stage(forMonths: months)
        let overrides = worker.overrides(childId: child.id)
        let effectiveOverrides = settings.showsPediatricianPlan ? overrides : [:]

        presenter.presentPlan(response: .init(
            child: child,
            months: months,
            stage: stage,
            profile: Guidance.profile(for: stage),
            targets: Guidance.targets(
                forMonths: months,
                weightKg: worker.latestWeight(childId: child.id),
                overrides: effectiveOverrides
            ),
            units: settings.units,
            usesPediatricianPlan: settings.showsPediatricianPlan,
            overrides: overrides,
            done: Guidance.currentMilestones(months: months),
            upcoming: Guidance.upcomingMilestones(months: months, limit: 6)
        ))
    }

    func togglePediatricianPlan(request: Plan.Toggle.Request) {
        var settings = worker.settings()
        settings.showsPediatricianPlan = request.enabled
        worker.save(settings: settings)
        load(request: .init())
    }

    func setTarget(request: Plan.SetTarget.Request) {
        guard let child = worker.activeChild() else { return }
        if let value = request.value {
            worker.setOverride(childId: child.id, key: request.key,
                               value: value, attribution: request.attribution)
            // Entering a doctor's number implies wanting to follow it; switching the plan on
            // here saves a parent from setting a value that silently does nothing.
            var settings = worker.settings()
            if !settings.showsPediatricianPlan {
                settings.showsPediatricianPlan = true
                worker.save(settings: settings)
            }
        } else {
            worker.clearOverride(childId: child.id, key: request.key)
        }
        load(request: .init())
    }
}
