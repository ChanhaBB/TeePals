import SwiftUI

// MARK: - Requests Section (Host Only)

struct RoundDetailRequestsSection: View {
    let requests: [RoundMember]
    let profiles: [String: PublicProfile]
    let onAccept: (String) -> Void
    let onDecline: (String) -> Void
    let onProfileTap: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            header
            
            AppCard(style: .outlined) {
                VStack(spacing: AppSpacing.md) {
                    ForEach(requests, id: \.uid) { request in
                        RequestRowView(
                            request: request,
                            profile: profiles[request.uid],
                            onAccept: { onAccept(request.uid) },
                            onDecline: { onDecline(request.uid) },
                            onProfileTap: { onProfileTap(request.uid) }
                        )
                        if request.uid != requests.last?.uid {
                            Divider()
                        }
                    }
                }
            }
        }
    }
    
    private var header: some View {
        HStack {
            Text("REQUESTS")
                .font(AppTypography.labelMedium)
                .foregroundColor(AppColors.textSecondary)
            
            Text("\(requests.count)")
                .font(AppTypography.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(AppColors.primary)
                .cornerRadius(10)
        }
    }
}

// MARK: - Request Row

struct RequestRowView: View {
    let request: RoundMember
    let profile: PublicProfile?
    let onAccept: () -> Void
    let onDecline: () -> Void
    let onProfileTap: () -> Void
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            profileButton
            Spacer()
            actionButtons
        }
    }
    
    private var profileButton: some View {
        Button(action: onProfileTap) {
            HStack(spacing: AppSpacing.md) {
                ProfileAvatarView(url: profile?.photoUrls.first, size: 44)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile?.nickname ?? "Golfer")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                    
                    if let skill = profile?.skillLevel {
                        Text(skill.displayText)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private var actionButtons: some View {
        HStack(spacing: AppSpacing.xs) {
            Button(action: onDecline) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColors.error)
                    .frame(width: 36, height: 36)
                    .background(AppColors.error.opacity(0.15))
                    .clipShape(Circle())
            }
            
            Button(action: onAccept) {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColors.success)
                    .frame(width: 36, height: 36)
                    .background(AppColors.success.opacity(0.15))
                    .clipShape(Circle())
            }
        }
    }
}

// MARK: - Host Message Section

struct RoundDetailDescriptionSection: View {
    let description: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("MESSAGE FROM HOST")
                .font(AppTypography.labelMedium)
                .foregroundColor(AppColors.textSecondary)
            
            AppCard(style: .elevated) {
                if let desc = description, !desc.isEmpty {
                    Text(desc)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("No message from host yet")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textTertiary)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

// MARK: - Preferred TeePals Section

struct RoundDetailInfoSection: View {
    let round: Round
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("PREFERRED TEEPALS")
                .font(AppTypography.labelMedium)
                .foregroundColor(AppColors.textSecondary)
            
            AppCard(style: .elevated) {
                VStack(spacing: AppSpacing.md) {
                    InfoRow(icon: "person.2", label: "Age Range", value: ageRangeDisplay)
                    InfoRow(icon: "chart.bar.fill", label: "Skill Level", value: skillLevelsDisplay)
                    InfoRow(icon: "dollarsign.circle", label: "Price", value: priceDisplay)
                }
            }
        }
    }
    
    private var ageRangeDisplay: String {
        if let min = round.requirements?.ageMin, let max = round.requirements?.ageMax {
            return "\(min) - \(max) years"
        } else if let min = round.requirements?.ageMin {
            return "\(min)+ years"
        } else if let max = round.requirements?.ageMax {
            return "Under \(max) years"
        }
        return "All ages welcome"
    }
    
    private var skillLevelsDisplay: String {
        if let skills = round.requirements?.skillLevelsAllowed, !skills.isEmpty {
            // If all skill levels are selected, show "All skill levels"
            if Set(skills) == Set(SkillLevel.allCases) {
                return "All skill levels"
            }
            return skills.map { $0.displayText }.joined(separator: ", ")
        }
        return "All skill levels"
    }
    
    private var priceDisplay: String {
        // If exact amount is set, show it
        if let amount = round.price?.amount, amount > 0 {
            if let note = round.price?.note, !note.isEmpty {
                return "$\(amount) (\(note))"
            }
            return "$\(amount)"
        }
        
        return "Price TBD"
    }
}

// MARK: - Info Row Helper

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .foregroundColor(AppColors.primary)
                .frame(width: 24)
            
            Text(label)
                .font(AppTypography.labelMedium)
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimary)
        }
    }
}

