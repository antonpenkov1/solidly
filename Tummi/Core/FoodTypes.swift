import Foundation

enum FoodGroup: String, CaseIterable, Hashable, Codable {
    case vegetable
    case fruit
    case grain
    case protein
    case legume
    case dairy
    case nutSeed
    case fat
    case avoid

    var title: LocalizedText {
        switch self {
        case .vegetable: return T("Vegetables", "Овощи")
        case .fruit: return T("Fruit", "Фрукты")
        case .grain: return T("Grains", "Злаки")
        case .protein: return T("Meat, fish, eggs", "Мясо, рыба, яйца")
        case .legume: return T("Legumes", "Бобовые")
        case .dairy: return T("Dairy", "Молочное")
        case .nutSeed: return T("Nuts & seeds", "Орехи и семена")
        case .fat: return T("Fats", "Жиры")
        case .avoid: return T("Hold off", "Не давать")
        }
    }

    var symbol: String {
        switch self {
        case .vegetable: return "carrot"
        case .fruit: return "apple.logo"
        case .grain: return "laurel.leading"
        case .protein: return "fish"
        case .legume: return "circle.grid.3x3.fill"
        case .dairy: return "drop.fill"
        case .nutSeed: return "leaf.fill"
        case .fat: return "drop.triangle.fill"
        case .avoid: return "hand.raised.fill"
        }
    }
}

/// The "top 9" allergens tracked by regulators in the US and EU. Tummi tracks exposure
/// counts per allergen because repeated, regular exposure — not a single taste — is what
/// the prevention trials actually studied.
enum Allergen: String, CaseIterable, Hashable, Codable {
    case milk
    case egg
    case peanut
    case treeNut
    case soy
    case wheat
    case fish
    case shellfish
    case sesame

    var title: LocalizedText {
        switch self {
        // "Dairy", not "Milk" — otherwise the allergen reads as the milk feed everywhere
        // it sits next to one.
        case .milk: return T("Dairy", "Молочный белок")
        case .egg: return T("Egg", "Яйцо")
        case .peanut: return T("Peanut", "Арахис")
        case .treeNut: return T("Tree nuts", "Орехи")
        case .soy: return T("Soy", "Соя")
        case .wheat: return T("Wheat", "Пшеница")
        case .fish: return T("Fish", "Рыба")
        case .shellfish: return T("Shellfish", "Моллюски и ракообразные")
        case .sesame: return T("Sesame", "Кунжут")
        }
    }
}

enum ChokingRisk: String, Hashable, Codable {
    case low
    case moderate
    case high

    var title: LocalizedText {
        switch self {
        case .low: return T("Low choking risk", "Низкий риск подавиться")
        case .moderate: return T("Cut with care", "Резать аккуратно")
        case .high: return T("High choking risk", "Высокий риск подавиться")
        }
    }
}

enum NutrientTag: String, CaseIterable, Hashable, Codable {
    case iron
    case zinc
    case omega3
    case vitaminC
    case vitaminA
    case vitaminD
    case calcium
    case protein
    case fibre
    case healthyFat

    var title: LocalizedText {
        switch self {
        case .iron: return T("Iron", "Железо")
        case .zinc: return T("Zinc", "Цинк")
        case .omega3: return T("Omega-3", "Омега-3")
        case .vitaminC: return T("Vitamin C", "Витамин C")
        case .vitaminA: return T("Vitamin A", "Витамин A")
        case .vitaminD: return T("Vitamin D", "Витамин D")
        case .calcium: return T("Calcium", "Кальций")
        case .protein: return T("Protein", "Белок")
        case .fibre: return T("Fibre", "Клетчатка")
        case .healthyFat: return T("Healthy fats", "Полезные жиры")
        }
    }
}

struct Food: Identifiable, Hashable {
    let id: String
    let name: LocalizedText
    let emoji: String
    let group: FoodGroup
    /// The age from which this food is commonly introduced, in months. Guidance, not a gate —
    /// the app never blocks logging a food, it only explains what the sources say.
    let earliestMonth: Int
    /// An age below which sources say *do not serve at all* (honey, cow's milk as a drink,
    /// juice). Rendered as a hard red limit rather than a soft suggestion.
    let hardLimitMonth: Int?
    let allergen: Allergen?
    let choking: ChokingRisk
    let nutrients: [NutrientTag]
    /// How to prepare it at 6–8 months, when the baby is learning to move food around.
    let serveEarly: LocalizedText
    /// How to prepare it from about 9 months, once the pincer grasp arrives.
    let serveLater: LocalizedText
    let caution: LocalizedText?
    let sourceIds: [String]

    var isAvoid: Bool { group == .avoid }

    /// Whether the food is age-appropriate for a child of this age, honouring a
    /// paediatrician override if the family recorded one.
    func availability(atMonths months: Double, overrideMonth: Double?) -> FoodAvailability {
        let earliest = overrideMonth ?? Double(earliestMonth)
        if let hardLimitMonth, months < Double(hardLimitMonth) { return .notYet }
        if months + 0.001 < earliest { return .soon }
        return .ready
    }
}

enum FoodAvailability: Hashable {
    /// A hard limit from the sources has not passed yet.
    case notYet
    /// Typically introduced later, but nothing says it is unsafe today.
    case soon
    case ready
}
