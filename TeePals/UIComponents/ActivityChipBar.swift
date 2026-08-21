import SwiftUI

/// Horizontal pill-shaped chip bar for Activity tab navigation.
/// Pills expand equally to fill available width.
/// Selected = forest green fill + white bold text.
/// Unselected = white + border + faded medium text.
/// Invites and Pending chips show badge counts when they have items.
struct ActivityChipBar: View {

    @Binding var selectedTab: ActivityTab
    let inviteCount: Int
    let pendingCount: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ActivityTab.allCases) { tab in
                chipButton(for: tab)
            }
        }
    }

    private func badgeCount(for tab: ActivityTab) -> Int {
        switch tab {
        case .invites: return inviteCount
        case .pending: return pendingCount
        default: return 0
        }
    }

    private func chipButton(for tab: ActivityTab) -> some View {
        let isSelected = selectedTab == tab
        let count = badgeCount(for: tab)

        return Button { selectedTab = tab } label: {
            HStack(spacing: 5) {
                Text(chipText(for: tab, isSelected: isSelected, count: count))
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                    .lineLimit(1)

                if count > 0 && !isSelected {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(AppColorsV3.forestGreen.opacity(0.7))
                        .cornerRadius(AppSpacingV3.radiusFull)
                }
            }
            .foregroundColor(isSelected ? .white : AppColorsV3.textSecondary.opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? AppColorsV3.forestGreen : .white)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacingV3.radiusFull)
                    .stroke(isSelected ? Color.clear : AppColorsV3.borderLight, lineWidth: 1)
            )
            .cornerRadius(AppSpacingV3.radiusFull)
        }
        .buttonStyle(.plain)
    }

    private func chipText(for tab: ActivityTab, isSelected: Bool, count: Int) -> String {
        if count > 0 && isSelected {
            return "\(tab.title) (\(count))"
        }
        return tab.title
    }
}
