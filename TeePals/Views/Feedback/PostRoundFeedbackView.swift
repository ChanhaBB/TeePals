import SwiftUI

/// Main view for post-round feedback flow.
/// Modern sliding card-based UI with smooth transitions.
struct PostRoundFeedbackView: View {
    @StateObject private var viewModel: PostRoundFeedbackViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: PostRoundFeedbackViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Background
            Color.white.ignoresSafeArea()

            // Main content
            Group {
                switch viewModel.currentStep {
                case .primaryQuestion:
                    PrimaryQuestionScreen(viewModel: viewModel)
                case .endorsement:
                    EndorsementScreen(viewModel: viewModel)
                case .selectIssueUsers:
                    SelectIssueUsersScreen(viewModel: viewModel)
                case .issueDetails:
                    IssueDetailsScreen(viewModel: viewModel)
                case .success:
                    FeedbackSuccessScreen(onDone: { dismiss() })
                case .alreadySubmitted:
                    AlreadySubmittedScreen(onDone: { dismiss() })
                }
            }

            // Close button - always visible
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(AppTypographyV3.headlineLarge)
                    .foregroundColor(AppColorsV3.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(AppColorsV3.surfaceWhite.opacity(0.9))
                    .clipShape(Circle())
            }
            .padding(AppSpacingV3.md)
        }
        .task {
            await viewModel.loadRound()
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
}

// MARK: - Primary Question Screen

private struct PrimaryQuestionScreen: View {
    @ObservedObject var viewModel: PostRoundFeedbackViewModel

    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView()
            } else {
                VStack(spacing: 0) {
                    Spacer()

                    // Question section
                    VStack(spacing: 0) {
                        // Course info - subtle context
                        Text(viewModel.courseName)
                            .font(AppTypographyV3.bodyMedium)
                            .foregroundColor(AppColorsV3.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 24)

                        // Main question - hero element
                        Text("How was the group experience?")
                            .font(AppTypographyV3.displayLargeSerifRegular)
                            .foregroundColor(AppColorsV3.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, AppSpacingV3.md)
                            .padding(.bottom, 28)

                        // Answer buttons
                        VStack(spacing: 12) {
                            // Yes button
                            Button {
                                viewModel.answerYes()
                            } label: {
                                HStack(spacing: AppSpacingV3.xs) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22))
                                    Text("Everything went well")
                                        .font(AppTypographyV3.headlineMediumSerif)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .foregroundColor(.white)
                                .background(AppColorsV3.success)
                                .cornerRadius(16)
                            }

                            // No button
                            Button {
                                viewModel.answerNo()
                            } label: {
                                HStack(spacing: AppSpacingV3.xs) {
                                    Image(systemName: "exclamationmark.circle")
                                        .font(.system(size: 22))
                                    Text("Report an issue")
                                        .font(AppTypographyV3.headlineMediumSerif)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .foregroundColor(AppColorsV3.textPrimary)
                                .background(AppColorsV3.surfaceWhite)
                                .cornerRadius(16)
                            }
                        }
                        .padding(.horizontal, AppSpacingV3.md)
                        .padding(.bottom, 20)

                        // Helper text
                        Text("You can skip this — feedback is optional and private")
                            .font(AppTypographyV3.bodyRegular)
                            .foregroundColor(AppColorsV3.textTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacingV3.lg)
                    }

                    Spacer()
                }
            }
        }
    }
}

// MARK: - Endorsement Screen

