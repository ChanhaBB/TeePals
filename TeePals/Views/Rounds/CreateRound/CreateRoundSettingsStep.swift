import SwiftUI

/// Step 3: Round settings — visibility, group size, green fee.
struct CreateRoundSettingsStep: View {
    @ObservedObject var viewModel: CreateRoundViewModel
    @FocusState private var isFeeFieldFocused: Bool
    @FocusState private var isMessageFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacingV3.lg) {
            stepTitle
            hostMessageSection
            visibilitySection
            groupSizeSection
            greenFeeSection
            Spacer(minLength: AppSpacingV3.md)
        }
        .padding(.top, AppSpacingV3.md)
    }
    
    // MARK: - Step Title
    
    private var stepTitle: some View {
        Text("Round Settings")
            .font(Font.custom("PlayfairDisplay-Regular", size: 30, relativeTo: .largeTitle).weight(.bold))
            .foregroundColor(AppColorsV3.textPrimary)
            .tracking(-0.3)
    }
    
    // MARK: - Visibility
    
    private var visibilitySection: some View {
        detailCard {
            VStack(alignment: .leading, spacing: AppSpacingV3.sm) {
                SectionLabelV3(title: "Visibility", size: 11)
                
                HStack(spacing: 8) {
                    ForEach(RoundVisibility.allCases, id: \.self) { vis in
                        visibilityChip(vis)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 6) {
                    Image(systemName: visibilityIcon)
                        .font(.system(size: 13))
                    Text(visibilityDescription)
                        .font(AppTypographyV3.bodyRegular)
                }
                .foregroundColor(AppColorsV3.textSecondary)
            }
        }
    }
    
    private func visibilityChip(_ vis: RoundVisibility) -> some View {
        let isSelected = viewModel.visibility == vis
        return Button { viewModel.visibility = vis } label: {
            HStack(spacing: 5) {
                Image(systemName: vis.systemImage)
                    .font(.system(size: 13))
                Text(vis.displayText)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? AppColorsV3.forestGreen : Color.clear)
            .foregroundColor(isSelected ? .white : AppColorsV3.textPrimary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : AppColorsV3.borderLight, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var visibilityIcon: String {
        switch viewModel.visibility {
        case .public:
            return "hand.raised.fill"
        case .friends:
            return "bolt.fill"
        case .private:
            return "lock.fill"
        }
    }

    private var visibilityDescription: String {
        switch viewModel.visibility {
        case .public:
            return "Round visible to everyone"
        case .friends:
            return "Round visible to friends"
        case .private:
            return "Invite-only"
        }
    }
    
    // MARK: - Group Size
    
    private var groupSizeSection: some View {
        detailCard {
            VStack(alignment: .leading, spacing: AppSpacingV3.sm) {
                SectionLabelV3(title: "Group Size", size: 11)
                
                HStack {
                    Text("\(viewModel.groupSize) players")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColorsV3.textPrimary)
                    
                    Spacer()
                    
                    HStack(spacing: 0) {
                        stepperButton(systemName: "minus") {
                            if viewModel.groupSize > CreateRoundViewModel.groupSizeRange.lowerBound {
                                viewModel.groupSize -= 1
                            }
                        }
                        .disabled(viewModel.groupSize <= CreateRoundViewModel.groupSizeRange.lowerBound)
                        
                        Text("\(viewModel.groupSize)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppColorsV3.textPrimary)
                            .frame(width: 40, alignment: .center)
                        
                        stepperButton(systemName: "plus") {
                            if viewModel.groupSize < CreateRoundViewModel.groupSizeRange.upperBound {
                                viewModel.groupSize += 1
                            }
                        }
                        .disabled(viewModel.groupSize >= CreateRoundViewModel.groupSizeRange.upperBound)
                    }
                }
            }
        }
    }
    
    private func stepperButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppColorsV3.forestGreen)
                .frame(width: 36, height: 36)
                .background(AppColorsV3.forestGreen.opacity(0.08))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Green Fee
    
    private var greenFeeSection: some View {
        detailCard {
            VStack(alignment: .leading, spacing: AppSpacingV3.sm) {
                HStack {
                    SectionLabelV3(title: "Green Fee", size: 11)
                    Spacer()
                    Text("per player · optional")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColorsV3.textSecondary.opacity(0.6))
                }
                
                HStack(spacing: 8) {
                    Text("$")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppColorsV3.textSecondary)
                    
                    TextField("0", text: $viewModel.greenFee)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppColorsV3.textPrimary)
                        .keyboardType(.numberPad)
                        .focused($isFeeFieldFocused)
                    
                    if isFeeFieldFocused {
                        Button {
                            isFeeFieldFocused = false
                        } label: {
                            Image(systemName: "keyboard.chevron.compact.down")
                                .font(.system(size: 18))
                                .foregroundColor(AppColorsV3.textSecondary)
                        }
                    }
                }
                .padding(.bottom, AppSpacingV3.xs)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(isFeeFieldFocused ? AppColorsV3.forestGreen : AppColorsV3.borderLight)
                        .frame(height: 1)
                }
                .animation(.easeInOut(duration: 0.15), value: isFeeFieldFocused)
            }
        }
    }
    
    // MARK: - Host Message
    
    private var hostMessageSection: some View {
        detailCard {
            VStack(alignment: .leading, spacing: AppSpacingV3.sm) {
                SectionLabelV3(title: "Message from Host", size: 11)
                
                TextField("Join me for a round!", text: $viewModel.hostMessage, axis: .vertical)
                    .lineLimit(3...6)
                    .font(AppTypographyV3.bodyRegular)
                    .foregroundColor(AppColorsV3.textPrimary)
                    .padding(AppSpacingV3.sm)
                    .background(AppColorsV3.forestGreen.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacingV3.xs))
                    .focused($isMessageFocused)
                
                if isMessageFocused {
                    HStack {
                        Spacer()
                        Button {
                            isMessageFocused = false
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "keyboard.chevron.compact.down")
                                    .font(.system(size: 14))
                                Text("Done")
                                    .font(AppTypographyV3.bodyMedium)
                            }
                            .foregroundColor(AppColorsV3.textSecondary)
                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.15), value: isMessageFocused)
        }
    }
    
    // MARK: - Shared
    
    private func detailCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacingV3.sm) {
            content()
        }
        .padding(AppSpacingV3.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColorsV3.surfaceWhite)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacingV3.radiusSmall))
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
    
}
