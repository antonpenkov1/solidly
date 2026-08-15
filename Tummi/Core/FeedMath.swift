import Foundation

/// Aggregates a day of logged entries into the numbers the Today screen compares
/// against the guidance ranges.
enum FeedMath {

    struct DayTotals: Hashable {
        var milkMl: Double = 0
        var breastMinutes: Double = 0
        var breastFeeds: Int = 0
        var bottleFeeds: Int = 0
        var solidGrams: Double = 0
        var solidMeals: Int = 0
        var waterMl: Double = 0
        var newFoods: Int = 0

        var milkFeeds: Int { breastFeeds + bottleFeeds }

        /// A breastfed day has no millilitres to add up. The Today screen switches to
        /// feed counts rather than showing a misleading 0 ml.
        var hasMeasurableMilkVolume: Bool { milkMl > 0 }
    }

    static func totals(_ entries: [FeedEntry]) -> DayTotals {
        var totals = DayTotals()
        for entry in entries {
            switch entry.kind {
            case .breast:
                totals.breastFeeds += 1
                totals.breastMinutes += entry.durationMin ?? 0
                totals.milkMl += entry.volumeMl ?? 0   // expressed milk logged by volume
            case .bottle:
                totals.bottleFeeds += 1
                totals.milkMl += entry.volumeMl ?? 0
            case .solid:
                totals.solidMeals += 1
                totals.solidGrams += entry.grams ?? 0
            case .water:
                totals.waterMl += entry.volumeMl ?? 0
            case .supplement:
                break
            }
        }
        return totals
    }

    /// Where a value sits against a guidance range, as 0...1 for a progress bar plus a verdict.
    enum RangeStanding: Hashable {
        case below(fraction: Double)
        case within(fraction: Double)
        case above(fraction: Double)

        var fraction: Double {
            switch self {
            case .below(let f), .within(let f), .above(let f): return f
            }
        }

        var isWithin: Bool { if case .within = self { return true }; return false }
    }

    static func standing(value: Double, in range: ClosedRange<Double>) -> RangeStanding {
        guard range.upperBound > 0 else { return .below(fraction: 0) }
        let fraction = (value / range.upperBound).clamped(to: 0...1)
        if value < range.lowerBound { return .below(fraction: fraction) }
        if value > range.upperBound { return .above(fraction: 1) }
        return .within(fraction: fraction)
    }

    /// Foods offered for the very first time on this day, used for the "new food" counter
    /// and for the reminder to leave a gap between new allergens.
    static func newFoodIds(entries: [FeedEntry], intros: [FoodIntro], on day: Date) -> [String] {
        let calendar = Calendar.current
        let introByFood = Dictionary(intros.map { ($0.foodId, $0) }, uniquingKeysWith: { first, _ in first })
        let loggedToday = Set(entries.flatMap(\.foodIds))
        return loggedToday.filter { foodId in
            guard let intro = introByFood[foodId] else { return true }
            return calendar.isDate(intro.firstOffered, inSameDayAs: day)
        }.sorted()
    }

    /// Rolling window totals, for the Growth and Log screens.
    static func dailySolidGrams(entries: [FeedEntry], days: Int, endingOn day: Date = Date()) -> [(day: Date, grams: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: day)
        return (0..<days).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let next = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            let grams = entries
                .filter { $0.kind == .solid && $0.date >= date && $0.date < next }
                .reduce(0) { $0 + ($1.grams ?? 0) }
            return (date, grams)
        }
    }
}
