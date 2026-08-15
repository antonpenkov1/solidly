import Foundation

enum Today {
    enum Load {
        struct Request {
            var date: Date = Date()
        }

        struct Response {
            let child: Child
            let date: Date
            let ageDays: Int
            let months: Double
            let stage: AgeStage
            let targets: FeedingTargets
            let totals: FeedMath.DayTotals
            let recent: [FeedEntry]
            let intros: [FoodIntro]
            let latestWeight: Double?
            let units: UnitSystem
            let focusCard: GuidanceCard
            let nextMilestone: Guidance.Milestone?
            let allergenGap: (allergen: Allergen, status: Guidance.AllergenStatus)?
            let newFoodIds: [String]
            let runningSleep: SleepEntry?
        }

        struct ViewModel {
            struct Metric: Identifiable, Hashable {
                enum Tint: Hashable { case accent, indigo, amber }
                let id: String
                let title: String
                let valueText: String
                let targetText: String?
                let fraction: Double
                let isWithin: Bool
                let tint: Tint
            }

            struct SourceChip: Identifiable, Hashable {
                let id: String
                let label: String
                let urlString: String
            }

            struct EntryRow: Identifiable, Hashable {
                let id: UUID
                let symbol: String
                let title: String
                let detail: String?
                let timeText: String
                let hasReaction: Bool
            }

            let isEmpty: Bool
            /// Nothing logged today at all. The metric bars are hidden in that case: three
            /// zeros under three empty bars reads as three failed targets before the parent
            /// has done anything, which is the opposite of what the ranges are for.
            let isDayEmpty: Bool
            let dayEmptyMessage: String
            let childName: String
            let ageText: String
            let stageTitle: String
            let stageRange: String
            let headline: String

            let metrics: [Metric]
            let overrideNote: String?

            let focusTitle: String
            let focusBody: String
            let focusSources: [SourceChip]

            let allergenTitle: String?
            let allergenDetail: String?

            let newFoodNote: String?

            let recentRows: [EntryRow]
            let sleepRunningText: String?

            let milestoneTitle: String?
            let milestoneDetail: String?
            let milestoneWhen: String?

            static let empty = ViewModel(
                isEmpty: true, isDayEmpty: true, dayEmptyMessage: "",
                childName: "", ageText: "", stageTitle: "", stageRange: "",
                headline: "", metrics: [], overrideNote: nil,
                focusTitle: "", focusBody: "", focusSources: [],
                allergenTitle: nil, allergenDetail: nil, newFoodNote: nil,
                recentRows: [], sleepRunningText: nil,
                milestoneTitle: nil, milestoneDetail: nil, milestoneWhen: nil
            )
        }
    }
}
