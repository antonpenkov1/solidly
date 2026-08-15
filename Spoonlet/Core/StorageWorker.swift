import Foundation
import SwiftData

/// The only thing in the app that talks to SwiftData. Interactors ask it for value types
/// and never see a managed object, which keeps scene logic testable against plain structs.
final class StorageWorker {
    static let shared = StorageWorker()

    let container: ModelContainer
    private let context: ModelContext

    init(inMemory: Bool = false) {
        container = Persistence.makeContainer(inMemory: inMemory)
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    private func commit() {
        do { try context.save() } catch { assertionFailure("Spoonlet save failed: \(error)") }
    }

    private func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> [T] {
        (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Settings

    private func settingsModel() -> SDSettings {
        if let existing = fetch(FetchDescriptor<SDSettings>()).first { return existing }
        let created = SDSettings()
        context.insert(created)
        commit()
        return created
    }

    func settings() -> AppSettings { settingsModel().dto }

    func save(settings: AppSettings) {
        settingsModel().apply(settings)
        commit()
    }

    // MARK: - Children

    func children() -> [Child] {
        fetch(FetchDescriptor<SDChild>(sortBy: [SortDescriptor(\.createdAt)])).map(\.dto)
    }

    func activeChild() -> Child? {
        let all = children()
        if let id = settings().activeChildId, let match = all.first(where: { $0.id == id }) {
            return match
        }
        return all.first
    }

    @discardableResult
    func save(child: Child) -> Child {
        let id = child.id
        if let existing = fetch(FetchDescriptor<SDChild>(
            predicate: #Predicate { $0.id == id })).first {
            existing.name = child.name
            existing.birthDate = child.birthDate
            existing.sexRaw = child.sex.rawValue
            existing.gestationWeeks = child.gestationWeeks
        } else {
            context.insert(SDChild(child: child))
        }
        commit()
        return child
    }

    func deleteChild(id: UUID) {
        for model in fetch(FetchDescriptor<SDChild>(predicate: #Predicate { $0.id == id })) {
            context.delete(model)
        }
        for model in fetch(FetchDescriptor<SDFeedEntry>(predicate: #Predicate { $0.childId == id })) {
            context.delete(model)
        }
        for model in fetch(FetchDescriptor<SDGrowthPoint>(predicate: #Predicate { $0.childId == id })) {
            context.delete(model)
        }
        for model in fetch(FetchDescriptor<SDSleepEntry>(predicate: #Predicate { $0.childId == id })) {
            context.delete(model)
        }
        for model in fetch(FetchDescriptor<SDDiaperEntry>(predicate: #Predicate { $0.childId == id })) {
            context.delete(model)
        }
        for model in fetch(FetchDescriptor<SDFoodIntro>(predicate: #Predicate { $0.childId == id })) {
            context.delete(model)
        }
        for model in fetch(FetchDescriptor<SDCareOverride>(predicate: #Predicate { $0.childId == id })) {
            context.delete(model)
        }
        commit()
    }

    // MARK: - Feed entries

    func feedEntries(childId: UUID, from start: Date, to end: Date) -> [FeedEntry] {
        fetch(FetchDescriptor<SDFeedEntry>(
            predicate: #Predicate { $0.childId == childId && $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )).map(\.dto)
    }

    func feedEntries(childId: UUID, on day: Date) -> [FeedEntry] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? day
        return feedEntries(childId: childId, from: start, to: end)
    }

    func recentFeedEntries(childId: UUID, limit: Int = 100) -> [FeedEntry] {
        var descriptor = FetchDescriptor<SDFeedEntry>(
            predicate: #Predicate { $0.childId == childId },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return fetch(descriptor).map(\.dto)
    }

    func save(feed: FeedEntry) {
        let id = feed.id
        if let existing = fetch(FetchDescriptor<SDFeedEntry>(
            predicate: #Predicate { $0.id == id })).first {
            existing.apply(feed)
        } else {
            context.insert(SDFeedEntry(entry: feed))
        }
        commit()
        recordExposures(for: feed)
    }

    func deleteFeed(id: UUID) {
        for model in fetch(FetchDescriptor<SDFeedEntry>(predicate: #Predicate { $0.id == id })) {
            context.delete(model)
        }
        commit()
    }

    // MARK: - Growth

    func growthPoints(childId: UUID) -> [GrowthPoint] {
        fetch(FetchDescriptor<SDGrowthPoint>(
            predicate: #Predicate { $0.childId == childId },
            sortBy: [SortDescriptor(\.date)]
        )).map(\.dto)
    }

    func latestWeight(childId: UUID) -> Double? {
        growthPoints(childId: childId).compactMap { point in
            point.weightKg.map { (point.date, $0) }
        }.max(by: { $0.0 < $1.0 })?.1
    }

    func save(growth: GrowthPoint) {
        let id = growth.id
        if let existing = fetch(FetchDescriptor<SDGrowthPoint>(
            predicate: #Predicate { $0.id == id })).first {
            existing.apply(growth)
        } else {
            context.insert(SDGrowthPoint(point: growth))
        }
        commit()
    }

    func deleteGrowth(id: UUID) {
        for model in fetch(FetchDescriptor<SDGrowthPoint>(predicate: #Predicate { $0.id == id })) {
            context.delete(model)
        }
        commit()
    }

    // MARK: - Sleep

    func sleepEntries(childId: UUID, from start: Date, to end: Date) -> [SleepEntry] {
        fetch(FetchDescriptor<SDSleepEntry>(
            predicate: #Predicate { $0.childId == childId && $0.start >= start && $0.start < end },
            sortBy: [SortDescriptor(\.start, order: .reverse)]
        )).map(\.dto)
    }

    func runningSleep(childId: UUID) -> SleepEntry? {
        fetch(FetchDescriptor<SDSleepEntry>(
            predicate: #Predicate { $0.childId == childId && $0.end == nil },
            sortBy: [SortDescriptor(\.start, order: .reverse)]
        )).first?.dto
    }

    func save(sleep: SleepEntry) {
        let id = sleep.id
        if let existing = fetch(FetchDescriptor<SDSleepEntry>(
            predicate: #Predicate { $0.id == id })).first {
            existing.apply(sleep)
        } else {
            context.insert(SDSleepEntry(entry: sleep))
        }
        commit()
    }

    func deleteSleep(id: UUID) {
        for model in fetch(FetchDescriptor<SDSleepEntry>(predicate: #Predicate { $0.id == id })) {
            context.delete(model)
        }
        commit()
    }

    // MARK: - Diapers

    func diaperEntries(childId: UUID, from start: Date, to end: Date) -> [DiaperEntry] {
        fetch(FetchDescriptor<SDDiaperEntry>(
            predicate: #Predicate { $0.childId == childId && $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )).map(\.dto)
    }

    func save(diaper: DiaperEntry) {
        let id = diaper.id
        if let existing = fetch(FetchDescriptor<SDDiaperEntry>(
            predicate: #Predicate { $0.id == id })).first {
            existing.apply(diaper)
        } else {
            context.insert(SDDiaperEntry(entry: diaper))
        }
        commit()
    }

    func deleteDiaper(id: UUID) {
        for model in fetch(FetchDescriptor<SDDiaperEntry>(predicate: #Predicate { $0.id == id })) {
            context.delete(model)
        }
        commit()
    }

    // MARK: - Food introductions

    func foodIntros(childId: UUID) -> [FoodIntro] {
        fetch(FetchDescriptor<SDFoodIntro>(
            predicate: #Predicate { $0.childId == childId },
            sortBy: [SortDescriptor(\.lastOffered, order: .reverse)]
        )).map(\.dto)
    }

    func foodIntro(childId: UUID, foodId: String) -> FoodIntro? {
        fetch(FetchDescriptor<SDFoodIntro>(
            predicate: #Predicate { $0.childId == childId && $0.foodId == foodId })).first?.dto
    }

    /// Rolls the introduction ledger forward from a logged meal.
    ///
    /// Exposure count is what the allergen guidance is actually about, so it is derived
    /// from meals rather than maintained by hand — a parent should never have to tick
    /// "yes, peanut again" separately from logging breakfast.
    private func recordExposures(for feed: FeedEntry) {
        guard !feed.foodIds.isEmpty else { return }
        let childId = feed.childId

        for foodId in Set(feed.foodIds) {
            let existing = fetch(FetchDescriptor<SDFoodIntro>(
                predicate: #Predicate { $0.childId == childId && $0.foodId == foodId })).first

            if let existing {
                // Re-logging the same meal must not double-count; only later meals add an exposure.
                if feed.date > existing.lastOffered {
                    existing.exposures += 1
                    existing.lastOffered = feed.date
                }
                existing.firstOffered = min(existing.firstOffered, feed.date)
                if let acceptance = feed.acceptance,
                   rank(acceptance) > rank(Acceptance(rawValue: existing.bestAcceptanceRaw) ?? .refused) {
                    existing.bestAcceptanceRaw = acceptance.rawValue
                }
                if severity(feed.reaction) > severity(ReactionSeverity(rawValue: existing.worstReactionRaw) ?? .noReaction) {
                    existing.worstReactionRaw = feed.reaction.rawValue
                }
            } else {
                context.insert(SDFoodIntro(intro: FoodIntro(
                    childId: childId, foodId: foodId,
                    firstOffered: feed.date, lastOffered: feed.date, exposures: 1,
                    bestAcceptance: feed.acceptance ?? .tasted,
                    worstReaction: feed.reaction
                )))
            }
        }
        commit()
    }

    func save(intro: FoodIntro) {
        let id = intro.id
        if let existing = fetch(FetchDescriptor<SDFoodIntro>(
            predicate: #Predicate { $0.id == id })).first {
            existing.apply(intro)
        } else {
            context.insert(SDFoodIntro(intro: intro))
        }
        commit()
    }

    func deleteIntro(childId: UUID, foodId: String) {
        for model in fetch(FetchDescriptor<SDFoodIntro>(
            predicate: #Predicate { $0.childId == childId && $0.foodId == foodId })) {
            context.delete(model)
        }
        commit()
    }

    private func rank(_ acceptance: Acceptance) -> Int {
        switch acceptance {
        case .loved: return 3
        case .ate: return 2
        case .tasted: return 1
        case .refused: return 0
        }
    }

    private func severity(_ reaction: ReactionSeverity) -> Int {
        switch reaction {
        case .noReaction: return 0
        case .mild: return 1
        case .notable: return 2
        }
    }

    // MARK: - Overrides

    func overrides(childId: UUID) -> [OverrideKey: CareOverride] {
        let stored = fetch(FetchDescriptor<SDCareOverride>(
            predicate: #Predicate { $0.childId == childId })).compactMap(\.dto)
        return Dictionary(stored.map { ($0.key, $0) }, uniquingKeysWith: { _, latest in latest })
    }

    func setOverride(childId: UUID, key: OverrideKey, value: Double, attribution: String) {
        let storageKey = key.storageKey
        if let existing = fetch(FetchDescriptor<SDCareOverride>(
            predicate: #Predicate { $0.childId == childId && $0.keyRaw == storageKey })).first {
            existing.value = value
            existing.attribution = attribution
            existing.createdAt = Date()
        } else {
            context.insert(SDCareOverride(override: CareOverride(
                childId: childId, key: key, value: value, attribution: attribution)))
        }
        commit()
    }

    func clearOverride(childId: UUID, key: OverrideKey) {
        let storageKey = key.storageKey
        for model in fetch(FetchDescriptor<SDCareOverride>(
            predicate: #Predicate { $0.childId == childId && $0.keyRaw == storageKey })) {
            context.delete(model)
        }
        commit()
    }

    func clearAllOverrides(childId: UUID) {
        for model in fetch(FetchDescriptor<SDCareOverride>(
            predicate: #Predicate { $0.childId == childId })) {
            context.delete(model)
        }
        commit()
    }

    // MARK: - Export

    /// Everything Spoonlet holds for a child, as JSON. Used by Settings → Export and by the
    /// "show my paediatrician" flow. Nothing ever leaves the device unless a parent shares it.
    func exportJSON(childId: UUID) -> Data? {
        struct Export: Encodable {
            let exportedAt: Date
            let child: Child
            let feeds: [FeedEntry]
            let growth: [GrowthPoint]
            let sleep: [SleepEntry]
            let diapers: [DiaperEntry]
            let foods: [FoodIntro]
        }
        guard let child = children().first(where: { $0.id == childId }) else { return nil }
        let distantPast = Date.distantPast
        let distantFuture = Date.distantFuture
        let payload = Export(
            exportedAt: Date(),
            child: child,
            feeds: feedEntries(childId: childId, from: distantPast, to: distantFuture),
            growth: growthPoints(childId: childId),
            sleep: sleepEntries(childId: childId, from: distantPast, to: distantFuture),
            diapers: diaperEntries(childId: childId, from: distantPast, to: distantFuture),
            foods: foodIntros(childId: childId)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(payload)
    }
}
