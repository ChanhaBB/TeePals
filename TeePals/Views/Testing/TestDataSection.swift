import SwiftUI

/// Development-only view for creating test data.
/// Add this to ProfileView during testing.
struct TestDataSection: View {
    @State private var isCreating = false
    @State private var statusMessage: String?
    @State private var showingAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacingV3.sm) {
            HStack {
                Text("Test Data")
                    .font(AppTypographyV3.headlineMedium)
                    .foregroundColor(AppColorsV3.error)

                Spacer()

                if isCreating {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            Divider()

            if let status = statusMessage {
                Text(status)
                    .font(AppTypographyV3.caption)
                    .foregroundColor(AppColorsV3.success)
            }

            VStack(spacing: AppSpacingV3.xs) {
                testButton(
                    title: "Create 3 Feedback Notifications",
                    icon: "bell.badge.fill",
                    action: createSampleNotifications
                )

                testButton(
                    title: "Clear Feedback Notifications",
                    icon: "trash",
                    isDestructive: true,
                    action: clearNotifications
                )

                Divider()

                testButton(
                    title: "Create Completed Round + Notification",
                    icon: "checkmark.circle",
                    action: createCompletedRound
                )

                Divider()

                testButton(
                    title: "Grant Trust Badges",
                    icon: "star.fill",
                    action: grantBadges
                )

                testButton(
                    title: "Clear All Badges",
                    icon: "xmark.circle",
                    isDestructive: true,
                    action: clearBadges
                )
            }

            Text("FOR TESTING ONLY - Remove before production")
                .font(AppTypographyV3.caption)
                .foregroundColor(AppColorsV3.error)
                .padding(.top, AppSpacingV3.xxs)
        }
        .padding(AppSpacingV3.md)
        .background(AppColorsV3.surfaceWhite)
        .cornerRadius(AppSpacingV3.radiusMedium)
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    // MARK: - Actions

    private func createSampleNotifications() {
        guard !isCreating else { return }
        isCreating = true
        statusMessage = nil

        Task {
            do {
                try await TestDataHelper.createSampleFeedbackNotifications()
                await MainActor.run {
                    statusMessage = "Created 3 feedback notifications - check Notifications tab"
                    isCreating = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = "Error: \(error.localizedDescription)"
                    isCreating = false
                }
            }
        }
    }

    private func clearNotifications() {
        guard !isCreating else { return }
        isCreating = true
        statusMessage = nil

        Task {
            do {
                try await TestDataHelper.clearFeedbackNotifications()
                await MainActor.run {
                    statusMessage = "Cleared all feedback notifications"
                    isCreating = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = "Error: \(error.localizedDescription)"
                    isCreating = false
                }
            }
        }
    }

    private func createCompletedRound() {
        guard !isCreating else { return }
        isCreating = true
        statusMessage = nil

        Task {
            do {
                let roundId = try await TestDataHelper.createCompletedRound(
                    courseName: "Test Golf Course"
                )

                try await TestDataHelper.createFeedbackNotification(
                    roundId: roundId,
                    courseName: "Test Golf Course",
                    daysAgo: 0
                )

                await MainActor.run {
                    statusMessage = "Created completed round + notification - check Notifications tab"
                    isCreating = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = "Error: \(error.localizedDescription)"
                    isCreating = false
                }
            }
        }
    }

    private func grantBadges() {
        guard !isCreating else { return }
        isCreating = true
        statusMessage = nil

        Task {
            do {
                try await TestDataHelper.grantTrustBadges()
                try? await Task.sleep(nanoseconds: 500_000_000)

                await MainActor.run {
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)
                    statusMessage = "Granted badges - scroll up to see Achievements section"
                    isCreating = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = "Error: \(error.localizedDescription)"
                    isCreating = false
                }
            }
        }
    }

    private func clearBadges() {
        guard !isCreating else { return }
        isCreating = true
        statusMessage = nil

        Task {
            do {
                try await TestDataHelper.clearTrustBadges()
                try? await Task.sleep(nanoseconds: 500_000_000)

                await MainActor.run {
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)
                    statusMessage = "Cleared all badges"
                    isCreating = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = "Error: \(error.localizedDescription)"
                    isCreating = false
                }
            }
        }
    }

    // MARK: - Helper Views

    private func testButton(
        title: String,
        icon: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacingV3.xs) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(AppTypographyV3.bodyMedium)
                Spacer()
            }
            .padding(AppSpacingV3.xs)
            .background(isDestructive ? AppColorsV3.error.opacity(0.1) : AppColorsV3.forestGreen.opacity(0.1))
            .foregroundColor(isDestructive ? AppColorsV3.error : AppColorsV3.forestGreen)
            .cornerRadius(AppSpacingV3.radiusSmall)
        }
        .buttonStyle(.plain)
        .disabled(isCreating)
    }
}

// MARK: - Preview

struct TestDataSection_Previews: PreviewProvider {
    static var previews: some View {
        TestDataSection()
            .padding()
            .background(AppColorsV3.surfaceLight)
    }
}
