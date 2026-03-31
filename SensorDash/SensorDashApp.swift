import SwiftUI

@main
struct SensorDashApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup("SensorDash") {
            DashboardView()
                .environment(appState)
        }
        .defaultSize(width: 1100, height: 750)

        MenuBarExtra("SensorDash", systemImage: "gauge.with.dots.needle.33percent") {
            MenuBarView()
                .environment(appState)
        }
        .menuBarExtraStyle(.window)
    }
}
