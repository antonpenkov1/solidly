import Foundation
import SwiftData

// MARK: - Stored models
//
// Every property has a default and nothing is marked unique, so the container can be
// switched to a CloudKit private database later without a migration. Value-type DTOs in
// Models.swift stay the interface between the store and the interactors.

@Model
final class SDChild {
    var id: UUID = UUID()
    var name: String = ""
    var birthDate: Date = Date()
    var sexRaw: String = ChildSex.girl.rawValue
    var gestationWeeks: Int = 40
    var createdAt: Date = Date()

    init(child: Child) {
        id = child.id
        name = child.name
        birthDate = child.birthDate
        sexRaw = child.sex.rawValue
        gestationWeeks = child.gestationWeeks
        createdAt = Date()
    }

    var dto: Child {
        Child(id: id, name: name, birthDate: birthDate,
              sex: ChildSex(rawValue: sexRaw) ?? .girl, gestationWeeks: gestationWeeks)
    }
}

@Model
final class SDFeedEntry {
    var id: UUID = UUID()
    var childId: UUID = UUID()
    var date: Date = Date()
    var kindRaw: String = FeedKind.solid.rawValue
    var milkTypeRaw: String?
    var sideRaw: String?
    var durationMin: Double?
    var volumeMl: Double?
    var grams: Double?
    var foodIdsRaw: String = ""
    var acceptanceRaw: String?
    var reactionRaw: String = ReactionSeverity.noReaction.rawValue
    var note: String = ""

    init(entry: FeedEntry) {
        apply(entry)
    }

    func apply(_ entry: FeedEntry) {
        id = entry.id
        childId = entry.childId
        date = entry.date
        kindRaw = entry.kind.rawValue
        milkTypeRaw = entry.milkType?.rawValue
        sideRaw = entry.side?.rawValue
        durationMin = entry.durationMin
        volumeMl = entry.volumeMl
        grams = entry.grams
        foodIdsRaw = entry.foodIds.joined(separator: ",")
        acceptanceRaw = entry.acceptance?.rawValue
        reactionRaw = entry.reaction.rawValue
        note = entry.note
    }

    var dto: FeedEntry {
        FeedEntry(
            id: id, childId: childId, date: date,
            kind: FeedKind(rawValue: kindRaw) ?? .solid,
            milkType: milkTypeRaw.flatMap(MilkType.init(rawValue:)),
            side: sideRaw.flatMap(BreastSide.init(rawValue:)),
            durationMin: durationMin, volumeMl: volumeMl, grams: grams,
            foodIds: foodIdsRaw.isEmpty ? [] : foodIdsRaw.components(separatedBy: ","),
            acceptance: acceptanceRaw.flatMap(Acceptance.init(rawValue:)),
            reaction: ReactionSeverity(rawValue: reactionRaw) ?? .noReaction,
            note: note
        )
    }
}

@Model
final class SDGrowthPoint {
    var id: UUID = UUID()
    var childId: UUID = UUID()
    var date: Date = Date()
    var weightKg: Double?
    var lengthCm: Double?
    var headCm: Double?
    var note: String = ""

    init(point: GrowthPoint) { apply(point) }

    func apply(_ point: GrowthPoint) {
        id = point.id
        childId = point.childId
        date = point.date
        weightKg = point.weightKg
        lengthCm = point.lengthCm
        headCm = point.headCm
        note = point.note
    }

    var dto: GrowthPoint {
        GrowthPoint(id: id, childId: childId, date: date,
                    weightKg: weightKg, lengthCm: lengthCm, headCm: headCm, note: note)
    }
}

@Model
final class SDSleepEntry {
    var id: UUID = UUID()
    var childId: UUID = UUID()
    var start: Date = Date()
    var end: Date?
    var note: String = ""

    init(entry: SleepEntry) { apply(entry) }

    func apply(_ entry: SleepEntry) {
        id = entry.id
        childId = entry.childId
        start = entry.start
        end = entry.end
        note = entry.note
    }

    var dto: SleepEntry {
        SleepEntry(id: id, childId: childId, start: start, end: end, note: note)
    }
}

@Model
final class SDDiaperEntry {
    var id: UUID = UUID()
    var childId: UUID = UUID()
    var date: Date = Date()
    var kindRaw: String = DiaperKind.wet.rawValue
    var note: String = ""

    init(entry: DiaperEntry) { apply(entry) }

    func apply(_ entry: DiaperEntry) {
        id = entry.id
        childId = entry.childId
        date = entry.date
        kindRaw = entry.kind.rawValue
        note = entry.note
    }

    var dto: DiaperEntry {
        DiaperEntry(id: id, childId: childId, date: date,
                    kind: DiaperKind(rawValue: kindRaw) ?? .wet, note: note)
    }
}

