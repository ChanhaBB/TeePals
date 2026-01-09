import Foundation
import CoreLocation
import MapKit

struct LocationResult: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
    
    var cityLabel: String {
        if subtitle.isEmpty {
            return title
        }
        return "\(title), \(subtitle)"
    }
    
    static func == (lhs: LocationResult, rhs: LocationResult) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
class LocationService: NSObject, ObservableObject {
    @Published var currentLocation: CLLocation?
    @Published var currentCityLabel: String?
    @Published var searchResults: [LocationResult] = []
    @Published var isSearching = false
    @Published var locationError: String?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    private let locationManager = CLLocationManager()
    private var searchCompleter: MKLocalSearchCompleter?
    private var pendingCompletion: ((CLLocation?, String?) -> Void)?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        authorizationStatus = locationManager.authorizationStatus
    }
    
    // MARK: - Current Location
    
    func requestCurrentLocation() async -> (location: CLLocation?, cityLabel: String?) {
        return await withCheckedContinuation { continuation in
            pendingCompletion = { location, cityLabel in
                continuation.resume(returning: (location, cityLabel))
            }
            
            let status = locationManager.authorizationStatus
            
            switch status {
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                locationManager.requestLocation()
            case .denied, .restricted:
                locationError = "Location access denied. Please enable in Settings."
                pendingCompletion?(nil, nil)
                pendingCompletion = nil
            @unknown default:
                pendingCompletion?(nil, nil)
                pendingCompletion = nil
            }
        }
    }
    
    private func reverseGeocode(location: CLLocation) async -> String? {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                let city = placemark.locality ?? placemark.administrativeArea ?? "Unknown"
                let state = placemark.administrativeArea ?? ""
                if city == state || state.isEmpty {
                    return city
                }
                return "\(city), \(state)"
            }
        } catch {
            print("Reverse geocode error: \(error)")
        }
        return nil
    }
    
    // MARK: - City Search
    
    func searchCities(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = query
        searchRequest.resultTypes = .address
        
        let search = MKLocalSearch(request: searchRequest)
        search.start { [weak self] response, error in
            Task { @MainActor in
                guard let self = self else { return }
                self.isSearching = false
                
                if let error = error {
                    print("Search error: \(error)")
                    return
                }
                
                guard let response = response else {
                    self.searchResults = []
                    return
                }
                
                // Filter to only city-level results and deduplicate
                var seen = Set<String>()
                self.searchResults = response.mapItems.compactMap { item -> LocationResult? in
                    guard let name = item.placemark.locality else { return nil }
                    
                    let state = item.placemark.administrativeArea ?? ""
                    let country = item.placemark.country ?? ""
                    let subtitle = [state, country].filter { !$0.isEmpty }.joined(separator: ", ")
                    let key = "\(name)-\(subtitle)"
                    
                    guard !seen.contains(key) else { return nil }
                    seen.insert(key)
                    
                    return LocationResult(
                        title: name,
                        subtitle: subtitle,
                        coordinate: item.placemark.coordinate
                    )
                }
            }
        }
    }
    
    func clearSearch() {
        searchResults = []
        isSearching = false
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            self.currentLocation = location
            let cityLabel = await self.reverseGeocode(location: location)
            self.currentCityLabel = cityLabel
            self.pendingCompletion?(location, cityLabel)
            self.pendingCompletion = nil
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.locationError = error.localizedDescription
            self.pendingCompletion?(nil, nil)
            self.pendingCompletion = nil
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            
            if manager.authorizationStatus == .authorizedWhenInUse ||
               manager.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }
}

