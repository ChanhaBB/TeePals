import SwiftUI
import AuthenticationServices

/// Onboarding carousel with 3 posters and infinite loop.
/// Shows Sign in with Apple button below carousel on every poster.
/// Updated to use UIFoundationNew V3 design system.
struct OnboardingCarouselView: View {
    @EnvironmentObject var authService: AuthService
    @State private var currentPage = 0

    // Poster data
    private let posters: [String] = [
        "OnboardingPoster1",
        "OnboardingPoster2",
        "OnboardingPoster3"
    ]

    // Onboarding-specific typography (larger than standard V3)
    private let onboardingTitleFont = Font.custom("PlayfairDisplay-Regular", size: 34, relativeTo: .largeTitle).weight(.semibold)

    var body: some View {
        ZStack {
            // 1. Carousel - raw images transition smoothly
            TabView(selection: $currentPage) {
                ForEach(0..<posters.count, id: \.self) { index in
                    OnboardingPosterView(imageName: posters[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.3), value: currentPage)

            // 2. Static gradient overlay (stays fixed, never rebuilds during swipe)
            staticGradientOverlay

            // 3. Overlay: Content card with consistent spacing
            VStack {
                Spacer()

                VStack(spacing: 0) {
                    // Text content (headline group)
                    VStack(spacing: AppSpacingV3.md) {
                        titleView(for: currentPage)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: 320)
                            .frame(height: 90, alignment: .center) // Fixed height for 2 lines

                        Text(subtitleText(for: currentPage))
                            .font(AppTypographyV3.bodyMedium)
                            .foregroundColor(Color(red: 229/255, green: 231/255, blue: 235/255)) // gray-200
                            .opacity(0.9)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .frame(maxWidth: 300)
                            .frame(height: 60, alignment: .top) // Fixed height
                    }
                    .padding(.horizontal, AppSpacingV3.lg)
                    .padding(.bottom, 40) // mb-10 in HTML
                    .allowsHitTesting(false) // Allow swipes to pass through text to TabView

                    // Page indicators (white dots)
                    HStack(spacing: 12) {
                        ForEach(0..<posters.count, id: \.self) { index in
                            Circle()
                                .fill(currentPage == index ? Color.white : Color.white.opacity(0.4))
                                .frame(width: 10, height: 10)
                        }
                    }
                    .padding(.bottom, 32) // mb-8 in HTML
                    .animation(.easeInOut(duration: 0.3), value: currentPage)
                    .allowsHitTesting(false) // Allow swipes to pass through indicators

                    // Sign in with Apple button
                    VStack(spacing: AppSpacingV3.xs) {
                        if let error = authService.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 32)
                        }

                        SignInWithAppleButton(.signIn) { request in
                            authService.handleSignInWithAppleRequest(request)
                        } onCompletion: { result in
                            authService.handleSignInWithAppleCompletion(result)
                        }
                        .signInWithAppleButtonStyle(.white) // White button with black text
                        .frame(height: 48)
                        .frame(maxWidth: 350)
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 32) // mt-8 spacing before footer

                    // Footer links
                    HStack(spacing: AppSpacingV3.md) {
                        Button("Privacy Policy") {
                            // TODO: Open privacy policy URL
                        }
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))

                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 1, height: 12)

                        Button("Terms of Service") {
                            // TODO: Open terms of service URL
                        }
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.bottom, 32)
                .padding(.horizontal, AppSpacingV3.lg)
            }
        }
    }

    // MARK: - Static Gradient Overlay

    private var staticGradientOverlay: some View {
        ZStack {
            // Overall subtle dim
            Color.black.opacity(0.1)
                .ignoresSafeArea()

            // Bottom gradient for text legibility
            VStack {
                Spacer()
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.85),
                        Color.black.opacity(0.6),
                        .clear
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: UIScreen.main.bounds.height * 0.6)
            }
            .ignoresSafeArea()
        }
        .allowsHitTesting(false) // Pass touches through to TabView underneath
    }

    // MARK: - Title Views with Green Highlights

    @ViewBuilder
    private func titleView(for page: Int) -> some View {
        switch page {
        case 0:
            // "Find Your\nNext Round" - 2 lines, all white
            Text("Find Your\nNext Round")
                .font(onboardingTitleFont)
                .foregroundColor(.white)
                .tracking(-0.5)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

        case 1:
            // "Host Like a Pro" - 1 line, all white, no line break
            Text("Host Like a Pro")
                .font(onboardingTitleFont)
                .foregroundColor(.white)
                .tracking(-0.5)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

        case 2:
            // "Golf is Better\nTogether" - 2 lines, all white
            Text("Golf is Better\nTogether")
                .font(onboardingTitleFont)
                .foregroundColor(.white)
                .tracking(-0.5)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

        default:
            Text("")
        }
    }

    private func subtitleText(for page: Int) -> String {
        switch page {
        case 0:
            return "Discover local rounds and meet golfers who match your vibe."
        case 1:
            return "Organize rounds and build the perfect group."
        case 2:
            return "Build your network, track your progress, and never play a solo round again."
        default:
            return ""
        }
    }
}
