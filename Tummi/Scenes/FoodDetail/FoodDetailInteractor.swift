import Foundation

protocol FoodDetailBusinessLogic {
    func load(request: FoodDetail.Load.Request)
    func setOverride(request: FoodDetail.SetOverride.Request)
}

final class FoodDetailInteractor: FoodDetailBusinessLogic {
    private let presenter: FoodDetailPresentationLogic
    private let worker: StorageWorker
    private var foodId: String = ""

    init(presenter: FoodDetailPresentationLogic, worker: StorageWorker = .shared) {
        self.presenter = presenter
        self.worker = worker
    }

    func load(request: FoodDetail.Load.Request) {
        foodId = request.foodId
        guard let food = FoodLibrary.food(request.foodId), let child = worker.activeChild() else {
            presenter.presentEmpty()
            return
        }
        let months = child.ageMonths()
        let override = worker.overrides(childId: child.id)[.foodEarliestMonth(food.id)]

        presenter.presentFood(response: .init(
            food: food,
            months: months,
            stage: AgeStage.stage(forMonths: months),
            intro: worker.foodIntro(childId: child.id, foodId: food.id),
            overrideMonth: override?.value,
            overrideAttribution: override?.attribution,
            availability: food.availability(atMonths: months, overrideMonth: override?.value)
        ))
    }

    func setOverride(request: FoodDetail.SetOverride.Request) {
        guard let child = worker.activeChild() else { return }
        if let month = request.month {
            worker.setOverride(childId: child.id, key: .foodEarliestMonth(request.foodId),
                               value: month, attribution: request.attribution)
        } else {
            worker.clearOverride(childId: child.id, key: .foodEarliestMonth(request.foodId))
        }
        load(request: .init(foodId: request.foodId))
    }
}
