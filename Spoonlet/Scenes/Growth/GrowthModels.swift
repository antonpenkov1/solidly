import Foundation

enum Growth {
    enum Load {
        struct Request {
            var indicator: GrowthIndicator = .weight
        }

        struct Response {
            let child: Child
            let indicator: GrowthIndicator
            let units: UnitSystem
            let points: [GrowthPoint]
            let ageMonths: Double
        }

        struct ViewModel {
            struct ChartPoint: Identifiable, Hashable {
                let id: String
                let month: Double
                let value: Double
                let series: String
            }

            struct HistoryRow: Identifiable, Hashable {
                let id: UUID
                let dateText: String
                let valueText: String
                let percentileText: String?
                let ageText: String
            }

            enum BandKind: Hashable { case typical, watch }

            let isEmpty: Bool
            let indicator: GrowthIndicator
            let curvePoints: [ChartPoint]
            let childPoints: [ChartPoint]
            let latestValueText: String?
            let latestPercentileText: String?
            let latestZText: String?
            let bandText: String?
            let bandKind: BandKind
            let axisLabel: String
            let rows: [HistoryRow]

            static let empty = ViewModel(
                isEmpty: true, indicator: .weight, curvePoints: [], childPoints: [],
                latestValueText: nil, latestPercentileText: nil, latestZText: nil,
                bandText: nil, bandKind: .typical, axisLabel: "", rows: []
            )
        }
    }

    enum Save {
        struct Request {
            let date: Date
            let weightKg: Double?
            let lengthCm: Double?
            let headCm: Double?
        }
    }
}
