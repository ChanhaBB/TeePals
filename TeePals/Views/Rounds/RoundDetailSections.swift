import SwiftUI

// MARK: - Header Section

struct RoundDetailHeader: View {
    let round: Round
    
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        return f
    }()
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    
    var body: some View {
        AppCard(style: .elevated) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                headerTopRow
                courseInfo
                Divider()
                dateTimeInfo
            }
        }
    }
    
    private var headerTopRow: some View {
        HStack {
            statusBadge
            
            // Friends Only visibility badge
            if round.visibility == .friends {
                friendsOnlyBadge
            }
            
            Spacer()
            
            if let tier = round.priceTier {
                Text(tier.displayText)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 4)
                    .background(AppColors.backgroundSecondary)
                    .cornerRadius(AppRadii.chip)
            }
        }
    }
    
    private var friendsOnlyBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 10))
            Text("Friends Only")
                .font(AppTypography.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(AppColors.primary)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, 4)
        .background(AppColors.primary.opacity(0.15))
        .cornerRadius(AppRadii.chip)
    }
    
    private var courseInfo: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "flag.fill")
                .foregroundColor(AppColors.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(round.displayCourseName)
                    .font(AppTypography.headlineMedium)
                    .foregroundColor(AppColors.textPrimary)
                Text(round.displayCityLabel)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
    
    @ViewBuilder
    private var dateTimeInfo: some View {
        if let teeTime = round.displayTeeTime {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "calendar")
                    .foregroundColor(AppColors.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(dateFormatter.string(from: teeTime))
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                    Text("at \(timeFormatter.string(from: teeTime))")
                        .font(AppTypography.headlineSmall)
                        .foregroundColor(AppColors.primary)
                }
            }
        }
    }
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(round.status.displayText.uppercased())
                .font(AppTypography.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(statusColor)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.15))
        .cornerRadius(AppRadii.chip)
    }
    
    private var statusColor: Color {
        switch round.status {
        case .open: return AppColors.success
        case .closed: return AppColors.primary
        case .canceled: return AppColors.error
        case .completed: return AppColors.textSecondary
        }
    }
}
