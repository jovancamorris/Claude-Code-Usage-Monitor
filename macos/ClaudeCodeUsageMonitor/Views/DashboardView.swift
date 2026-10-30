import SwiftUI

public struct DashboardView: View {
    @EnvironmentObject var poller: UsagePoller
    @EnvironmentObject var settings: SettingsManager
    @State private var showingSettings = false
    
    public var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: settings.selectedProvider.icon)
                    .font(.system(size: 15))
                    .foregroundColor(settings.selectedProvider == .antigravity ? .blue : .orange)
                
                Text(settings.selectedProvider.rawValue)
                    .font(.system(size: 14, weight: .bold))
                
                Spacer()
                
                statusBadge
            }
            .padding(.bottom, 2)
            
            // Provider Segmented Switcher
            Picker("Provider", selection: $settings.selectedProvider) {
                ForEach(ProviderType.allCases) { prov in
                    Text(prov.rawValue).tag(prov)
                }
            }
            .pickerStyle(.segmented)
            
            // Provider Content
            if settings.selectedProvider == .antigravity {
                antigravityContent
            } else {
                claudeCodeContent
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
                    Text(sourceText)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    Button {
                        poller.fetchAll(settings: settings)
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
        .frame(width: 330)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(poller)
        }
    }
    
    // MARK: - Antigravity Content
    @ViewBuilder
    private var antigravityContent: some View {
        if case .error(let msg) = poller.antigravityData.status {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(msg)
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                }
                if !settings.demoMode {
                    Button("Enable Demo Mode") {
                        settings.demoMode = true
                        poller.fetchAll(settings: settings)
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
        
        if poller.antigravityData.groups.isEmpty && !poller.isLoading {
            Text("No quota information available yet.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.vertical, 8)
        } else {
            VStack(spacing: 10) {
                ForEach(poller.antigravityData.groups) { group in
                    AntigravityGroupCardView(group: group, direction: settings.displayDirection)
                }
            }
        }
    }
    
    // MARK: - Claude Code Content
    @ViewBuilder
    private var claudeCodeContent: some View {
        if case .error(let msg) = poller.usageData.status {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(msg)
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                }
                if !settings.demoMode && settings.customToken.isEmpty {
                    Button("Enable Demo Mode") {
                        settings.demoMode = true
                        poller.fetchAll(settings: settings)
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
        
        LimitCardView(
            title: "5-Hour Session Window",
            icon: "hourglass",
            bucket: poller.usageData.fiveHour,
            direction: settings.displayDirection
        )
        
        LimitCardView(
            title: "7-Day Weekly Window",
            icon: "calendar",
            bucket: poller.usageData.sevenDay,
            direction: settings.displayDirection
        )
        
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
    }
    
    private var sourceText: String {
        if settings.selectedProvider == .antigravity {
            if let proj = poller.antigravityData.project {
                return "Project: \(proj)"
            }
            return "Source: \(poller.antigravityData.credentialSource)"
        } else {
            return "Source: \(poller.usageData.credentialSource)"
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
        if poller.isLoading { return .blue }
        let status = settings.selectedProvider == .antigravity ? poller.antigravityData.status : poller.usageData.status
        switch status {
        case .success: return .green
        case .loading: return .blue
        case .error: return .red
        case .idle: return .gray
        }
    }
    
    private var statusLabel: String {
        if poller.isLoading { return "Updating" }
        let status = settings.selectedProvider == .antigravity ? poller.antigravityData.status : poller.usageData.status
        switch status {
        case .success: return "Active"
        case .loading: return "Updating"
        case .error: return "Error"
        case .idle: return "Idle"
        }
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
