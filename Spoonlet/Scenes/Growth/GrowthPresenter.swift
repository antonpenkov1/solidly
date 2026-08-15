import Foundation

protocol GrowthPresentationLogic {
    func presentGrowth(response: Growth.Load.Response)
    func presentEmpty()
}

protocol GrowthDisplayLogic: AnyObject {
    func displayGrowth(viewModel: Growth.Load.ViewModel)
}

final class GrowthPresenter: GrowthPresentationLogic {
    weak var view: GrowthDisplayLogic?

    func presentEmpty() {
        view?.displayGrowth(viewModel: .empty)
    }

    func presentGrowth(response: Growth.Load.Response) {
        let indicator = response.indicator
        let child = response.child
        let units = response.units

        // Show the curves a little past the child's current age so the trend has somewhere
        // to go, but never the full five years — the chart would be unreadable at 2 months.
        let horizon = min(24, max(6, Int(response.ageMonths.rounded(.up)) + 3))

        var curvePoints: [Growth.Load.ViewModel.ChartPoint] = []
        for (zValue, label) in [(-2.0, "−2 SD"), (0.0, String(localized: "median")), (2.0, "+2 SD")] {
            let curve = GrowthMath.curve(indicator: indicator, sex: child.sex,
                                         z: zValue, upToMonths: horizon)
            curvePoints += curve.map {
                .init(id: "\(label)-\($0.month)", month: $0.month,
                      value: convert($0.value, indicator: indicator, units: units), series: label)
            }
        }

        let measured = response.points.compactMap { point -> (GrowthPoint, Double)? in
            guard let value = point.value(for: indicator) else { return nil }
            return (point, value)
        }

        let childSeries = String(localized: "your baby")
        let childPoints = measured.map { point, value in
            Growth.Load.ViewModel.ChartPoint(
                id: point.id.uuidString,
                month: child.ageMonths(on: point.date),
                value: convert(value, indicator: indicator, units: units),
                series: childSeries
            )
        }

        let latest = measured.max { $0.0.date < $1.0.date }
        let latestReading = latest.flatMap { point, value in
            GrowthMath.reading(value: value, indicator: indicator, sex: child.sex,
                               ageMonths: child.ageMonths(on: point.date))
        }

        view?.displayGrowth(viewModel: .init(
            isEmpty: measured.isEmpty,
            indicator: indicator,
            curvePoints: curvePoints,
            childPoints: childPoints,
            latestValueText: latest.map { valueText($0.1, indicator: indicator, units: units) },
            latestPercentileText: latestReading.map {
                String(localized: "\(Fmt.percentile($0.percentile))th percentile")
            },
            latestZText: latestReading.map { Fmt.zScore($0.z) },
            bandText: latestReading.map { bandText($0, indicator: indicator) },
            bandKind: (latestReading.map { GrowthMath.band(forZ: $0.z).needsAttention } ?? false)
                ? .watch : .typical,
            axisLabel: axisLabel(indicator, units: units),
            rows: measured.sorted { $0.0.date > $1.0.date }.map { point, value in
                let reading = GrowthMath.reading(
                    value: value, indicator: indicator, sex: child.sex,
                    ageMonths: child.ageMonths(on: point.date)
                )
                return .init(
                    id: point.id,
                    dateText: Fmt.fullDate(point.date),
                    valueText: valueText(value, indicator: indicator, units: units),
                    percentileText: reading.map { String(localized: "p\(Fmt.percentile($0.percentile))") },
                    ageText: Fmt.age(days: child.correctedAgeDays(on: point.date))
                )
            }
        ))
    }

    // MARK: - Pieces

    /// WHO tables are metric; the display unit is applied only at the edge so that curves
    /// and measured points are always converted the same way.
    private func convert(_ value: Double, indicator: GrowthIndicator, units: UnitSystem) -> Double {
        guard units == .imperial else { return value }
        return indicator == .weight ? value * 2.20462 : value / 2.54
    }

    private func valueText(_ value: Double, indicator: GrowthIndicator, units: UnitSystem) -> String {
        indicator == .weight ? Fmt.weight(value, units: units) : Fmt.length(value, units: units)
    }

    private func axisLabel(_ indicator: GrowthIndicator, units: UnitSystem) -> String {
        switch (indicator, units) {
        case (.weight, .metric): return String(localized: "kg")
        case (.weight, .imperial): return String(localized: "lb")
        case (_, .metric): return String(localized: "cm")
        case (_, .imperial): return String(localized: "in")
        }
    }

    /// Deliberately phrased as "worth mentioning", never as a finding. WHO flags start at
    /// ±2 SD, but a single point outside the band is a reason to talk to a doctor, not a
    /// diagnosis an app should hand a parent.
    private func bandText(_ reading: GrowthMath.Reading, indicator: GrowthIndicator) -> String {
        switch GrowthMath.band(forZ: reading.z) {
        case .typical, .belowMid, .aboveMid:
            return String(localized: "Within the usual range. What matters is that the curve keeps its own shape over months, not any single reading.")
        case .low:
            return String(localized: "Below the WHO −2 SD line. That is a threshold clinicians look at — worth mentioning at your next visit, and sooner if it is a change from before.")
        case .high:
            return String(localized: "Above the WHO +2 SD line. Often simply a big, healthy baby — worth mentioning at your next visit so someone who can examine your child takes a look.")
        }
    }
}
