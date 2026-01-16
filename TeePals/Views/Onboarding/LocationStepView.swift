import SwiftUI

/// Step 3: Location entry for Tier 1 onboarding.
struct LocationStepView: View {
    @ObservedObject var viewModel: Tier1OnboardingViewModel
    @StateObject private var locationService = LocationService()
    
    @State private var isLocatingGPS = false
    @State private var showingCitySearch = false
    @State private var locationError: String?
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            headerSection
            
            if !viewModel.primaryCityLabel.isEmpty {
                selectedLocationView
            }
            
            locationButtons
            
            if let error = locationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
            
            Spacer()
            Spacer()
        }
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
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color(red: 0.1, green: 0.45, blue: 0.25))
            
            Text(viewModel.currentStep.title)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(viewModel.currentStep.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Selected Location
    
    private var selectedLocationView: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.primaryCityLabel)
                    .font(.headline)
                Text("Your home location")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                viewModel.primaryCityLabel = ""
                viewModel.primaryLocation = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Location Buttons
    
    private var locationButtons: some View {
        VStack(spacing: 12) {
            gpsButton
            orDivider
            searchButton
        }
        .padding(.horizontal)
    }
    
    private var gpsButton: some View {
        Button(action: useCurrentLocation) {
            HStack {
                if isLocatingGPS {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "location.fill")
                }
                Text(isLocatingGPS ? "Finding location..." : "Use My Location")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(red: 0.1, green: 0.45, blue: 0.25))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isLocatingGPS)
    }
    
    private var orDivider: some View {
        HStack {
            Rectangle().fill(Color(.separator)).frame(height: 1)
            Text("or").font(.caption).foregroundStyle(.secondary)
            Rectangle().fill(Color(.separator)).frame(height: 1)
        }
    }
    
    private var searchButton: some View {
        Button { showingCitySearch = true } label: {
            HStack {
                Image(systemName: "magnifyingglass")
                Text("Search for a City")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.secondarySystemBackground))
            .foregroundColor(.primary)
            .cornerRadius(12)
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
    func fetchPublicProfile(uid: String) async throws -> PublicProfile? { nil }
    func fetchPrivateProfile(uid: String) async throws -> PrivateProfile? { nil }
    func upsertPublicProfile(_ profile: PublicProfile) async throws {}
    func upsertPrivateProfile(_ profile: PrivateProfile) async throws {}
}
#endif
