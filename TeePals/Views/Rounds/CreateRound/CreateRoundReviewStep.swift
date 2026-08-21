import SwiftUI

/// Step 4: Review all round details before posting.
/// Hero course image, floating tee time card, 3-card grid, speech bubble for host message.
struct CreateRoundReviewStep: View {
    @ObservedObject var viewModel: CreateRoundViewModel

    private let fullDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()


    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title
            stepTitle

            // Course hero card with overlapping tee time card
            if let course = viewModel.selectedCourse {
                ZStack(alignment: .bottom) {
                    courseHeroCard(course)

                    // Overlapping tee time card
                    teeTimeCard
                        .padding(.horizontal, 12)
                        .offset(y: 40)
                }
                .padding(.bottom, 40) // Space for overlapping card
            }

            // Content sections
            VStack(alignment: .leading, spacing: AppSpacingV3.lg) {
                hostMessageSection
                roundDetailsGrid
            }
            .padding(.top, AppSpacingV3.lg)
            .padding(.bottom, AppSpacingV3.md)

            Spacer(minLength: AppSpacingV3.md)
        }
        .padding(.top, AppSpacingV3.md)
    }

    // MARK: - Step Title

    private var stepTitle: some View {
        Text("Review Round")
            .font(Font.custom("PlayfairDisplay-Regular", size: 30, relativeTo: .largeTitle).weight(.bold))
            .foregroundColor(AppColorsV3.textPrimary)
            .tracking(-0.3)
            .padding(.bottom, AppSpacingV3.lg)
    }

    // MARK: - Course Hero Card

    private func courseHeroCard(_ course: CourseCandidate) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Background image layer
            Color.clear
                .overlay {
                    if let photoURL = viewModel.coursePhotoURL {
                        TPImage(url: photoURL)
                    } else {
                        Image("course-placeholder")
                            .resizable()
                            .scaledToFill()
                    }
                }
                .clipped()

            // Gradient overlay
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black.opacity(0.2), location: 0.6),
                    .init(color: .black.opacity(0.7), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Course name + location overlay (bottom-left)
            VStack(alignment: .leading, spacing: 6) {
                Text(course.name)
                    .font(.custom("PlayfairDisplay-Regular", size: 30, relativeTo: .largeTitle))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)

                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 16))
                    Text(course.cityLabel)
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 64)

            // Edit button (top-right)
            VStack {
                HStack {
                    Spacer()
                    Button {
                        viewModel.goToStep(.course)
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 16)
                }
                Spacer()
            }
        }
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color(red: 11/255, green: 61/255, blue: 46/255).opacity(0.12), radius: 16, x: 0, y: 6)
    }

    // MARK: - Tee Time Card (Floating)

    private var teeTimeCard: some View {
        HStack(spacing: AppSpacingV3.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(fullDateFormatter.string(from: viewModel.combinedDateTime))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColorsV3.textSecondary)

                Text(timeFormatter.string(from: viewModel.preferredTime))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppColorsV3.forestGreen)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                viewModel.goToStep(.dateTime)
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundColor(AppColorsV3.forestGreen)
                    .frame(width: 32, height: 32)
                    .background(Color.gray.opacity(0.05))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(AppColorsV3.surfaceWhite)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.gray.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: Color(red: 11/255, green: 61/255, blue: 46/255).opacity(0.08), radius: 12, x: 0, y: 4)
    }

    // MARK: - Round Details Grid

    private var roundDetailsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Text("ROUND DETAILS")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(AppColorsV3.textSecondary.opacity(0.6))
                Spacer()
                Button {
                    viewModel.goToStep(.settings)
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 16))
                        .foregroundColor(AppColorsV3.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            // 2-column grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                detailCard(icon: "person.2.fill", label: "Group Size", value: "\(viewModel.groupSize) Players")
                detailCard(icon: "dollarsign.circle", label: "Green Fee", value: greenFeeDisplay)
                detailCard(icon: viewModel.visibility.systemImage, label: "Visibility", value: viewModel.visibility.displayText)
            }
        }
    }

    private func detailCard(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Icon at top
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "E8F1EE"))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(AppColorsV3.forestGreen)
                )

            Spacer()

            // Label and value at bottom
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundColor(AppColorsV3.textSecondary)

                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColorsV3.textPrimary)
            }
        }
        .padding(16)
        .frame(height: 112)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColorsV3.surfaceWhite)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.gray.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color(red: 11/255, green: 61/255, blue: 46/255).opacity(0.08), radius: 12, x: 0, y: 4)
    }

    private var greenFeeDisplay: String {
        if let amount = Int(viewModel.greenFee), amount > 0 {
            return "$\(amount) / player"
        }
        return "TBD"
    }

    // MARK: - Host Message (Speech Bubble)

    private var hostMessageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Text("MESSAGE FROM HOST")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(AppColorsV3.textSecondary.opacity(0.6))

                Spacer()

                Button {
                    viewModel.goToStep(.settings)
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 16))
                        .foregroundColor(AppColorsV3.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            SpeechBubbleV3(
                message: viewModel.hostMessage.isEmpty ? CreateRoundViewModel.defaultHostMessage : viewModel.hostMessage,
                initials: nil,
                onEdit: nil
            )
        }
    }
}
