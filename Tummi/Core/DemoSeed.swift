#if DEBUG
import Foundation

/// Populates a realistic 7-month-old for screenshots and manual verification.
/// Launch with `-DemoSeed 1`; add `-DemoReset 1` to wipe first.
enum DemoSeed {
    static func seedIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-DemoSeed") else { return }

        let worker = StorageWorker.shared

        if arguments.contains("-DemoReset") {
            for child in worker.children() { worker.deleteChild(id: child.id) }
        }
        guard worker.activeChild() == nil else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let birthDate = calendar.date(byAdding: .day, value: -229, to: today) ?? today  // ~7.5 months

        let child = Child(name: "Mila", birthDate: birthDate, sex: .girl)
        worker.save(child: child)

        var settings = worker.settings()
        settings.activeChildId = child.id
        settings.disclaimerAcceptedAt = Date()
        worker.save(settings: settings)

        seedGrowth(child: child, worker: worker, calendar: calendar, today: today)
        seedHistory(child: child, worker: worker, calendar: calendar, today: today)

        if arguments.contains("-DemoOverrides") {
            seedOverrides(child: child, worker: worker)
        }
    }

    /// A family whose paediatrician set their own numbers — the state the Plan screen
    /// exists for, and the one that is otherwise fiddly to reach by hand.
    private static func seedOverrides(child: Child, worker: StorageWorker) {
        worker.setOverride(childId: child.id, key: .perMealGrams,
                           value: 80, attribution: "Dr Ivanova, 2 Aug")
        worker.setOverride(childId: child.id, key: .mealsPerDay,
                           value: 3, attribution: "Dr Ivanova, 2 Aug")
        worker.setOverride(childId: child.id, key: .foodEarliestMonth("cowMilkDrink"),
                           value: 10, attribution: "Dr Ivanova, 2 Aug")
        var settings = worker.settings()
        settings.showsPediatricianPlan = true
        worker.save(settings: settings)
    }

    private static func seedGrowth(child: Child, worker: StorageWorker,
                                   calendar: Calendar, today: Date) {
        // Roughly the 45th percentile, tracking steadily — the healthy pattern the
        // Growth screen is meant to make legible.
        let measurements: [(daysAgo: Int, weight: Double, length: Double, head: Double)] = [
            (229, 3.30, 49.5, 34.2),
            (198, 4.25, 53.4, 36.6),
            (168, 5.30, 56.8, 38.4),
            (137, 6.10, 59.6, 39.8),
            (107, 6.75, 61.9, 41.0),
            (76, 7.25, 63.9, 42.0),
            (45, 7.70, 65.6, 42.8),
            (12, 8.05, 67.0, 43.5),
        ]
        for measurement in measurements {
            guard let date = calendar.date(byAdding: .day, value: -measurement.daysAgo, to: today) else { continue }
            worker.save(growth: GrowthPoint(
                childId: child.id, date: date,
                weightKg: measurement.weight, lengthCm: measurement.length, headCm: measurement.head
            ))
        }
    }

    private static func seedHistory(child: Child, worker: StorageWorker,
                                    calendar: Calendar, today: Date) {
        let breakfasts = [["ironCereal", "pear"], ["oats", "blueberry"], ["egg", "avocado"]]
        let lunches = [["beef", "sweetPotato"], ["lentil", "bellPepper"], ["salmon", "broccoli"], ["chicken", "pumpkin"]]
        let dinners = [["yogurt", "banana"], ["tofu", "greenBean"], ["buckwheat", "carrot"]]

        for dayOffset in stride(from: 20, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }

            // Milk feeds through the day.
            for (index, hour) in [6, 10, 14, 18, 21].enumerated() {
                guard let date = calendar.date(bySettingHour: hour, minute: index * 7, second: 0, of: day),
                      date <= Date() else { continue }
                worker.save(feed: FeedEntry(
                    childId: child.id, date: date, kind: .bottle,
                    milkType: index % 2 == 0 ? .breastMilk : .formula,
                    volumeMl: [140.0, 160, 150, 170, 130][index]
                ))
            }

            // Two or three solid meals, growing across the weeks.
            let meals: [(hour: Int, foods: [String], grams: Double)] = [
                (8, breakfasts[dayOffset % breakfasts.count], 45 + Double(20 - dayOffset)),
                (12, lunches[dayOffset % lunches.count], 55 + Double(20 - dayOffset)),
                (17, dinners[dayOffset % dinners.count], 40 + Double(20 - dayOffset)),
            ]
            for meal in meals.prefix(dayOffset > 12 ? 2 : 3) {
                guard let date = calendar.date(bySettingHour: meal.hour, minute: 15, second: 0, of: day),
                      date <= Date() else { continue }
                worker.save(feed: FeedEntry(
                    childId: child.id, date: date, kind: .solid,
                    grams: meal.grams.rounded(),
                    foodIds: meal.foods,
                    acceptance: dayOffset % 5 == 0 ? .refused : (dayOffset % 3 == 0 ? .loved : .ate)
                ))
            }

            // Water with lunch, and a couple of nappies.
            if let date = calendar.date(bySettingHour: 12, minute: 40, second: 0, of: day), date <= Date() {
                worker.save(feed: FeedEntry(childId: child.id, date: date, kind: .water, volumeMl: 30))
            }
            for hour in [9, 15, 20] {
                guard let date = calendar.date(bySettingHour: hour, minute: 5, second: 0, of: day),
                      date <= Date() else { continue }
                worker.save(diaper: DiaperEntry(
                    childId: child.id, date: date, kind: hour == 15 ? .mixed : .wet))
            }
        }

        // A peanut introduction that started well but has not been kept up — the exact
        // situation the Today screen is built to notice.
        if let date = calendar.date(byAdding: .day, value: -26, to: today) {
            worker.save(feed: FeedEntry(
                childId: child.id, date: date, kind: .solid,
                grams: 10, foodIds: ["peanut"], acceptance: .tasted
            ))
        }
    }
}
#endif