private struct EndorsementScreen: View {
    @ObservedObject var viewModel: PostRoundFeedbackViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 8) {
                Circle()
                    .fill(AppColorsV3.success)
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(AppColorsV3.forestGreen)
                    .frame(width: 8, height: 8)
            }
            .padding(.top, 60)

            ScrollView {
                VStack(spacing: AppSpacingV3.lg) {
                    // Title
                    VStack(spacing: AppSpacingV3.xxs) {
                        Text("Great!")
                            .font(AppTypographyV3.displayMediumSerif)
                            .foregroundColor(AppColorsV3.success)

                        Text("Would you play with them again?")
                            .font(AppTypographyV3.displayMediumSerif)
                            .foregroundColor(AppColorsV3.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                    .padding(.top, AppSpacingV3.lg)

                    // Player cards
                    VStack(spacing: AppSpacingV3.md) {
                        ForEach(viewModel.participants) { participant in
                            PlayerEndorsementCard(
                                participant: participant,
                                isEndorsed: viewModel.isEndorsed(participant.id ?? ""),
                                onTap: { viewModel.toggleEndorsement(participant.id ?? "") }
                            )
                        }
                    }

                    // Skill accuracy question
                    VStack(spacing: AppSpacingV3.md) {
                        Text("Was everyone's skill level accurate?")
                            .font(AppTypographyV3.headlineMediumSerif)
                            .foregroundColor(AppColorsV3.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: AppSpacingV3.md) {
                            Button {
                                viewModel.skillAccurate = true
                            } label: {
                                HStack {
                                    Image(systemName: viewModel.skillAccurate == true ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                    Text("Yes")
                                        .font(AppTypographyV3.bodyLarge)
                                }
                                .foregroundColor(viewModel.skillAccurate == true ? AppColorsV3.forestGreen : AppColorsV3.textSecondary)
                            }

                            Button {
                                viewModel.skillAccurate = false
                            } label: {
                                HStack {
                                    Image(systemName: viewModel.skillAccurate == false ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                    Text("No")
                                        .font(AppTypographyV3.bodyLarge)
                                }
                                .foregroundColor(viewModel.skillAccurate == false ? AppColorsV3.forestGreen : AppColorsV3.textSecondary)
                            }
                        }
                    }

                    // Bottom padding
                    Spacer()
                        .frame(height: 120)
                }
                .padding(.horizontal, AppSpacingV3.md)
            }

            // Sticky bottom buttons
            VStack(spacing: AppSpacingV3.xs) {
                Button {
                    Task { await viewModel.submitFeedback() }
                } label: {
                    Text("Submit Feedback")
                        .font(AppTypographyV3.headlineMediumSerif)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(AppColorsV3.forestGreen)
                        .cornerRadius(16)
                }

                Button {
                    viewModel.skipEndorsements()
                } label: {
                    Text("Skip for Now")
                        .font(AppTypographyV3.bodyLarge)
                        .foregroundColor(AppColorsV3.textSecondary)
                        .frame(height: 44)
                }
            }
            .padding(.horizontal, AppSpacingV3.md)
            .padding(.bottom, AppSpacingV3.md)
            .background(Color.white)
        }
    }
}

// MARK: - Player Endorsement Card

private struct PlayerEndorsementCard: View {
    let participant: PublicProfile
    let isEndorsed: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacingV3.md) {
                TPAvatar(
                    url: participant.photoUrls.first.flatMap { URL(string: $0) },
                    size: 64
                )

                // Name & location
                VStack(alignment: .leading, spacing: 4) {
                    Text(participant.nickname)
                        .font(AppTypographyV3.headlineMediumSerif)
                        .foregroundColor(AppColorsV3.textPrimary)

                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(AppTypographyV3.captionEmphasis)
                        Text(participant.primaryCityLabel)
                            .font(AppTypographyV3.bodyRegular)
                    }
                    .foregroundColor(AppColorsV3.textSecondary)
                }

                Spacer()

                // Checkmark
                Image(systemName: isEndorsed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28))
                    .foregroundColor(isEndorsed ? AppColorsV3.success : AppColorsV3.textTertiary)
            }
            .padding(AppSpacingV3.md)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isEndorsed ? AppColorsV3.success.opacity(0.08) : AppColorsV3.surfaceWhite)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isEndorsed ? AppColorsV3.success.opacity(0.3) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var placeholderImage: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .foregroundColor(AppColorsV3.textTertiary)
    }
}

// MARK: - Select Issue Users Screen

