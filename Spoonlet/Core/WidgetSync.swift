import Foundation
import WidgetKit

/// Builds the widget snapshot from the same guidance the Today screen uses, so the two can
/// never disagree about what today's range is.
enum WidgetSync {

    static func push(worker: StorageWorker = .shared, on date: Date = Date()) {
        guard let child = worker.activeChild() else {
            WidgetBridge.write(WidgetSnapshot())
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetBridge.kind)
            return
        }

        let settings = worker.settings()
        let months = child.ageMonths(on: date)
        let entries = worker.feedEntries(childId: child.id, on: date)
        let totals = FeedMath.totals(entries)
        let intros = worker.foodIntros(childId: child.id)
        let overrides = settings.showsPediatricianPlan ? worker.overrides(childId: child.id) : [:]
        let targets = Guidance.targets(
            forMonths: months,
            weightKg: worker.latestWeight(childId: child.id),
            overrides: overrides
        )

        var snapshot = WidgetSnapshot()
        snapshot.childName = child.name
        snapshot.ageText = Fmt.age(days: child.correctedAgeDays(on: date))
        snapshot.stageTitle = AgeStage.stage(forMonths: months).title.text
        snapshot.usesMetric = settings.units == .metric
        snapshot.lastFeedAt = entries.map(\.date).max()
        snapshot.updatedAt = date

        if let perMeal = targets.perMealGrams {
            let meals = targets.mealsPerDay ?? 1...1
            snapshot.solidTargetLow = perMeal.lowerBound * Double(meals.lowerBound)
            snapshot.solidTargetHigh = perMeal.upperBound * Double(meals.upperBound)
        }
        snapshot.solidGrams = totals.solidGrams

        snapshot.showsMilkVolume = totals.hasMeasurableMilkVolume
        snapshot.milkMl = totals.milkMl
        if let milk = targets.dailyMilkMl {
            snapshot.milkTargetLow = milk.lowerBound
            snapshot.milkTargetHigh = milk.upperBound
        }
        snapshot.milkFeeds = totals.milkFeeds
        snapshot.milkFeedTarget = targets.milkFeedsPerDay?.upperBound ?? 0

        snapshot.meals = totals.solidMeals
        snapshot.mealTargetLow = targets.mealsPerDay?.lowerBound ?? 0
        snapshot.mealTargetHigh = targets.mealsPerDay?.upperBound ?? 0

        // The one thing worth surfacing on a home screen that no other tracker does.
        if months >= 4 {
            let stale = Allergen.allCases.compactMap { allergen -> (Allergen, Date)? in
                guard case .introduced = Guidance.allergenStatus(allergen, intros: intros, on: date) else {
                    return nil
                }
                let foodIds = Set(FoodLibrary.all
                    .filter { $0.allergen == allergen && !$0.isAvoid }.map(\.id))
                let last = intros.filter { foodIds.contains($0.foodId) }
                    .map(\.lastOffered).max() ?? .distantPast
                return (allergen, last)
            }
            snapshot.lapsedAllergen = stale.min { $0.1 < $1.1 }?.0.title.text
        }

        WidgetBridge.write(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetBridge.kind)
    }
}

/// Everything the app needs to refresh after data changes, in one call so no site can
/// remember to update the widget but forget the reminders.
enum AppRefresh {
    static func run(worker: StorageWorker = .shared) {
        Reminders.reschedule(worker: worker)
        WidgetSync.push(worker: worker)
    }
}
