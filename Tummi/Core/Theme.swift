import SwiftUI

/// Tummi's design system: warm oat paper, deep cocoa ink, a single sage accent.
/// Deliberately calm rather than nursery-pastel — the app carries clinical guidance,
/// and pastel candy colours undercut that. Amber marks allergens, clay marks cautions.
/// Every colour has a light and dark variant through a UIColor dynamic provider so
/// UIKit appearance surfaces (tab bar, nav bar) stay in step.
enum Theme {
    static let bgUI = dynamicUI(light: (0.980, 0.972, 0.957), dark: (0.078, 0.075, 0.070))
    static let cardUI = dynamicUI(light: (1.000, 0.998, 0.992), dark: (0.128, 0.124, 0.116))
    static let inkUI = dynamicUI(light: (0.129, 0.114, 0.098), dark: (0.945, 0.935, 0.918))
    static let hairlineUI = dynamicUI(light: (0.886, 0.868, 0.835), dark: (0.212, 0.206, 0.192))

    static let bg = Color(bgUI)
    static let card = Color(cardUI)
    static let ink = Color(inkUI)
    static let hairline = Color(hairlineUI)

    static let secondary = Color(dynamicUI(light: (0.455, 0.424, 0.384), dark: (0.620, 0.600, 0.565)))
    static let faint = Color(dynamicUI(light: (0.660, 0.630, 0.585), dark: (0.430, 0.418, 0.394)))

    /// Sage — "on track", the primary action colour.
    static let accent = Color(dynamicUI(light: (0.243, 0.463, 0.361), dark: (0.435, 0.706, 0.565)))
    static let accentSoft = Color(dynamicUI(light: (0.902, 0.937, 0.914), dark: (0.145, 0.212, 0.176)))

    /// Amber — allergen flags. Informative, never alarming.
    static let amber = Color(dynamicUI(light: (0.706, 0.475, 0.129), dark: (0.882, 0.678, 0.322)))
    static let amberSoft = Color(dynamicUI(light: (0.976, 0.941, 0.867), dark: (0.208, 0.169, 0.086)))

    /// Clay — choking hazards and hard "not before" limits.
    static let clay = Color(dynamicUI(light: (0.706, 0.271, 0.216), dark: (0.878, 0.482, 0.427)))
    static let claySoft = Color(dynamicUI(light: (0.976, 0.914, 0.898), dark: (0.212, 0.114, 0.098)))

    /// Indigo — milk, sleep and other night-time surfaces.
    static let indigo = Color(dynamicUI(light: (0.290, 0.353, 0.545), dark: (0.545, 0.612, 0.812)))
    static let indigoSoft = Color(dynamicUI(light: (0.918, 0.929, 0.960), dark: (0.129, 0.149, 0.216)))

    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static let cardRadius: CGFloat = 20
    static let gutter: CGFloat = 18

    private static func dynamicUI(
        light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)
    ) -> UIColor {
        UIColor { trait in
            let rgb = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        }
    }
}

extension AppearanceMode {
    var uiStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// Overrides the trait on the app's windows. More reliable than `preferredColorScheme`,
    /// which never resets back to system once it has been set.
    func apply() {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .forEach { $0.overrideUserInterfaceStyle = uiStyle }
    }

    var title: String {
        switch self {
        case .system: return String(localized: "System")
        case .light: return String(localized: "Light")
        case .dark: return String(localized: "Dark")
        }
    }
}

// MARK: - Shared views

struct Hairline: View {
    var body: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1)
    }
}

struct CardBackground: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
    }
}

extension View {
    func cardStyle(padding: CGFloat = 16) -> some View {
        modifier(CardBackground(padding: padding))
    }
}

struct SectionLabel: View {
    let text: LocalizedStringKey

    init(_ text: LocalizedStringKey) { self.text = text }

    var body: some View {
        Text(text)
            .font(Theme.rounded(12, .bold))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(Theme.faint)
    }
}

/// Small pill used for allergen / choking / nutrient flags.
struct Chip: View {
    let title: String
    var systemImage: String?
    var tint: Color = Theme.accent
    var background: Color = Theme.accentSoft

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 10, weight: .bold))
            }
            Text(title).font(Theme.rounded(12, .semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(background))
    }
}

/// A dismissible keyboard bar. The native `ToolbarItemGroup(placement: .keyboard)`
/// silently stops appearing inside a TabView, so Tummi drives its own bar off the
/// keyboard notifications — the same fix Jarz needed.
struct KeyboardDoneBar: ViewModifier {
    @State private var visible = false
    @FocusState private var dummy: Bool

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                if visible {
                    HStack {
                        Spacer()
                        Button(String(localized: "Done")) {
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.resignFirstResponder),
                                to: nil, from: nil, for: nil
                            )
                        }
                        .font(Theme.rounded(16, .semibold))
                        .foregroundStyle(Theme.accent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.bar)
                }
            }
            .onReceive(NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillShowNotification)) { _ in visible = true }
            .onReceive(NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillHideNotification)) { _ in visible = false }
    }
}

extension View {
    func keyboardDoneButton() -> some View { modifier(KeyboardDoneBar()) }
}
