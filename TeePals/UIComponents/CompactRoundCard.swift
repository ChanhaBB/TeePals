import SwiftUI

/// Compact Round Card - Horizontal layout without course photo
/// Shows date badge, course name, host info, and participant slots
struct CompactRoundCard: View {

    // MARK: - Data

    let dateMonth: String // "Feb"
    let dateDay: String // "16"
    let courseName: String
    let hostName: String
    let hostPhotoURL: URL?
    let distance: String // "18.6mi"
    let totalSlots: Int?
    let filledSlots: Int?
    let statusBadge: String?
    let isUserRound: Bool
    let showSlots: Bool
    let action: () -> Void

    init(
        dateMonth: String,
        dateDay: String,
        courseName: String,
        hostName: String,
        hostPhotoURL: URL? = nil,
        distance: String,
        totalSlots: Int? = nil,
        filledSlots: Int? = nil,
        statusBadge: String? = nil,
        isUserRound: Bool = false,
        showSlots: Bool = true,
        action: @escaping () -> Void
    ) {
        self.dateMonth = dateMonth
        self.dateDay = dateDay
        self.courseName = courseName
        self.hostName = hostName
        self.hostPhotoURL = hostPhotoURL
        self.distance = distance
        self.totalSlots = totalSlots
        self.filledSlots = filledSlots
        self.statusBadge = statusBadge
        self.isUserRound = isUserRound
        self.showSlots = showSlots
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacingV3.md) {
                // Date badge
                dateBadge

                // Main content
                VStack(alignment: .leading, spacing: 2) {
                    // Course name + status badge
                    HStack(spacing: AppSpacingV3.xs) {
                        Text(courseName)
                            .font(AppTypographyV3.roundCardTitle)
                            .foregroundColor(AppColorsV3.textPrimary)
                            .lineLimit(1)

                        if let badge = statusBadge {
                            statusBadgeView(text: badge)
                        }
                    }

                    // Host info
                    HStack(spacing: AppSpacingV3.xs) {
                        // Host avatar (always show, with placeholder if no URL)
                        if let photoURL = hostPhotoURL {
                            AsyncImage(url: photoURL) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Circle().fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 16, height: 16)
                            .clipped()
                            .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 16, height: 16)
                        }

                        Text(hostInfoText)
                            .font(AppTypographyV3.bodySmall)
                            .foregroundColor(AppColorsV3.textSecondary)
                    }
                }

                Spacer()

                if showSlots, let totalSlots, let filledSlots {
                    slotsIndicator(total: totalSlots, filled: filledSlots)
                }
            }
            .padding(AppSpacingV3.md)
            .background(AppColorsV3.surfaceWhite)
            .cornerRadius(AppSpacingV3.radiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacingV3.radiusMedium)
                    .stroke(AppColorsV3.borderLight, lineWidth: 1)
            )
            .premiumShadow()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Computed

    private var hostInfoText: String {
        let trimmed = distance.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed == "—" {
            return hostName
        }
        return "\(hostName) • \(trimmed)"
    }

    // MARK: - Subviews

    private var dateBadge: some View {
        VStack(spacing: 0) {
            Text(dateMonth)
                .font(AppTypographyV3.labelTiny)
                .textCase(.uppercase)
                .tracking(-0.5)
                .foregroundColor(isUserRound ? .white.opacity(0.8) : AppColorsV3.textSecondary)

            Text(dateDay)
                .font(AppTypographyV3.numberMediumSerif)
                .foregroundColor(isUserRound ? .white : AppColorsV3.forestGreen)
        }
        .frame(width: 48, height: 48)
        .background(
            RoundedRectangle(cornerRadius: AppSpacingV3.radiusSmall)
                .fill(isUserRound ? AppColorsV3.forestGreen : Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacingV3.radiusSmall)
                        .stroke(isUserRound ? AppColorsV3.forestGreen : AppColorsV3.borderLight, lineWidth: 1)
                )
        )
    }

    private func statusBadgeView(text: String) -> some View {
        Text(text)
            .font(AppTypographyV3.buttonBadge)
            .textCase(.uppercase)
            .tracking(-0.3)
            .foregroundColor(AppColorsV3.forestGreen)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppColorsV3.forestGreen.opacity(0.1))
            )
    }

    private func slotsIndicator(total: Int, filled: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<total, id: \.self) { index in
                Image(systemName: "person.fill")
                    .font(.system(size: 16))
                    .foregroundColor(
                        index < filled
                        ? AppColorsV3.forestGreen
                        : Color.gray.opacity(0.2)
                    )
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct CompactRoundCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            // User's round (filled date badge)
            CompactRoundCard(
                dateMonth: "Feb",
                dateDay: "16",
                courseName: "Torrey Pines South",
                hostName: "Alex P.",
                distance: "18.6mi",
                totalSlots: 4,
                filledSlots: 4,
                statusBadge: "You're In",
                isUserRound: true,
                action: {}
            )

            // Discover round (outline date badge)
            CompactRoundCard(
                dateMonth: "Feb",
                dateDay: "15",
                courseName: "Riverwalk Golf Club",
                hostName: "Sarah M.",
                distance: "5.2mi",
                totalSlots: 4,
                filledSlots: 3,
                isUserRound: false,
                action: {}
            )

            // Partially filled
            CompactRoundCard(
                dateMonth: "Feb",
                dateDay: "23",
                courseName: "Mission Bay Course",
                hostName: "Mike D.",
                distance: "1.8mi",
                totalSlots: 4,
                filledSlots: 2,
                isUserRound: false,
                action: {}
            )
        }
        .padding()
        .background(AppColorsV3.bgNeutral)
    }
}
#endif
