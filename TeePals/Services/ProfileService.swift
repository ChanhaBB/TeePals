import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class ProfileService: ObservableObject {
    @Published var profile: Profile?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    
    var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    // MARK: - Fetch Profile
    
    func fetchProfile() async {
        guard let userId = currentUserId else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let doc = try await db.collection(FirestoreCollection.profiles).document(userId).getDocument()
            self.profile = try doc.data(as: Profile.self)
        } catch {
            errorMessage = "Failed to load profile"
            print("Fetch profile error: \(error)")
        }
    }
    
    // MARK: - Save Profile
    
    func saveProfile(_ profile: Profile) async -> Bool {
        guard let userId = currentUserId else {
            errorMessage = "Not signed in"
            return false
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try db.collection(FirestoreCollection.profiles).document(userId).setData(from: profile)
            self.profile = profile
            return true
        } catch {
            errorMessage = "Failed to save profile: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Update Profile Fields
    
    func updateProfile(
        homeCityLabel: String? = nil,
        homeLocation: GeoPoint? = nil,
        locationSource: LocationSource? = nil,
        ageBucket: AgeBucket? = nil,
        avgScore18: Int? = nil,
        skillLevel: SkillLevel? = nil
    ) async -> Bool {
        guard let userId = currentUserId else {
            errorMessage = "Not signed in"
            return false
        }
        
        var updates: [String: Any] = ["updatedAt": FieldValue.serverTimestamp()]
        
        if let homeCityLabel = homeCityLabel {
            updates["homeCityLabel"] = homeCityLabel
        }
        if let homeLocation = homeLocation {
            updates["homeLocation"] = homeLocation
        }
        if let locationSource = locationSource {
            updates["locationSource"] = locationSource.rawValue
        }
        if let ageBucket = ageBucket {
            updates["ageBucket"] = ageBucket.rawValue
        }
        if let avgScore18 = avgScore18 {
            updates["avgScore18"] = avgScore18
        }
        if let skillLevel = skillLevel {
            updates["skillLevel"] = skillLevel.rawValue
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await db.collection(FirestoreCollection.profiles).document(userId).updateData(updates)
            await fetchProfile()
            return true
        } catch {
            errorMessage = "Failed to update profile"
            return false
        }
    }
}

