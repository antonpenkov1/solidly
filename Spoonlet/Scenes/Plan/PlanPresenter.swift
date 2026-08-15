import Foundation

protocol PlanPresentationLogic {
    func presentPlan(response: Plan.Load.Response)
    func presentEmpty()
}

protocol PlanDisplayLogic: AnyObject {
    func displayPlan(viewModel: Plan.Load.ViewModel)
}

final class PlanPresenter: PlanPresentationLogic {
    weak var view: PlanDisplayLogic?

    func presentEmpty() {
        view?.displayPlan(viewModel: .empty)
    }

    func presentPlan(response: Plan.Load.Response) {
        let targets = response.targets
        let units = response.units
        var rows: [Plan.Load.ViewModel.TargetRow] = []

        if let feeds = targets.milkFeedsPerDay {
            rows.append(.init(
                id: "milkFeeds", title: String(localized: "Milk feeds a day"),
                valueText: Fmt.intRange(feeds), isOverridden: false, overrideKind: .none
            ))
        }
        if let milk = targets.dailyMilkMl {
            rows.append(.init(
                id: "milk", title: String(localized: "Milk a day"),
                valueText: Fmt.range(milk, units: units, unit: .ml),
                isOverridden: targets.overriddenFields.contains(.dailyMilkMl),
                overrideKind: .dailyMilkMl
            ))
        }
        if let meals = targets.mealsPerDay {
            rows.append(.init(
                id: "meals", title: String(localized: "Meals a day"),
                valueText: Fmt.intRange(meals),
                isOverridden: targets.overriddenFields.contains(.mealsPerDay),
                overrideKind: .mealsPerDay
            ))
        }
        if let snacks = targets.snacksPerDay, snacks.upperBound > 0 {
            rows.append(.init(
                id: "snacks", title: String(localized: "Snacks a day"),
                valueText: Fmt.intRange(snacks), isOverridden: false, overrideKind: .none
            ))
        }
        if let perMeal = targets.perMealGrams {
            rows.append(.init(
                id: "perMeal", title: String(localized: "Food per meal"),
                valueText: Fmt.range(perMeal, units: units, unit: .g),
                isOverridden: targets.overriddenFields.contains(.perMealGrams),
                overrideKind: .perMealGrams
            ))
        }
        if let kcal = targets.energyFromSolidsKcal {
            rows.append(.init(
                id: "kcal", title: String(localized: "Energy from solids"),
                valueText: String(localized: "about \(kcal) kcal a day"),
                isOverridden: false, overrideKind: .none
            ))
        }

        let banner: String?
        if response.usesPediatricianPlan && targets.isOverridden {
            let attribution = targets.attribution?.trimmingCharacters(in: .whitespaces) ?? ""
            banner = attribution.isEmpty
                ? String(localized: "Your paediatrician's numbers are in use.")
                : String(localized: "Your paediatrician's numbers are in use — \(attribution).")
        } else if response.usesPediatricianPlan {
            banner = String(localized: "Tap any number below to replace it with the one your doctor gave you.")
        } else {
            banner = nil
        }

        var milestones = response.upcoming.map { milestone in
            Plan.Load.ViewModel.MilestoneRow(
                id: milestone.id, title: milestone.title.text, detail: milestone.detail.text,
                whenText: whenText(milestone, months: response.months),
                isDone: false, sources: chips(milestone.sourceIds)
            )
        }
        milestones += response.done.reversed().prefix(4).map { milestone in
            Plan.Load.ViewModel.MilestoneRow(
                id: milestone.id, title: milestone.title.text, detail: milestone.detail.text,
                whenText: String(localized: "already applies"),
                isDone: true, sources: chips(milestone.sourceIds)
            )
        }

        view?.displayPlan(viewModel: .init(
            isEmpty: false,
            stageTitle: response.stage.title.text,
            stageRange: response.stage.rangeLabel.text,
            headline: response.profile.headline.text,
            targetRows: rows,
            targetSources: chips(targets.sourceIds),
            overrideBanner: banner,
            usesPediatricianPlan: response.usesPediatricianPlan,
            cards: response.profile.cards.map { card in
                .init(id: card.id, title: card.title.text, body: card.body.text,
                      sources: chips(card.sourceIds))
            },
            milestones: milestones
        ))
    }

    private func whenText(_ milestone: Guidance.Milestone, months: Double) -> String {
        let away = milestone.atMonths - months
        if away <= 1 { return String(localized: "within a month") }
        if away < 3 { return String(localized: "in \(Int(away.rounded())) months") }
        return String(localized: "at \(Int(milestone.atMonths)) months")
    }

    private func chips(_ ids: [String]) -> [Plan.Load.ViewModel.SourceChipsRowItem] {
        Evidence.sources(ids).map {
            .init(id: $0.id, label: $0.citation, urlString: $0.urlString)
        }
    }
}
