import SwiftUI

/// Unified card component for displaying rounds across all tabs.
/// Adapts layout based on context (Nearby, Activity, Following).
enum RoundCardContext {
    case nearby     // Discovery: course-first, host visible but secondary
    case following  // Social: host-led emphasis
    case activity   // User context: badge provides prominence
}

struct RoundCardView: View {
    let round: Round
    var hostProfile: PublicProfile?
    var badge: RoundCardBadge? = nil
    var context: RoundCardContext = .nearby
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // Header: Title + Badges
                HStack(alignment: .top) {
                    Text(round.displayTitle)
                        .font(AppTypography.headlineSmall)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    HStack(spacing: 4) {
                        // Visibility badge for friends-only rounds
                        if round.visibility == .friends, badge == .hosting {
                            visibilityBadge
                        }
                        // Context badge (Hosting, Pending, etc.)
                        if let badge = badge {
                            badgeView(for: badge)
                        } else {
                            spotsBadge
                        }
                    }
                }

                // Date/Time (priority detail)
                if let dateText = round.displayDateTime {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(AppColors.iconAccent)
                        Text(dateText)
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textPrimary)
                    }
                }

                // Location
                if let location = round.displayLocationString {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin")
                            .font(.caption)
                            .foregroundColor(AppColors.iconAccent)
                        Text(location)
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textPrimary)
                    }
                }

                // Host info (bottom row with chevron)
                HStack {
                    hostRow

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(AppSpacing.md)
            .background(AppColors.backgroundPrimary)
            .cornerRadius(AppSpacing.radiusMedium)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Badges

    private var visibilityBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 8))
            Text("Friends")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(AppColors.primary)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(AppColors.primary.opacity(0.15))
        .cornerRadius(AppSpacing.radiusSmall)
    }

    @ViewBuilder
    private func badgeView(for badge: RoundCardBadge) -> some View {
        switch badge {
        case .hosting:
            Text("HOSTING")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColors.primary)
                .cornerRadius(AppSpacing.radiusSmall)

        case .requested:
            Text("REQUESTED")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.warning)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColors.warning.opacity(0.15))
                .cornerRadius(AppSpacing.radiusSmall)

        case .confirmed:
            Text("CONFIRMED")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.success)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColors.success.opacity(0.15))
                .cornerRadius(AppSpacing.radiusSmall)

        case .played:
            Text("PLAYED")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColors.backgroundSecondary)
                .cornerRadius(AppSpacing.radiusSmall)

        case .declined:
            Text("DECLINED")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.error)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColors.error.opacity(0.15))
                .cornerRadius(AppSpacing.radiusSmall)

        case .invited:
            Text("INVITED")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.info)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColors.info.opacity(0.15))
                .cornerRadius(AppSpacing.radiusSmall)
        }
    }

    private var spotsBadge: some View {
        let remaining = round.spotsRemaining
        let color: Color = remaining > 0 ? AppColors.primary : AppColors.textSecondary

        return Text("\(remaining) open")
            .font(.caption2)
            .fontWeight(.regular)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(AppSpacing.radiusSmall)
    }

    // MARK: - Host Row

    private var hostRow: some View {
        HStack(spacing: 8) {
            // Host profile photo
            Group {
                if let host = hostProfile, let photoUrlString = host.photoUrls.first, let photoUrl = URL(string: photoUrlString) {
                    CachedAsyncImage(url: photoUrl) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(AppColors.textTertiary)
                    }
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .frame(width: 24, height: 24)
            .clipShape(Circle())

            if let host = hostProfile {
                Text("hosted by \(host.nickname)")
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textSecondary)
            } else {
                // Reserve space to prevent layout shift
                Text("Loading host...")
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textTertiary)
                    .redacted(reason: .placeholder)
            }
        }
    }
}

// MARK: - Round Card Badge

enum RoundCardBadge: Equatable {
    case hosting
    case requested    // User requested to join (was "pending")
    case confirmed    // Approved to join - future rounds (was "approved")
    case played       // Approved - past rounds
    case invited      // User needs to accept/decline
    case declined     // Not shown in Activity (kept for compatibility)
}
