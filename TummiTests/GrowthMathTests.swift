import XCTest
@testable import Tummi

final class GrowthMathTests: XCTestCase {

    /// The published WHO table row for a boy at 0 months lists the median weight as
    /// 3.3464 kg and the −2 SD line at 2.5 kg. A z of 0 must land on the median exactly.
    func testMedianIsZeroZ() {
        let lms = WHOStandards.weightBoys[0]
        let z = GrowthMath.z(lms.m, lms: lms)
        XCTAssertEqual(z, 0, accuracy: 0.001)
        XCTAssertEqual(GrowthMath.percentile(fromZ: z), 50, accuracy: 0.001)
    }

    /// Reconstructing the published SD lines from L, M and S is the sharpest check that
    /// the table survived generation and that the formula matches WHO's.
    func testReconstructsPublishedSDLines() {
        let lms = WHOStandards.weightBoys[0]
        XCTAssertEqual(GrowthMath.value(atZ: -2, lms: lms), 2.5, accuracy: 0.05)
        XCTAssertEqual(GrowthMath.value(atZ: 2, lms: lms), 4.4, accuracy: 0.05)
        XCTAssertEqual(GrowthMath.value(atZ: -3, lms: lms), 2.1, accuracy: 0.05)

        let girls12 = WHOStandards.weightGirls[12]
        XCTAssertEqual(girls12.month, 12)
        XCTAssertEqual(GrowthMath.value(atZ: 0, lms: girls12), 8.9, accuracy: 0.05)
    }

    func testLengthAndHeadTablesCoverTwoYears() {
        XCTAssertEqual(WHOStandards.lengthBoys.count, 25)
        XCTAssertEqual(WHOStandards.headGirls.count, 25)
        XCTAssertEqual(WHOStandards.lengthBoys.last?.month, 24)
        XCTAssertEqual(GrowthMath.value(atZ: 0, lms: WHOStandards.lengthBoys[0]), 49.88, accuracy: 0.02)
    }

    /// Beyond ±3 SD the Box-Cox tail explodes; WHO switches to linear extrapolation.
    /// Without the correction an 11 kg newborn reads as a wildly implausible z.
    func testTailCorrectionKeepsExtremesPlausible() {
        let lms = WHOStandards.weightBoys[0]
        let z = GrowthMath.z(11.0, lms: lms)
        XCTAssertGreaterThan(z, 3)
        XCTAssertLessThan(z, 20, "tail correction should keep extreme z-scores finite and readable")
    }

    func testInterpolationSitsBetweenNeighbouringMonths() {
        let table = WHOStandards.weightGirls
        guard let mid = GrowthMath.interpolatedLMS(ageMonths: 7.5, table: table) else {
            return XCTFail("expected an interpolated row")
        }
        XCTAssertGreaterThan(mid.m, table[7].m)
        XCTAssertLessThan(mid.m, table[8].m)
    }

    func testReadingProducesPercentileAndBand() {
        // A 4-month-old girl at the median should read as the 50th percentile.
        let median = WHOStandards.weightGirls[4].m
        guard let reading = GrowthMath.reading(
            value: median, indicator: .weight, sex: .girl, ageMonths: 4
        ) else {
            return XCTFail("expected a reading")
        }
        XCTAssertEqual(reading.percentile, 50, accuracy: 0.5)
        XCTAssertEqual(GrowthMath.band(forZ: reading.z), .typical)
        XCTAssertFalse(GrowthMath.band(forZ: reading.z).needsAttention)
        XCTAssertTrue(GrowthMath.band(forZ: -2.4).needsAttention)
    }
}
