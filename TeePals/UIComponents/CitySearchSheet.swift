import SwiftUI
import CoreLocation

/// Reusable city search sheet for location selection.
/// Used in both profile setup and onboarding flows.
struct CitySearchSheet: View {
    @ObservedObject var locationService: LocationService
    let onSelect: (String, CLLocationCoordinate2D) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                Divider()
                resultsContent
            }
            .navigationTitle("Search City")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Search Field
    
    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search for a city...", text: $searchText)
                .autocorrectionDisabled()
                .onChange(of: searchText) { _, newValue in
                    locationService.searchCities(query: newValue)
                }
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    locationService.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding()
    }
    
    // MARK: - Results Content
    
    @ViewBuilder
    private var resultsContent: some View {
        if locationService.isSearching {
            Spacer()
            ProgressView()
            Spacer()
        } else if locationService.searchResults.isEmpty && !searchText.isEmpty {
            Spacer()
            Text("No cities found")
                .foregroundColor(.secondary)
            Spacer()
        } else {
            resultsList
        }
    }
    
    private var resultsList: some View {
        List(locationService.searchResults) { result in
            Button {
                onSelect(result.cityLabel, result.coordinate)
                dismiss()
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.title)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    if !result.subtitle.isEmpty {
                        Text(result.subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.interactively)
    }
}

#if DEBUG
#Preview {
    CitySearchSheet(
        locationService: LocationService(),
        onSelect: { city, coord in
            print("Selected: \(city) at \(coord)")
        }
    )
}
#endif

