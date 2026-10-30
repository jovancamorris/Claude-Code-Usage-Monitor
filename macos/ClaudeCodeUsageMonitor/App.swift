import SwiftUI

@main
struct ClaudeCodeUsageMonitorApp: App {
    @StateObject private var settings = SettingsManager()
    @StateObject private var poller = UsagePoller()
    
    var body: some Scene {
        MenuBarExtra {
            DashboardView()
                .environmentObject(poller)
                .environmentObject(settings)
                .onAppear {
                    poller.startPolling(settings: settings)
                }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: settings.selectedProvider.icon)
                let text = poller.menuBarText(settings: settings)
                if !text.isEmpty {
                    Text(text)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
