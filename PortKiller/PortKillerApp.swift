import SwiftUI

@main
struct PortKillerApp: App {
    var body: some Scene {
        MenuBarExtra("PortKiller", image: "MenuBarIcon") {
            MenuBarContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
