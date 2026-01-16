import Foundation
import SwiftUI

/// ViewModel for post-round feedback flow.
/// Manages state for primary question, endorsements, and incident reporting.
@MainActor
final class PostRoundFeedbackViewModel: ObservableObject {

    // MARK: - Dependencies

    private let roundId: String
    private let trustRepository: TrustRepository
    private let roundsRepository: RoundsRepository
    private let profileRepository: ProfileRepository
    private let currentUid: () -> String?

    // MARK: - State

    @Published var round: Round?
    @Published var participants: [PublicProfile] = []
    @Published var courseName: String = ""

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentStep: FeedbackStep = .primaryQuestion

    // Primary question
    @Published var roundSafetyOK: Bool?

    // Endorsement screen (Yes flow)
    @Published var endorsedUserIds: Set<String> = []
    @Published var skillAccurate: Bool? = true // Default to Yes

    // Incident reporting (No flow)
    @Published var selectedIssueUsers: Set<String> = []
    @Published var currentIssueUserIndex: Int = 0
    @Published var issuesByUser: [String: Set<IssueType>] = [:]
    @Published var commentsByUser: [String: String] = [:]
    @Published var issueComment: String = "" // Current comment being edited

    // Submission
    @Published var isSubmitting = false
    @Published var submissionComplete = false

    // MARK: - Computed

