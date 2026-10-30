import Foundation
import Combine

@MainActor
public class UsagePoller: ObservableObject {
    @Published public var usageData: UsageData = UsageData()
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
        fetchUsage(settings: settings)
        
        timer = Timer.scheduledTimer(withTimeInterval: settings.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetchUsage(settings: settings)
            }
        }
    }
    
    private func startCountdownTimer() {
        // Ticks every 30 seconds to refresh UI countdown badges
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.objectWillChange.send()
            }
        }
    }
    
    public func fetchUsage(settings: SettingsManager) {
        if settings.demoMode {
            self.isLoading = false
            self.errorMessage = nil
            let now = Date()
            let fiveHourReset = now.addingTimeInterval(3 * 3600 + 15 * 60)
            let sevenDayReset = now.addingTimeInterval(4 * 86400 + 12 * 3600)
            
            self.usageData = UsageData(
                fiveHour: UsageBucket(utilization: 0.38, resetsAt: fiveHourReset, rawResetsAt: "demo"),
                sevenDay: UsageBucket(utilization: 0.19, resetsAt: sevenDayReset, rawResetsAt: "demo"),
                spend: SpendBucket(enabled: true, usedMinor: 240, limitMinor: 2500, exponent: 2),
                lastUpdated: now,
                status: .success,
                credentialSource: "Demo Mode"
            )
            self.lastPollTime = now
            return
        }
        
        guard let credential = CredentialManager.getCredential(customToken: settings.customToken) else {
            self.isLoading = false
            self.errorMessage = "No Claude credentials found. Run 'claude login' in Terminal or enter token in Settings."
            self.usageData.status = .error("Credentials missing")
            return
        }
        
        self.isLoading = true
        self.errorMessage = nil
        self.usageData.credentialSource = credential.source
        
        guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(credential.token)", forHTTPHeaderField: "Authorization")
        request.addValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.addValue("claude-code-usage-monitor-mac/2.22.4", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.usageData.status = .error(error.localizedDescription)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.errorMessage = "Invalid network response"
                    self.usageData.status = .error("Invalid response")
                    return
                }
                
                guard let data = data else {
                    self.errorMessage = "Empty data received"
                    self.usageData.status = .error("Empty response")
                    return
                }
                
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    self.errorMessage = "Authentication failed (HTTP \(httpResponse.statusCode)). Please re-authenticate."
                    self.usageData.status = .error("Auth error")
                    return
                }
                
                if httpResponse.statusCode != 200 {
                    let bodyStr = String(data: data, encoding: .utf8) ?? ""
                    self.errorMessage = "HTTP Error \(httpResponse.statusCode): \(bodyStr)"
                    self.usageData.status = .error("HTTP \(httpResponse.statusCode)")
                    return
                }
                
                self.parseUsageResponse(data: data, source: credential.source)
            }
        }.resume()
    }
    
    private func parseUsageResponse(data: Data, source: String) {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw NSError(domain: "JSONError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON"])
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
            
            let now = Date()
            self.usageData = UsageData(
                fiveHour: fiveHourBucket,
                sevenDay: sevenDayBucket,
                spend: spendBucket,
                lastUpdated: now,
                status: .success,
                credentialSource: source
            )
            self.lastPollTime = now
            self.errorMessage = nil
            
        } catch {
            self.errorMessage = "Failed to parse usage: \(error.localizedDescription)"
            self.usageData.status = .error("Parse failure")
        }
    }
    
    public func menuBarText(settings: SettingsManager) -> String {
        if settings.demoMode {
            return "Demo: 38%"
        }
        
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
