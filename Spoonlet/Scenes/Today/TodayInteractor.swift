import Foundation

protocol TodayBusinessLogic {
    func load(request: Today.Load.Request)
}

final class TodayInteractor: TodayBusinessLogic {
    private let presenter: TodayPresentationLogic
    private let worker: StorageWorker

    init(presenter: TodayPresentationLogic, worker: StorageWorker = .shared) {
        self.presenter = presenter
        self.worker = worker
    }

    func load(request: Today.Load.Request) {
        guard let child = worker.activeChild() else {
            presenter.presentEmpty()
            return
        }

        let settings = worker.settings()
        let months = child.ageMonths(on: request.date)
        let stage = AgeStage.stage(forMonths: months)
        let entries = worker.feedEntries(childId: child.id, on: request.date)
        let intros = worker.foodIntros(childId: child.id)
        let weight = worker.latestWeight(childId: child.id)
        let overrides = settings.showsPediatricianPlan ? worker.overrides(childId: child.id) : [:]

        let profile = Guidance.profile(for: stage)
        // One focus card a day, rotating through the stage's set, so the screen has
        // something new to say without nagging with all of it at once.
        let dayIndex = Calendar.current.ordinality(of: .day, in: .era, for: request.date) ?? 0
        let focusCard = profile.cards[dayIndex % max(1, profile.cards.count)]

        presenter.presentToday(response: .init(
            child: child,
            date: request.date,
            ageDays: child.ageDays(on: request.date),
            months: months,
            stage: stage,
            targets: Guidance.targets(forMonths: months, weightKg: weight, overrides: overrides),
            totals: FeedMath.totals(entries),
            recent: Array(entries.prefix(6)),
            intros: intros,
            latestWeight: weight,
            units: settings.units,
            focusCard: focusCard,
            nextMilestone: Guidance.upcomingMilestones(months: months, limit: 1).first,
            allergenGap: allergenGap(months: months, intros: intros, on: request.date),
            newFoodIds: FeedMath.newFoodIds(entries: entries, intros: intros, on: request.date),
            runningSleep: worker.runningSleep(childId: child.id)
        ))
    }

    /// Picks the single allergen worth mentioning today.
    ///
    /// Priority goes to one that was introduced and then quietly dropped, because losing
    /// tolerance after stopping is the failure mode the prevention trials warn about —
    /// ahead of allergens never started at all.
    private func allergenGap(
        months: Double, intros: [FoodIntro], on date: Date
    ) -> (allergen: Allergen, status: Guidance.AllergenStatus)? {
        guard months >= 4 else { return nil }

        let statuses = Allergen.allCases.map { ($0, Guidance.allergenStatus($0, intros: intros, on: date)) }

        // Among the lapsed ones, surface whichever has gone longest without an exposure —
        // enum order would otherwise always nominate dairy and never the peanut that was
        // tried once a month ago and forgotten.
        let lapsed = statuses.filter { _, status in
            if case .introduced = status { return true }
            return false
        }
        if !lapsed.isEmpty {
            let stalest = lapsed.min { left, right in
                lastExposure(left.0, intros: intros) < lastExposure(right.0, intros: intros)
            }
            if let stalest { return stalest }
        }
        if let notStarted = statuses.first(where: { _, status in status == .notStarted }) {
            return notStarted
        }
        return nil
    }

    private func lastExposure(_ allergen: Allergen, intros: [FoodIntro]) -> Date {
        let foodIds = Set(FoodLibrary.all.filter { $0.allergen == allergen && !$0.isAvoid }.map(\.id))
        return intros.filter { foodIds.contains($0.foodId) }.map(\.lastOffered).max() ?? .distantPast
    }
}
