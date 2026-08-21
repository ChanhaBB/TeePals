import SwiftUI

/// TeePals V3 Typography System
/// Inter Variable Font for body text, Playfair Display for elegant headers
enum AppTypographyV3 {

    // MARK: - Display (Playfair Display Variable Font - Serif)

    /// Large display serif - 30pt bold italic (for "Sunday Morning" greeting)
    static let displayLargeSerif = Font.custom("PlayfairDisplay-Italic", size: 30, relativeTo: .largeTitle)
        .weight(.bold)

    /// Large display serif regular - 30pt bold (non-italic variant)
    static let displayLargeSerifRegular = Font.custom("PlayfairDisplay-Regular", size: 30, relativeTo: .largeTitle)
        .weight(.bold)

    /// Medium display serif - 24pt bold (for hero card titles)
    static let displayMediumSerif = Font.custom("PlayfairDisplay-Regular", size: 24, relativeTo: .title)
        .weight(.bold)

    /// Section header serif - 20pt bold (for section titles like "My Schedule")
    static let sectionHeaderSerif = Font.custom("PlayfairDisplay-Regular", size: 20, relativeTo: .title2)
        .weight(.bold)

    /// Headline medium serif - 18pt bold (for profile username, card titles)
    static let headlineMediumSerif = Font.custom("PlayfairDisplay-Regular", size: 18, relativeTo: .title3)
        .weight(.bold)

    /// Headline large serif - 22pt bold (for profile display name)
    static let headlineLargeSerif = Font.custom("PlayfairDisplay-Regular", size: 22, relativeTo: .title2)
        .weight(.bold)

    /// Large number serif - 30pt bold (for metric card numbers)
    static let numberLargeSerif = Font.custom("PlayfairDisplay-Regular", size: 30, relativeTo: .largeTitle)
        .weight(.bold)

    /// Medium number serif - 18pt bold (for date badges)
    static let numberMediumSerif = Font.custom("PlayfairDisplay-Regular", size: 18, relativeTo: .title3)
        .weight(.bold)

    // MARK: - Onboarding Styles

    /// Onboarding title - 36pt bold serif (for step titles like "What is your name?")
    static let onboardingTitle = Font.custom("PlayfairDisplay-Regular", size: 36, relativeTo: .largeTitle)
        .weight(.bold)

    /// Onboarding input large - 24pt medium serif (for large text input fields)
    static let onboardingInputLarge = Font.custom("PlayfairDisplay-Regular", size: 24, relativeTo: .title)
        .weight(.medium)

    /// Onboarding subtitle - 14pt regular (for step descriptions)
    static let onboardingSubtitle = Font.system(size: 14, weight: .regular, design: .default)

    /// Onboarding step counter - 14pt bold (for "1/4", "2/4" etc)
    static let onboardingStepCounter = Font.system(size: 14, weight: .bold, design: .default)

    // MARK: - Body (Inter Variable Font - Sans Serif)

    /// Body medium - 14pt medium
    static let bodyMedium = Font.system(size: 14, weight: .medium, design: .default)

    /// Body regular - 14pt regular
    static let bodyRegular = Font.system(size: 14, weight: .regular, design: .default)

    /// Body semibold - 14pt semibold
    static let bodySemibold = Font.system(size: 14, weight: .semibold, design: .default)

    /// Body small - 11pt medium (for host info, distance)
    static let bodySmall = Font.system(size: 11, weight: .medium, design: .default)

    /// Body large - 16pt regular (for larger body text)
    static let bodyLarge = Font.system(size: 16, weight: .regular, design: .default)

    /// Round card title - 15pt bold
    static let roundCardTitle = Font.system(size: 15, weight: .bold, design: .default)

    // MARK: - Labels

    /// Label uppercase bold - 10pt bold (for "INVITES", "PENDING", date labels)
    static let labelUppercaseBold = Font.system(size: 10, weight: .bold, design: .default)

    /// Label small - 9pt bold (for tiny uppercase labels like "Feb", "You're In")
    static let labelTiny = Font.system(size: 9, weight: .bold, design: .default)

    /// Label small - 11pt regular (for stats labels like "Followers", "Following")
    static let labelSmall = Font.system(size: 11, weight: .regular, design: .default)

