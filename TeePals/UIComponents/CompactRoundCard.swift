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
    let showNotificationDot: Bool
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
        showNotificationDot: Bool = false,
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
        self.showNotificationDot = showNotificationDot
        self.isUserRound = isUserRound
        self.showSlots = showSlots
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacingV3.md) {
                dateBadge

                VStack(alignment: .leading, spacing: 2) {
                    Text(courseName)
                        .font(AppTypographyV3.roundCardTitle)
                        .foregroundColor(AppColorsV3.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: AppSpacingV3.xs) {
                        TPAvatar(url: hostPhotoURL, size: 16)

                        Text(hostInfoText)
                            .font(AppTypographyV3.bodySmall)
                            .foregroundColor(AppColorsV3.textSecondary)
                    }
                }

                Spacer()

                if showSlots, let totalSlots, let filledSlots {
                    slotsIndicator(total: totalSlots, filled: filledSlots)
                } else if let badge = statusBadge {
                    statusBadgeView(text: badge)
                }
            }
            .padding(AppSpacingV3.md)
            .background(AppColorsV3.surfaceWhite)
            .cornerRadius(AppSpacingV3.radiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacingV3.radiusMedium)
                    .stroke(AppColorsV3.borderLight, lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                if showNotificationDot {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .offset(x: -8, y: 8)
                }
            }
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
            CompactRoundCard(
                dateMonth: "Feb",
                dateDay: "16",
                courseName: "Torrey Pines South",
                hostName: "Alex P.",
                distance: "18.6mi",
                statusBadge: "Hosting",
                showNotificationDot: true,
                isUserRound: true,
                action: {}
            )

            CompactRoundCard(
                dateMonth: "Feb",
                dateDay: "15",
                courseName: "Riverwalk GC",
                hostName: "Sarah M.",
                distance: "5.2mi",
                totalSlots: 4,
                filledSlots: 3,
                isUserRound: false,
                action: {}
            )

            CompactRoundCard(
                dateMonth: "Feb",
                dateDay: "23",
                courseName: "Mission Bay GC",
                hostName: "Mike D.",
                distance: "1.8mi",
                statusBadge: "Awaiting Host",
                isUserRound: false,
                action: {}
            )
        }
        .padding()
        .background(AppColorsV3.bgNeutral)
    }
}
#endif
