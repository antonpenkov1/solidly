import Foundation

protocol LogPresentationLogic {
    func presentLog(response: Log.Load.Response)
    func presentEmpty()
}

protocol LogDisplayLogic: AnyObject {
    func displayLog(viewModel: Log.Load.ViewModel)
}

final class LogPresenter: LogPresentationLogic {
    weak var view: LogDisplayLogic?

    func presentEmpty() {
        view?.displayLog(viewModel: .empty)
    }

    func presentLog(response: Log.Load.Response) {
        let calendar = Calendar.current
        let units = response.units

        var rowsByDay: [Date: [(date: Date, row: Log.Load.ViewModel.Row)]] = [:]

        for feed in response.feeds {
            let day = calendar.startOfDay(for: feed.date)
            rowsByDay[day, default: []].append((feed.date, feedRow(feed, units: units)))
        }
        for diaper in response.diapers {
            let day = calendar.startOfDay(for: diaper.date)
            rowsByDay[day, default: []].append((diaper.date, diaperRow(diaper)))
        }
        for sleep in response.sleeps {
            let day = calendar.startOfDay(for: sleep.start)
            rowsByDay[day, default: []].append((sleep.start, sleepRow(sleep)))
        }

        let sections = rowsByDay.keys.sorted(by: >).map { day -> Log.Load.ViewModel.DaySection in
            let dayRows = (rowsByDay[day] ?? []).sorted { $0.date > $1.date }.map(\.row)
            let dayFeeds = response.feeds.filter { calendar.isDate($0.date, inSameDayAs: day) }
            return .init(
                id: day,
                title: Fmt.day(day),
                summary: summary(FeedMath.totals(dayFeeds), units: units),
                rows: dayRows
            )
        }

        view?.displayLog(viewModel: .init(
            isEmpty: sections.isEmpty,
            sections: sections,
            runningSleepText: response.runningSleep.map {
                String(localized: "Sleeping since \(Fmt.time($0.start))")
            }
        ))
    }

    // MARK: - Rows

    private func feedRow(_ feed: FeedEntry, units: UnitSystem) -> Log.Load.ViewModel.Row {
        let symbol: String
        let title: String

        switch feed.kind {
        case .breast:
            symbol = "drop.fill"
            title = String(localized: "Breastfeed")
        case .bottle:
            symbol = "waterbottle"
            title = feed.milkType == .formula
                ? String(localized: "Formula")
                : String(localized: "Expressed milk")
        case .solid:
            symbol = "fork.knife"
            let foods = FoodLibrary.foods(feed.foodIds).map { $0.name.text }
            title = foods.isEmpty ? String(localized: "Meal") : foods.joined(separator: ", ")
        case .water:
            symbol = "cup.and.saucer"
            title = String(localized: "Water")
        case .supplement:
            symbol = "pills"
            title = String(localized: "Supplement")
        }

        var parts: [String] = []
        if let amount = feed.displayAmount {
            switch amount.unit {
            case .ml: parts.append(Fmt.ml(amount.value, units: units))
            case .g: parts.append(Fmt.grams(amount.value, units: units))
            case .min: parts.append(Fmt.minutes(amount.value))
            }
        }
        if let acceptance = feed.acceptance, feed.kind == .solid {
            parts.append(acceptanceText(acceptance))
        }
        if !feed.note.isEmpty { parts.append(feed.note) }

        return .init(
            id: feed.id, source: .feed(feed.id), symbol: symbol, title: title,
            detail: parts.isEmpty ? nil : parts.joined(separator: " · "),
            timeText: Fmt.time(feed.date),
            hasReaction: feed.reaction != .noReaction
        )
    }

    private func diaperRow(_ diaper: DiaperEntry) -> Log.Load.ViewModel.Row {
        let title: String
        switch diaper.kind {
        case .wet: title = String(localized: "Wet nappy")
        case .dirty: title = String(localized: "Dirty nappy")
        case .mixed: title = String(localized: "Wet and dirty")
        case .dry: title = String(localized: "Dry nappy")
        }
        return .init(
            id: diaper.id, source: .diaper(diaper.id), symbol: "hare", title: title,
            detail: diaper.note.isEmpty ? nil : diaper.note,
            timeText: Fmt.time(diaper.date), hasReaction: false
        )
    }

    private func sleepRow(_ sleep: SleepEntry) -> Log.Load.ViewModel.Row {
        .init(
            id: sleep.id, source: .sleep(sleep.id), symbol: "moon.zzz.fill",
            title: sleep.isRunning ? String(localized: "Sleeping") : String(localized: "Sleep"),
            detail: sleep.isRunning ? nil : Fmt.duration(sleep.duration),
            timeText: Fmt.time(sleep.start), hasReaction: false
        )
    }

    private func acceptanceText(_ acceptance: Acceptance) -> String {
        switch acceptance {
        case .loved: return String(localized: "loved it")
        case .ate: return String(localized: "ate it")
        case .tasted: return String(localized: "tasted")
        case .refused: return String(localized: "refused")
        }
    }

    private func summary(_ totals: FeedMath.DayTotals, units: UnitSystem) -> String {
        var parts: [String] = []
        if totals.milkFeeds > 0 {
            parts.append(totals.hasMeasurableMilkVolume
                ? Fmt.ml(totals.milkMl, units: units)
                : String(localized: "\(totals.milkFeeds) milk feeds"))
        }
        if totals.solidMeals > 0 {
            parts.append(String(format: String(localized: "%1$lld meals · %2$@"),
                                totals.solidMeals,
                                Fmt.grams(totals.solidGrams, units: units)))
        }
        return parts.joined(separator: "  ·  ")
    }
}
