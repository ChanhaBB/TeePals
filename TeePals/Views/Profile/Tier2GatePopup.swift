import SwiftUI

/// Modal popup shown when user attempts a Tier 2 gated action (V3 Design).
/// Matches photoUpload.html design with forest green title, requirement card, and CTA button.
/// Slides up from bottom like a sheet.
struct Tier2GatePopup: View {
    @ObservedObject var coordinator: ProfileGateCoordinator
    @Binding var selectedTab: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Backdrop blur
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    coordinator.notNowTapped()
                }

            // Modal card (aligned to bottom)
            VStack {
                Spacer()

                VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        coordinator.notNowTapped()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(AppColorsV3.textSecondary)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(Color.gray.opacity(0.1))
                            )
                    }
                }
                .padding(.top, 24)
                .padding(.horizontal, 32)

                // Content
                VStack(alignment: .leading, spacing: 12) {
                    // Title
                    Text("Complete Your Profile")
                        .font(.custom("PlayfairDisplay-Regular", size: 32, relativeTo: .largeTitle))
                        .fontWeight(.bold)
                        .foregroundColor(AppColorsV3.forestGreen)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Subtitle
                    Text("To join rounds and connect with golfers, please add:")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColorsV3.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 32)
                .padding(.top, 12)

                // Requirements section
                VStack(spacing: 16) {
                    ForEach(coordinator.missingTier2Requirements, id: \.self) { requirement in
                        RequirementCardV3(requirement: requirement)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 32)

                // CTA Button
                PrimaryButtonV3(
                    title: "Add Profile Photo",
                    action: {
                        coordinator.notNowTapped() // Dismiss gate
                        selectedTab = 4 // Navigate to Profile tab (index 4)
                    }
                )
                .padding(.horizontal, 32)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity)
            .background(AppColorsV3.surfaceWhite)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .cornerRadius(32, corners: [.topLeft, .topRight]) // Only top corners rounded
            .shadow(color: .black.opacity(0.2), radius: 20, y: -10)
            .ignoresSafeArea(edges: .bottom)
        }
        }
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Requirement Card V3

private struct RequirementCardV3: View {
    let requirement: ProfileRequirement

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(AppColorsV3.forestGreen.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: iconName)
                    .font(.system(size: 20))
                    .foregroundColor(AppColorsV3.forestGreen)
            }

            // Text content
            VStack(alignment: .leading, spacing: 2) {
                Text(requirement.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColorsV3.textPrimary)

                Text(requirementDescription)
                    .font(.system(size: 12))
                    .foregroundColor(AppColorsV3.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)
            }

            Spacer()
        }
        .padding(16)
        .background(AppColorsV3.bgNeutral)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(AppColorsV3.borderLight, lineWidth: 1)
        )
    }

    private var iconName: String {
        switch requirement {
        case .profilePhoto:
            return "person.crop.circle"
        default:
            return requirement.systemImage
        }
    }

    private var requirementDescription: String {
        switch requirement {
        case .profilePhoto:
            return "Help others recognize you on the course"
        default:
            return ""
        }
    }
}

// MARK: - Tier 2 Gate Modifier

/// ViewModifier that presents the Tier 2 gate popup and handles navigation.
/// Apply at the root (TabView or NavigationStack) to enable gating everywhere.
struct Tier2GateModifier: ViewModifier {
    @ObservedObject var coordinator: ProfileGateCoordinator
    @Binding var selectedTab: Int

    func body(content: Content) -> some View {
        content
            .overlay {
                if coordinator.isGatePresented {
                    Tier2GatePopup(coordinator: coordinator, selectedTab: $selectedTab)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(999)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.9), value: coordinator.isGatePresented)
    }
}

extension View {
    /// Applies Tier 2 gating behavior to this view.
    /// - Parameters:
    ///   - coordinator: The gate coordinator to use
    ///   - selectedTab: Binding to the current tab index
    func tier2Gated(
        coordinator: ProfileGateCoordinator,
        selectedTab: Binding<Int>
    ) -> some View {
        modifier(Tier2GateModifier(
            coordinator: coordinator,
            selectedTab: selectedTab
        ))
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ZStack {
        // Mock background content
        VStack {
            Text("Home Screen")
                .font(.largeTitle)
        }

        Tier2GatePopup(
            coordinator: ProfileGateCoordinator(
                profileRepository: PreviewMocks.profileRepository,
                currentUid: { "preview" }
            ),
            selectedTab: .constant(0)
        )
    }
}

private enum PreviewMocks {
    static let profileRepository: ProfileRepository = MockRepo()

    private class MockRepo: ProfileRepository {
        func profileExists(uid: String) async throws -> Bool { false }
        func fetchPublicProfile(uid: String) async throws -> PublicProfile? { nil }
        func fetchPrivateProfile(uid: String) async throws -> PrivateProfile? { nil }
        func upsertPublicProfile(_ profile: PublicProfile) async throws {}
        func upsertPrivateProfile(_ profile: PrivateProfile) async throws {}
    }
}
#endif