private struct SelectIssueUsersScreen: View {
    @ObservedObject var viewModel: PostRoundFeedbackViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 8) {
                Circle()
                    .fill(AppColorsV3.error)
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(AppColorsV3.forestGreen)
                    .frame(width: 8, height: 8)
            }
            .padding(.top, 60)

            ScrollView {
                VStack(spacing: AppSpacingV3.lg) {
                    // Title
                    Text("Who had issues?")
                        .font(AppTypographyV3.displayLargeSerifRegular)
                        .foregroundColor(AppColorsV3.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.top, AppSpacingV3.lg)

                    Text("Select all that apply")
                        .font(AppTypographyV3.bodyLarge)
                        .foregroundColor(AppColorsV3.textSecondary)

                    // Player cards
                    VStack(spacing: AppSpacingV3.md) {
                        ForEach(viewModel.participants) { participant in
                            IssueUserCard(
                                participant: participant,
                                isSelected: viewModel.isIssueUserSelected(participant.id ?? ""),
                                onTap: { viewModel.toggleIssueUser(participant.id ?? "") }
                            )
                        }
                    }

                    // Bottom padding
                    Spacer()
                        .frame(height: 100)
                }
                .padding(.horizontal, AppSpacingV3.md)
            }

            // Sticky bottom button
            Button {
                viewModel.proceedToIssueDetails()
            } label: {
                Text("Continue")
                    .font(AppTypographyV3.headlineMediumSerif)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(viewModel.hasSelectedIssueUsers ? AppColorsV3.forestGreen : AppColorsV3.textTertiary)
                    .cornerRadius(16)
            }
            .disabled(!viewModel.hasSelectedIssueUsers)
            .padding(.horizontal, AppSpacingV3.md)
            .padding(.bottom, AppSpacingV3.md)
            .background(Color.white)
        }
    }
}

// MARK: - Issue User Card

private struct IssueUserCard: View {
    let participant: PublicProfile
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacingV3.md) {
                TPAvatar(
                    url: participant.photoUrls.first.flatMap { URL(string: $0) },
                    size: 64
                )

                // Name & location
                VStack(alignment: .leading, spacing: 4) {
                    Text(participant.nickname)
                        .font(AppTypographyV3.headlineMediumSerif)
                        .foregroundColor(AppColorsV3.textPrimary)

                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(AppTypographyV3.captionEmphasis)
                        Text(participant.primaryCityLabel)
                            .font(AppTypographyV3.bodyRegular)
                    }
                    .foregroundColor(AppColorsV3.textSecondary)
                }

                Spacer()

                // Checkmark
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28))
                    .foregroundColor(isSelected ? AppColorsV3.error : AppColorsV3.textTertiary)
            }
            .padding(AppSpacingV3.md)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? AppColorsV3.error.opacity(0.08) : AppColorsV3.surfaceWhite)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? AppColorsV3.error.opacity(0.3) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var placeholderImage: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .foregroundColor(AppColorsV3.textTertiary)
    }
}

// MARK: - Issue Details Screen

private struct IssueDetailsScreen: View {
    @ObservedObject var viewModel: PostRoundFeedbackViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 8) {
                Circle()
                    .fill(AppColorsV3.error.opacity(0.4))
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(AppColorsV3.error)
                    .frame(width: 8, height: 8)
            }
            .padding(.top, 60)

            ScrollView {
                VStack(spacing: AppSpacingV3.lg) {
                    // Title
                    Text("What happened?")
                        .font(AppTypographyV3.displayLargeSerifRegular)
                        .foregroundColor(AppColorsV3.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.top, AppSpacingV3.lg)

                    // Issue chips for each selected user
                    ForEach(Array(viewModel.selectedIssueUsers), id: \.self) { uid in
                        if let participant = viewModel.participants.first(where: { $0.id == uid }) {
                            UserIssueSection(
                                participant: participant,
                                selectedIssues: Binding(
                                    get: { viewModel.issuesByUser[uid] ?? [] },
                                    set: { viewModel.issuesByUser[uid] = $0 }
                                )
                            )
                        }
                    }

                    // Bottom padding
                    Spacer()
                        .frame(height: 100)
                }
                .padding(.horizontal, AppSpacingV3.md)
            }

            // Sticky bottom button
            Button {
                Task { await viewModel.submitFeedback() }
            } label: {
                Text("Submit Report")
                    .font(AppTypographyV3.headlineMediumSerif)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(AppColorsV3.error)
                    .cornerRadius(16)
            }
            .padding(.horizontal, AppSpacingV3.md)
            .padding(.bottom, AppSpacingV3.md)
            .background(Color.white)
        }
    }
}

