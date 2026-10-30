import Foundation
import Combine

@MainActor
public class UsagePoller: ObservableObject {
    @Published public var usageData: UsageData = UsageData()
    @Published public var antigravityData: AntigravityUsageData = AntigravityUsageData()
    @Published public var isLoading: Bool = false
    @Published public var lastPollTime: Date? = nil
    @Published public var errorMessage: String? = nil
    
    private var timer: Timer?
    private var countdownTimer: Timer?
    
    private let isoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    private let fallbackIsoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    public init() {
        startCountdownTimer()
    }
    
    public func startPolling(settings: SettingsManager) {
        timer?.invalidate()
        fetchAll(settings: settings)
        
        timer = Timer.scheduledTimer(withTimeInterval: settings.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetchAll(settings: settings)
            }
        }
    }
    
    private func startCountdownTimer() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.objectWillChange.send()
            }
        }
    }
    
    public func fetchAll(settings: SettingsManager) {
        if settings.demoMode {
            loadDemoData()
            return
        }
        
        self.isLoading = true
        self.errorMessage = nil
        
        Task {
            // 1. Fetch Antigravity
            do {
                let agyData = try await AntigravityService.fetchUsage()
                self.antigravityData = agyData
            } catch {
                self.antigravityData.status = .error(error.localizedDescription)
            }
            
            // 2. Fetch Claude Code
            await fetchClaudeCode(settings: settings)
            
            self.isLoading = false
            self.lastPollTime = Date()
        }
    }
    
    private func fetchClaudeCode(settings: SettingsManager) async {
        guard let credential = CredentialManager.getCredential(customToken: settings.customToken) else {
            self.usageData.status = .error("No Claude Code credentials found.")
            return
        }
        
        self.usageData.credentialSource = credential.source
        guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(credential.token)", forHTTPHeaderField: "Authorization")
        request.addValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.addValue("claude-code-usage-monitor-mac/2.22.4", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                self.usageData.status = .error("Invalid response")
                return
            }
            
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                self.usageData.status = .error("Auth error (HTTP \(httpResponse.statusCode))")
                return
            }
            
            if httpResponse.statusCode != 200 {
                self.usageData.status = .error("HTTP \(httpResponse.statusCode)")
                return
            }
            
            parseClaudeUsage(data: data, source: credential.source)
        } catch {
            self.usageData.status = .error(error.localizedDescription)
        }
    }
    
    private func parseClaudeUsage(data: Data, source: String) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            self.usageData.status = .error("Failed to parse JSON")
            return
        }
        
        var fiveHourBucket: UsageBucket? = nil
        if let fiveHourDict = json["five_hour"] as? [String: Any] {
            let util = (fiveHourDict["utilization"] as? Double) ?? 0.0
            let resetsStr = fiveHourDict["resets_at"] as? String
            let date = resetsStr.flatMap { isoDateFormatter.date(from: $0) ?? fallbackIsoDateFormatter.date(from: $0) }
            fiveHourBucket = UsageBucket(utilization: util, resetsAt: date, rawResetsAt: resetsStr)
        }
        
        var sevenDayBucket: UsageBucket? = nil
        if let sevenDayDict = json["seven_day"] as? [String: Any] {
            let util = (sevenDayDict["utilization"] as? Double) ?? 0.0
            let resetsStr = sevenDayDict["resets_at"] as? String
            let date = resetsStr.flatMap { isoDateFormatter.date(from: $0) ?? fallbackIsoDateFormatter.date(from: $0) }
            sevenDayBucket = UsageBucket(utilization: util, resetsAt: date, rawResetsAt: resetsStr)
        }
        
        var spendBucket: SpendBucket? = nil
        if let spendDict = json["spend"] as? [String: Any] {
            let enabled = (spendDict["enabled"] as? Bool) ?? false
            var usedMinor = 0.0
            var limitMinor = 0.0
            var exp = 2
            
            if let usedDict = spendDict["used"] as? [String: Any] {
                usedMinor = (usedDict["amount_minor"] as? Double) ?? 0.0
                exp = (usedDict["exponent"] as? Int) ?? 2
            }
            if let limitDict = spendDict["limit"] as? [String: Any] {
                limitMinor = (limitDict["amount_minor"] as? Double) ?? 0.0
            }
            spendBucket = SpendBucket(enabled: enabled, usedMinor: usedMinor, limitMinor: limitMinor, exponent: exp)
        }
        
        self.usageData = UsageData(
            fiveHour: fiveHourBucket,
            sevenDay: sevenDayBucket,
            spend: spendBucket,
            lastUpdated: Date(),
            status: .success,
            credentialSource: source
        )
    }
    
    private func loadDemoData() {
        self.isLoading = false
        self.errorMessage = nil
        let now = Date()
        
        // Demo Claude Code
        self.usageData = UsageData(
            fiveHour: UsageBucket(utilization: 0.38, resetsAt: now.addingTimeInterval(3 * 3600), rawResetsAt: "demo"),
            sevenDay: UsageBucket(utilization: 0.19, resetsAt: now.addingTimeInterval(4 * 86400), rawResetsAt: "demo"),
            spend: SpendBucket(enabled: true, usedMinor: 240, limitMinor: 2500, exponent: 2),
            lastUpdated: now,
            status: .success,
            credentialSource: "Demo Mode"
        )
        
        // Demo Antigravity
        self.antigravityData = AntigravityUsageData(
            groups: [
                AntigravityGroupQuota(
                    displayName: "Gemini Models",
                    iconName: "sparkles",
                    fiveHour: UsageBucket(utilization: 0.03, resetsAt: now.addingTimeInterval(4 * 3600 + 45 * 60)),
                    weekly: UsageBucket(utilization: 0.65, resetsAt: now.addingTimeInterval(2 * 86400 + 9 * 3600))
                ),
                AntigravityGroupQuota(
                    displayName: "Claude and GPT models",
                    iconName: "brain.head.profile",
                    fiveHour: UsageBucket(utilization: 0.0, resetsAt: now.addingTimeInterval(5 * 3600)),
                    weekly: UsageBucket(utilization: 0.50, resetsAt: now.addingTimeInterval(5 * 86400))
                ),
                AntigravityGroupQuota(
                    displayName: "Gemini 4 Argon",
                    iconName: "bolt.fill",
                    fiveHour: nil,
                    weekly: UsageBucket(utilization: 0.35, resetsAt: now.addingTimeInterval(4 * 86400))
                )
            ],
            lastUpdated: now,
            status: .success,
            credentialSource: "Demo Mode",
            project: "aicode-consumers"
        )
        
        self.lastPollTime = now
    }
    
    public func menuBarText(settings: SettingsManager) -> String {
        if settings.demoMode {
            return "Demo: 3%"
        }
        
        if settings.selectedProvider == .antigravity {
            guard antigravityData.status == .success, let gemini = antigravityData.groups.first(where: { $0.displayName.contains("Gemini Models") }) else {
                return "AGY"
            }
            
            switch settings.menuBarDisplayMode {
            case .iconOnly:
                return ""
            case .compact:
                if let five = gemini.fiveHour {
                    return five.formattedPercentage(direction: settings.displayDirection)
                }
                return "AGY"
            case .full:
                let fiveStr = gemini.fiveHour?.formattedPercentage(direction: settings.displayDirection) ?? "--%"
                let weeklyStr = gemini.weekly?.formattedPercentage(direction: settings.displayDirection) ?? "--%"
                return "Gemini: \(fiveStr) | W: \(weeklyStr)"
            }
        } else {
            guard usageData.status == .success else {
                return "Claude"
            }
            
            switch settings.menuBarDisplayMode {
            case .iconOnly:
                return ""
            case .compact:
                if let five = usageData.fiveHour {
                    return five.formattedPercentage(direction: settings.displayDirection)
                }
                return "Claude"
            case .full:
                let fiveStr = usageData.fiveHour?.formattedPercentage(direction: settings.displayDirection) ?? "--%"
                let sevenStr = usageData.sevenDay?.formattedPercentage(direction: settings.displayDirection) ?? "--%"
                return "5h: \(fiveStr) | 7d: \(sevenStr)"
            }
        }
    }
}
