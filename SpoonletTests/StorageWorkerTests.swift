import XCTest
@testable import Spoonlet

final class StorageWorkerTests: XCTestCase {
    private var worker: StorageWorker!
    private var child: Child!

    override func setUp() {
        super.setUp()
        worker = StorageWorker(inMemory: true)
        child = Child(name: "Test", birthDate: Date().addingTimeInterval(-220 * 86_400), sex: .girl)
        worker.save(child: child)
        var settings = worker.settings()
        settings.activeChildId = child.id
        worker.save(settings: settings)
    }

    /// Exposure counts drive the allergen guidance, so they are derived from logged meals
    /// rather than kept by hand. Each new meal adds one.
    func testLoggingMealsBuildsTheIntroductionLedger() {
        let day = Date().addingTimeInterval(-3 * 86_400)
        worker.save(feed: FeedEntry(childId: child.id, date: day, kind: .solid,
                                    grams: 30, foodIds: ["egg", "avocado"], acceptance: .tasted))
        worker.save(feed: FeedEntry(childId: child.id, date: day.addingTimeInterval(86_400),
                                    kind: .solid, grams: 45, foodIds: ["egg"], acceptance: .loved))

        guard let egg = worker.foodIntro(childId: child.id, foodId: "egg") else {
            return XCTFail("expected an egg introduction")
        }
        XCTAssertEqual(egg.exposures, 2)
        XCTAssertEqual(egg.bestAcceptance, .loved, "best acceptance should ratchet up, not overwrite")
        XCTAssertEqual(worker.foodIntro(childId: child.id, foodId: "avocado")?.exposures, 1)
    }

    /// Editing yesterday's meal must not invent an extra exposure — otherwise a parent who
    /// corrects a typo makes the allergen tracker claim a serving that never happened.
    func testResavingTheSameEntryDoesNotDoubleCount() {
        var entry = FeedEntry(childId: child.id, date: Date().addingTimeInterval(-86_400),
                              kind: .solid, grams: 30, foodIds: ["peanut"], acceptance: .tasted)
        worker.save(feed: entry)
        entry.grams = 40
        worker.save(feed: entry)
        entry.note = "thinned with formula"
        worker.save(feed: entry)

        XCTAssertEqual(worker.foodIntro(childId: child.id, foodId: "peanut")?.exposures, 1)
    }

    func testWorstReactionRatchetsAndNeverClears() {
        let base = Date().addingTimeInterval(-5 * 86_400)
        worker.save(feed: FeedEntry(childId: child.id, date: base, kind: .solid,
                                    grams: 20, foodIds: ["shrimp"], reaction: .mild))
        worker.save(feed: FeedEntry(childId: child.id, date: base.addingTimeInterval(86_400),
                                    kind: .solid, grams: 20, foodIds: ["shrimp"], reaction: .noReaction))

        XCTAssertEqual(worker.foodIntro(childId: child.id, foodId: "shrimp")?.worstReaction, .mild)
    }

    func testOverridesRoundTripThroughTheirStorageKey() {
        worker.setOverride(childId: child.id, key: .foodEarliestMonth("cowMilkDrink"),
                           value: 10, attribution: "Dr Ivanova")
        worker.setOverride(childId: child.id, key: .perMealGrams, value: 80, attribution: "Dr Ivanova")

        let overrides = worker.overrides(childId: child.id)
        XCTAssertEqual(overrides[.foodEarliestMonth("cowMilkDrink")]?.value, 10)
        XCTAssertEqual(overrides[.perMealGrams]?.value, 80)
        XCTAssertEqual(overrides[.perMealGrams]?.attribution, "Dr Ivanova")

        worker.clearOverride(childId: child.id, key: .perMealGrams)
        XCTAssertNil(worker.overrides(childId: child.id)[.perMealGrams])
        XCTAssertNotNil(worker.overrides(childId: child.id)[.foodEarliestMonth("cowMilkDrink")])
    }

    func testLatestWeightPicksTheMostRecentMeasurement() {
        let now = Date()
        worker.save(growth: GrowthPoint(childId: child.id, date: now.addingTimeInterval(-30 * 86_400),
                                        weightKg: 7.2))
        worker.save(growth: GrowthPoint(childId: child.id, date: now, weightKg: 8.05))
        // A later entry with no weight must not shadow the last real reading.
        worker.save(growth: GrowthPoint(childId: child.id, date: now.addingTimeInterval(86_400),
                                        lengthCm: 68))

        XCTAssertEqual(worker.latestWeight(childId: child.id) ?? 0, 8.05, accuracy: 0.001)
    }

    func testDeletingAChildRemovesEverythingBelongingToIt() {
        worker.save(feed: FeedEntry(childId: child.id, kind: .solid, grams: 30, foodIds: ["pear"]))
        worker.save(growth: GrowthPoint(childId: child.id, weightKg: 8))
        worker.save(diaper: DiaperEntry(childId: child.id))
        worker.setOverride(childId: child.id, key: .perMealGrams, value: 80, attribution: "")

        worker.deleteChild(id: child.id)

        XCTAssertTrue(worker.children().isEmpty)
        XCTAssertTrue(worker.recentFeedEntries(childId: child.id).isEmpty)
        XCTAssertTrue(worker.growthPoints(childId: child.id).isEmpty)
        XCTAssertTrue(worker.foodIntros(childId: child.id).isEmpty)
        XCTAssertTrue(worker.overrides(childId: child.id).isEmpty)
    }

    func testExportContainsTheChildAndItsEntries() {
        worker.save(feed: FeedEntry(childId: child.id, kind: .solid, grams: 30, foodIds: ["pear"]))
        guard let data = worker.exportJSON(childId: child.id),
              let text = String(data: data, encoding: .utf8) else {
            return XCTFail("expected JSON export")
        }
        XCTAssertTrue(text.contains("\"pear\""))
        XCTAssertTrue(text.contains("\"exportedAt\""))
    }
}
