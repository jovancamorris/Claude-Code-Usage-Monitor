import SwiftUI

public struct LimitCardView: View {
    public var title: String
    public var icon: String
    public var bucket: UsageBucket?
    public var direction: DisplayDirection
    
    public init(title: String, icon: String, bucket: UsageBucket?, direction: DisplayDirection) {
        self.title = title
        self.icon = icon
        self.bucket = bucket
        self.direction = direction
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Row
            HStack {
                Label(title, systemImage: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let bucket = bucket {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(bucket.timeRemainingString)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(6)
                }
            }
            
            if let bucket = bucket {
                // Percentage Row
                HStack(alignment: .lastTextBaseline) {
                    Text(bucket.formattedPercentage(direction: direction))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(direction == .used ? "used" : "remaining")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let rawDate = bucket.resetsAt {
                        Text("Resets \(formattedResetTime(rawDate))")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Progress Bar
                ProgressBarView(value: bucket.utilization, height: 7)
            } else {
                Text("Limit data unavailable")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
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
    
    private func formattedResetTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "at HH:mm"
        } else {
            formatter.dateFormat = "EEE HH:mm"
        }
        return formatter.string(from: date)
    }
}
