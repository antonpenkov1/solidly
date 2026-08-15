import WidgetKit
import SwiftUI

/// The widget keeps its own copy of the palette: the app's `Theme` reaches for
/// `UIApplication.shared`, which is unavailable in an app extension.
enum WTheme {
    static let bg = Color(uiColor: dynamic(light: (0.980, 0.972, 0.957), dark: (0.078, 0.075, 0.070)))
    static let ink = Color(uiColor: dynamic(light: (0.129, 0.114, 0.098), dark: (0.945, 0.935, 0.918)))
    static let faint = Color(uiColor: dynamic(light: (0.660, 0.630, 0.585), dark: (0.430, 0.418, 0.394)))
    static let secondary = Color(uiColor: dynamic(light: (0.455, 0.424, 0.384), dark: (0.620, 0.600, 0.565)))
    static let accent = Color(uiColor: dynamic(light: (0.243, 0.463, 0.361), dark: (0.435, 0.706, 0.565)))
    static let indigo = Color(uiColor: dynamic(light: (0.290, 0.353, 0.545), dark: (0.545, 0.612, 0.812)))
    static let amber = Color(uiColor: dynamic(light: (0.706, 0.475, 0.129), dark: (0.882, 0.678, 0.322)))
    static let hairline = Color(uiColor: dynamic(light: (0.886, 0.868, 0.835), dark: (0.212, 0.206, 0.192)))

    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func serif(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    private static func dynamic(
        light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)
    ) -> UIColor {
        UIColor { trait in
            let rgb = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        }
    }
}

struct TummiEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct TummiProvider: TimelineProvider {
    func placeholder(in context: Context) -> TummiEntry {
        TummiEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (TummiEntry) -> Void) {
        completion(TummiEntry(date: Date(), snapshot: WidgetBridge.read() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TummiEntry>) -> Void) {
        let snapshot = WidgetBridge.read() ?? WidgetSnapshot()
        let now = Date()

        // The app pushes a fresh snapshot on every save, so the timeline only needs to
        // cover the case where nothing is logged all day — and to roll over at midnight,
        // when "today so far" resets to zero.
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: now.addingTimeInterval(86_400))
        let entries = [TummiEntry(date: now, snapshot: snapshot)]
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }
}

// MARK: - Views

private func amount(_ value: Double, metric: Bool, gram: Bool) -> String {
    if metric {
        return String(format: "%.0f %@", value.rounded(), gram ? "g" : "ml")
    }
    return String(format: "%.1f %@", value / (gram ? 28.3495 : 29.5735), gram ? "oz" : "fl oz")
}

private struct Bar: View {
    let value: Double
    let low: Double
    let high: Double
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(WTheme.hairline)
                Capsule()
                    .fill(tint.opacity(value >= low && value <= high ? 1 : 0.55))
                    .frame(width: max(4, geometry.size.width * fraction))
            }
        }
        .frame(height: 5)
    }

    private var fraction: Double {
        guard high > 0 else { return 0 }
        return min(1, max(0, value / high))
    }
}

