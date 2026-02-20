import SwiftUI

/// Horizontal pill-shaped chip bar for Activity tab navigation.
/// Selected = forest green fill + white text.
/// Unselected = white + border + secondary text.
/// Invites chip shows a badge count when not selected (neutral pill).
struct ActivityChipBar: View {

    @Binding var selectedTab: ActivityTab
    let inviteCount: Int

    var body: some View {
        HStack(spacing: AppSpacingV3.xs) {
            ForEach(ActivityTab.allCases) { tab in
                chipButton(for: tab)
            }
        }
    }

    private func chipButton(for tab: ActivityTab) -> some View {
        let isSelected = selectedTab == tab

        return Button { selectedTab = tab } label: {
            HStack(spacing: 6) {
                Text(chipText(for: tab, isSelected: isSelected))
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .textCase(.uppercase)

                if tab == .invites && inviteCount > 0 && !isSelected {
                    Text("\(inviteCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.gray.opacity(0.6))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.12))
                        .cornerRadius(AppSpacingV3.radiusFull)
                }
            }
            .foregroundColor(isSelected ? .white : AppColorsV3.textSecondary)
            .padding(.horizontal, 20)
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

    private func chipText(for tab: ActivityTab, isSelected: Bool) -> String {
        if tab == .invites && inviteCount > 0 && isSelected {
            return "\(tab.title) (\(inviteCount))"
        }
        return tab.title
    }
}
