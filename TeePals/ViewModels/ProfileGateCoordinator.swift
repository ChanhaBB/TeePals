import Foundation

/// Destination for profile gate navigation.
enum GateDestination {
    case profileEdit
}

/// Coordinates Tier 2 profile gating across the app.
/// Provides a simple `requireTier2()` check that shows the gate popup if incomplete.
///
/// Usage:
/// ```swift
/// if gateCoordinator.requireTier2() {
///     // perform gated action
/// }
/// ```
@MainActor
final class ProfileGateCoordinator: ObservableObject {
    
    // MARK: - Dependencies
    
    private let profileRepository: ProfileRepository
    private let currentUid: () -> String?
    
    // MARK: - Published State
    
    /// Whether the gate popup is presented.
    @Published var isGatePresented = false
    
    /// Where to navigate after user taps "Complete now".
    @Published var gateDestination: GateDestination?
    
    /// Whether the profile edit sheet is presented.
    @Published var isProfileEditPresented = false
    
    /// Cached completion status (refreshed on demand).
    @Published private(set) var completionStatus: ProfileCompletionStatus?
    
    // MARK: - Init
    
    init(
        profileRepository: ProfileRepository,
        currentUid: @escaping () -> String?
    ) {
        self.profileRepository = profileRepository
        self.currentUid = currentUid
    }
    
    // MARK: - Gating Logic
    
    /// Checks if user meets Tier 2 requirements.
    /// If not, presents the gate popup.
    /// - Returns: `true` if action is allowed, `false` if gated (popup shown)
    func requireTier2() -> Bool {
        guard let status = completionStatus else {
            // If no status cached, assume incomplete and show gate
            isGatePresented = true
            return false
        }
        
        if status.canEngage {
            return true
        } else {
            isGatePresented = true
            return false
        }
    }
    
    /// Async version that refreshes status first.
    /// Use when you need fresh data (e.g., after coming back from edit).
    func requireTier2Async() async -> Bool {
        await refreshStatus()
        return requireTier2()
    }
    
    // MARK: - Refresh Status
    
    /// Refreshes completion status from Firestore.
    func refreshStatus() async {
        guard let uid = currentUid() else {
            completionStatus = ProfileCompletionStatus(
                level: .incomplete,
                missingRequirements: ProfileRequirement.allCases
            )
            return
        }
        
        do {
            let publicProfile = try await profileRepository.fetchPublicProfile(uid: uid)
            let privateProfile = try await profileRepository.fetchPrivateProfile(uid: uid)
            
            completionStatus = ProfileCompletionEvaluator.evaluate(
                publicProfile: publicProfile,
                privateProfile: privateProfile
            )
        } catch {
            // On error, keep existing status or assume incomplete
            if completionStatus == nil {
                completionStatus = ProfileCompletionStatus(
                    level: .incomplete,
                    missingRequirements: ProfileRequirement.allCases
                )
            }
        }
    }
    
    // MARK: - Gate Actions
    
    /// Called when user taps "Complete now" in the gate popup.
    func completeNowTapped() {
        isGatePresented = false
        gateDestination = .profileEdit
        isProfileEditPresented = true
    }
    
    /// Called when user taps "Not now" in the gate popup.
    func notNowTapped() {
        isGatePresented = false
    }
    
    /// Called when profile edit is dismissed.
    func profileEditDismissed() async {
        isProfileEditPresented = false
        gateDestination = nil
        // Refresh status so gating reflects any changes
        await refreshStatus()
    }
    
    // MARK: - Computed Properties
    
    /// Whether user can engage (Tier 2 complete).
    var canEngage: Bool {
        completionStatus?.canEngage ?? false
    }
    
    /// Missing Tier 2 requirements for display.
    var missingTier2Requirements: [ProfileRequirement] {
        completionStatus?.missingFor(tier: .tier2).filter { $0.tier == .tier2 } ?? []
    }
}

