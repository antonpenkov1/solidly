import Foundation

enum Log {
    enum Load {
        struct Request {
            var days: Int = 30
        }

        struct Response {
            let child: Child
            let units: UnitSystem
            let feeds: [FeedEntry]
            let diapers: [DiaperEntry]
            let sleeps: [SleepEntry]
            let runningSleep: SleepEntry?
        }

        struct ViewModel {
            struct Row: Identifiable, Hashable {
                enum Source: Hashable {
                    case feed(UUID)
                    case diaper(UUID)
                    case sleep(UUID)
                }
                let id: UUID
                let source: Source
                let symbol: String
                let title: String
                let detail: String?
                let timeText: String
                let hasReaction: Bool
            }

            struct DaySection: Identifiable, Hashable {
                let id: Date
                let title: String
                let summary: String
                let rows: [Row]
            }

            let isEmpty: Bool
            let sections: [DaySection]
            let runningSleepText: String?

            static let empty = ViewModel(isEmpty: true, sections: [], runningSleepText: nil)
        }
    }
}
