import Foundation

protocol FoodsBusinessLogic {
    func load(request: Foods.Load.Request)
}

final class FoodsInteractor: FoodsBusinessLogic {
    private let presenter: FoodsPresentationLogic
    private let worker: StorageWorker

    init(presenter: FoodsPresentationLogic, worker: StorageWorker = .shared) {
        self.presenter = presenter
        self.worker = worker
    }

    func load(request: Foods.Load.Request) {
        guard let child = worker.activeChild() else {
            presenter.presentEmpty()
            return
        }
        let months = child.ageMonths()
        let introList = worker.foodIntros(childId: child.id)
        let intros = Dictionary(introList.map { ($0.foodId, $0) }, uniquingKeysWith: { first, _ in first })
        let overrides = worker.overrides(childId: child.id)

        var foods = FoodLibrary.search(request.query)

        switch request.filter {
        case .all:
            break
        case .readyNow:
            foods = foods.filter {
                $0.availability(atMonths: months, overrideMonth: overrideMonth($0, overrides)) == .ready
                    && !$0.isAvoid
            }
        case .allergens:
            foods = foods.filter { $0.allergen != nil && !$0.isAvoid }
        case .notTried:
            foods = foods.filter { intros[$0.id] == nil && !$0.isAvoid }
        case .introduced:
            foods = foods.filter { intros[$0.id] != nil }
        }

        presenter.presentFoods(response: .init(
            months: months,
            foods: foods,
            intros: intros,
            overrides: overrides,
            filter: request.filter,
            allergenSummary: Allergen.allCases.map {
                ($0, Guidance.allergenStatus($0, intros: introList))
            }
        ))
    }

    private func overrideMonth(_ food: Food, _ overrides: [OverrideKey: CareOverride]) -> Double? {
        overrides[.foodEarliestMonth(food.id)]?.value
    }
}