    /// Label medium - 11pt bold (for "View All" links)
    static let labelLink = Font.system(size: 11, weight: .bold, design: .default)

    /// Tab bar label - 9pt bold (for bottom nav labels)
    static let tabBarLabel = Font.system(size: 9, weight: .bold, design: .default)

    // MARK: - Buttons

    /// Button uppercase - 11pt bold (for primary CTAs)
    static let buttonUppercase = Font.system(size: 11, weight: .bold, design: .default)

    /// Button badge - 8pt bold (for "You're In" badges)
    static let buttonBadge = Font.system(size: 8, weight: .bold, design: .default)

    // MARK: - Helper Text

    /// Helper text - 14pt medium (for welcome message)
    static let helperText = Font.system(size: 14, weight: .medium, design: .default)

    /// Placeholder - 14pt medium (for empty states)
    static let placeholder = Font.system(size: 14, weight: .medium, design: .default)

    /// Caption - 12pt regular (for secondary info, captions)
    static let caption = Font.system(size: 12, weight: .regular, design: .default)

    /// Caption emphasis - 12pt medium
    static let captionEmphasis = Font.system(size: 12, weight: .medium, design: .default)

    /// Label medium - 13pt medium (for banner action text, secondary labels)
    static let labelMedium = Font.system(size: 13, weight: .medium, design: .default)

    /// Headline large - 20pt bold (for numbers in stats)
    static let headlineLarge = Font.system(size: 20, weight: .bold, design: .default)

    /// Headline medium - 16pt semibold (for card section headers)
    static let headlineMedium = Font.system(size: 16, weight: .semibold, design: .default)
}

// MARK: - Text Modifiers

extension View {
    /// Apply serif display style with italic
    func displayLargeSerifStyle() -> some View {
        self.font(AppTypographyV3.displayLargeSerif)
    }

    /// Apply section header serif style
    func sectionHeaderSerifStyle() -> some View {
        self.font(AppTypographyV3.sectionHeaderSerif)
    }

    /// Apply uppercase label style with tracking
    func labelUppercaseStyle(tracking: CGFloat = 0.2) -> some View {
        self
            .font(AppTypographyV3.labelUppercaseBold)
            .textCase(.uppercase)
            .tracking(tracking)
    }

    /// Apply button uppercase style with wide tracking
    func buttonUppercaseStyle(tracking: CGFloat = 0.15) -> some View {
        self
            .font(AppTypographyV3.buttonUppercase)
            .textCase(.uppercase)
            .tracking(tracking)
    }
}

// MARK: - Font Registration Helper

/// Helper to check if custom fonts are loaded
/// Call this during app initialization to verify fonts
func verifyCustomFonts() {
    print("\n🔤 Verifying Custom Fonts...")

    // Check Inter Variable Font
    let interNames = ["Inter-Regular", "Inter", "InterVariable-Regular"]
    var interLoaded = false
    for name in interNames {
        if let font = UIFont(name: name, size: 12) {
            print("✅ Inter Variable Font loaded: \(font.fontName)")
            interLoaded = true
            break
        }
    }
    if !interLoaded {
        print("⚠️ Inter Variable Font not found - using system font fallback")
    }

    // Check Playfair Display Variable Font
    let playfairNames = [
        "PlayfairDisplay-Regular",
        "PlayfairDisplay",
        "PlayfairDisplay-Italic"
    ]
    var playfairLoaded = false
    for name in playfairNames {
        if let font = UIFont(name: name, size: 12) {
            print("✅ Playfair Display Variable Font loaded: \(font.fontName)")
            playfairLoaded = true
            break
        }
    }
    if !playfairLoaded {
        print("⚠️ Playfair Display Variable Font not found - using system serif fallback")
    }

    // List all available font families (useful for debugging)
    print("\n📚 Available font families:")
    for family in UIFont.familyNames.sorted() {
        if family.lowercased().contains("inter") || family.lowercased().contains("playfair") {
            print("  • \(family)")
            for name in UIFont.fontNames(forFamilyName: family) {
                print("    - \(name)")
            }
        }
    }
    print("")
}
