import Foundation

/// What the widget knows.
///
/// The widget reads this snapshot and nothing else — it never opens the SwiftData store.
/// That keeps the extension small and fast, and it means the store stays a single-writer
/// resource owned by the app, which is the failure mode most widget/host pairs trip over.
struct WidgetSnapshot: Codable, Hashable {
    var childName: String = ""
    var ageText: String = ""
    var stageTitle: String = ""

    var solidGrams: Double = 0
    var solidTargetLow: Double = 0
    var solidTargetHigh: Double = 0

    var milkMl: Double = 0
    var milkTargetLow: Double = 0
    var milkTargetHigh: Double = 0
    /// Fully breastfed days have no millilitres, so the widget shows feed counts instead.
    var showsMilkVolume: Bool = true
    var milkFeeds: Int = 0
    var milkFeedTarget: Int = 0

    var meals: Int = 0
    var mealTargetLow: Int = 0
    var mealTargetHigh: Int = 0

    var lastFeedAt: Date?
    var lapsedAllergen: String?
    var usesMetric: Bool = true
    var updatedAt: Date = Date()

    static let placeholder = WidgetSnapshot(
        childName: "Mila", ageText: "7mo 2w", stageTitle: "First tastes",
        solidGrams: 140, solidTargetLow: 90, solidTargetHigh: 257,
        milkMl: 620, milkTargetLow: 500, milkTargetHigh: 800,
        showsMilkVolume: true, milkFeeds: 4, milkFeedTarget: 5,
        meals: 2, mealTargetLow: 2, mealTargetHigh: 3,
        lastFeedAt: Date().addingTimeInterval(-2400), lapsedAllergen: "Peanut"
    )
}

enum WidgetBridge {
    static let appGroup = "group.com.antonpenkov.spoonlet"
    static let kind = "SpoonletTodayWidget"

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("widget.json")
    }

    static func write(_ snapshot: WidgetSnapshot) {
        guard let fileURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func read() -> WidgetSnapshot? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }
}
