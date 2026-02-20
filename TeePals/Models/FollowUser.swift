import Foundation

/// A user in a follow relationship, with basic profile data.
struct FollowUser: Identifiable, Equatable {
    let uid: String
    var nickname: String
    var photoUrl: String?
    var isMutualFollow: Bool

    var id: String { uid }

    init(uid: String, nickname: String = "", photoUrl: String? = nil, isMutualFollow: Bool = false) {
        self.uid = uid
        self.nickname = nickname
        self.photoUrl = photoUrl
        self.isMutualFollow = isMutualFollow
    }
}
