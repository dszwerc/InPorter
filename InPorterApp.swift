import SwiftUI
import Combine

@main
struct InPorterApp: App {
    // REMOVED: The global @StateObject model was causing all windows to sync.
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowToolbarStyle(.unifiedCompact)
        .windowStyle(.hiddenTitleBar)

        Settings {
            // Settings can use its own instance. Since InPorterModel loads/saves 
            // to UserDefaults in its init, changes here will persist globally.
            SettingsView()
                .environmentObject(InPorterModel())
        }
    }
}
