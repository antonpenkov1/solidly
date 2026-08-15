import Foundation

enum FoodDetail {
    enum Load {
        struct Request {
            let foodId: String
        }

        struct Response {
            let food: Food
            let months: Double
            let stage: AgeStage
            let intro: FoodIntro?
            let overrideMonth: Double?
            let overrideAttribution: String?
            let availability: FoodAvailability
        }

        struct ViewModel {
            struct SourceItem: Identifiable, Hashable {
                let id: String
                let citation: String
                let title: String
                let kindLabel: String
                let takeaway: String
                let urlString: String
            }

            let emoji: String
            let name: String
            let groupTitle: String
            let statusText: String
            let statusDetail: String
            let statusKind: StatusKind
            let servingTitle: String
            let servingText: String
            let otherServingTitle: String
            let otherServingText: String
            let allergenText: String?
            let chokingText: String?
            let nutrientTitles: [String]
            let cautionText: String?
            let historyText: String?
            let overrideText: String?
            let sources: [SourceItem]

            enum StatusKind: Hashable { case ready, soon, blocked }

            static let empty = ViewModel(
                emoji: "", name: "", groupTitle: "", statusText: "", statusDetail: "",
                statusKind: .ready, servingTitle: "", servingText: "",
                otherServingTitle: "", otherServingText: "",
                allergenText: nil, chokingText: nil, nutrientTitles: [],
                cautionText: nil, historyText: nil, overrideText: nil, sources: []
            )
        }
    }

    enum SetOverride {
        struct Request {
            let foodId: String
            let month: Double?
            let attribution: String
        }
    }
}
