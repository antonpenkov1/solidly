import SwiftUI

/// Wraps its subviews onto as many lines as they need.
///
/// Chip rows are built from data — a milestone can cite three bodies, a food can carry an
/// allergen plus a choking flag plus a paediatrician marker — so their total width is not
/// knowable at design time. A plain `HStack` silently grows past the screen and drags the
/// whole scroll view sideways with it; this never does.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    private struct Line {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func lines(subviews: Subviews, maxWidth: CGFloat) -> [Line] {
        var result: [Line] = []
        var current = Line()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let widthIfAppended = current.indices.isEmpty
                ? size.width
                : current.width + spacing + size.width

            if !current.indices.isEmpty && widthIfAppended > maxWidth {
                result.append(current)
                current = Line(indices: [index], width: size.width, height: size.height)
            } else {
                current.indices.append(index)
                current.width = widthIfAppended
                current.height = max(current.height, size.height)
            }
        }
        if !current.indices.isEmpty { result.append(current) }
        return result
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let lines = lines(subviews: subviews, maxWidth: maxWidth)
        let height = lines.reduce(0) { $0 + $1.height }
            + lineSpacing * CGFloat(max(0, lines.count - 1))
        let widest = lines.map(\.width).max() ?? 0
        return CGSize(width: maxWidth.isFinite ? min(widest, maxWidth) : widest, height: height)
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        var y = bounds.minY
        for line in lines(subviews: subviews, maxWidth: bounds.width) {
            var x = bounds.minX
            for index in line.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (line.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += line.height + lineSpacing
        }
    }
}

/// The citation row that appears under every claim in the app.
///
/// Tapping opens the source. This is the whole premise of Tummi, so it is a shared
/// component rather than something each scene re-implements — if a card has no sources,
/// it should not be making a claim.
struct SourceChipsRow: View {
    struct Item: Identifiable, Hashable {
        let id: String
        let label: String
        let urlString: String
    }

    let items: [Item]
    @Environment(\.openURL) private var openURL

    /// Two WHO documents from the same year would render as two identical "WHO, 2023"
    /// chips; the first one already links somewhere useful, so collapse by label.
    private var uniqueItems: [Item] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.label).inserted }
    }

    var body: some View {
        if !items.isEmpty {
            FlowLayout(spacing: 6, lineSpacing: 5) {
                Image(systemName: "text.book.closed")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.faint)
                ForEach(uniqueItems) { item in
                    Button {
                        if let url = URL(string: item.urlString) { openURL(url) }
                    } label: {
                        Text(item.label)
                            .font(Theme.rounded(11, .semibold))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Theme.accentSoft))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A horizontal bar showing today's value against the guidance range.
///
/// The range is drawn as a band rather than a single line, and landing anywhere in the
/// band reads as fine — the design has to avoid feeling like a quota with a pass mark.
struct RangeBar: View {
    let fraction: Double
    let isWithin: Bool
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.hairline)
                Capsule()
                    .fill(tint.opacity(isWithin ? 1 : 0.55))
                    .frame(width: max(6, geometry.size.width * fraction))
            }
        }
        .frame(height: 7)
    }
}

struct MetricTile: View {
    let title: String
    let valueText: String
    let targetText: String?
    let fraction: Double
    let isWithin: Bool
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(Theme.rounded(12, .semibold))
                .foregroundStyle(Theme.faint)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(valueText)
                    .font(Theme.serif(24, .medium))
                    .foregroundStyle(Theme.ink)
                if let targetText {
                    Text("/ \(targetText)")
                        .font(Theme.rounded(12, .medium))
                        .foregroundStyle(Theme.faint)
                }
            }
            RangeBar(fraction: fraction, isWithin: isWithin, tint: tint)
        }
    }
}

/// Standard framing for a screen: warm background, large serif title, generous gutters.
struct ScreenScaffold<Content: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: () -> Content
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(Theme.serif(30, .semibold))
                                .foregroundStyle(Theme.ink)
                            if let subtitle {
                                Text(subtitle)
                                    .font(Theme.rounded(13, .medium))
                                    .foregroundStyle(Theme.secondary)
                            }
                        }
                        Spacer()
                        trailing()
                    }
                    .padding(.top, 8)

                    content()
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 32)
            }
        }
    }
}

extension ScreenScaffold where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, subtitle: subtitle, content: content, trailing: { EmptyView() })
    }
}

/// A card that carries a claim plus the sources behind it.
struct EvidenceCard: View {
    let title: String
    let message: String
    let sources: [SourceChipsRow.Item]
    var accentSymbol: String?

    init(title: String, body: String, sources: [SourceChipsRow.Item], accentSymbol: String? = nil) {
        self.title = title
        self.message = body
        self.sources = sources
        self.accentSymbol = accentSymbol
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if let accentSymbol {
                    Image(systemName: accentSymbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                Text(title)
                    .font(Theme.rounded(16, .semibold))
                    .foregroundStyle(Theme.ink)
            }
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            SourceChipsRow(items: sources)
        }
        .cardStyle()
    }
}

/// An empty screen should carry the action that fills it.
///
/// "Tap the plus" pointing at a 24pt target in the opposite corner is an instruction, not an
/// affordance — the button belongs where the sentence explaining it is.
struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var actionSymbol: String = "plus"
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Theme.faint)
            Text(title)
                .font(Theme.rounded(17, .semibold))
                .foregroundStyle(Theme.ink)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: actionSymbol)
                        .font(Theme.rounded(16, .semibold))
                        .padding(.horizontal, 22)
                        .padding(.vertical, 13)
                        .background(Capsule().fill(Theme.accent))
                        .foregroundStyle(Theme.bg)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}

/// A one-off hint that teaches something the interface cannot say on its own — currently
/// that citations are tappable, which is the entire premise of the app and otherwise looks
/// like decoration. Dismissed for good once read.
struct FirstRunHint: View {
    let storageKey: String
    let symbol: String
    let title: String
    let message: String

    @AppStorage private var dismissed: Bool

    init(storageKey: String, symbol: String, title: String, message: String) {
        self.storageKey = storageKey
        self.symbol = symbol
        self.title = title
        self.message = message
        _dismissed = AppStorage(wrappedValue: false, storageKey)
    }

    var body: some View {
        if !dismissed {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(Theme.rounded(15, .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { dismissed = true }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.faint)
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.accentSoft))
        }
    }
}
