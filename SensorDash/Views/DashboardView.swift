import SwiftUI

struct DashboardView: View {
    @Environment(AppState.self) var appState
    @State private var selectedTab: SensorCategory? = .battery

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                ForEach(SensorCategory.allCases) { category in
                    HStack {
                        Label(category.rawValue, systemImage: category.icon)
                        Spacer()
                        Circle()
                            .fill(appState.dashboard.status(for: category).color)
                            .frame(width: 8, height: 8)
                    }
                    .tag(category)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            .listStyle(.sidebar)
        } detail: {
            if let selectedTab {
                detailView(for: selectedTab)
                    .id(selectedTab)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView("Select a Sensor", systemImage: "gauge.with.dots.needle.33percent", description: Text("Choose a sensor category from the sidebar"))
            }
        }
        .navigationTitle("SensorDash")
        .onAppear { appState.dashboard.startAll() }
        .onDisappear { appState.dashboard.stopAll() }
    }

    @ViewBuilder
    private func detailView(for category: SensorCategory) -> some View {
        switch category {
        case .battery:
            BatteryDetailView()
        case .smc:
            SMCDetailView()
        case .display:
            DisplayDetailView()
        case .multitouch:
            MultitouchDetailView()
        case .hidEvents:
            HIDEventDetailView()
        case .motion:
            MotionDetailView()
        case .proximity:
            ProximityDetailView()
        case .neuralEngine:
            ANEDetailView()
        case .depth:
            DepthDetailView()
        }
    }
}
