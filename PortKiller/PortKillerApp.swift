import SwiftUI

@main
struct PortKillerApp: App {
    @State private var preferences = UserPreferences()

    var body: some Scene {
        MenuBarExtra("PortKiller", image: "MenuBarIcon") {
            MenuBarContentView(preferences: preferences)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(preferences: preferences)
        }

        Window("About PortKiller", id: WindowID.about) {
            AboutView()
        }
        .windowResizability(.contentSize)
    }
}

enum WindowID {
    static let about = "about"
}
