import Foundation
import FirebaseFirestore

struct Round: Codable, Identifiable {
    @DocumentID var id: String?
    let hostUserId: String
    let courseName: String
    let cityLabel: String
    let location: GeoPoint
    let teeTime: Date
    let maxPlayers: Int
    var participantCount: Int
    var status: RoundStatus
    let createdAt: Date
    
    // Computed property for client-side distance (not stored in Firestore)
    var distanceKm: Double?
    
    init(
        id: String? = nil,
        hostUserId: String,
        courseName: String,
        cityLabel: String,
        location: GeoPoint,
        teeTime: Date,
        maxPlayers: Int = 4,
        participantCount: Int = 1,
        status: RoundStatus = .open,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.hostUserId = hostUserId
        self.courseName = courseName
        self.cityLabel = cityLabel
        self.location = location
        self.teeTime = teeTime
        self.maxPlayers = maxPlayers
        self.participantCount = participantCount
        self.status = status
        self.createdAt = createdAt
    }
    
    var isFull: Bool {
        participantCount >= maxPlayers
    }
    
    var spotsRemaining: Int {
        max(0, maxPlayers - participantCount)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, hostUserId, courseName, cityLabel, location, teeTime
        case maxPlayers, participantCount, status, createdAt
    }
}

enum RoundStatus: String, Codable {
    case open
    case full
    case canceled
}

