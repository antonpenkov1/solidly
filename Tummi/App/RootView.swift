import SwiftUI

struct RootView: View {
    @State private var hasChild = StorageWorker.shared.activeChild() != nil
    @State private var acceptedDisclaimer = StorageWorker.shared.settings().disclaimerAcceptedAt != nil
    @State private var selectedTab = 0
    @ObservedObject private var deepLink = DeepLink.shared

    var body: some View {
        Group {
            if !hasChild || !acceptedDisclaimer {
                OnboardingView(onFinish: {
                    hasChild = StorageWorker.shared.activeChild() != nil
                    acceptedDisclaimer = StorageWorker.shared.settings().disclaimerAcceptedAt != nil
                })
            } else {
                tabs
            }
        }
        .tint(Theme.accent)
        .onAppear(perform: applyLaunchArguments)
        .onOpenURL { url in
            deepLink.handle(url)
        }
        .onChange(of: deepLink.tab) { _, tab in
            if let tab { selectedTab = tab; deepLink.tab = nil }
        }
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem { Label(String(localized: "Today"), systemImage: "sun.max") }
                .tag(0)

            LogView()
                .tabItem { Label(String(localized: "Log"), systemImage: "list.bullet") }
                .tag(1)

            FoodsView()
                .tabItem { Label(String(localized: "Foods"), systemImage: "carrot") }
                .tag(2)

            PlanView()
                .tabItem { Label(String(localized: "Plan"), systemImage: "checklist") }
                .tag(3)

            GrowthView()
                .tabItem { Label(String(localized: "Growth"), systemImage: "chart.xyaxis.line") }
                .tag(4)
        }
    }

    /// DEBUG entry points used for screenshots and manual verification.
    private func applyLaunchArguments() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-OpenTab"), index + 1 < arguments.count,
           let tab = Int(arguments[index + 1]) {
            selectedTab = tab
        }
        #endif
    }
}
