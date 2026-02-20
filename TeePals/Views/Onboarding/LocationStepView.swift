import SwiftUI

/// Step 3: Location entry for Tier 1 onboarding (V3 Design)
struct LocationStepView: View {
    @ObservedObject var viewModel: Tier1OnboardingViewModel
    @StateObject private var locationService = LocationService()

    @State private var isLocatingGPS = false
    @State private var showingCitySearch = false
    @State private var locationError: String?

    var body: some View {
        VStack(spacing: 0) {
            // Title and subtitle
            VStack(alignment: .leading, spacing: 12) {
                Text("Where do you usually golf?")
                    .font(AppTypographyV3.onboardingTitle)
                    .foregroundColor(AppColorsV3.forestGreen)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("We'll show you rounds nearby.")
                    .font(AppTypographyV3.onboardingSubtitle)
                    .foregroundColor(AppColorsV3.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.bottom, 24)

            // Selected location or input options
            if !viewModel.primaryCityLabel.isEmpty {
                selectedLocationCard
            } else {
                locationOptionsSection
            }

            if let error = locationError {
                Text(error)
                    .font(AppTypographyV3.onboardingSubtitle)
                    .foregroundStyle(.red)
                    .padding(.top, 16)
            }

            Spacer()
        }
        .padding(.horizontal, 32)
        .sheet(isPresented: $showingCitySearch) {
            CitySearchSheet(
                locationService: locationService,
                onSelect: { cityLabel, coordinate in
                    viewModel.setLocation(
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude,
                        cityLabel: cityLabel
                    )
                    locationError = nil
                }
            )
        }
    }

    // MARK: - Selected Location Card

    private var selectedLocationCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.fill")
                .foregroundStyle(AppColorsV3.forestGreen)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.primaryCityLabel)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColorsV3.textPrimary)
                Text("Your home location")
                    .font(AppTypographyV3.onboardingSubtitle)
                    .foregroundColor(AppColorsV3.textSecondary)
            }

            Spacer()

            Button {
                viewModel.primaryCityLabel = ""
                viewModel.primaryLocation = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.gray.opacity(0.5))
                    .font(.system(size: 22))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColorsV3.forestGreen.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(AppColorsV3.forestGreen.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Location Options

    private var locationOptionsSection: some View {
        VStack(spacing: 16) {
            // GPS Button
            Button(action: useCurrentLocation) {
                HStack(spacing: 12) {
                    if isLocatingGPS {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "location.fill")
                            .font(.system(size: 18))
                    }
                    Text(isLocatingGPS ? "Finding location..." : "Use My Location")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AppColorsV3.forestGreen)
                .cornerRadius(12)
            }
            .disabled(isLocatingGPS)

            // Or Divider
            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                Text("or")
                    .font(AppTypographyV3.onboardingSubtitle)
                    .foregroundColor(AppColorsV3.textSecondary)
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
            }

            // Search Button
            Button(action: { showingCitySearch = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18))
                    Text("Search for a City")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(AppColorsV3.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AppColorsV3.surfaceWhite)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .cornerRadius(12)
            }
        }
    }

    // MARK: - GPS Action

    private func useCurrentLocation() {
        isLocatingGPS = true
        locationError = nil

        Task {
            let result = await locationService.requestCurrentLocation()
            isLocatingGPS = false

            if let location = result.location, let cityLabel = result.cityLabel {
                viewModel.setLocation(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    cityLabel: cityLabel
                )
            } else {
                locationError = "Could not determine location. Try searching instead."
            }
        }
    }
}

#if DEBUG
struct LocationStepView_Previews: PreviewProvider {
    static var previews: some View {
        LocationStepView(
            viewModel: Tier1OnboardingViewModel(
                profileRepository: PreviewMockProfileRepository(),
                currentUid: { "preview" }
            )
        )
    }
}

private class PreviewMockProfileRepository: ProfileRepository {
    func profileExists(uid: String) async throws -> Bool { false }
    func fetchPublicProfile(uid: String) async throws -> PublicProfile? { nil }
    func fetchPrivateProfile(uid: String) async throws -> PrivateProfile? { nil }
    func upsertPublicProfile(_ profile: PublicProfile) async throws {}
    func upsertPrivateProfile(_ profile: PrivateProfile) async throws {}
}
#endif
