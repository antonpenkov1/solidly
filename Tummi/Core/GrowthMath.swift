import Foundation

/// Converts a measurement into a WHO z-score and percentile.
///
/// The WHO Child Growth Standards describe each measurement at each age as a Box-Cox
/// power distribution with three parameters — L (skew), M (median), S (variation).
/// A z-score is read off that distribution; the percentile is the normal CDF of the z.
enum GrowthMath {

    /// Value of the reference curve at a given z-score, e.g. the median (z = 0) or the
    /// -2 SD line that clinicians read as the lower edge of normal.
    static func value(atZ z: Double, lms: LMS) -> Double {
        if abs(lms.l) < 1e-7 {
            return lms.m * exp(lms.s * z)
        }
        return lms.m * pow(1 + lms.l * lms.s * z, 1 / lms.l)
    }

    /// Raw LMS z-score, before the WHO tail correction.
    private static func rawZ(_ x: Double, lms: LMS) -> Double {
        if abs(lms.l) < 1e-7 {
            return log(x / lms.m) / lms.s
        }
        return (pow(x / lms.m, lms.l) - 1) / (lms.l * lms.s)
    }

    /// z-score with the correction WHO applies beyond ±3 SD.
    ///
    /// The power distribution's tails are unstable far from the median, so WHO switches
    /// to linear extrapolation using the distance between the 2nd and 3rd SD lines.
    /// Without this, a big-but-healthy baby can read as an implausible +7 SD.
    static func z(_ x: Double, lms: LMS) -> Double {
        let raw = rawZ(x, lms: lms)
        guard raw.isFinite else { return raw }

        if raw > 3 {
            let sd3 = value(atZ: 3, lms: lms)
            let sd2 = value(atZ: 2, lms: lms)
            let gap = sd3 - sd2
            guard gap > 0 else { return raw }
            return 3 + (x - sd3) / gap
        }
        if raw < -3 {
            let sd3neg = value(atZ: -3, lms: lms)
            let sd2neg = value(atZ: -2, lms: lms)
            let gap = sd2neg - sd3neg
            guard gap > 0 else { return raw }
            return -3 + (x - sd3neg) / gap
        }
        return raw
    }

    /// Standard normal CDF, as a percentile in 0...100.
    static func percentile(fromZ z: Double) -> Double {
        let p = 0.5 * (1 + erf(z / 2.0.squareRoot()))
        return min(100, max(0, p * 100))
    }

    /// Linear interpolation between the whole-month reference rows.
    ///
    /// A baby measured at 7 months 20 days sits between two published rows; jumping to
    /// the nearest month would move the percentile by several points around growth spurts.
    static func interpolatedLMS(ageMonths: Double, table: [LMS]) -> LMS? {
        guard let first = table.first, let last = table.last else { return nil }
        if ageMonths <= Double(first.month) { return first }
        if ageMonths >= Double(last.month) { return last }

        guard let upperIndex = table.firstIndex(where: { Double($0.month) >= ageMonths }),
              upperIndex > 0 else { return first }
        let lower = table[upperIndex - 1]
        let upper = table[upperIndex]
        let span = Double(upper.month - lower.month)
        guard span > 0 else { return lower }
        let t = (ageMonths - Double(lower.month)) / span

        return LMS(
            month: lower.month,
            l: lower.l + (upper.l - lower.l) * t,
            m: lower.m + (upper.m - lower.m) * t,
            s: lower.s + (upper.s - lower.s) * t
        )
    }

    struct Reading: Hashable {
        let z: Double
        let percentile: Double
        let median: Double
    }

    static func reading(
        value: Double, indicator: GrowthIndicator, sex: ChildSex, ageMonths: Double
    ) -> Reading? {
        let table = WHOStandards.table(for: indicator, sex: sex)
        guard value > 0, let lms = interpolatedLMS(ageMonths: ageMonths, table: table) else { return nil }
        let zScore = z(value, lms: lms)
        guard zScore.isFinite else { return nil }
        return Reading(z: zScore, percentile: percentile(fromZ: zScore), median: lms.m)
    }

    /// Reference curve points for drawing the -2 SD / median / +2 SD bands on a chart.
    static func curve(
        indicator: GrowthIndicator, sex: ChildSex, z zValue: Double, upToMonths: Int
    ) -> [(month: Double, value: Double)] {
        WHOStandards.table(for: indicator, sex: sex)
            .filter { $0.month <= upToMonths }
            .map { (Double($0.month), value(atZ: zValue, lms: $0)) }
    }

    /// How a z-score reads clinically. WHO flags start at ±2 SD; Tummi phrases them as
    /// "worth mentioning to your doctor", never as a diagnosis.
    enum Band: Hashable {
        case low        // below -2 SD
        case belowMid   // -2 to -1
        case typical    // -1 to +1
        case aboveMid   // +1 to +2
        case high       // above +2 SD

        var needsAttention: Bool { self == .low || self == .high }
    }

    static func band(forZ z: Double) -> Band {
        switch z {
        case ..<(-2): return .low
        case -2 ..< -1: return .belowMid
        case -1 ... 1: return .typical
        case 1 ... 2: return .aboveMid
        default: return .high
        }
    }
}
