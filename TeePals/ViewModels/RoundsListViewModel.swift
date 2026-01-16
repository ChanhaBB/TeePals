import Foundation
import UIKit

/// ViewModel for browsing and listing rounds.
@MainActor
final class RoundsListViewModel: ObservableObject {
    
    // MARK: - Dependencies
    
    private let roundsSearchService: RoundsSearchService
    private let profileRepository: ProfileRepository
    private let currentUid: () -> String?
    
    // MARK: - State

    @Published var rounds: [Round] = []
    @Published var hostProfiles: [String: PublicProfile] = [:] // uid -> profile
    @Published var isLoading = false // Start false, set true only when loading
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var isTruncated = false // True if results were limited

    private var hasLoadedOnce = false // Track if we've loaded before

    // Computed property: show skeleton until first load completes
    var shouldShowSkeleton: Bool {
        !hasLoadedOnce
    }

    // User's profile for default filters
    @Published var userProfile: PublicProfile?

    // Debug info (dev only)
    var lastSearchDebug: RoundsSearchDebugInfo?

    // MARK: - Pagination

    private var nextPageCursor: RoundsPageCursor?
    private var hasMorePages: Bool { nextPageCursor != nil }

    // MARK: - Filters

    @Published var filters = RoundsListFilters.defaults
    @Published var hasActiveFilters = false

    // MARK: - Init

    init(
        roundsSearchService: RoundsSearchService,
        profileRepository: ProfileRepository,
        currentUid: @escaping () -> String?
    ) {
        self.roundsSearchService = roundsSearchService
        self.profileRepository = profileRepository
        self.currentUid = currentUid
    }

    // MARK: - Computed Properties

    var isEmpty: Bool {
        rounds.isEmpty && !isLoading && hasLoadedOnce
    }
    
    var hasRounds: Bool {
        !rounds.isEmpty
    }
    
    /// Current filter summary for display
    var filterSummary: String {
        var parts: [String] = []
        
        if filters.distance != RoundsListFilters.defaultDistance {
            parts.append(filters.distance.displayText)
        }
        
        if filters.dateRange != RoundsListFilters.defaultDateRange {
            parts.append(filters.dateRange.displayText)
        }
        
        return parts.isEmpty ? "Default" : parts.joined(separator: " • ")
    }
    
    // MARK: - Initialize Filters from Profile
    
    func initializeFilters() async {
        guard let uid = currentUid() else { return }
        
        do {
            if let profile = try await profileRepository.fetchPublicProfile(uid: uid) {
                userProfile = profile
                
                // Set default filters from user profile
                let location = profile.primaryLocation
                filters = RoundsListFilters(
                    centerLat: location.latitude,
                    centerLng: location.longitude,
                    cityLabel: profile.primaryCityLabel,
                    distance: RoundsListFilters.defaultDistance,
                    dateRange: RoundsListFilters.defaultDateRange,
                    sortBy: .date
                )
            }
        } catch {
            print("Failed to load user profile for filters: \(error)")
        }
    }
    
    // MARK: - Load Rounds
    
