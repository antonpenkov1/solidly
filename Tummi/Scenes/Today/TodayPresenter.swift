import Foundation

protocol TodayPresentationLogic {
    func presentToday(response: Today.Load.Response)
    func presentEmpty()
}

protocol TodayDisplayLogic: AnyObject {
    func displayToday(viewModel: Today.Load.ViewModel)
}

final class TodayPresenter: TodayPresentationLogic {
    weak var view: TodayDisplayLogic?

    func presentEmpty() {
        view?.displayToday(viewModel: .empty)
    }

    func presentToday(response: Today.Load.Response) {
        let units = response.units

        let totals = response.totals
        let dayEmpty = totals.milkFeeds == 0 && totals.solidMeals == 0 && totals.waterMl == 0

        view?.displayToday(viewModel: .init(
            isEmpty: false,
            isDayEmpty: dayEmpty,
            dayEmptyMessage: dayEmptyMessage(response),
            childName: response.child.name,
            ageText: ageText(response),
            stageTitle: response.stage.title.text,
            stageRange: response.stage.rangeLabel.text,
            headline: Guidance.profile(for: response.stage).headline.text,
            metrics: metrics(response, units: units),
            overrideNote: overrideNote(response),
            focusTitle: response.focusCard.title.text,
            focusBody: response.focusCard.body.text,
            focusSources: sourceChips(response.focusCard.sourceIds),
            allergenTitle: allergenTitle(response),
            allergenDetail: allergenDetail(response),
            newFoodNote: newFoodNote(response),
            recentRows: response.recent.map { row($0, units: units) },
            sleepRunningText: response.runningSleep.map {
                String(localized: "Sleeping for \(Fmt.duration($0.duration))")
            },
            milestoneTitle: response.nextMilestone?.title.text,
            milestoneDetail: response.nextMilestone?.detail.text,
            milestoneWhen: response.nextMilestone.map { milestone in
                let monthsAway = milestone.atMonths - response.months
                if monthsAway <= 1 { return String(localized: "in a few weeks") }
                return String(localized: "at \(Int(milestone.atMonths)) months")
            }
        ))
    }

    // MARK: - Pieces

    /// Says what today's ranges will be, without pretending the parent has missed them.
    private func dayEmptyMessage(_ response: Today.Load.Response) -> String {
        let units = response.units
        let targets = response.targets

        if let perMeal = targets.perMealGrams, let meals = targets.mealsPerDay {
            let dayLow = perMeal.lowerBound * Double(meals.lowerBound)
            let dayHigh = perMeal.upperBound * Double(meals.upperBound)
            return String(
                format: String(localized: "Today's guidance is %1$@ meals and about %2$@ of food. Log a feed and Solidly will start tracking against it."),
                Fmt.intRange(meals),
                Fmt.range(dayLow...dayHigh, units: units, unit: .g)
            )
        }
        if let feeds = targets.milkFeedsPerDay {
            return String(
                format: String(localized: "Today's guidance is %1$@ milk feeds. Log one and Solidly will start tracking against it."),
                Fmt.intRange(feeds)
            )
        }
        return String(localized: "Log a feed and Solidly will start tracking it against the guidance for this age.")
    }

    private func ageText(_ response: Today.Load.Response) -> String {
        let age = Fmt.age(days: response.child.correctedAgeDays(on: response.date))
        guard response.child.isPreterm else { return age }
        return String(localized: "\(age) corrected")
    }

    private func metrics(_ response: Today.Load.Response, units: UnitSystem) -> [Today.Load.ViewModel.Metric] {
        var metrics: [Today.Load.ViewModel.Metric] = []
        let totals = response.totals
        let targets = response.targets

        // Milk. A fully breastfed day has no millilitres, so it is shown as feeds instead
        // of a zero that would read as "your baby ate nothing".
        if totals.hasMeasurableMilkVolume, let range = targets.dailyMilkMl {
            let standing = FeedMath.standing(value: totals.milkMl, in: range)
            metrics.append(.init(
                id: "milk",
                title: String(localized: "Milk"),
                valueText: Fmt.ml(totals.milkMl, units: units),
                targetText: Fmt.range(range, units: units, unit: .ml),
                fraction: standing.fraction,
                isWithin: standing.isWithin,
                tint: .indigo
            ))
        } else if let feeds = targets.milkFeedsPerDay {
            let standing = FeedMath.standing(
                value: Double(totals.milkFeeds),
                in: Double(feeds.lowerBound)...Double(feeds.upperBound)
            )
            metrics.append(.init(
                id: "milkFeeds",
                title: String(localized: "Milk feeds"),
                valueText: "\(totals.milkFeeds)",
                targetText: Fmt.intRange(feeds),
                fraction: standing.fraction,
                isWithin: standing.isWithin,
                tint: .indigo
            ))
        }

        // Solids, expressed both as meals and as the amount eaten — the amount is the part
        // no other tracker shows against guidance.
        if let mealRange = targets.mealsPerDay {
            let standing = FeedMath.standing(
                value: Double(totals.solidMeals),
                in: Double(mealRange.lowerBound)...Double(mealRange.upperBound)
            )
            metrics.append(.init(
                id: "meals",
                title: String(localized: "Meals"),
                valueText: "\(totals.solidMeals)",
                targetText: Fmt.intRange(mealRange),
                fraction: standing.fraction,
                isWithin: standing.isWithin,
                tint: .accent
            ))
        }

        if let perMeal = targets.perMealGrams {
            // Widest honest range: fewest meals at the smaller portion through to the most
            // meals at the larger one. Anchoring both ends to the same meal count would
            // make a perfectly normal day read as over-target.
            let meals = targets.mealsPerDay ?? 1...1
            let dayLow = perMeal.lowerBound * Double(meals.lowerBound)
            let dayHigh = perMeal.upperBound * Double(meals.upperBound)
            let dayRange = dayLow...dayHigh
            let standing = FeedMath.standing(value: totals.solidGrams, in: dayRange)
            metrics.append(.init(
                id: "solids",
                title: String(localized: "Food eaten"),
                valueText: Fmt.grams(totals.solidGrams, units: units),
                targetText: Fmt.range(dayRange, units: units, unit: .g),
                fraction: standing.fraction,
                isWithin: standing.isWithin,
                tint: .accent
            ))
        }

        return metrics
    }

