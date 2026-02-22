import SwiftUI

/// Horizontal pill-shaped chip bar for Activity tab navigation.
/// Selected = forest green fill + white text.
/// Unselected = white + border + secondary text.
/// Invites and Pending chips show badge counts when they have items.
struct ActivityChipBar: View {

    @Binding var selectedTab: ActivityTab
    let inviteCount: Int
    let pendingCount: Int

    var body: some View {
        HStack(spacing: AppSpacingV3.xs) {
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
            HStack(spacing: 6) {
                Text(chipText(for: tab, isSelected: isSelected, count: count))
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .textCase(.uppercase)

                if count > 0 && !isSelected {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.gray.opacity(0.6))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.12))
                        .cornerRadius(AppSpacingV3.radiusFull)
                }
            }
            .foregroundColor(isSelected ? .white : AppColorsV3.textSecondary)
            .padding(.horizontal, 16)
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