    func loadRounds() async {
        // Skip if already loaded once (prevents redundant loads on tab switches)
        guard !hasLoadedOnce else { return }

        // Skip if currently loading
        guard !isLoading else { return }

        // Initialize filters from profile if not already done
        if filters.centerLat == nil {
            await initializeFilters()
        }

        isLoading = true
        errorMessage = nil
        nextPageCursor = nil

        do {
            let searchFilter: RoundsSearchFilter

            switch filters.searchMode {
            case .geo:
                // Geo mode: Must have a center location
                guard let centerLat = filters.centerLat,
                      let centerLng = filters.centerLng,
                      let radiusMiles = filters.radiusMiles else {
                    errorMessage = "Please set your location in your profile to search for rounds."
                    isLoading = false
                    return
                }

                searchFilter = RoundsSearchFilter(
                    centerLat: centerLat,
                    centerLng: centerLng,
                    radiusMiles: radiusMiles,
                    startTimeMin: filters.dateRange.startDate,
                    startTimeMax: filters.dateRange.endDate,
                    status: .open,
                    visibility: .public,
                    excludeFullRounds: true
                )

            case .discovery:
                // Discovery mode: Date-only, use a dummy center (ignored in query)
                searchFilter = RoundsSearchFilter(
                    centerLat: 0,
                    centerLng: 0,
                    radiusMiles: 0, // 0 signals discovery mode
                    startTimeMin: filters.dateRange.startDate,
                    startTimeMax: filters.dateRange.endDate,
                    status: .open,
                    visibility: .public,
                    excludeFullRounds: true,
                    isDiscoveryMode: true
                )
            }

            let page = try await roundsSearchService.searchRounds(filter: searchFilter, page: nil)

            let sortedRounds = sortResults(page.items)
            nextPageCursor = page.nextPageCursor
            isTruncated = page.isTruncated
            lastSearchDebug = page.debug

            // Load profiles before showing rounds (everything appears together)
            await loadHostProfiles(for: sortedRounds)

            // Preload profile images into cache
            await preloadProfileImages()

            // Show rounds with profiles and images loaded
            rounds = sortedRounds
            isLoading = false
            hasLoadedOnce = true
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    func loadMoreIfNeeded(currentRound: Round) async {
        guard hasMorePages,
              !isLoadingMore,
              let lastRound = rounds.last,
              currentRound.id == lastRound.id else {
            return
        }
        
        isLoadingMore = true
        
        do {
            let searchFilter: RoundsSearchFilter
            
            switch filters.searchMode {
            case .geo:
                guard let centerLat = filters.centerLat,
                      let centerLng = filters.centerLng,
                      let radiusMiles = filters.radiusMiles else {
                    isLoadingMore = false
                    return
                }
                
                searchFilter = RoundsSearchFilter(
                    centerLat: centerLat,
                    centerLng: centerLng,
                    radiusMiles: radiusMiles,
                    startTimeMin: filters.dateRange.startDate,
                    startTimeMax: filters.dateRange.endDate,
                    status: .open,
                    visibility: .public,
                    excludeFullRounds: true
                )
                
            case .discovery:
                searchFilter = RoundsSearchFilter(
                    centerLat: 0,
                    centerLng: 0,
                    radiusMiles: 0,
                    startTimeMin: filters.dateRange.startDate,
                    startTimeMax: filters.dateRange.endDate,
                    status: .open,
                    visibility: .public,
                    excludeFullRounds: true,
                    isDiscoveryMode: true
                )
            }
            
            let page = try await roundsSearchService.searchRounds(filter: searchFilter, page: nextPageCursor)
            
            let newRounds = sortResults(page.items)
            rounds.append(contentsOf: newRounds)
            nextPageCursor = page.nextPageCursor
            
            // Fetch host profiles for new rounds
            await loadHostProfiles(for: newRounds)
            
            isLoadingMore = false
        } catch {
            isLoadingMore = false
        }
    }
    
    func refresh() async {
        // Allow refresh even if already loaded
        hasLoadedOnce = false
        await loadRounds()
    }
    
    // MARK: - Sorting
    
    private func sortResults(_ items: [Round]) -> [Round] {
        switch filters.sortBy {
        case .date:
            return items.sorted { ($0.startTime ?? .distantFuture) < ($1.startTime ?? .distantFuture) }
        case .distance:
            return items.sorted { ($0.distanceMiles ?? .infinity) < ($1.distanceMiles ?? .infinity) }
        case .newest:
            return items.sorted { $0.createdAt > $1.createdAt }
        }
    }
    
    // MARK: - Filter Updates
    
    func updateFilters(
        centerLat: Double? = nil,
        centerLng: Double? = nil,
        cityLabel: String? = nil,
        distance: DistanceSelection? = nil,
        dateRange: DateRangeOption? = nil,
        sortBy: RoundSortOption? = nil
    ) {
        if let centerLat = centerLat {
            filters.centerLat = centerLat
        }
        if let centerLng = centerLng {
            filters.centerLng = centerLng
        }
        if let cityLabel = cityLabel {
            filters.cityLabel = cityLabel
        }
        if let distance = distance {
            filters.distance = distance
        }
        if let dateRange = dateRange {
            filters.dateRange = dateRange
        }
        if let sortBy = sortBy {
            filters.sortBy = sortBy
        }
        
        // Check if any filters differ from defaults
        hasActiveFilters = filters.distance != RoundsListFilters.defaultDistance ||
                          filters.dateRange != RoundsListFilters.defaultDateRange ||
                          filters.sortBy != .date
    }
    
    func applyFilters(_ newFilters: RoundsListFilters) {
        filters = newFilters
        hasActiveFilters = newFilters.distance != RoundsListFilters.defaultDistance ||
                          newFilters.dateRange != RoundsListFilters.defaultDateRange ||
                          newFilters.sortBy != .date
    }
    
    func resetFilters() {
        guard let profile = userProfile else { return }
        let location = profile.primaryLocation
        
        filters = RoundsListFilters(
            centerLat: location.latitude,
            centerLng: location.longitude,
            cityLabel: profile.primaryCityLabel,
            distance: RoundsListFilters.defaultDistance,
            dateRange: RoundsListFilters.defaultDateRange,
            sortBy: .date
        )
        hasActiveFilters = false
    }
    
    // MARK: - Host Profiles

    private func loadHostProfiles(for rounds: [Round]) async {
        let hostUids = Set(rounds.map { $0.hostUid })
        let missingUids = hostUids.filter { hostProfiles[$0] == nil }

        guard !missingUids.isEmpty else { return }

        // Fetch all profiles in parallel
        let profiles = await withTaskGroup(of: (String, PublicProfile?).self) { group in
            for uid in missingUids {
                group.addTask {
                    let profile = try? await self.profileRepository.fetchPublicProfile(uid: uid)
                    return (uid, profile)
                }
            }

            var result: [String: PublicProfile] = [:]
            for await (uid, profile) in group {
                if let profile = profile {
                    result[uid] = profile
                }
            }
            return result
        }

        // Update all at once to prevent flickering
        hostProfiles.merge(profiles) { _, new in new }
    }

    private func preloadProfileImages() async {
        // Extract all photo URLs from loaded profiles
        let photoURLs = hostProfiles.values.compactMap { profile -> URL? in
            guard let urlString = profile.photoUrls.first else { return nil }
            return URL(string: urlString)
        }

        guard !photoURLs.isEmpty else { return }

        // Download all images in parallel and cache them
        await withTaskGroup(of: Void.self) { group in
            for url in photoURLs {
                group.addTask {
                    // Check if already cached
                    if ImageCache.shared.get(for: url) != nil {
                        return
                    }

                    // Download and cache
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        if let image = UIImage(data: data) {
                            ImageCache.shared.set(image, for: url)
                        }
                    } catch {
                        // Silently fail - image will show placeholder
                    }
                }
            }
        }
    }

    func hostProfile(for round: Round) -> PublicProfile? {
        hostProfiles[round.hostUid]
    }
}

// MARK: - UI Filters

/// Filters for the rounds list UI.
/// Separate from RoundsSearchFilter to allow simpler UI state management.
struct RoundsListFilters: Equatable {
    var centerLat: Double?
    var centerLng: Double?
    var cityLabel: String?           // Display label for the selected city
    var distance: DistanceSelection  // Distance enum with .anywhere support
    var dateRange: DateRangeOption
    var sortBy: RoundSortOption
    
