import SwiftUI

/// Date separator shown between messages on different days.
struct ChatDateSeparator: View {
    let date: Date
    
    var body: some View {
        HStack {
            line
            Text(displayText)
                .font(AppTypography.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)
            line
        }
        .padding(.vertical, AppSpacing.sm)
    }
    
    private var line: some View {
        Rectangle()
            .fill(AppColors.textTertiary.opacity(0.3))
            .frame(height: 1)
    }
    
    private var displayText: String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
    }
}

