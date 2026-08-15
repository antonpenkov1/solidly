import Foundation
import SwiftUI

/// Routing for `spoonlet://` URLs, which today come from the widget.
///
/// A widget that only opens the app to its front page wastes the tap. Tapping the food
/// figure should land on the sheet that changes that figure.
final class DeepLink: ObservableObject {
    static let shared = DeepLink()

    @Published var tab: Int?
    @Published var pendingLogKind: FeedKind?

    private init() {}

    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard url.scheme == "spoonlet" else { return false }

        switch url.host {
        case "log":
            tab = 0
            switch url.lastPathComponent {
            case "bottle": pendingLogKind = .bottle
            case "breast": pendingLogKind = .breast
            case "water": pendingLogKind = .water
            default: pendingLogKind = .solid
            }
        case "growth":
            tab = 4
        case "plan":
            tab = 3
        case "foods":
            tab = 2
        default:
            tab = 0
        }
        return true
    }

    func consumeLogKind() -> FeedKind? {
        defer { pendingLogKind = nil }
        return pendingLogKind
    }
}
