import Foundation

protocol FoodsPresentationLogic {
    func presentFoods(response: Foods.Load.Response)
    func presentEmpty()
}

protocol FoodsDisplayLogic: AnyObject {
    func displayFoods(viewModel: Foods.Load.ViewModel)
}

final class FoodsPresenter: FoodsPresentationLogic {
    weak var view: FoodsDisplayLogic?

    func presentEmpty() {
        view?.displayFoods(viewModel: .empty)
    }

    func presentFoods(response: Foods.Load.Response) {
        let sections = FoodGroup.allCases.compactMap { group -> Foods.Load.ViewModel.Section? in
            let rows = response.foods
                .filter { $0.group == group }
                .map { row($0, response: response) }
            guard !rows.isEmpty else { return nil }
            return .init(id: group.rawValue, title: group.title.text, rows: rows)
        }

        let triedCount = response.intros.count
        let libraryCount = FoodLibrary.all.filter { !$0.isAvoid }.count

        view?.displayFoods(viewModel: .init(
            sections: sections,
            allergenPills: response.allergenSummary.map(pill),
            progressText: String(format: String(localized: "%1$lld of %2$lld foods tried"),
                                 triedCount, libraryCount),
            isEmpty: sections.isEmpty
        ))
    }

    private func row(_ food: Food, response: Foods.Load.Response) -> Foods.Load.ViewModel.Row {
        let overrideMonth = response.overrides[.foodEarliestMonth(food.id)]?.value
        let availability = food.availability(atMonths: response.months, overrideMonth: overrideMonth)
        let intro = response.intros[food.id]

        var badges: [Foods.Load.ViewModel.Row.Badge] = []
        switch availability {
        case .notYet:
            badges.append(.notYet(String(localized: "Not before \(food.hardLimitMonth ?? 12) mo")))
        case .soon:
            let month = Int((overrideMonth ?? Double(food.earliestMonth)).rounded())
            badges.append(.soon(String(localized: "From \(month) mo")))
        case .ready:
            break
        }
        if overrideMonth != nil {
            badges.append(.pediatrician(String(localized: "Your doctor's date")))
        }
        if let allergen = food.allergen {
            badges.append(.allergen(allergen.title.text))
        }
        if food.choking == .high {
            badges.append(.choking(String(localized: "Cut safely")))
        }

        return .init(
            id: food.id,
            emoji: food.emoji,
            name: food.name.text,
            badges: badges,
            exposuresText: intro.map { intro in
                intro.exposures == 1
                    ? String(localized: "tried once")
                    : String(localized: "\(intro.exposures) times")
            },
            isIntroduced: intro != nil,
            hadReaction: intro.map { $0.worstReaction != .noReaction } ?? false
        )
    }

    private func pill(
        _ allergen: Allergen, _ status: Guidance.AllergenStatus
    ) -> Foods.Load.ViewModel.AllergenPill {
        let state: Foods.Load.ViewModel.AllergenPill.State
        let detail: String
        switch status {
        case .notStarted:
            state = .notStarted
            detail = String(localized: "not started")
        case .introduced(let exposures):
            state = .introduced
            detail = String(localized: "\(exposures)×, keep going")
        case .maintained(let exposures):
            state = .maintained
            detail = String(localized: "\(exposures)×, regular")
        case .reacted:
            state = .reacted
            detail = String(localized: "reaction logged")
        }
        return .init(id: allergen.rawValue, title: allergen.title.text,
                     detail: detail, state: state)
    }
}
