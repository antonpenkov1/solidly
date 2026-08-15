import Foundation

// MARK: - Bilingual content

/// Content strings (food names, serving advice, guidance copy) ship as data rather than
/// as `Localizable.xcstrings` keys: the library is expected to grow, and a curator adding
/// a food should not have to touch the string catalogue. UI chrome still uses String(localized:).
struct LocalizedText: Hashable, Codable {
    let en: String
    let ru: String

    init(_ en: String, _ ru: String) {
        self.en = en
        self.ru = ru
    }

    var text: String {
        Locale.current.language.languageCode?.identifier == "ru" ? ru : en
    }
}

func T(_ en: String, _ ru: String) -> LocalizedText { LocalizedText(en, ru) }

// MARK: - Child

enum ChildSex: String, Codable, CaseIterable, Hashable {
    case boy
    case girl
}

struct Child: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var birthDate: Date = Date()
    var sex: ChildSex = .girl
    /// Weeks of gestation at birth. Below 37 the app corrects age for prematurity,
    /// which is what growth charts and feeding milestones are read against.
    var gestationWeeks: Int = 40

    var isPreterm: Bool { gestationWeeks < 37 }

    func ageDays(on date: Date = Date()) -> Int {
        let calendar = Calendar.current
        let from = calendar.startOfDay(for: birthDate)
        let to = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }

    /// Age adjusted for prematurity, in days. Equals chronological age for term babies.
    func correctedAgeDays(on date: Date = Date()) -> Int {
        guard isPreterm else { return ageDays(on: date) }
        return max(0, ageDays(on: date) - (40 - gestationWeeks) * 7)
    }

    func ageMonths(on date: Date = Date()) -> Double {
        Double(correctedAgeDays(on: date)) / 30.4375
    }
}

// MARK: - Feeding

enum FeedKind: String, Codable, CaseIterable, Hashable {
    case breast
    case bottle
    case solid
    case water
    case supplement

    var isMilk: Bool { self == .breast || self == .bottle }
}

enum MilkType: String, Codable, CaseIterable, Hashable {
    case breastMilk
    case formula
}

enum BreastSide: String, Codable, CaseIterable, Hashable {
    case left
    case right
    case both
}

/// How well the food went down. Kept separate from `ReactionSeverity` on purpose —
/// a refused food is a normal part of learning to eat, an allergic reaction is not.
enum Acceptance: String, Codable, CaseIterable, Hashable {
    case loved
    case ate
    case tasted
    case refused
}

enum ReactionSeverity: String, Codable, CaseIterable, Hashable {
    case noReaction = "none"
    case mild
    case notable
}

struct FeedEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var childId: UUID
    var date: Date = Date()
    var kind: FeedKind

    var milkType: MilkType?
    var side: BreastSide?
    var durationMin: Double?
    var volumeMl: Double?
    var grams: Double?

    var foodIds: [String] = []
    var acceptance: Acceptance?
    var reaction: ReactionSeverity = .noReaction
    var note: String = ""

    /// Everything the baby swallowed, expressed in the unit the entry was logged in.
    var displayAmount: (value: Double, unit: AmountUnit)? {
        if let volumeMl { return (volumeMl, .ml) }
        if let grams { return (grams, .g) }
        if let durationMin { return (durationMin, .min) }
        return nil
    }
}

enum AmountUnit: String, Codable, Hashable {
    case ml
    case g
    case min
}

// MARK: - Growth

enum GrowthIndicator: String, CaseIterable, Codable, Hashable {
    case weight
    case length
    case head
}

struct GrowthPoint: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var childId: UUID
    var date: Date = Date()
    var weightKg: Double?
    var lengthCm: Double?
    var headCm: Double?
    var note: String = ""

    func value(for indicator: GrowthIndicator) -> Double? {
        switch indicator {
        case .weight: return weightKg
        case .length: return lengthCm
        case .head: return headCm
        }
    }

    var isEmpty: Bool { weightKg == nil && lengthCm == nil && headCm == nil }
}

// MARK: - Sleep and diapers

struct SleepEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var childId: UUID
    var start: Date = Date()
    var end: Date?
    var note: String = ""

    var isRunning: Bool { end == nil }
    var duration: TimeInterval { (end ?? Date()).timeIntervalSince(start) }
}

enum DiaperKind: String, Codable, CaseIterable, Hashable {
    case wet
    case dirty
    case mixed
    case dry
}

struct DiaperEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var childId: UUID
    var date: Date = Date()
    var kind: DiaperKind = .wet
    var note: String = ""
}

// MARK: - Food introductions

struct FoodIntro: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var childId: UUID
    var foodId: String
    var firstOffered: Date = Date()
    var lastOffered: Date = Date()
    var exposures: Int = 1
    var bestAcceptance: Acceptance = .tasted
    var worstReaction: ReactionSeverity = .noReaction
    var note: String = ""
}

// MARK: - Pediatrician overrides

/// The "my paediatrician said otherwise" layer. International guidance stays visible,
/// but the numbers the app shows as *the plan* become the ones the family's doctor gave.
enum OverrideKey: Hashable, Codable {
    case foodEarliestMonth(String)
    case dailyMilkMl
    case mealsPerDay
    case perMealGrams
    case solidsStartMonth

    var storageKey: String {
        switch self {
        case .foodEarliestMonth(let id): return "food.earliestMonth.\(id)"
        case .dailyMilkMl: return "targets.dailyMilkMl"
        case .mealsPerDay: return "targets.mealsPerDay"
        case .perMealGrams: return "targets.perMealGrams"
        case .solidsStartMonth: return "targets.solidsStartMonth"
        }
    }

    static func from(storageKey: String) -> OverrideKey? {
        if storageKey.hasPrefix("food.earliestMonth.") {
            return .foodEarliestMonth(String(storageKey.dropFirst("food.earliestMonth.".count)))
        }
        switch storageKey {
        case "targets.dailyMilkMl": return .dailyMilkMl
        case "targets.mealsPerDay": return .mealsPerDay
        case "targets.perMealGrams": return .perMealGrams
        case "targets.solidsStartMonth": return .solidsStartMonth
        default: return nil
        }
    }
}

struct CareOverride: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var childId: UUID
    var key: OverrideKey
    var value: Double
    /// Who prescribed it — shown next to every overridden number so the family can
    /// tell their doctor's plan apart from the published guidance.
    var attribution: String = ""
    var createdAt: Date = Date()
}

// MARK: - Settings

enum UnitSystem: String, Codable, CaseIterable, Hashable {
    case metric
    case imperial
}

enum AppearanceMode: String, Codable, CaseIterable, Hashable {
    case system
    case light
    case dark
}

struct AppSettings: Codable, Hashable {
    var activeChildId: UUID?
    var units: UnitSystem = .metric
    var appearance: AppearanceMode = .system
    var disclaimerAcceptedAt: Date?
    var showsPediatricianPlan: Bool = false

    /// Reminders default to off. An app about infant feeding that starts sending
    /// notifications uninvited is one more voice telling a tired parent they are behind.
    var allergenReminders: Bool = false
    var growthReminders: Bool = false
    var stageReminders: Bool = false

    var anyRemindersOn: Bool { allergenReminders || growthReminders || stageReminders }
}
