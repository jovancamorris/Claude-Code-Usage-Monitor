import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject var poller: UsagePoller
    @Environment(\.dismiss) var dismiss
    
    @State private var tempToken: String = ""
    @State private var showToken: Bool = false
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Preferences")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.bottom, 4)
            
            Divider()
            
            // Section 1: Provider & Display
            VStack(alignment: .leading, spacing: 12) {
                Text("General Settings")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Picker("Default Provider", selection: $settings.selectedProvider) {
                    ForEach(ProviderType.allCases) { prov in
                        Text(prov.rawValue).tag(prov)
                    }
                }
                
                Picker("Display Direction", selection: $settings.displayDirection) {
                    ForEach(DisplayDirection.allCases) { dir in
                        Text(dir.rawValue).tag(dir)
                    }
                }
                .pickerStyle(.segmented)
                
                Picker("Menu Bar Format", selection: $settings.menuBarDisplayMode) {
                    ForEach(MenuBarDisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                
                Picker("Refresh Interval", selection: $settings.refreshInterval) {
                    Text("1 minute").tag(60.0)
                    Text("5 minutes").tag(300.0)
                    Text("15 minutes (Default)").tag(900.0)
                    Text("30 minutes").tag(1800.0)
                    Text("1 hour").tag(3600.0)
                }
            }
            
            Divider()
            
            // Section 2: Claude Code Token Override
            VStack(alignment: .leading, spacing: 8) {
                Text("Claude Code Authentication Override")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Text("Leave blank to automatically detect credentials from macOS Keychain or ~/.claude/.credentials.json.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                HStack {
                    if showToken {
                        TextField("sk-ant-oat01-...", text: $tempToken)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("sk-ant-oat01-...", text: $tempToken)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Button {
                        showToken.toggle()
                    } label: {
                        Image(systemName: showToken ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                }
                
                HStack {
                    Button("Apply Token") {
                        settings.customToken = tempToken
                        poller.fetchAll(settings: settings)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    
                    if !settings.customToken.isEmpty {
                        Button("Clear") {
                            tempToken = ""
                            settings.customToken = ""
                            poller.fetchAll(settings: settings)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            
            Divider()
            
            // Section 3: Antigravity Note
            VStack(alignment: .leading, spacing: 4) {
                Text("Google Antigravity Setup")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("Detected automatically from ~/.gemini/jetski-standalone-oauth-token with token auto-refresh via Google Cloud Code APIs.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Section 4: Demo Mode Toggle
            HStack {
                Toggle("Demo Mode (Simulate live metrics)", isOn: $settings.demoMode)
                    .onChange(of: settings.demoMode) {
                        poller.fetchAll(settings: settings)
                    }
                Spacer()
            }
            
            Divider()
            
            // About & Credits
            HStack {
                Text("Usage Monitor for macOS v2.23.0")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                Link("GitHub Repo", destination: URL(string: "https://github.com/jovancamorris/Claude-Code-Usage-Monitor")!)
                    .font(.system(size: 10))
            }
        }
        .padding(18)
        .frame(width: 360)
        .onAppear {
            tempToken = settings.customToken
        }
    }
}
