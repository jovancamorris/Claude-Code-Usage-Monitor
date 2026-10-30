import SwiftUI

public struct ProgressBarView: View {
    public var value: Double // 0.0 ... 1.0
    public var height: CGFloat = 8.0
    
    public init(value: Double, height: CGFloat = 8.0) {
        self.value = max(0.0, min(1.0, value))
        self.height = height
    }
    
    private var progressColor: Color {
        if value >= 0.90 {
            return .red
        } else if value >= 0.70 {
            return .orange
        } else {
            return .green
        }
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background Track
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: height)
                
                // Active Fill
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(
                        LinearGradient(
                            colors: [progressColor, progressColor.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(height, geometry.size.width * CGFloat(value)), height: height)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: value)
            }
        }
        .frame(height: height)
    }
}
