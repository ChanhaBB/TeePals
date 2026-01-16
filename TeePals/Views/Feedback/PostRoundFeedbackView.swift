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
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(AppColors.surface.opacity(0.9))
                    .clipShape(Circle())
            }
            .padding(AppSpacing.contentPadding)
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
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 24)

                        // Main question - hero element
                        Text("How was the group experience?")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, AppSpacing.contentPadding)
                            .padding(.bottom, 28)

                        // Answer buttons
                        VStack(spacing: 12) {
                            // Yes button
                            Button {
                                viewModel.answerYes()
                            } label: {
                                HStack(spacing: AppSpacing.sm) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22))
                                    Text("Everything went well")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .foregroundColor(.white)
                                .background(AppColors.success)
                                .cornerRadius(16)
                            }

                            // No button
                            Button {
                                viewModel.answerNo()
                            } label: {
                                HStack(spacing: AppSpacing.sm) {
                                    Image(systemName: "exclamationmark.circle")
                                        .font(.system(size: 22))
                                    Text("Report an issue")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .foregroundColor(AppColors.textPrimary)
                                .background(AppColors.surface)
                                .cornerRadius(16)
                            }
                        }
                        .padding(.horizontal, AppSpacing.contentPadding)
                        .padding(.bottom, 20)

                        // Helper text
                        Text("You can skip this — feedback is optional and private")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.xl)
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
                    .fill(AppColors.success)
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(AppColors.primary)
                    .frame(width: 8, height: 8)
            }
            .padding(.top, 60)

            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Title
                    VStack(spacing: AppSpacing.xs) {
                        Text("Great!")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(AppColors.success)

                        Text("Would you play with them again?")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                    .padding(.top, AppSpacing.xl)

                    // Player cards
                    VStack(spacing: AppSpacing.md) {
                        ForEach(viewModel.participants) { participant in
                            PlayerEndorsementCard(
                                participant: participant,
                                isEndorsed: viewModel.isEndorsed(participant.id ?? ""),
                                onTap: { viewModel.toggleEndorsement(participant.id ?? "") }
                            )
                        }
                    }

                    // Skill accuracy question
                    VStack(spacing: AppSpacing.md) {
                        Text("Was everyone's skill level accurate?")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: AppSpacing.md) {
                            Button {
                                viewModel.skillAccurate = true
                            } label: {
                                HStack {
                                    Image(systemName: viewModel.skillAccurate == true ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                    Text("Yes")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(viewModel.skillAccurate == true ? AppColors.primary : AppColors.textSecondary)
                            }

                            Button {
                                viewModel.skillAccurate = false
                            } label: {
                                HStack {
                                    Image(systemName: viewModel.skillAccurate == false ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                    Text("No")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(viewModel.skillAccurate == false ? AppColors.primary : AppColors.textSecondary)
                            }
                        }
                    }

                    // Bottom padding
                    Spacer()
                        .frame(height: 120)
                }
                .padding(.horizontal, AppSpacing.contentPadding)
            }

            // Sticky bottom buttons
            VStack(spacing: AppSpacing.sm) {
                Button {
                    Task { await viewModel.submitFeedback() }
                } label: {
                    Text("Submit Feedback")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(AppColors.primary)
                        .cornerRadius(16)
                }

                Button {
                    viewModel.skipEndorsements()
                } label: {
                    Text("Skip for Now")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(height: 44)
                }
            }
            .padding(.horizontal, AppSpacing.contentPadding)
            .padding(.bottom, AppSpacing.lg)
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
            HStack(spacing: AppSpacing.md) {
                // Profile photo
                if let photoUrl = participant.photoUrls.first, let url = URL(string: photoUrl) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        placeholderImage
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
                } else {
                    placeholderImage
                        .frame(width: 64, height: 64)
                }

                // Name & location
                VStack(alignment: .leading, spacing: 4) {
                    Text(participant.nickname)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)

                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 12))
                        Text(participant.primaryCityLabel)
                            .font(.system(size: 14))
                    }
                    .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                // Checkmark
                Image(systemName: isEndorsed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28))
                    .foregroundColor(isEndorsed ? AppColors.success : AppColors.textTertiary)
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isEndorsed ? AppColors.success.opacity(0.08) : AppColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isEndorsed ? AppColors.success.opacity(0.3) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var placeholderImage: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .foregroundColor(AppColors.textTertiary)
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
                    .fill(AppColors.error)
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(AppColors.primary)
                    .frame(width: 8, height: 8)
            }
            .padding(.top, 60)

            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Title
                    Text("Who had issues?")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.top, AppSpacing.xl)

                    Text("Select all that apply")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textSecondary)

                    // Player cards
                    VStack(spacing: AppSpacing.md) {
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
                .padding(.horizontal, AppSpacing.contentPadding)
            }

            // Sticky bottom button
            Button {
                viewModel.proceedToIssueDetails()
            } label: {
                Text("Continue")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(viewModel.hasSelectedIssueUsers ? AppColors.primary : AppColors.textTertiary)
                    .cornerRadius(16)
            }
            .disabled(!viewModel.hasSelectedIssueUsers)
            .padding(.horizontal, AppSpacing.contentPadding)
            .padding(.bottom, AppSpacing.lg)
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
            HStack(spacing: AppSpacing.md) {
                // Profile photo
                if let photoUrl = participant.photoUrls.first, let url = URL(string: photoUrl) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        placeholderImage
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
                } else {
                    placeholderImage
                        .frame(width: 64, height: 64)
                }

                // Name & location
                VStack(alignment: .leading, spacing: 4) {
                    Text(participant.nickname)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)

                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 12))
                        Text(participant.primaryCityLabel)
                            .font(.system(size: 14))
                    }
                    .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                // Checkmark
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28))
                    .foregroundColor(isSelected ? AppColors.error : AppColors.textTertiary)
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? AppColors.error.opacity(0.08) : AppColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? AppColors.error.opacity(0.3) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var placeholderImage: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .foregroundColor(AppColors.textTertiary)
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
                    .fill(AppColors.error.opacity(0.4))
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(AppColors.error)
                    .frame(width: 8, height: 8)
            }
            .padding(.top, 60)

            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Title
                    Text("What happened?")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.top, AppSpacing.xl)

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
                .padding(.horizontal, AppSpacing.contentPadding)
            }

            // Sticky bottom button
            Button {
                Task { await viewModel.submitFeedback() }
            } label: {
                Text("Submit Report")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(AppColors.error)
                    .cornerRadius(16)
            }
            .padding(.horizontal, AppSpacing.contentPadding)
            .padding(.bottom, AppSpacing.lg)
            .background(Color.white)
        }
    }
}

