import Foundation

struct PrivateProfile: Codable, Identifiable {
    var id: String?
    
    let birthDate: String  // Format: "YYYY-MM-DD"
    let createdAt: Date
    var updatedAt: Date
    
    init(
        id: String? = nil,
        birthDate: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.birthDate = birthDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Computed Properties
    
    /// Returns the birth date as a Date object
    var birthDateAsDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: birthDate)
    }
    
    /// Calculates the user's current age
    var age: Int? {
        guard let birthDate = birthDateAsDate else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: birthDate, to: Date())
        return components.year
    }
    
    /// Returns the age decade for matching with AgeDecade enum
    var ageDecade: AgeDecade? {
        guard let age = age else { return nil }
        switch age {
        case ..<20: return .teens
        case 20..<30: return .twenties
        case 30..<40: return .thirties
        case 40..<50: return .forties
        case 50..<60: return .fifties
        case 60..<70: return .sixties
        default: return .seventiesPlus
        }
    }
}

