import Foundation

enum Plan {
    enum Load {
        struct Request {}

        struct Response {
            let child: Child
            let months: Double
            let stage: AgeStage
            let profile: StageProfile
            let targets: FeedingTargets
            let units: UnitSystem
            let usesPediatricianPlan: Bool
            let overrides: [OverrideKey: CareOverride]
            let done: [Guidance.Milestone]
            let upcoming: [Guidance.Milestone]
        }

        struct ViewModel {
            struct TargetRow: Identifiable, Hashable {
                let id: String
                let title: String
                let valueText: String
                let isOverridden: Bool
                let overrideKind: OverrideKind

                enum OverrideKind: Hashable {
                    case dailyMilkMl
                    case mealsPerDay
                    case perMealGrams
                    case none
                }
            }

            struct CardItem: Identifiable, Hashable {
                let id: String
                let title: String
                let body: String
                let sources: [SourceChipsRowItem]
            }

            struct SourceChipsRowItem: Identifiable, Hashable {
                let id: String
                let label: String
                let urlString: String
            }

            struct MilestoneRow: Identifiable, Hashable {
                let id: String
                let title: String
                let detail: String
                let whenText: String
                let isDone: Bool
                let sources: [SourceChipsRowItem]
            }

            let isEmpty: Bool
            let stageTitle: String
            let stageRange: String
            let headline: String
            let targetRows: [TargetRow]
            let targetSources: [SourceChipsRowItem]
            let overrideBanner: String?
            let usesPediatricianPlan: Bool
            let cards: [CardItem]
            let milestones: [MilestoneRow]

            static let empty = ViewModel(
                isEmpty: true, stageTitle: "", stageRange: "", headline: "",
                targetRows: [], targetSources: [], overrideBanner: nil,
                usesPediatricianPlan: false, cards: [], milestones: []
            )
        }
    }

    enum Toggle {
        struct Request {
            let enabled: Bool
        }
    }

    enum SetTarget {
        struct Request {
            let key: OverrideKey
            let value: Double?
            let attribution: String
        }
    }
}
