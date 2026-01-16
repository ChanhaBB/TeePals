import Foundation
import UIKit

/// ViewModel for ProfileEditView.
/// Handles loading, editing, and saving profile data.
@MainActor
final class ProfileEditViewModel: ObservableObject {
    
    // MARK: - Dependencies

    private let profileRepository: ProfileRepository
    private let storageService: StorageServiceProtocol
    private let postsRepository: PostsRepository
    private let currentUid: () -> String?
    
    // MARK: - State
    
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var validationError: String?
    
    // MARK: - Basic Info Fields
    
    @Published var nickname = ""
    @Published var birthDate: Date?
    @Published var gender: Gender?
    @Published var primaryCityLabel = ""
    @Published var primaryLocation: GeoLocation?
    @Published var occupation = ""
    @Published var bio = ""
    @Published var skillLevel: SkillLevel?
    @Published var photoUrls: [String] = [] {
        willSet {
            print("⚠️ [ProfileEdit] photoUrls about to change: \(photoUrls.count) -> \(newValue.count)")
            if newValue.isEmpty && !photoUrls.isEmpty {
                print("⚠️ [ProfileEdit] WARNING: photoUrls being cleared! Stack trace:")
                Thread.callStackSymbols.prefix(10).forEach { print("  \($0)") }
            }
        }
    }
    
    // MARK: - Golf Info Fields

    @Published var avgScore: Int?
    @Published var experienceLevel: ExperienceLevel?
    @Published var playsPerMonth: Int?

    // MARK: - Social Media

    @Published var instagramUsername: String = ""
    
    // MARK: - Photo Upload State
    
    @Published var isUploadingPhoto = false
    @Published var uploadProgress: Double = 0
    
    // Cached private profile for birthDate persistence
    private var privateProfile: PrivateProfile?

    // Track original values to detect changes
    private var originalNickname: String?
    private var originalPhotoUrl: String?

    // Track if profile has been loaded to prevent reloads
    private var hasLoadedProfile = false
    
    // MARK: - Constants
    
    static let maxPhotos = 5
    
    // MARK: - Init
    
    init(
        profileRepository: ProfileRepository,
        storageService: StorageServiceProtocol,
        postsRepository: PostsRepository,
        currentUid: @escaping () -> String?
    ) {
        self.profileRepository = profileRepository
        self.storageService = storageService
        self.postsRepository = postsRepository
        self.currentUid = currentUid
    }
    
    // MARK: - Computed Properties
    
    var trimmedNickname: String {
        nickname.trimmingCharacters(in: .whitespaces)
    }
    
    /// Whether profile can be saved (Tier 1 fields required).
    /// Note: Tier 2 gating (photo) is enforced at action time, not save time.
    var canSave: Bool {
        // Only require Tier 1 fields to save
        !trimmedNickname.isEmpty &&
        !primaryCityLabel.isEmpty &&
        primaryLocation != nil &&
        gender != nil
    }
    
    var canAddMorePhotos: Bool {
        photoUrls.count < Self.maxPhotos && !isUploadingPhoto
    }
    
    /// Extracts birth year from birthDate for public profile (age calculation)
    var birthYear: Int? {
        guard let birthDate = birthDate else { return nil }
        return Calendar.current.component(.year, from: birthDate)
    }
    
    // MARK: - Load Profile
    
