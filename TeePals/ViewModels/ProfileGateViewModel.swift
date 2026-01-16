import Foundation

/// ViewModel for managing profile gating state and action resumption.
/// Used by ProfileGateView to show what's missing and route to completion.
@MainActor
final class ProfileGateViewModel: ObservableObject {
    
    // MARK: - Dependencies
    
    private let profileRepository: ProfileRepository
    private let currentUid: () -> String?
    
    // MARK: - Published State
    
    @Published private(set) var completionStatus: ProfileCompletionStatus?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    
    /// The action to resume after profile completion.
    private var pendingAction: (() async -> Void)?
    
    /// Whether the gate modal is being shown.
    @Published var isShowingGate = false
    
    /// Whether the profile completion flow is being shown.
    @Published var isShowingCompletion = false
    
    // MARK: - Computed Properties
    
    var currentLevel: ProfileCompletionLevel {
        completionStatus?.level ?? .incomplete
    }
    
    var missingRequirements: [ProfileRequirement] {
        completionStatus?.missingRequirements ?? []
    }
    
    var canEngage: Bool {
        completionStatus?.canEngage ?? false
    }
    
    // MARK: - Init
    
    init(
        profileRepository: ProfileRepository,
        currentUid: @escaping () -> String?
    ) {
        self.profileRepository = profileRepository
        self.currentUid = currentUid
    }
    
    // MARK: - Refresh Status
    
    /// Refreshes the profile completion status from Firestore.
    func refreshStatus() async {
        guard let uid = currentUid() else {
            completionStatus = ProfileCompletionStatus(
                level: .incomplete,
                missingRequirements: ProfileRequirement.allCases
            )
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let publicProfile = try await profileRepository.fetchPublicProfile(uid: uid)
            let privateProfile = try await profileRepository.fetchPrivateProfile(uid: uid)
            
            completionStatus = ProfileCompletionEvaluator.evaluate(
                publicProfile: publicProfile,
                privateProfile: privateProfile
            )
        } catch {
            // On error, assume incomplete to be safe
            completionStatus = ProfileCompletionStatus(
                level: .incomplete,
                missingRequirements: ProfileRequirement.allCases
            )
            errorMessage = "Failed to check profile status"
        }
    }
    
    // MARK: - Gating Logic
    
    /// Attempts to perform a gated action. If profile is incomplete, shows the gate.
    /// - Parameters:
    ///   - requiredLevel: The minimum profile level required (default: .tier2)
    ///   - action: The async action to perform if profile is complete
    /// - Returns: True if action was performed immediately, false if gated
    @discardableResult
    func attemptGatedAction(
        requiredLevel: ProfileCompletionLevel = .tier2,
        action: @escaping () async -> Void
    ) async -> Bool {
        // Refresh status first
        await refreshStatus()
        
        guard let status = completionStatus else {
            isShowingGate = true
            pendingAction = action
            return false
        }
        
        if status.level >= requiredLevel {
            // Profile is complete enough, perform action
            await action()
            return true
        } else {
            // Profile incomplete, show gate
            pendingAction = action
            isShowingGate = true
            return false
        }
    }
    
    /// Called when user dismisses the gate without completing profile.
    func dismissGate() {
        isShowingGate = false
        pendingAction = nil
    }
    
    /// Called when user taps to complete their profile.
    func startCompletion() {
        isShowingGate = false
        isShowingCompletion = true
    }
    
    /// Called when profile completion flow finishes successfully.
    func completionFinished() async {
        isShowingCompletion = false
        
        // Refresh status
        await refreshStatus()
        
        // If now complete, resume the pending action
        if canEngage, let action = pendingAction {
            pendingAction = nil
            await action()
        } else {
            pendingAction = nil
        }
    }
    
    /// Called when profile completion flow is cancelled.
    func completionCancelled() {
        isShowingCompletion = false
        pendingAction = nil
    }
}

