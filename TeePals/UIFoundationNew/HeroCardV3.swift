import SwiftUI

/// Hero Card V3 - Large card with course photo and gradient overlay
/// Used for displaying next upcoming round or empty state
struct HeroCardV3: View {

    let backgroundImage: URL?
    let assetImageName: String?
    let badgeText: String?
    let title: String
    let subtitle: String?
    let buttonTitle: String
    let action: () -> Void
    let isEmptyState: Bool

    init(
        backgroundImage: URL? = nil,
        assetImageName: String? = nil,
        badgeText: String? = nil,
        title: String,
        subtitle: String? = nil,
        buttonTitle: String,
        isEmptyState: Bool = false,
        action: @escaping () -> Void
    ) {
        self.backgroundImage = backgroundImage
        self.assetImageName = assetImageName
        self.badgeText = badgeText
        self.title = title
        self.subtitle = subtitle
        self.buttonTitle = buttonTitle
        self.isEmptyState = isEmptyState
        self.action = action
    }

    var body: some View {
        GeometryReader { geometry in
            cardContent(geometry: geometry)
        }
        .aspectRatio(4/3, contentMode: .fit)
    }

    @ViewBuilder
    private func cardContent(geometry: GeometryProxy) -> some View {
        if isEmptyState {
            // Empty state: only button is tappable, not the whole card
            ZStack(alignment: .bottomLeading) {
                // Background image
                backgroundView

                // Gradient overlay
                gradientOverlay

                // Content
                VStack(alignment: .center, spacing: AppSpacingV3.md) {
                    Spacer()

                    // Title and subtitle
                    contentSection

                    // CTA Button (only this is tappable)
                    Button(action: action) {
                        ctaButtonContent
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(AppSpacingV3.lg)
            }
            .frame(width: geometry.size.width)
            .aspectRatio(4/3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacingV3.radiusLarge, style: .continuous))
            .premiumShadow()
        } else {
            // Next round: whole card is tappable
            Button(action: action) {
                ZStack(alignment: .bottomLeading) {
                    // Background image
                    backgroundView

                    // Gradient overlay
                    gradientOverlay

                    // Content
                    VStack(alignment: .leading, spacing: AppSpacingV3.md) {
                        Spacer()

                        if let badgeText = badgeText {
                            badge(text: badgeText)
                        }

                        // Title and subtitle
                        contentSection

                        // CTA Button (visual only, parent button handles tap)
                        ctaButtonContent
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacingV3.lg)
                }
                .frame(width: geometry.size.width)
                .aspectRatio(4/3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacingV3.radiusLarge, style: .continuous))
                .premiumShadow()
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var backgroundView: some View {
        Color.clear
            .overlay {
                Group {
                    if let assetName = assetImageName {
                        Image(assetName)
                            .resizable()
                            .scaledToFill()

                    } else if let imageURL = backgroundImage {
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                placeholderBackground
                            }
                        }

                    } else {
                        placeholderBackground
                    }
                }
            }
            .clipped()
    }

    private var placeholderBackground: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var gradientOverlay: some View {
        Group {
            if isEmptyState {
                AppGradientsV3.heroCardEmpty
            } else {
                AppGradientsV3.heroCardForestGreen
            }
        }
    }

    private func badge(text: String) -> some View {
        Text(text)
            .labelUppercaseStyle()
            .foregroundColor(.white)
            .padding(.horizontal, AppSpacingV3.sm)
            .padding(.vertical, AppSpacingV3.xs)
            .background(
                Capsule()
                    .fill(.white.opacity(0.2))
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )
            )
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var contentSection: some View {
        VStack(alignment: isEmptyState ? .center : .leading, spacing: isEmptyState ? AppSpacingV3.xs : AppSpacingV3.xs) {
            Text(title)
                .font(AppTypographyV3.displayMediumSerif)
                .foregroundColor(.white)
                .textDropShadow()
                .multilineTextAlignment(isEmptyState ? .center : .leading)

            if let subtitle = subtitle {
                if isEmptyState {
                    // Empty state subtitle
                    Text(subtitle)
                        .font(AppTypographyV3.bodyMedium)
                        .foregroundColor(.white.opacity(0.9))
                        .textDropShadow()
                        .multilineTextAlignment(.center)
                } else {
                    // Round details (date, time icons)
                    HStack(spacing: AppSpacingV3.md) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 16))
                            Text(subtitle)
                        }
                    }
                    .font(AppTypographyV3.bodySmall)
                    .foregroundColor(.white.opacity(0.95))
                }
            }
        }
    }

    private var ctaButtonContent: some View {
        Text(buttonTitle)
            .buttonUppercaseStyle(tracking: 0.15)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: AppSpacingV3.radiusButton)
                    .fill(AppColorsV3.forestGreen)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacingV3.radiusButton)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .buttonShadowV3()
            .padding(.horizontal, isEmptyState ? AppSpacingV3.lg : 0)
    }
}

// MARK: - Preview

#if DEBUG
struct HeroCardV3_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 24) {
            // With round
            HeroCardV3(
                backgroundImage: URL(string: "https://example.com/course.jpg"),
                badgeText: "Upcoming Round",
                title: "Torrey Pines South",
                subtitle: "Sun, Feb 16 • 07:30 AM",
                buttonTitle: "View Details",
                action: {}
            )

            // Empty state
            HeroCardV3(
                backgroundImage: URL(string: "https://example.com/course.jpg"),
                title: "No Upcoming Rounds",
                subtitle: "Your next tee time awaits",
                buttonTitle: "Find a Round",
                isEmptyState: true,
                action: {}
            )
        }
        .padding()
        .background(AppColorsV3.bgNeutral)
    }
}
#endif