@Model
final class SDFoodIntro {
    var id: UUID = UUID()
    var childId: UUID = UUID()
    var foodId: String = ""
    var firstOffered: Date = Date()
    var lastOffered: Date = Date()
    var exposures: Int = 1
    var bestAcceptanceRaw: String = Acceptance.tasted.rawValue
    var worstReactionRaw: String = ReactionSeverity.noReaction.rawValue
    var note: String = ""

    init(intro: FoodIntro) { apply(intro) }

    func apply(_ intro: FoodIntro) {
        id = intro.id
        childId = intro.childId
        foodId = intro.foodId
        firstOffered = intro.firstOffered
        lastOffered = intro.lastOffered
        exposures = intro.exposures
        bestAcceptanceRaw = intro.bestAcceptance.rawValue
        worstReactionRaw = intro.worstReaction.rawValue
        note = intro.note
    }

    var dto: FoodIntro {
        FoodIntro(id: id, childId: childId, foodId: foodId,
                  firstOffered: firstOffered, lastOffered: lastOffered, exposures: exposures,
                  bestAcceptance: Acceptance(rawValue: bestAcceptanceRaw) ?? .tasted,
                  worstReaction: ReactionSeverity(rawValue: worstReactionRaw) ?? .noReaction,
                  note: note)
    }
}

@Model
final class SDCareOverride {
    var id: UUID = UUID()
    var childId: UUID = UUID()
    var keyRaw: String = ""
    var value: Double = 0
    var attribution: String = ""
    var createdAt: Date = Date()

    init(override: CareOverride) {
        id = override.id
        childId = override.childId
        keyRaw = override.key.storageKey
        value = override.value
        attribution = override.attribution
        createdAt = override.createdAt
    }

    var dto: CareOverride? {
        guard let key = OverrideKey.from(storageKey: keyRaw) else { return nil }
        return CareOverride(id: id, childId: childId, key: key, value: value,
                            attribution: attribution, createdAt: createdAt)
    }
}

@Model
final class SDSettings {
    var activeChildId: UUID?
    var unitsRaw: String = UnitSystem.metric.rawValue
    var appearanceRaw: String = AppearanceMode.system.rawValue
    var disclaimerAcceptedAt: Date?
    var showsPediatricianPlan: Bool = false
    var allergenReminders: Bool = false
    var growthReminders: Bool = false
    var stageReminders: Bool = false

    init() {}

    var dto: AppSettings {
        AppSettings(
            activeChildId: activeChildId,
            units: UnitSystem(rawValue: unitsRaw) ?? .metric,
            appearance: AppearanceMode(rawValue: appearanceRaw) ?? .system,
            disclaimerAcceptedAt: disclaimerAcceptedAt,
            showsPediatricianPlan: showsPediatricianPlan,
            allergenReminders: allergenReminders,
            growthReminders: growthReminders,
            stageReminders: stageReminders
        )
    }

    func apply(_ settings: AppSettings) {
        activeChildId = settings.activeChildId
        unitsRaw = settings.units.rawValue
        appearanceRaw = settings.appearance.rawValue
        disclaimerAcceptedAt = settings.disclaimerAcceptedAt
        showsPediatricianPlan = settings.showsPediatricianPlan
        allergenReminders = settings.allergenReminders
        growthReminders = settings.growthReminders
        stageReminders = settings.stageReminders
    }
}

// MARK: - Container

enum Persistence {
    static let schema = Schema([
        SDChild.self, SDFeedEntry.self, SDGrowthPoint.self, SDSleepEntry.self,
        SDDiaperEntry.self, SDFoodIntro.self, SDCareOverride.self, SDSettings.self,
    ])

    /// The store location is pinned explicitly rather than left to the default.
    ///
    /// SwiftData moves its default store into the shared container as soon as an app-group
    /// entitlement appears — which is exactly what adding the widget does. Naming the URL
    /// means the entitlement can come and go without the data appearing to vanish.
    static var storeURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return support.appendingPathComponent("Tummi.store")
    }

    /// iCloud sync is written but switched off.
    ///
    /// Every model here is already CloudKit-safe — no unique attributes, every property
    /// defaulted — so turning it on is this flag plus the two entitlement keys noted in
    /// `Tummi.entitlements`. It stays off until the CloudKit container actually exists in
    /// the developer account, because an entitlement pointing at a missing container fails
    /// provisioning rather than degrading quietly.
    ///
    /// It also keeps the 1.0 privacy claim absolute: nothing leaves the device at all.
    static let iCloudSyncEnabled = false

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else if iCloudSyncEnabled {
            configuration = ModelConfiguration(
                schema: schema, url: storeURL,
                cloudKitDatabase: .private("iCloud.com.antonpenkov.tummi")
            )
        } else {
            configuration = ModelConfiguration(schema: schema, url: storeURL)
        }

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // A store that cannot be opened is unrecoverable for the user; falling back to
            // memory at least keeps the app usable and visibly empty rather than crashing.
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }
}
