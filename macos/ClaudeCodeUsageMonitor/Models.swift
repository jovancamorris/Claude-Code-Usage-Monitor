import Foundation

public enum MonitorStatus: Equatable {
    case idle
    case loading
    case success
    case error(String)
    
    public var displayText: String {
        switch self {
        case .idle:
            return "Idle"
        case .loading:
            return "Refreshing..."
        case .success:
            return "Active"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

public enum DisplayDirection: String, CaseIterable, Identifiable {
    case used = "Used"
    case remaining = "Remaining"
    
    public var id: String { rawValue }
}

public enum MenuBarDisplayMode: String, CaseIterable, Identifiable {
    case full = "Full (5h & 7d)"
    case compact = "Compact (5h only)"
    case iconOnly = "Icon Only"
    
    public var id: String { rawValue }
}

public struct UsageBucket: Equatable {
    public var utilization: Double // Normalized 0.0 ... 1.0
    public var resetsAt: Date?
    public var rawResetsAt: String?
    
    public init(utilization: Double, resetsAt: Date? = nil, rawResetsAt: String? = nil) {
        self.utilization = max(0.0, min(1.0, utilization))
        self.resetsAt = resetsAt
        self.rawResetsAt = rawResetsAt
    }
    
    public var percentageString: String {
        return "\(Int(round(utilization * 100)))%"
    }
    
    public func formattedPercentage(direction: DisplayDirection) -> String {
        let val = direction == .used ? utilization : (1.0 - utilization)
        return "\(Int(round(val * 100)))%"
    }
    
    public var timeRemainingString: String {
        guard let resetsAt = resetsAt else {
            return "No reset timer"
        }
        let now = Date()
        let diff = resetsAt.timeIntervalSince(now)
        if diff <= 0 {
            return "Resetting soon"
        }
        
        let hours = Int(diff) / 3600
        let minutes = (Int(diff) % 3600) / 60
        if hours > 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "\(days)d \(remainingHours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(max(1, minutes))m"
        }
    }
}

public struct SpendBucket: Equatable {
    public var enabled: Bool
    public var usedMinor: Double
    public var limitMinor: Double
    public var exponent: Int
    
    public init(enabled: Bool, usedMinor: Double, limitMinor: Double, exponent: Int = 2) {
        self.enabled = enabled
        self.usedMinor = usedMinor
        self.limitMinor = limitMinor
        self.exponent = exponent
    }
    
    public var usedMajor: Double {
        return usedMinor / pow(10.0, Double(exponent))
    }
    
    public var limitMajor: Double {
        return limitMinor / pow(10.0, Double(exponent))
    }
    
    public var formattedUsed: String {
        return String(format: "$%.2f", usedMajor)
    }
    
    public var formattedLimit: String {
        return String(format: "$%.2f", limitMajor)
    }
}

public struct UsageData: Equatable {
    public var fiveHour: UsageBucket?
    public var sevenDay: UsageBucket?
    public var spend: SpendBucket?
    public var lastUpdated: Date?
    public var status: MonitorStatus = .idle
    public var credentialSource: String = "Unknown"
    
    public init(
        fiveHour: UsageBucket? = nil,
        sevenDay: UsageBucket? = nil,
        spend: SpendBucket? = nil,
        lastUpdated: Date? = nil,
        status: MonitorStatus = .idle,
        credentialSource: String = "Unknown"
    ) {
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
        self.spend = spend
        self.lastUpdated = lastUpdated
        self.status = status
        self.credentialSource = credentialSource
    }
}