struct TummiWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TummiEntry

    var body: some View {
        switch family {
        case .accessoryRectangular: rectangular
        case .systemMedium: medium
        default: small
        }
    }

    private var snapshot: WidgetSnapshot { entry.snapshot }
    private var isEmpty: Bool { snapshot.childName.isEmpty && snapshot.solidTargetHigh == 0 }

    // MARK: Small

    private var small: some View {
        VStack(alignment: .leading, spacing: 7) {
            header
            Spacer(minLength: 0)
            if isEmpty {
                Text("Open Tummi to get started")
                    .font(WTheme.rounded(12, .medium))
                    .foregroundStyle(WTheme.faint)
            } else {
                solidsBlock
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(WTheme.bg, for: .widget)
        .widgetURL(URL(string: "tummi://log/solid"))
    }

    // MARK: Medium

    private var medium: some View {
        HStack(alignment: .top, spacing: 16) {
            // Each half opens the sheet that changes the figure it shows, rather than
            // dumping the parent on the front page to find it themselves.
            Link(destination: URL(string: "tummi://log/solid")!) {
                VStack(alignment: .leading, spacing: 7) {
                    header
                    Spacer(minLength: 0)
                    solidsBlock
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
            }
            VStack(alignment: .leading, spacing: 10) {
                Link(destination: URL(string: "tummi://log/bottle")!) {
                    milkBlock.contentShape(Rectangle())
                }
                mealsBlock
                Spacer(minLength: 0)
                if let allergen = snapshot.lapsedAllergen {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 9, weight: .bold))
                        // Two-argument keys need String(format:) — the key SwiftUI builds
                        // from interpolation does not match the positional one the
                        // exporter writes, and the string silently stays English.
                        Text(String(format: String(localized: "Keep up: %@"), allergen))
                            .font(WTheme.rounded(11, .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(WTheme.amber)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(WTheme.bg, for: .widget)
    }

    // MARK: Lock screen

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(snapshot.childName.isEmpty ? "Tummi" : snapshot.childName)
                .font(.system(size: 13, weight: .semibold))
            Text(amount(snapshot.solidGrams, metric: snapshot.usesMetric, gram: true)
                 + " · " + "\(snapshot.meals)/\(snapshot.mealTargetHigh)")
                .font(.system(size: 12))
            if let last = snapshot.lastFeedAt {
                Text(last, style: .relative)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.clear, for: .widget)
    }

    // MARK: Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(snapshot.childName.isEmpty ? "Tummi" : snapshot.childName)
                .font(WTheme.rounded(14, .bold))
                .foregroundStyle(WTheme.ink)
                .lineLimit(1)
            Text(snapshot.ageText)
                .font(WTheme.rounded(11, .medium))
                .foregroundStyle(WTheme.faint)
        }
    }

    private var solidsBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Food today")
                .font(WTheme.rounded(10, .semibold))
                .foregroundStyle(WTheme.faint)
            Text(amount(snapshot.solidGrams, metric: snapshot.usesMetric, gram: true))
                .font(WTheme.serif(24))
                .foregroundStyle(WTheme.ink)
            if snapshot.solidTargetHigh > 0 {
                Bar(value: snapshot.solidGrams, low: snapshot.solidTargetLow,
                    high: snapshot.solidTargetHigh, tint: WTheme.accent)
                Text(String(format: "%.0f–%.0f", snapshot.solidTargetLow, snapshot.solidTargetHigh))
                    .font(WTheme.rounded(10, .medium))
                    .foregroundStyle(WTheme.faint)
            }
        }
    }

    private var milkBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Milk")
                .font(WTheme.rounded(10, .semibold))
                .foregroundStyle(WTheme.faint)
            if snapshot.showsMilkVolume {
                Text(amount(snapshot.milkMl, metric: snapshot.usesMetric, gram: false))
                    .font(WTheme.serif(17))
                    .foregroundStyle(WTheme.ink)
                Bar(value: snapshot.milkMl, low: snapshot.milkTargetLow,
                    high: snapshot.milkTargetHigh, tint: WTheme.indigo)
            } else {
                Text("\(snapshot.milkFeeds) feeds")
                    .font(WTheme.serif(17))
                    .foregroundStyle(WTheme.ink)
                Bar(value: Double(snapshot.milkFeeds), low: 0,
                    high: Double(max(1, snapshot.milkFeedTarget)), tint: WTheme.indigo)
            }
        }
    }

    private var mealsBlock: some View {
        HStack(spacing: 5) {
            Image(systemName: "fork.knife")
                .font(.system(size: 10, weight: .semibold))
            Text(String(format: String(localized: "%1$lld of %2$lld–%3$lld meals"),
                        snapshot.meals, snapshot.mealTargetLow, snapshot.mealTargetHigh))
                .font(WTheme.rounded(11, .medium))
                .lineLimit(1)
        }
        .foregroundStyle(WTheme.secondary)
    }
}

struct TummiTodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetBridge.kind, provider: TummiProvider()) { entry in
            TummiWidgetView(entry: entry)
        }
        .configurationDisplayName("Today")
        .description("Today's food and milk against the guidance range for your baby's age.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

@main
struct TummiWidgetBundle: WidgetBundle {
    var body: some Widget {
        TummiTodayWidget()
    }
}
