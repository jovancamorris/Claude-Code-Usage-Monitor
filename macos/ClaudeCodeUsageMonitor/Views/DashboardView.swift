import SwiftUI

public struct DashboardView: View {
    @EnvironmentObject var poller: UsagePoller
    @EnvironmentObject var settings: SettingsManager
    @State private var showingSettings = false
    
    public var body: some View {
        VStack(spacing: 14) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)
                
                Text("Claude Code Monitor")
                    .font(.system(size: 14, weight: .bold))
                
                Spacer()
                
                // Status pill
                statusBadge
            }
            .padding(.bottom, 2)
            
            // Error banner if any
            if let error = poller.errorMessage {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    if !settings.demoMode && settings.customToken.isEmpty {
                        Button("Enable Demo Mode") {
                            settings.demoMode = true
                            poller.fetchUsage(settings: settings)
                        }
                        .font(.system(size: 11, weight: .medium))
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                }
                .padding(10)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(8)
            }
            
            // 5-Hour Limit Card
            LimitCardView(
                title: "5-Hour Session Window",
                icon: "hourglass",
                bucket: poller.usageData.fiveHour,
                direction: settings.displayDirection
            )
            
            // 7-Day Limit Card
            LimitCardView(
                title: "7-Day Weekly Window",
                icon: "calendar",
                bucket: poller.usageData.sevenDay,
                direction: settings.displayDirection
            )
            
            // Extra Spend Card (if enabled)
            if let spend = poller.usageData.spend, spend.enabled {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("On-Demand Spend")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("\(spend.formattedUsed) / \(spend.formattedLimit)")
                            .font(.system(size: 14, weight: .bold))
                    }
                    Spacer()
                    Image(systemName: "creditcard.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 16))
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                .cornerRadius(8)
            }
            
            Divider()
            
            // Footer Info & Actions
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let updated = poller.lastPollTime {
                        Text("Updated \(formattedTime(updated))")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Text("Source: \(poller.usageData.credentialSource)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 6) {
                    Button {
                        poller.fetchUsage(settings: settings)
                    } label: {
                        if poller.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Refresh Now")
                    
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Preferences")
                    
                    Button {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Image(systemName: "power")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Quit Application")
                }
            }
        }
        .padding(14)
        .frame(width: 320)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(poller)
        }
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text(statusLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(0.12))
        .cornerRadius(10)
    }
    
    private var statusColor: Color {
        if poller.isLoading {
            return .blue
        }
        switch poller.usageData.status {
        case .success:
            return .green
        case .loading:
            return .blue
        case .error:
            return .red
        case .idle:
            return .gray
        }
    }
    
    private var statusLabel: String {
        if poller.isLoading {
            return "Updating"
        }
        switch poller.usageData.status {
        case .success:
            return "Active"
        case .loading:
            return "Updating"
        case .error:
            return "Error"
        case .idle:
            return "Idle"
        }
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