    func loadProfile() async {
        // Prevent reloading if already loaded (avoids overwriting unsaved changes)
        guard !hasLoadedProfile else {
            print("⏭️ [ProfileEdit] Profile already loaded, skipping reload")
            return
        }

        guard let uid = currentUid() else { return }

        // Set flag IMMEDIATELY to prevent concurrent loads
        hasLoadedProfile = true

        print("📝 [ProfileEdit] Loading profile...")
        isLoading = true
        defer { isLoading = false }

        do {
            // Load public profile
            if let publicProfile = try await profileRepository.fetchPublicProfile(uid: uid) {
                print("📝 [ProfileEdit] Profile loaded with \(publicProfile.photoUrls.count) photos")
                nickname = publicProfile.nickname
                gender = publicProfile.gender
                primaryCityLabel = publicProfile.primaryCityLabel
                primaryLocation = publicProfile.primaryLocation
                occupation = publicProfile.occupation ?? ""
                bio = publicProfile.bio ?? ""
                skillLevel = publicProfile.skillLevel
                photoUrls = publicProfile.photoUrls
                avgScore = publicProfile.avgScore
                experienceLevel = publicProfile.experienceLevel
                playsPerMonth = publicProfile.playsPerMonth
                instagramUsername = publicProfile.instagramUsername ?? ""

                // Track original values
                originalNickname = publicProfile.nickname
                originalPhotoUrl = publicProfile.photoUrls.first
            }
            
            // Load private profile (for birthDate)
            if let privateProfile = try await profileRepository.fetchPrivateProfile(uid: uid) {
                self.privateProfile = privateProfile
                self.birthDate = parseBirthDate(privateProfile.birthDate)
            }
        } catch {
            errorMessage = "Failed to load profile: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Save Profile
    
    func saveProfile() async -> Bool {
        guard canSave else {
            validationError = "Please fill in all required fields."
            return false
        }
        
        guard let uid = currentUid(),
              let location = primaryLocation,
              let selectedGender = gender else {
            validationError = "Missing required fields."
            return false
        }
        
        isSaving = true
        validationError = nil
        errorMessage = nil
        defer { isSaving = false }
        
        do {
            // Build public profile
            let publicProfile = PublicProfile(
                id: uid,
                nickname: trimmedNickname,
                photoUrls: photoUrls,
                gender: selectedGender,
                occupation: occupation.isEmpty ? nil : occupation,
                bio: bio.isEmpty ? nil : bio,
                primaryCityLabel: primaryCityLabel,
                primaryLocation: location,
                avgScore: avgScore,
                experienceLevel: experienceLevel,
                playsPerMonth: playsPerMonth,
                skillLevel: skillLevel,
                birthYear: birthYear,
                instagramUsername: instagramUsername.isEmpty ? nil : instagramUsername
            )
            
            try await profileRepository.upsertPublicProfile(publicProfile)

            // Save birthDate to private profile if changed
            if let birthDate = birthDate {
                let privateProfile = PrivateProfile(
                    id: uid,
                    birthDate: formatBirthDate(birthDate)
                )
                try await profileRepository.upsertPrivateProfile(privateProfile)
            }

            // Update all posts if nickname or photo changed
            let newPhotoUrl = photoUrls.first
            let nicknameChanged = originalNickname != nil && originalNickname != trimmedNickname
            let photoChanged = originalPhotoUrl != newPhotoUrl

            if nicknameChanged || photoChanged {
                print("📝 [ProfileEdit] Profile changed - updating posts (nickname: \(nicknameChanged), photo: \(photoChanged))")
                try? await postsRepository.updateAuthorProfile(
                    uid: uid,
                    nickname: trimmedNickname,
                    photoUrl: newPhotoUrl
                )
            }

            // Update tracked values
            originalNickname = trimmedNickname
            originalPhotoUrl = newPhotoUrl

            return true
        } catch {
            errorMessage = "Failed to save profile: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Photo Management
    
    func uploadPhoto(_ image: UIImage) async {
        guard canAddMorePhotos else {
            print("❌ [ProfileEdit] Cannot add more photos (current: \(photoUrls.count), max: \(Self.maxPhotos))")
            return
        }

        print("📸 [ProfileEdit] Starting upload (current photos: \(photoUrls.count))")

        guard let imageData = image.compressedJPEGData(maxDimension: 1024, quality: 0.8) else {
            errorMessage = "Failed to process image."
            return
        }

        isUploadingPhoto = true

        do {
            let url = try await storageService.uploadProfilePhoto(imageData)
            // Ensure UI update happens on MainActor
            await MainActor.run {
                print("✅ [ProfileEdit] Photo uploaded, appending to array (current: \(photoUrls.count))")
                photoUrls.append(url)
                print("✅ [ProfileEdit] Array updated (now: \(photoUrls.count) photos)")
                isUploadingPhoto = false
            }
        } catch {
            await MainActor.run {
                print("❌ [ProfileEdit] Upload failed: \(error)")
                errorMessage = "Failed to upload photo: \(error.localizedDescription)"
                isUploadingPhoto = false
            }
        }
    }
    
    func deletePhoto(at index: Int) async {
        guard index < photoUrls.count else { return }

        let url = photoUrls[index]
        photoUrls.remove(at: index)

        // Try to delete from storage (fire and forget)
        Task {
            try? await storageService.deleteProfilePhoto(url: url)
        }
    }

    func reorderPhotos(from source: IndexSet, to destination: Int) {
        print("📸 [ProfileEdit] Reordering photos from \(source) to \(destination)")
        photoUrls.move(fromOffsets: source, toOffset: destination)
        print("📸 [ProfileEdit] New order: \(photoUrls.count) photos, first is now main")
    }
    
    // MARK: - Location
    
    func setLocation(latitude: Double, longitude: Double, cityLabel: String) {
        primaryLocation = GeoLocation(latitude: latitude, longitude: longitude)
        primaryCityLabel = cityLabel
    }
    
    // MARK: - Helpers
    
    private func formatBirthDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func parseBirthDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}

