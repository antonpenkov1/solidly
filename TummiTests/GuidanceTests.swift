import XCTest
@testable import Tummi

final class GuidanceTests: XCTestCase {

    func testStageBoundaries() {
        XCTAssertEqual(AgeStage.stage(forMonths: 0), .milkOnly)
        XCTAssertEqual(AgeStage.stage(forMonths: 3.9), .milkOnly)
        XCTAssertEqual(AgeStage.stage(forMonths: 4), .gettingReady)
        XCTAssertEqual(AgeStage.stage(forMonths: 6), .firstTastes)
        XCTAssertEqual(AgeStage.stage(forMonths: 9), .buildingMeals)
        XCTAssertEqual(AgeStage.stage(forMonths: 12), .familyTable)
        XCTAssertEqual(AgeStage.stage(forMonths: 24), .toddler)
    }

    /// The WHO portion ladder: 2–3 tablespoons (~30–45 g) at 6 months growing to about
    /// half a 250 ml cup by 9 months. The interpolation must hit both ends.
    func testPortionLadderMatchesWHOEndpoints() {
        let atSix = Guidance.targets(forMonths: 6, weightKg: 7.9).perMealGrams
        XCTAssertEqual(atSix?.lowerBound ?? 0, 30, accuracy: 0.5)
        XCTAssertEqual(atSix?.upperBound ?? 0, 45, accuracy: 0.5)

        let almostNine = Guidance.targets(forMonths: 8.99, weightKg: 8.6).perMealGrams
        XCTAssertEqual(almostNine?.upperBound ?? 0, 125, accuracy: 1)

        let atNine = Guidance.targets(forMonths: 9, weightKg: 8.9).perMealGrams
        XCTAssertEqual(atNine?.upperBound ?? 0, 125, accuracy: 0.5)
    }

    /// NHS: 150–200 ml per kg per day until around 6 months.
    func testMilkGuideScalesWithWeight() {
        let targets = Guidance.targets(forMonths: 2, weightKg: 5)
        XCTAssertEqual(targets.dailyMilkMl?.lowerBound ?? 0, 750, accuracy: 0.5)
        XCTAssertEqual(targets.dailyMilkMl?.upperBound ?? 0, 1000, accuracy: 0.5)
    }

    /// Without a weight there is nothing to scale, so the range is omitted rather than
    /// invented — an app that guesses a millilitre target is worse than one that says nothing.
    func testMilkGuideOmittedWithoutWeightUnderSixMonths() {
        XCTAssertNil(Guidance.targets(forMonths: 2, weightKg: nil).dailyMilkMl)
        XCTAssertNotNil(Guidance.targets(forMonths: 7, weightKg: nil).dailyMilkMl)
    }

    func testPediatricianOverrideWins() {
        let childId = UUID()
        let overrides: [OverrideKey: CareOverride] = [
            .perMealGrams: CareOverride(childId: childId, key: .perMealGrams,
                                        value: 80, attribution: "Dr Ivanova"),
        ]
        let targets = Guidance.targets(forMonths: 7, weightKg: 8, overrides: overrides)
        XCTAssertEqual(targets.perMealGrams?.lowerBound, 80)
        XCTAssertEqual(targets.perMealGrams?.upperBound, 80)
        XCTAssertTrue(targets.isOverridden)
        XCTAssertEqual(targets.attribution, "Dr Ivanova")
        XCTAssertTrue(targets.overriddenFields.contains(.perMealGrams))
        XCTAssertFalse(targets.overriddenFields.contains(.dailyMilkMl))
    }

    /// A single taste is not what the prevention trials tested; "maintained" requires both
    /// enough exposures and a recent one.
    func testAllergenStatusNeedsRegularExposure() {
        let childId = UUID()
        let now = Date()

        XCTAssertEqual(Guidance.allergenStatus(.peanut, intros: [], on: now), .notStarted)

        let onceOnly = FoodIntro(childId: childId, foodId: "peanut",
                                 firstOffered: now, lastOffered: now, exposures: 1)
        XCTAssertEqual(Guidance.allergenStatus(.peanut, intros: [onceOnly], on: now),
                       .introduced(exposures: 1))

        let regular = FoodIntro(childId: childId, foodId: "peanut",
                                firstOffered: now.addingTimeInterval(-60 * 86_400),
                                lastOffered: now.addingTimeInterval(-3 * 86_400), exposures: 8)
        XCTAssertEqual(Guidance.allergenStatus(.peanut, intros: [regular], on: now),
                       .maintained(exposures: 8))

        // Same count, but dropped a month ago — no longer maintained.
        let lapsed = FoodIntro(childId: childId, foodId: "peanut",
                               firstOffered: now.addingTimeInterval(-90 * 86_400),
                               lastOffered: now.addingTimeInterval(-30 * 86_400), exposures: 8)
        XCTAssertEqual(Guidance.allergenStatus(.peanut, intros: [lapsed], on: now),
                       .introduced(exposures: 8))

        let reacted = FoodIntro(childId: childId, foodId: "peanut",
                                firstOffered: now, lastOffered: now, exposures: 3,
                                worstReaction: .notable)
        XCTAssertEqual(Guidance.allergenStatus(.peanut, intros: [reacted], on: now), .reacted)
    }
}

final class FoodLibraryTests: XCTestCase {

    func testEveryFoodHasResolvableSources() {
        for food in FoodLibrary.all {
            XCTAssertFalse(food.sourceIds.isEmpty, "\(food.id) makes claims with no source")
            for id in food.sourceIds {
                XCTAssertNotNil(Evidence.source(id), "\(food.id) cites unknown source \(id)")
            }
        }
    }

    func testFoodIdsAreUnique() {
        let ids = FoodLibrary.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "duplicate food ids would silently shadow entries")
    }

    /// The hard limits are the ones with a mechanism behind them; they must actually gate.
    func testHardLimitsBlockUntilTheirAge() {
        guard let honey = FoodLibrary.food("honey") else { return XCTFail("honey missing") }
        XCTAssertEqual(honey.availability(atMonths: 8, overrideMonth: nil), .notYet)
        XCTAssertEqual(honey.availability(atMonths: 12, overrideMonth: nil), .ready)

        // A paediatrician override must never unlock a botulism-grade limit.
        XCTAssertEqual(honey.availability(atMonths: 8, overrideMonth: 6), .notYet)

        guard let avocado = FoodLibrary.food("avocado") else { return XCTFail("avocado missing") }
        XCTAssertEqual(avocado.availability(atMonths: 5, overrideMonth: nil), .soon)
        XCTAssertEqual(avocado.availability(atMonths: 5, overrideMonth: 4), .ready)
    }

    func testEveryAllergenIsRepresentedByAtLeastOneRealFood() {
        for allergen in Allergen.allCases {
            let matches = FoodLibrary.all.filter { $0.allergen == allergen && !$0.isAvoid }
            XCTAssertFalse(matches.isEmpty, "no introducible food covers \(allergen.rawValue)")
        }
    }

    func testSearchIsBilingual() {
        XCTAssertTrue(FoodLibrary.search("avocado").contains { $0.id == "avocado" })
        XCTAssertTrue(FoodLibrary.search("авокадо").contains { $0.id == "avocado" })
    }
}
