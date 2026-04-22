import SwiftUI

@main
struct PortKillerApp: App {
    @State private var preferences: UserPreferences
    @State private var monitor: PortMonitor

    init() {
        let prefs = UserPreferences()
        _preferences = State(wrappedValue: prefs)
        _monitor = State(wrappedValue: PortMonitor(preferences: prefs))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(preferences: preferences, monitor: monitor)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(preferences: preferences)
        }
    }

    /// 점유 중인 포트 개수에 따라 라벨이 바뀜.
    /// - 0개: 로고만
    /// - N개: 로고 + 숫자 배지
    @ViewBuilder
    private var menuBarLabel: some View {
        let count = monitor.visiblePorts.count
        if count == 0 {
            Image("MenuBarIcon")
        } else {
            HStack(spacing: 3) {
                Image("MenuBarIcon")
                Text("\(count)")
            }
        }
    }
}
