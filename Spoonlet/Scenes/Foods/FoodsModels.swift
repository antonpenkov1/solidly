import Foundation

enum Foods {
    enum Filter: String, CaseIterable, Hashable {
        case all
        case readyNow
        case allergens
        case notTried
        case introduced

        var title: LocalizedText {
            switch self {
            case .all: return T("All", "Все")
            case .readyNow: return T("Ready now", "Можно сейчас")
            case .allergens: return T("Allergens", "Аллергены")
            case .notTried: return T("Not tried", "Не пробовали")
            case .introduced: return T("Tried", "Пробовали")
            }
        }
    }

    enum Load {
        struct Request {
            var query: String = ""
            var filter: Filter = .all
        }

        struct Response {
            let months: Double
            let foods: [Food]
            let intros: [String: FoodIntro]
            let overrides: [OverrideKey: CareOverride]
            let filter: Filter
            let allergenSummary: [(allergen: Allergen, status: Guidance.AllergenStatus)]
        }

        struct ViewModel {
            struct Row: Identifiable, Hashable {
                enum Badge: Hashable {
                    case notYet(String)
                    case soon(String)
                    case allergen(String)
                    case choking(String)
                    case pediatrician(String)
                }
                let id: String
                let emoji: String
                let name: String
                let badges: [Badge]
                let exposuresText: String?
                let isIntroduced: Bool
                let hadReaction: Bool
            }

            struct Section: Identifiable, Hashable {
                let id: String
                let title: String
                let rows: [Row]
            }

            struct AllergenPill: Identifiable, Hashable {
                enum State: Hashable { case notStarted, introduced, maintained, reacted }
                let id: String
                let title: String
                let detail: String
                let state: State
            }

            let sections: [Section]
            let allergenPills: [AllergenPill]
            let progressText: String
            let isEmpty: Bool

            static let empty = ViewModel(sections: [], allergenPills: [],
                                         progressText: "", isEmpty: true)
        }
    }
}