    init(
        centerLat: Double? = nil,
        centerLng: Double? = nil,
        cityLabel: String? = nil,
        distance: DistanceSelection = .miles(25),
        dateRange: DateRangeOption = RoundsListFilters.defaultDateRange,
        sortBy: RoundSortOption = .date
    ) {
        self.centerLat = centerLat
        self.centerLng = centerLng
        self.cityLabel = cityLabel
        self.distance = distance
        self.dateRange = dateRange
        self.sortBy = sortBy
    }
    
    // MARK: - Computed Properties
    
    /// Search mode derived from distance selection
    var searchMode: RoundsSearchMode {
        switch distance {
        case .anywhere:
            return .discovery
        case .miles:
            return .geo
        }
    }
    
    /// Radius in miles (nil for discovery mode)
    var radiusMiles: Double? {
        switch distance {
        case .anywhere:
            return nil
        case .miles(let value):
            return Double(value)
        }
    }
    
    // MARK: - Defaults
    
    static let defaultDistance: DistanceSelection = .miles(25)
    static let defaultDateRange: DateRangeOption = .next30
    
    static var defaults: RoundsListFilters {
        RoundsListFilters()
    }
}

// MARK: - Search Mode

/// Determines query strategy: geo-based or discovery (date-only)
enum RoundsSearchMode: Equatable {
    case geo        // Location + radius based search
    case discovery  // Date-only, shows rounds anywhere
}

// MARK: - Distance Selection

/// Distance options for rounds search
enum DistanceSelection: Equatable, Hashable {
    case miles(Int)   // Specific radius in miles
    case anywhere     // Discovery mode - ignore location
    
    var displayText: String {
        switch self {
        case .miles(let value):
            return "\(value) mi"
        case .anywhere:
            return "Anywhere"
        }
    }
    
    var intValue: Int? {
        switch self {
        case .miles(let value):
            return value
        case .anywhere:
            return nil
        }
    }
    
    /// All available distance options
    static var allOptions: [DistanceSelection] {
        [.miles(5), .miles(10), .miles(25), .miles(50), .miles(100), .anywhere]
    }
}
