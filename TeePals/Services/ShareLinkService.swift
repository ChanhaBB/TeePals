import Foundation

/// Service for generating share links for rounds.
/// Uses HTTPS Universal Links (teepals.com/r/{roundId}) for vendor-agnostic deep linking.
protocol ShareLinkServiceProtocol {
    func createRoundInviteLink(
        roundId: String,
        round: Round,
        inviterUid: String?
    ) async throws -> URL
}

final class ShareLinkService: ShareLinkServiceProtocol {

    // MARK: - Configuration

    // TODO: Update to custom domain (teepals.com) once DNS is configured
    private let baseHost = "teepals-cf67c.web.app"
    private let basePath = "/r"

    // MARK: - Public Methods

    func createRoundInviteLink(
        roundId: String,
        round: Round,
        inviterUid: String? = nil
    ) async throws -> URL {
        // Simple URL construction - no network call needed
        var components = URLComponents()
        components.scheme = "https"
        components.host = baseHost
        components.path = "\(basePath)/\(roundId)"

        // Optional: Add inviter for attribution (future analytics)
        var queryItems: [URLQueryItem] = []

        if let inviterUid = inviterUid {
            queryItems.append(URLQueryItem(name: "inviter", value: inviterUid))
        }

        // Optional: Add source tracking (future analytics)
        // queryItems.append(URLQueryItem(name: "source", value: "app"))

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw ShareLinkError.invalidURL
        }

        return url
    }
}

// MARK: - Error Types

enum ShareLinkError: LocalizedError {
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Failed to create share link. Please try again."
        }
    }
}