    var hasText: Bool {
        !composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var composerText: String {
        get { issueComment }
        set { issueComment = newValue }
    }

    var currentIssueUser: PublicProfile? {
        guard currentStep == .issueDetails else { return nil }
        let userIds = Array(selectedIssueUsers)
        guard currentIssueUserIndex < userIds.count else { return nil }
        let uid = userIds[currentIssueUserIndex]
        return participants.first { $0.id == uid }
    }

    var hasMoreIssueUsers: Bool {
        currentIssueUserIndex < selectedIssueUsers.count - 1
    }

    var hasSelectedIssueUsers: Bool {
        !selectedIssueUsers.isEmpty
    }

    // MARK: - Init

    init(
        roundId: String,
        trustRepository: TrustRepository,
        roundsRepository: RoundsRepository,
        profileRepository: ProfileRepository,
        currentUid: @escaping () -> String?
    ) {
        self.roundId = roundId
        self.trustRepository = trustRepository
        self.roundsRepository = roundsRepository
        self.profileRepository = profileRepository
        self.currentUid = currentUid
    }

    // MARK: - Load Data

    func loadRound() async {
        isLoading = true
        errorMessage = nil

        do {
            // Check if already submitted
            let alreadySubmitted = try await trustRepository.hasFeedbackBeenSubmitted(roundId: roundId)
            if alreadySubmitted {
                currentStep = .alreadySubmitted
                isLoading = false
                return
            }

            // Load round
            guard let fetchedRound = try await roundsRepository.fetchRound(id: roundId) else {
                throw TrustError.roundNotCompleted
            }

            round = fetchedRound
            courseName = fetchedRound.displayCourseName

            // Load participants (exclude current user)
            let members = try await roundsRepository.fetchMembers(roundId: roundId)
            let participantUids = members
                .filter { $0.status == .accepted && $0.uid != currentUid() }
                .map { $0.uid }

            // Fetch all profiles in parallel
            await loadProfiles(for: participantUids)

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func loadProfiles(for uids: [String]) async {
        let profiles = await withTaskGroup(of: (String, PublicProfile?).self) { group in
            for uid in uids {
                group.addTask {
                    let profile = try? await self.profileRepository.fetchPublicProfile(uid: uid)
                    return (uid, profile)
                }
            }

            var result: [PublicProfile] = []
            for await (_, profile) in group {
                if let profile = profile {
                    result.append(profile)
                }
            }
            return result
        }

        participants = profiles
    }

    // MARK: - Primary Question Actions

    func answerYes() {
        roundSafetyOK = true

        if participants.isEmpty {
            // Solo round - skip endorsement screen, go directly to success
            Task { await submitFeedback() }
        } else {
            currentStep = .endorsement
        }
    }

    func answerNo() {
        roundSafetyOK = false
        currentStep = .selectIssueUsers
    }

    // MARK: - Endorsement Actions

    func toggleEndorsement(_ uid: String) {
        if endorsedUserIds.contains(uid) {
            endorsedUserIds.remove(uid)
        } else {
            endorsedUserIds.insert(uid)
        }
    }

    func isEndorsed(_ uid: String) -> Bool {
        endorsedUserIds.contains(uid)
    }

    func skipEndorsements() {
        Task { await submitFeedback() }
    }

    // MARK: - Incident Reporting Actions

    func isIssueUserSelected(_ uid: String) -> Bool {
        selectedIssueUsers.contains(uid)
    }

    func toggleIssueUser(_ uid: String) {
        if selectedIssueUsers.contains(uid) {
            selectedIssueUsers.remove(uid)
        } else {
            selectedIssueUsers.insert(uid)
        }
    }

    func proceedToIssueDetails() {
        guard !selectedIssueUsers.isEmpty else { return }
        currentIssueUserIndex = 0
        currentStep = .issueDetails

        // Load saved issues/comment for first user if any
        if let firstUid = Array(selectedIssueUsers).first {
            issueComment = commentsByUser[firstUid] ?? ""
        }
    }

    func toggleIssue(_ issueType: IssueType, for uid: String) {
        var issues = issuesByUser[uid] ?? []
        if issues.contains(issueType) {
            issues.remove(issueType)
        } else {
            issues.insert(issueType)
        }
        issuesByUser[uid] = issues
    }

    func selectedIssues(for uid: String) -> Set<IssueType> {
        issuesByUser[uid] ?? []
    }

    func goBackToUserSelection() {
        // Save current comment
        if let currentUid = currentIssueUser?.id {
            commentsByUser[currentUid] = issueComment
        }
        currentStep = .selectIssueUsers
    }

    func submitIncidentReport() async {
        guard let currentUser = currentIssueUser else { return }
        guard let currentUserId = currentUser.id else { return }

        // Save current comment
        commentsByUser[currentUserId] = issueComment

        // Validate issues selected
        guard !selectedIssues(for: currentUserId).isEmpty else {
            errorMessage = "Please select at least one issue type"
            return
        }

        // Move to next user or submit all
        if hasMoreIssueUsers {
            currentIssueUserIndex += 1
            if let nextUid = Array(selectedIssueUsers)[safe: currentIssueUserIndex] {
                issueComment = commentsByUser[nextUid] ?? ""
            }
        } else {
            // Last user - submit everything
            await submitAllFeedback()
        }
    }

    func goBack() {
        switch currentStep {
        case .endorsement:
            currentStep = .primaryQuestion
        case .selectIssueUsers:
            currentStep = .primaryQuestion
        case .issueDetails:
            if let currentUid = currentIssueUser?.id {
                commentsByUser[currentUid] = issueComment
            }
            if currentIssueUserIndex > 0 {
                currentIssueUserIndex -= 1
                if let prevUid = Array(selectedIssueUsers)[safe: currentIssueUserIndex] {
                    issueComment = commentsByUser[prevUid] ?? ""
                }
            } else {
                currentStep = .selectIssueUsers
            }
        default:
            break
        }
    }

    // MARK: - Submission

    func submitFeedback() async {
        guard let safetyOK = roundSafetyOK else { return }

        // Optimistic UI - show success immediately
        currentStep = .success
        submissionComplete = true

        // Submit in background
        do {
            // Submit round feedback
            _ = try await trustRepository.submitRoundFeedback(
                roundId: roundId,
                roundSafetyOK: safetyOK,
                skillLevelsAccurate: skillAccurate
            )

            // Submit endorsements if any
            if safetyOK && !endorsedUserIds.isEmpty {
                let endorsements = endorsedUserIds.map { uid in
                    (targetUid: uid, wouldPlayAgain: true)
                }
                try await trustRepository.submitEndorsements(
                    roundId: roundId,
                    endorsements: endorsements
                )
            }
        } catch {
            // Show error but stay on success screen (already submitted optimistically)
            errorMessage = error.localizedDescription
        }
    }

    private func submitAllFeedback() async {
        // Optimistic UI - show success immediately
        currentStep = .success
        submissionComplete = true

        // Submit in background
        do {
            // Submit round feedback (safety NOT OK)
            _ = try await trustRepository.submitRoundFeedback(
                roundId: roundId,
                roundSafetyOK: false,
                skillLevelsAccurate: nil
            )

            // Submit all incident reports
            for userId in selectedIssueUsers {
                let issues = issuesByUser[userId] ?? []
                let comment = commentsByUser[userId]

                if !issues.isEmpty {
                    try await trustRepository.submitIncidentReport(
                        roundId: roundId,
                        targetUid: userId,
                        issueTypes: Array(issues),
                        comment: comment
                    )
                }
            }
        } catch {
            // Show error but stay on success screen (already submitted optimistically)
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Feedback Step

enum FeedbackStep {
    case primaryQuestion
    case endorsement
    case selectIssueUsers
    case issueDetails
    case success
    case alreadySubmitted
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
