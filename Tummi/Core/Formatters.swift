import Foundation

enum Fmt {

    // MARK: - Amounts

    static func grams(_ value: Double, units: UnitSystem = .metric) -> String {
        switch units {
        case .metric:
            return String(format: "%.0f %@", value.rounded(), String(localized: "g"))
        case .imperial:
            return String(format: "%.1f %@", value / 28.3495, String(localized: "oz"))
        }
    }

    static func ml(_ value: Double, units: UnitSystem = .metric) -> String {
        switch units {
        case .metric:
            return String(format: "%.0f %@", value.rounded(), String(localized: "ml"))
        case .imperial:
            return String(format: "%.1f %@", value / 29.5735, String(localized: "fl oz"))
        }
    }

    static func range(_ range: ClosedRange<Double>, units: UnitSystem, unit: AmountUnit) -> String {
        let low = range.lowerBound
        let high = range.upperBound
        if abs(high - low) < 1 {
            return unit == .ml ? ml(low, units: units) : grams(low, units: units)
        }
        switch (unit, units) {
        case (.ml, .metric):
            return String(format: "%.0f–%.0f %@", low, high, String(localized: "ml"))
        case (.ml, .imperial):
            return String(format: "%.1f–%.1f %@", low / 29.5735, high / 29.5735, String(localized: "fl oz"))
        case (.g, .metric):
            return String(format: "%.0f–%.0f %@", low, high, String(localized: "g"))
        case (.g, .imperial):
            return String(format: "%.1f–%.1f %@", low / 28.3495, high / 28.3495, String(localized: "oz"))
        case (.min, _):
            return String(format: "%.0f–%.0f %@", low, high, String(localized: "min"))
        }
    }

    static func intRange(_ range: ClosedRange<Int>) -> String {
        range.lowerBound == range.upperBound
            ? "\(range.lowerBound)"
            : "\(range.lowerBound)–\(range.upperBound)"
    }

    static func minutes(_ value: Double) -> String {
        String(format: "%.0f %@", value.rounded(), String(localized: "min"))
    }

    static func duration(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "\(minutes) \(String(localized: "min"))" }
        return "\(hours) \(String(localized: "h")) \(minutes) \(String(localized: "min"))"
    }

    // MARK: - Measurements

    static func weight(_ kg: Double, units: UnitSystem) -> String {
        switch units {
        case .metric: return String(format: "%.2f %@", kg, String(localized: "kg"))
        case .imperial:
            let totalOunces = kg * 35.274
            let pounds = Int(totalOunces / 16)
            let ounces = totalOunces - Double(pounds) * 16
            return String(format: "%d %@ %.0f %@", pounds, String(localized: "lb"), ounces, String(localized: "oz"))
        }
    }

    static func length(_ cm: Double, units: UnitSystem) -> String {
        switch units {
        case .metric: return String(format: "%.1f %@", cm, String(localized: "cm"))
        case .imperial: return String(format: "%.1f %@", cm / 2.54, String(localized: "in"))
        }
    }

    static func percentile(_ value: Double) -> String {
        if value < 1 { return "<1" }
        if value > 99 { return ">99" }
        return String(format: "%.0f", value.rounded())
    }

    static func zScore(_ value: Double) -> String {
        String(format: "%+.1f SD", value)
    }

    // MARK: - Age

    /// "7 months 2 weeks" — the unit parents and paediatricians actually use.
    static func age(days: Int) -> String {
        if days < 14 {
            return String(localized: "\(days)d")
        }
        if days < 92 {
            let weeks = days / 7
            return String(localized: "\(weeks)w")
        }
        let months = Int(Double(days) / 30.4375)
        if months < 24 {
            let remainderDays = days - Int(Double(months) * 30.4375)
            let weeks = remainderDays / 7
            if weeks == 0 { return String(localized: "\(months)mo") }
            // Multi-argument keys go through String(format:) with the positional literal:
            // the key `String(localized:)` builds at runtime from two interpolations does
            // not match the positional one the exporter extracts, so the lookup misses and
            // the string silently stays English.
            return String(format: String(localized: "%1$lldmo %2$lldw"), months, weeks)
        }
        let years = months / 12
        let leftover = months % 12
        if leftover == 0 { return String(localized: "\(years)y") }
        return String(format: String(localized: "%1$lldy %2$lldmo"), years, leftover)
    }

    static func monthsLabel(_ months: Double) -> String {
        String(format: "%.0f", months.rounded(.down))
    }

    // MARK: - Dates

    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func day(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return String(localized: "Today") }
        if calendar.isDateInYesterday(date) { return String(localized: "Yesterday") }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }

    static func fullDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year())
    }

    static func relative(_ date: Date, to now: Date = Date()) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return String(localized: "just now") }
        if seconds < 3600 {
            return String(localized: "\(Int(seconds / 60))m ago")
        }
        if seconds < 86_400 {
            let hours = Int(seconds / 3600)
            let minutes = Int(seconds.truncatingRemainder(dividingBy: 3600) / 60)
            return minutes == 0
                ? String(localized: "\(hours)h ago")
                : String(format: String(localized: "%1$lldh %2$lldm ago"), hours, minutes)
        }
        return day(date)
    }
}
