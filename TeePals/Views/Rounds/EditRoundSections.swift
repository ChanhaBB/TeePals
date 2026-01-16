import SwiftUI

// MARK: - Price Section

struct EditRoundPriceSection: View {
    @Binding var priceAmount: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("ESTIMATED PRICE")
                .font(AppTypography.labelMedium)
                .foregroundColor(AppColors.textSecondary)
            
            AppCard(style: .elevated) {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    HStack {
                        Text("$")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textSecondary)
                        TextField("Enter amount (leave empty for TBD)", text: $priceAmount)
                            .font(AppTypography.bodyMedium)
                            .keyboardType(.numberPad)
                            .focused($isFocused)
                        
                        if isFocused {
                            Button {
                                isFocused = false
                            } label: {
                                Image(systemName: "keyboard.chevron.compact.down")
                                    .font(.system(size: 18))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                    .padding(AppSpacing.sm)
                    .background(AppColors.backgroundSecondary)
                    .cornerRadius(AppSpacing.radiusSmall)
                    .animation(.easeInOut(duration: 0.15), value: isFocused)
                    
                    Text(priceAmount.isEmpty ? "Price TBD" : "$\(priceAmount)")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }
}

// MARK: - Preferred TeePals Section

struct EditRoundPreferredTeePalsSection: View {
    @Binding var minAge: Double
    @Binding var maxAge: Double
    @Binding var selectedSkillLevels: Set<SkillLevel>
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("PREFERRED TEEPALS")
                .font(AppTypography.labelMedium)
                .foregroundColor(AppColors.textSecondary)
            
            AppCard(style: .elevated) {
                VStack(spacing: AppSpacing.lg) {
                    ageRangeSlider
                    Divider()
                    skillLevelSelector
                }
            }
        }
    }
    
    private var ageRangeSlider: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("Age Range")
                    .font(AppTypography.labelMedium)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text("\(Int(minAge)) - \(Int(maxAge)) years")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.primary)
            }
            
            RangeSliderView(minValue: $minAge, maxValue: $maxAge, bounds: 18...80)
        }
    }
    
    private var skillLevelSelector: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Skill Levels")
                .font(AppTypography.labelMedium)
                .foregroundColor(AppColors.textSecondary)
            
            MultiSelectChipGroup(
                options: SkillLevel.allCases,
                selection: selectedSkillLevels,
                labelProvider: { $0.displayText },
                onToggle: { skill in
                    if selectedSkillLevels.contains(skill) {
                        selectedSkillLevels.remove(skill)
                    } else {
                        selectedSkillLevels.insert(skill)
                    }
                },
                allSelectedText: "All skill levels welcome",
                noneSelectedText: "All skill levels welcome"
            )
        }
    }
}

// MARK: - Message Section

struct EditRoundMessageSection: View {
    @Binding var message: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Message from Host")
                .font(AppTypography.labelMedium)
                .foregroundColor(AppColors.textSecondary)
            
            AppCard(style: .elevated) {
                VStack(alignment: .trailing, spacing: AppSpacing.sm) {
                    TextField("Add a message for potential players...", text: $message, axis: .vertical)
                        .lineLimit(3...6)
                        .font(AppTypography.bodyMedium)
                        .focused($isFocused)
                    
                    if isFocused {
                        Button {
                            isFocused = false
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "keyboard.chevron.compact.down")
                                    .font(.system(size: 16))
                                Text("Done")
                                    .font(AppTypography.caption)
                            }
                            .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: isFocused)
            }
        }
    }
}
