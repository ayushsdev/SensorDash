import SwiftUI

@Observable
@MainActor
final class AppState {
    let dashboard = DashboardViewModel()
}