// MARK: - User Issue Section

private struct UserIssueSection: View {
    let participant: PublicProfile
    @Binding var selectedIssues: Set<IssueType>

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // User header
            HStack(spacing: AppSpacing.sm) {
                if let photoUrl = participant.photoUrls.first, let url = URL(string: photoUrl) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        placeholderImage
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                } else {
                    placeholderImage
                        .frame(width: 40, height: 40)
                }

                Text(participant.nickname)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
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
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .cornerRadius(16)
    }

    private var placeholderImage: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .foregroundColor(AppColors.textTertiary)
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
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(isSelected ? .white : AppColors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? AppColors.error : Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(isSelected ? Color.clear : AppColors.border, lineWidth: 1)
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
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            // Success icon
            ZStack {
                Circle()
                    .fill(AppColors.success.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundColor(AppColors.success)
            }

            // Title
            Text("Thank you!")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(AppColors.textPrimary)

            // Message
            Text("Your feedback helps build a safer golf community")
                .font(.system(size: 17))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)

            Spacer()

            // Done button
            Button {
                onDone()
            } label: {
                Text("Done")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(AppColors.primary)
                    .cornerRadius(16)
            }
            .padding(.horizontal, AppSpacing.contentPadding)
            .padding(.bottom, AppSpacing.lg)
        }
    }
}

// MARK: - Already Submitted Screen

private struct AlreadySubmittedScreen: View {
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            // Icon
            Image(systemName: "checkmark.circle")
                .font(.system(size: 72))
                .foregroundColor(AppColors.textSecondary)

            // Title
            Text("Already Submitted")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(AppColors.textPrimary)

            // Message
            Text("You've already provided feedback for this round")
                .font(.system(size: 17))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)

            Spacer()

            // Done button
            Button {
                onDone()
            } label: {
                Text("Done")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(AppColors.primary)
                    .cornerRadius(16)
            }
            .padding(.horizontal, AppSpacing.contentPadding)
            .padding(.bottom, AppSpacing.lg)
        }
    }
}
