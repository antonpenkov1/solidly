import AppIntents
import Foundation

/// Siri and Shortcuts entry points.
///
/// Deliberately narrow: logging a bottle and asking what has been eaten are the two things
/// a parent does with one hand while holding a baby with the other. Anything that needs a
/// decision — which foods, how it went, whether there was a reaction — belongs on a screen
/// where the safety copy is visible, not in a voice command.
struct LogBottleIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a bottle"
    static var description = IntentDescription(
        "Records a bottle feed for the current baby.",
        categoryName: "Logging"
    )
    static var openAppWhenRun = false

    @Parameter(title: "Amount in millilitres", default: 120,
               inclusiveRange: (1, 500))
    var millilitres: Int

    @Parameter(title: "Formula", default: true)
    var isFormula: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Log a \(\.$millilitres) ml bottle")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let worker = StorageWorker.shared
        guard let child = worker.activeChild() else {
            return .result(dialog: "Add a baby in Spoonlet first.")
        }

        worker.save(feed: FeedEntry(
            childId: child.id, kind: .bottle,
            milkType: isFormula ? .formula : .breastMilk,
            volumeMl: Double(millilitres)
        ))
        AppRefresh.run(worker: worker)

        let totals = FeedMath.totals(worker.feedEntries(childId: child.id, on: Date()))
        let units = worker.settings().units
        return .result(dialog: IntentDialog(stringLiteral: String(
            format: String(localized: "Logged. %1$@ so far today."),
            Fmt.ml(totals.milkMl, units: units)
        )))
    }
}

struct LogMealIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a meal"
    static var description = IntentDescription(
        "Records how much solid food the baby ate. Which foods and how it went can be added in the app.",
        categoryName: "Logging"
    )
    static var openAppWhenRun = false

    @Parameter(title: "Amount in grams", default: 60, inclusiveRange: (1, 500))
    var grams: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Log a \(\.$grams) g meal")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let worker = StorageWorker.shared
        guard let child = worker.activeChild() else {
            return .result(dialog: "Add a baby in Spoonlet first.")
        }

        worker.save(feed: FeedEntry(
            childId: child.id, kind: .solid, grams: Double(grams), acceptance: .ate
        ))
        AppRefresh.run(worker: worker)

        return .result(dialog: IntentDialog(stringLiteral: String(localized: "Logged.")))
    }
}

struct TodayIntakeIntent: AppIntent {
    static var title: LocalizedStringResource = "How much today"
    static var description = IntentDescription(
        "Reads back today's milk and solid food against the guidance range for the baby's age.",
        categoryName: "Information"
    )
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let worker = StorageWorker.shared
        guard let child = worker.activeChild() else {
            return .result(dialog: "Add a baby in Spoonlet first.")
        }

        let settings = worker.settings()
        let months = child.ageMonths()
        let totals = FeedMath.totals(worker.feedEntries(childId: child.id, on: Date()))
        let targets = Guidance.targets(
            forMonths: months,
            weightKg: worker.latestWeight(childId: child.id),
            overrides: settings.showsPediatricianPlan ? worker.overrides(childId: child.id) : [:]
        )

        var parts: [String] = []
        if totals.hasMeasurableMilkVolume {
            parts.append(String(format: String(localized: "%1$@ of milk"),
                                Fmt.ml(totals.milkMl, units: settings.units)))
        } else if totals.milkFeeds > 0 {
            parts.append(String(format: String(localized: "%1$lld milk feeds"), totals.milkFeeds))
        }
        if totals.solidMeals > 0 {
            parts.append(String(format: String(localized: "%1$@ of food across %2$lld meals"),
                                Fmt.grams(totals.solidGrams, units: settings.units),
                                totals.solidMeals))
        }

        guard !parts.isEmpty else {
            return .result(dialog: IntentDialog(stringLiteral:
                String(localized: "Nothing logged yet today.")))
        }

        var sentence = parts.joined(separator: ", ")
        // The range is the point of the app, so it goes in the answer rather than a bare number.
        if let perMeal = targets.perMealGrams, let meals = targets.mealsPerDay {
            let dayLow = perMeal.lowerBound * Double(meals.lowerBound)
            let dayHigh = perMeal.upperBound * Double(meals.upperBound)
            sentence += ". " + String(
                format: String(localized: "Today's guidance range is %1$@ across %2$@ meals."),
                Fmt.range(dayLow...dayHigh, units: settings.units, unit: .g),
                Fmt.intRange(meals)
            )
        }
        return .result(dialog: IntentDialog(stringLiteral: sentence))
    }
}

struct SpoonletShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogBottleIntent(),
            phrases: [
                "Log a bottle in \(.applicationName)",
                "Add a bottle to \(.applicationName)",
            ],
            shortTitle: "Log a bottle",
            systemImageName: "waterbottle"
        )
        AppShortcut(
            intent: LogMealIntent(),
            phrases: [
                "Log a meal in \(.applicationName)",
                "Add a meal to \(.applicationName)",
            ],
            shortTitle: "Log a meal",
            systemImageName: "fork.knife"
        )
        AppShortcut(
            intent: TodayIntakeIntent(),
            phrases: [
                "How much has the baby eaten in \(.applicationName)",
                "Today's intake in \(.applicationName)",
            ],
            shortTitle: "How much today",
            systemImageName: "chart.bar"
        )
    }
}