    private func overrideNote(_ response: Today.Load.Response) -> String? {
        guard response.targets.isOverridden else { return nil }
        let attribution = response.targets.attribution?.trimmingCharacters(in: .whitespaces) ?? ""
        return attribution.isEmpty
            ? String(localized: "Following your paediatrician's numbers.")
            : String(localized: "Following your paediatrician's numbers — \(attribution).")
    }

    private func allergenTitle(_ response: Today.Load.Response) -> String? {
        guard let gap = response.allergenGap else { return nil }
        switch gap.status {
        case .notStarted:
            return String(localized: "Not tried yet: \(gap.allergen.title.text)")
        case .introduced:
            return String(localized: "Keep going with \(gap.allergen.title.text)")
        case .maintained, .reacted:
            return nil
        }
    }

    private func allergenDetail(_ response: Today.Load.Response) -> String? {
        guard let gap = response.allergenGap else { return nil }
        switch gap.status {
        case .notStarted:
            return String(localized: "Introduce one new allergen at a time, at home and earlier in the day, so you have hours of daylight to watch.")
        case .introduced(let exposures):
            return String(localized: "\(exposures) exposures so far. The prevention trials relied on eating it regularly — roughly twice a week — not on a single taste.")
        case .maintained, .reacted:
            return nil
        }
    }

    private func newFoodNote(_ response: Today.Load.Response) -> String? {
        let names = FoodLibrary.foods(response.newFoodIds).map { $0.name.text }
        guard !names.isEmpty else { return nil }
        if names.count == 1 {
            return String(localized: "First time trying \(names[0]) today.")
        }
        return String(format: String(localized: "%1$lld new foods today: %2$@."),
                      names.count, names.joined(separator: ", "))
    }

    private func row(_ entry: FeedEntry, units: UnitSystem) -> Today.Load.ViewModel.EntryRow {
        let title: String
        let symbol: String

        switch entry.kind {
        case .breast:
            symbol = "drop.fill"
            title = String(localized: "Breastfeed")
        case .bottle:
            symbol = "waterbottle"
            title = entry.milkType == .formula
                ? String(localized: "Formula")
                : String(localized: "Expressed milk")
        case .solid:
            symbol = "fork.knife"
            let foods = FoodLibrary.foods(entry.foodIds).map { $0.name.text }
            title = foods.isEmpty ? String(localized: "Meal") : foods.joined(separator: ", ")
        case .water:
            symbol = "cup.and.saucer"
            title = String(localized: "Water")
        case .supplement:
            symbol = "pills"
            title = String(localized: "Supplement")
        }

        var detail: String?
        if let amount = entry.displayAmount {
            switch amount.unit {
            case .ml: detail = Fmt.ml(amount.value, units: units)
            case .g: detail = Fmt.grams(amount.value, units: units)
            case .min: detail = Fmt.minutes(amount.value)
            }
        }
        if entry.kind == .breast, let side = entry.side {
            let sideText: String
            switch side {
            case .left: sideText = String(localized: "left")
            case .right: sideText = String(localized: "right")
            case .both: sideText = String(localized: "both")
            }
            detail = [detail, sideText].compactMap { $0 }.joined(separator: " · ")
        }

        return .init(
            id: entry.id,
            symbol: symbol,
            title: title,
            detail: detail,
            timeText: Fmt.time(entry.date),
            hasReaction: entry.reaction != .noReaction
        )
    }

    private func sourceChips(_ ids: [String]) -> [Today.Load.ViewModel.SourceChip] {
        Evidence.sources(ids).map {
            .init(id: $0.id, label: $0.citation, urlString: $0.urlString)
        }
    }
}
