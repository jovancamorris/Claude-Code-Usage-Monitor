import SwiftUI

public struct AntigravityGroupCardView: View {
    public var group: AntigravityGroupQuota
    public var direction: DisplayDirection
    
    public init(group: AntigravityGroupQuota, direction: DisplayDirection) {
        self.group = group
        self.direction = direction
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Group Header
            HStack(spacing: 6) {
                Image(systemName: group.iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(headerColor)
                
                Text(group.displayName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // 5-Hour Window (if available)
            if let fiveHour = group.fiveHour {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("5-Hour Session")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 9))
                            Text(fiveHour.timeRemainingString)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .firstTextBaseline) {
                        Text(fiveHour.formattedPercentage(direction: direction))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Text(direction == .used ? "used" : "remaining")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    ProgressBarView(value: fiveHour.utilization, height: 6)
                }
            }
            
            // Weekly Window (if available)
            if let weekly = group.weekly {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Weekly Allowance")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        HStack(spacing: 3) {
                            Image(systemName: "calendar")
                                .font(.system(size: 9))
                            Text(weekly.timeRemainingString)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .firstTextBaseline) {
                        Text(weekly.formattedPercentage(direction: direction))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Text(direction == .used ? "used" : "remaining")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    ProgressBarView(value: weekly.utilization, height: 6)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }
    
    private var headerColor: Color {
        let lower = group.displayName.lowercased()
        if lower.contains("claude") || lower.contains("gpt") {
            return .orange
        } else if lower.contains("argon") {
            return .purple
        } else {
            return .blue
        }
    }
}
