import Foundation
import MapKit

/// Service for searching golf courses using Apple MapKit.
@MainActor
final class GolfCourseSearchService: ObservableObject {
    
    @Published var searchResults: [CourseCandidate] = []
    @Published var isSearching = false
    @Published var errorMessage: String?
    
    private var searchTask: Task<Void, Never>?
    
    /// Searches for golf courses near the given query text.
    /// - Parameter query: Search text (e.g., "golf course san jose" or just "pebble beach")
    func search(query: String) {
        // Cancel previous search
        searchTask?.cancel()
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
        guard trimmedQuery.count >= 2 else {
            searchResults = []
            return
        }
        
        isSearching = true
        errorMessage = nil
        
        searchTask = Task {
            do {
                let results = try await performSearch(query: trimmedQuery)
                
                guard !Task.isCancelled else { return }
                
                self.searchResults = results
                self.isSearching = false
            } catch {
                guard !Task.isCancelled else { return }
                
                self.errorMessage = "Search failed. Please try again."
                self.isSearching = false
            }
        }
    }
    
    /// Clears search results.
    func clearResults() {
        searchTask?.cancel()
        searchResults = []
        isSearching = false
        errorMessage = nil
    }
    
    // MARK: - Private
    
    private func performSearch(query: String) async throws -> [CourseCandidate] {
        // Add "golf" to query if not present to improve results
        let searchQuery = query.lowercased().contains("golf") ? query : "\(query) golf course"
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchQuery
        request.resultTypes = .pointOfInterest
        
        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        
        // Filter and map results to CourseCandidate
        let courses = response.mapItems.compactMap { item -> CourseCandidate? in
            guard let name = item.name else { return nil }
            
            // Filter for likely golf courses
            let isGolfCourse = name.lowercased().contains("golf") ||
                               name.lowercased().contains("country club") ||
                               name.lowercased().contains("links") ||
                               item.pointOfInterestCategory == .park
            
            // Be lenient - include if it matches search or looks like golf
            guard isGolfCourse || name.lowercased().contains(query.lowercased()) else {
                return nil
            }
            
            let coordinate = item.placemark.coordinate
            let cityLabel = formatCityLabel(from: item.placemark)
            
            return CourseCandidate(
                name: name,
                cityLabel: cityLabel,
                location: GeoLocation(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
            )
        }
        
        // Remove duplicates and limit results
        var seen = Set<String>()
        return courses.filter { course in
            let key = course.name.lowercased()
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }.prefix(10).map { $0 }
    }
    
    private func formatCityLabel(from placemark: MKPlacemark) -> String {
        var parts: [String] = []
        
        if let city = placemark.locality {
            parts.append(city)
        }
        
        if let state = placemark.administrativeArea {
            parts.append(state)
        }
        
        return parts.joined(separator: ", ")
    }
}

