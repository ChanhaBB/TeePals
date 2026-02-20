import SwiftUI

/// Unified card component for displaying rounds across all tabs.
/// Adapts layout based on context (Nearby, Activity, Following).
enum RoundCardContext {
    case nearby     // Discovery: course-first, host visible but secondary
    case following  // Social: host-led emphasis
    case activity   // User context: badge provides prominence
}

struct RoundCardView: View {
    let round: Round
    var hostProfile: PublicProfile?
    var badge: RoundCardBadge? = nil
    var context: RoundCardContext = .nearby
    var onTap: (() -> Void)?

    @EnvironmentObject var container: AppContainer
    @State private var coursePhotoURL: URL?
    @State private var isLoadingPhoto = false

    // MARK: - Constants

    private enum Layout {
        static let cardHeight: CGFloat = 110
        static let photoWidth: CGFloat = 100
        static let hostAvatarSize: CGFloat = 20
    }

    // MARK: - Body

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(alignment: .top, spacing: 0) {
                // Course photo with badge (left side)
                coursePhotoSection

                // Content section (right side)
                contentSection
            }
            .frame(minHeight: Layout.cardHeight)
            .background(AppColorsV3.surfaceWhite)
            .cornerRadius(12)
            .shadow(color: Color(red: 11/255, green: 61/255, blue: 46/255).opacity(0.08), radius: 10, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .task {
            await loadCoursePhoto()
        }
    }

    // MARK: - Course Photo Section (Left Side)

    @ViewBuilder
    private var coursePhotoSection: some View {
        ZStack(alignment: .topLeading) {
            // Background photo
            photoBackground

            // Spots badge overlay (top-left)
            spotsBadgeOverlay
                .padding(8)
        }
        .frame(width: Layout.photoWidth)
        .clipped()
    }

    @ViewBuilder
    private var photoBackground: some View {
        if let photoURL = coursePhotoURL {
            AsyncImage(url: photoURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: Layout.photoWidth)
                        .frame(minHeight: Layout.cardHeight)
                        .clipped()
                case .empty:
                    photoLoadingState
                case .failure:
                    photoFallbackGradient
                @unknown default:
                    photoFallbackGradient
                }
            }
        } else {
            photoLoadingState
        }
    }

    private var photoLoadingState: some View {
        Rectangle()
            .fill(AppColorsV3.bgNeutral)
            .frame(width: Layout.photoWidth)
            .frame(minHeight: Layout.cardHeight)
            .overlay {
                if isLoadingPhoto {
                    ProgressView()
                        .tint(AppColorsV3.forestGreen)
                }
            }
    }

    private var photoFallbackGradient: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        AppColorsV3.forestGreen.opacity(0.3),
                        AppColorsV3.forestGreen.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: Layout.photoWidth)
            .frame(minHeight: Layout.cardHeight)
    }

    // MARK: - Content Section (Right Side)

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Course name
            Text(round.displayCourseName)
                .font(AppTypographyV3.roundCardTitle)
                .foregroundColor(AppColorsV3.textPrimary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)

            // Date/time + distance
            if let dateTimeAndDistance = dateTimeDistanceText {
                Text(dateTimeAndDistance)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColorsV3.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Host row
            hostRow
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dateTimeDistanceText: String? {
        var components: [String] = []

        if let dateText = round.displayDateTime {
            components.append(dateText)
        }

        if let distance = formattedDistance {
            components.append(distance)
        }

        return components.isEmpty ? nil : components.joined(separator: " • ")
    }

    // MARK: - Badges

    private var spotsBadgeOverlay: some View {
        let remaining = round.spotsRemaining
        let total = round.maxPlayers

        return Text("\(remaining)/\(total) OPEN")
            .font(.system(size: 9, weight: .bold))
            .tracking(0.5)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.black.opacity(0.6))
            .cornerRadius(4)
    }

    // MARK: - Host Row

    private var hostRow: some View {
        HStack(spacing: 6) {
            // Host avatar
            ProfileAvatarView(
                url: hostProfile?.photoUrls.first,
                size: Layout.hostAvatarSize
            )

            if let host = hostProfile {
                Text("Hosted by \(host.displayName)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColorsV3.textSecondary)
            } else {
                Text("Loading host...")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColorsV3.textSecondary)
                    .redacted(reason: .placeholder)
            }
        }
    }

    // MARK: - Computed Properties

    private var formattedDistance: String? {
        guard let distance = round.distanceMiles else { return nil }
        return String(format: "%.1f mi", distance)
    }

    // MARK: - Photo Loading

    private func loadCoursePhoto() async {
        guard let course = round.chosenCourse ?? round.courseCandidates.first else {
            return
        }

        guard !isLoadingPhoto else { return }
        isLoadingPhoto = true

        coursePhotoURL = await container.coursePhotoService.fetchPhotoURL(for: course)
        isLoadingPhoto = false
    }
}

// MARK: - Round Card Badge

enum RoundCardBadge: Equatable {
    case hosting
    case requested    // User requested to join
    case confirmed    // Approved to join - future rounds
    case played       // Approved - past rounds
    case invited      // User needs to accept/decline
    case declined     // Not shown in Activity
}
