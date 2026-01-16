import SwiftUI

/// Development-only view for creating test data.
/// Add this to ProfileView during testing.
/// ⚠️ Remove before production release.
struct TestDataSection: View {
    @State private var isCreating = false
    @State private var statusMessage: String?
    @State private var showingAlert = false

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                // Header
                HStack {
                    Text("🧪 Test Data")
                        .font(AppTypography.headlineMedium)
                        .foregroundColor(AppColors.error)

                    Spacer()

                    if isCreating {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }

                Divider()

                // Status message
                if let status = statusMessage {
                    Text(status)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.success)
                }

                // Buttons
                VStack(spacing: AppSpacing.sm) {
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

                // Warning text
                Text("⚠️ FOR TESTING ONLY - Remove before production")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.error)
                    .padding(.top, AppSpacing.xs)
            }
            .padding(AppSpacing.contentPadding)
        }
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
                    statusMessage = "✅ Created 3 feedback notifications - check Notifications tab"
                    isCreating = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = "❌ Error: \(error.localizedDescription)"
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
                    statusMessage = "✅ Cleared all feedback notifications"
                    isCreating = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = "❌ Error: \(error.localizedDescription)"
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

                // Also create notification for this round
                try await TestDataHelper.createFeedbackNotification(
                    roundId: roundId,
                    courseName: "Test Golf Course",
                    daysAgo: 0
                )

                await MainActor.run {
                    statusMessage = "✅ Created completed round + notification - check Notifications tab"
                    isCreating = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = "❌ Error: \(error.localizedDescription)"
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

                // Wait a moment for Firestore to propagate the write
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                await MainActor.run {
                    // Force reload profile to show badges
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)

                    statusMessage = "✅ Granted badges - scroll up to see Achievements section"
                    isCreating = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = "❌ Error: \(error.localizedDescription)"
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

                // Wait a moment for Firestore to propagate the write
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                await MainActor.run {
                    // Force reload profile to show cleared badges
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)

                    statusMessage = "✅ Cleared all badges"
                    isCreating = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = "❌ Error: \(error.localizedDescription)"
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
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(AppTypography.bodyMedium)
                Spacer()
            }
            .padding(AppSpacing.sm)
            .background(isDestructive ? AppColors.error.opacity(0.1) : AppColors.primary.opacity(0.1))
            .foregroundColor(isDestructive ? AppColors.error : AppColors.primary)
            .cornerRadius(AppSpacing.radiusSmall)
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
            .background(AppColors.backgroundGrouped)
    }
}
