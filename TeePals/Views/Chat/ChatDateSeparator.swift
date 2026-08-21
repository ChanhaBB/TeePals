import SwiftUI

/// V3 Date separator shown between messages on different days.
struct ChatDateSeparator: View {
    let date: Date

    var body: some View {
        HStack {
            Spacer()
            Text(displayText)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color.gray.opacity(0.6))
                .textCase(.uppercase)
                .tracking(1)
                .padding(.horizontal, 8)
                .background(AppColorsV3.surfaceWhite)
            Spacer()
        }
        .padding(.vertical, AppSpacingV3.md)
    }

    private var displayText: String {
        if Calendar.current.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Today, \(formatter.string(from: date))"
        } else if Calendar.current.isDateInYesterday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Yesterday, \(formatter.string(from: date))"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, h:mm a"
            return formatter.string(from: date)
        }
    }
}