// MARK: - User Issue Section

private struct UserIssueSection: View {
    let participant: PublicProfile
    @Binding var selectedIssues: Set<IssueType>

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacingV3.md) {
            // User header
            HStack(spacing: AppSpacingV3.xs) {
                TPAvatar(
                    url: participant.photoUrls.first.flatMap { URL(string: $0) },
                    size: 40
                )

                Text(participant.nickname)
                    .font(AppTypographyV3.headlineMediumSerif)
                    .foregroundColor(AppColorsV3.textPrimary)
            }

            // Issue chips
            FlowLayout(spacing: 8) {
                ForEach(IssueType.allCases, id: \.self) { issueType in
                    IssueChip(
                        issueType: issueType,
                        isSelected: selectedIssues.contains(issueType),
                        onTap: {
                            if selectedIssues.contains(issueType) {
                                selectedIssues.remove(issueType)
                            } else {
                                selectedIssues.insert(issueType)
                            }
                        }
                    )
                }
            }
        }
        .padding(AppSpacingV3.md)
        .background(AppColorsV3.surfaceWhite)
        .cornerRadius(16)
    }

    private var placeholderImage: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .foregroundColor(AppColorsV3.textTertiary)
    }
}

// MARK: - Issue Chip

private struct IssueChip: View {
    let issueType: IssueType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(issueType.displayName)
                .font(AppTypographyV3.bodyMedium)
                .foregroundColor(isSelected ? .white : AppColorsV3.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? AppColorsV3.error : Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(isSelected ? Color.clear : AppColorsV3.borderLight, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize
        var positions: [CGPoint]

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var positions: [CGPoint] = []
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                positions.append(CGPoint(x: currentX, y: currentY))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
            self.positions = positions
        }
    }
}

// MARK: - Success Screen

private struct FeedbackSuccessScreen: View {
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: AppSpacingV3.lg) {
            Spacer()

            // Success icon
            ZStack {
                Circle()
                    .fill(AppColorsV3.success.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundColor(AppColorsV3.success)
            }

            // Title
            Text("Thank you!")
                .font(AppTypographyV3.displayLargeSerifRegular)
                .foregroundColor(AppColorsV3.textPrimary)

            // Message
            Text("Your feedback helps build a safer golf community")
                .font(AppTypographyV3.bodyLarge)
                .foregroundColor(AppColorsV3.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacingV3.lg)

            Spacer()

            // Done button
            Button {
                onDone()
            } label: {
                Text("Done")
                    .font(AppTypographyV3.headlineMediumSerif)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(AppColorsV3.forestGreen)
                    .cornerRadius(16)
            }
            .padding(.horizontal, AppSpacingV3.md)
            .padding(.bottom, AppSpacingV3.md)
        }
    }
}

// MARK: - Already Submitted Screen

private struct AlreadySubmittedScreen: View {
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: AppSpacingV3.lg) {
            Spacer()

            // Icon
            Image(systemName: "checkmark.circle")
                .font(.system(size: 72))
                .foregroundColor(AppColorsV3.textSecondary)

            // Title
            Text("Already Submitted")
                .font(AppTypographyV3.displayMediumSerif)
                .foregroundColor(AppColorsV3.textPrimary)

            // Message
            Text("You've already provided feedback for this round")
                .font(AppTypographyV3.bodyLarge)
                .foregroundColor(AppColorsV3.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacingV3.lg)

            Spacer()

            // Done button
            Button {
                onDone()
            } label: {
                Text("Done")
                    .font(AppTypographyV3.headlineMediumSerif)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(AppColorsV3.forestGreen)
                    .cornerRadius(16)
            }
            .padding(.horizontal, AppSpacingV3.md)
            .padding(.bottom, AppSpacingV3.md)
        }
    }
}
