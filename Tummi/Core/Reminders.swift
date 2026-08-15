import Foundation
import UserNotifications

/// Local reminders. There are exactly three, and each exists because missing it has a
/// consequence the app can name:
///
/// - **Allergen upkeep** — the prevention trials relied on eating an allergen regularly.
///   An allergen introduced once and forgotten is the failure mode nobody notices.
/// - **Growth check-in** — a percentile is meaningless without a second point. A monthly
///   nudge is what turns the chart from a number into a trend.
/// - **Stage change** — 6, 9, 12 and 24 months each change what the guidance says.
///
/// Deliberately no "time to feed your baby" reminder: parents of infants do not need an
/// app to tell them that, and a tracker that nags about feeds becomes one more source of
/// pressure at exactly the wrong moment.
enum Reminders {

    private static let allergenId = "tummi.allergen.upkeep"
    private static let growthId = "tummi.growth.checkin"
    private static let stagePrefix = "tummi.stage."

    // MARK: - Authorization

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    // MARK: - Scheduling

    /// Rebuilds the whole schedule from current state.
    ///
    /// Called on launch, on foreground and after every save. Reminders are derived from
    /// data rather than maintained incrementally, so a logged meal that closes an allergen
    /// gap silently cancels the reminder about it — there is no stale-notification path.
    static func reschedule(worker: StorageWorker = .shared) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let ours = pending.map(\.identifier).filter {
                $0 == allergenId || $0 == growthId || $0.hasPrefix(stagePrefix)
            }
            center.removePendingNotificationRequests(withIdentifiers: ours)

            let settings = worker.settings()
            guard let child = worker.activeChild() else { return }

            if settings.allergenReminders {
                scheduleAllergenUpkeep(child: child, worker: worker, center: center)
            }
            if settings.growthReminders {
                scheduleGrowthCheckIn(child: child, worker: worker, center: center)
            }
            if settings.stageReminders {
                scheduleStageChanges(child: child, center: center)
            }
        }
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - Individual reminders

    private static func scheduleAllergenUpkeep(
        child: Child, worker: StorageWorker, center: UNUserNotificationCenter
    ) {
        guard child.ageMonths() >= 5.5 else { return }

        let intros = worker.foodIntros(childId: child.id)
        let lapsed = Allergen.allCases.filter { allergen in
            if case .introduced = Guidance.allergenStatus(allergen, intros: intros) { return true }
            return false
        }
        guard !lapsed.isEmpty else { return }

        let names = lapsed.prefix(3).map { $0.title.text }.joined(separator: ", ")
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Keep the allergens going")
        content.body = lapsed.count == 1
            ? String(format: String(localized: "%@ was introduced but has not been offered lately. Regular exposure is what the prevention trials tested."), names)
            : String(format: String(localized: "These were introduced but have not been offered lately: %@."), names)
        content.sound = .default

        // Saturday morning: a weekend breakfast is the realistic moment to act on it.
        var when = DateComponents()
        when.weekday = 7
        when.hour = 9
        when.minute = 30

        center.add(UNNotificationRequest(
            identifier: allergenId,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
        ))
    }

    private static func scheduleGrowthCheckIn(
        child: Child, worker: StorageWorker, center: UNUserNotificationCenter
    ) {
        let points = worker.growthPoints(childId: child.id)
        let last = points.map(\.date).max()
        let calendar = Calendar.current

        // Under 6 months growth is fast enough that fortnightly is the useful cadence;
        // after that monthly matches how often a scale is realistically to hand.
        let interval = child.ageMonths() < 6 ? 14 : 30
        let due = calendar.date(byAdding: .day, value: interval, to: last ?? Date()) ?? Date()
        let fireDate = max(due, Date().addingTimeInterval(3600))

        var components = calendar.dateComponents([.year, .month, .day], from: fireDate)
        components.hour = 10
        components.minute = 0

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Time for a weigh-in")
        content.body = last == nil
            ? String(localized: "A single measurement is just a number. Add one and Tummi can start showing the curve.")
            : String(localized: "It has been a while since the last measurement. One more point keeps the curve honest.")
        content.sound = .default

        center.add(UNNotificationRequest(
            identifier: growthId,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        ))
    }

    private static func scheduleStageChanges(child: Child, center: UNUserNotificationCenter) {
        let calendar = Calendar.current
        let now = Date()

        for stage in AgeStage.allCases {
            let months = stage.monthRange.lowerBound
            guard months > 0 else { continue }

            let days = Int(months * 30.4375)
            // Preterm babies reach each stage by corrected age, which is later by exactly
            // the weeks they were early — the same correction the rest of the app applies.
            let correction = child.isPreterm ? (40 - child.gestationWeeks) * 7 : 0
            guard let date = calendar.date(byAdding: .day, value: days + correction, to: child.birthDate),
                  date > now else { continue }

            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = 9
            components.minute = 0

            let profile = Guidance.profile(for: stage)
            let content = UNMutableNotificationContent()
            content.title = String(format: String(localized: "New stage: %@"), stage.title.text)
            content.body = profile.headline.text
            content.sound = .default

            center.add(UNNotificationRequest(
                identifier: stagePrefix + stage.rawValue,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            ))
        }
    }
}
