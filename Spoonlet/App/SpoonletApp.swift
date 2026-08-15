import SwiftUI

@main
struct SpoonletApp: App {
    @AppStorage("appearance") private var appearanceRaw = AppearanceMode.system.rawValue
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        DemoSeed.seedIfRequested()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .task {
                    (AppearanceMode(rawValue: appearanceRaw) ?? .system).apply()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            // Reminders and the widget snapshot are both derived from data, so they are
            // rebuilt whenever the app comes forward — a gap closed on another day cancels
            // its own reminder, and midnight resets "today so far".
            if phase == .active || phase == .background {
                AppRefresh.run()
            }
        }
    }
}
