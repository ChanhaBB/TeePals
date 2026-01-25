import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Firestore implementation of PostsRepository.
/// Handles posts, comments, and upvotes with proper security.
final class FirestorePostsRepository: PostsRepository {
    
    private let db = Firestore.firestore()
    private let profileRepository: ProfileRepository
    private let socialRepository: SocialRepository
    
    private var currentUid: String? {
        Auth.auth().currentUser?.uid
    }
    
    init(profileRepository: ProfileRepository, socialRepository: SocialRepository) {
        self.profileRepository = profileRepository
        self.socialRepository = socialRepository
    }
    
    // MARK: - Post CRUD
    
    func createPost(_ post: Post) async throws -> Post {
        guard let uid = currentUid else {
            throw PostsError.notAuthenticated
        }
        
        guard post.authorUid == uid else {
            throw PostsError.unauthorized
        }
        
        guard post.text.count <= Post.maxTextLength else {
            throw PostsError.textTooLong
        }
        
        guard post.photoUrls.count <= Post.maxPhotos else {
            throw PostsError.tooManyPhotos
        }
        
        // Get author profile for denormalization
        let profile = try? await profileRepository.fetchPublicProfile(uid: uid)
        
        print("📝 [Posts] Creating post with visibility: '\(post.visibility.rawValue)'")
        
        var data: [String: Any] = [
            "authorUid": uid,
            "text": post.text.trimmingCharacters(in: .whitespacesAndNewlines),
            "photoUrls": post.photoUrls,
            "visibility": post.visibility.rawValue,
            "upvoteCount": 0,
            "commentCount": 0,
            "isEdited": false,
            "isDeleted": false,
            "authorNickname": profile?.nickname ?? "Unknown",
            "authorPhotoUrl": profile?.photoUrls.first ?? "",
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if let title = post.title, !title.isEmpty {
            data["title"] = title.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let linkedRoundId = post.linkedRoundId {
            data["linkedRoundId"] = linkedRoundId
        }

        if let cityId = post.cityId {
            data["cityId"] = cityId
        }

        if let courseId = post.courseId {
            data["courseId"] = courseId
        }

        if let tags = post.tags, !tags.isEmpty {
            data["tags"] = tags
        }
        
        let docRef = try await db.collection(FirestoreCollection.posts)
            .addDocument(data: data)
        
        print("📝 [Posts] Created post with ID: \(docRef.documentID)")
        
        var newPost = post
        newPost.id = docRef.documentID
        newPost.authorNickname = profile?.nickname
        newPost.authorPhotoUrl = profile?.photoUrls.first
        return newPost
    }
    
    func fetchPost(id: String) async throws -> Post? {
        let doc = try await db.collection(FirestoreCollection.posts)
            .document(id)
            .getDocument()
        
        guard doc.exists, let data = doc.data() else { return nil }
        
        var post = try decodePost(from: data, id: doc.documentID)
        
        // Check if current user has upvoted
        if let uid = currentUid {
            post.hasUpvoted = try await hasUpvotedInternal(postId: id, uid: uid)
        }
        
        return post
    }
    
    func updatePost(_ post: Post) async throws {
        guard let uid = currentUid, let postId = post.id else {
            throw PostsError.notAuthenticated
        }
        
        guard post.authorUid == uid else {
            throw PostsError.unauthorized
        }

        var data: [String: Any] = [
            "text": post.text.trimmingCharacters(in: .whitespacesAndNewlines),
            "photoUrls": post.photoUrls,
            "visibility": post.visibility.rawValue,
            "isEdited": true,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if let title = post.title, !title.isEmpty {
            data["title"] = title.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        try await db.collection(FirestoreCollection.posts)
            .document(postId)
            .updateData(data)
    }
    
    func deletePost(id: String) async throws {
        guard let uid = currentUid else {
            throw PostsError.notAuthenticated
        }
        
        // Verify ownership
        let doc = try await db.collection(FirestoreCollection.posts)
            .document(id)
            .getDocument()
        
        guard let data = doc.data(),
              let authorUid = data["authorUid"] as? String,
              authorUid == uid else {
            throw PostsError.unauthorized
        }
        
        // Delete post (comments and upvotes will remain orphaned - can clean up via Cloud Functions later)
        try await db.collection(FirestoreCollection.posts)
            .document(id)
            .delete()
    }

    func updateAuthorProfile(uid: String, nickname: String, photoUrl: String?) async throws {
        guard let currentUid = currentUid, currentUid == uid else {
            throw PostsError.unauthorized
        }

        print("📝 [Posts] Updating author profile for all posts by \(uid)")

        // Fetch all posts by this user
        let snapshot = try await db.collection(FirestoreCollection.posts)
            .whereField("authorUid", isEqualTo: uid)
            .getDocuments()

        print("📝 [Posts] Found \(snapshot.documents.count) posts to update")

        // Update in batches (Firestore batch max is 500)
        let batchSize = 500
        for chunk in snapshot.documents.chunked(into: batchSize) {
            let batch = db.batch()

            for doc in chunk {
                let ref = db.collection(FirestoreCollection.posts).document(doc.documentID)
                batch.updateData([
                    "authorNickname": nickname,
                    "authorPhotoUrl": photoUrl ?? ""
                ], forDocument: ref)
            }

            try await batch.commit()
        }

        print("✅ [Posts] Updated \(snapshot.documents.count) posts with new profile data")
    }

    func updateCommentAuthorProfile(uid: String, nickname: String, photoUrl: String?) async throws {
        guard let currentUid = currentUid, currentUid == uid else {
            throw PostsError.unauthorized
        }

        print("💬 [Posts] Updating author profile for all comments by \(uid)")

        // Use collectionGroup to find all comments by this user across all posts
        let snapshot = try await db.collectionGroup("comments")
            .whereField("authorUid", isEqualTo: uid)
            .getDocuments()

        print("💬 [Posts] Found \(snapshot.documents.count) comments to update")

        // Update in batches (Firestore batch max is 500)
        let batchSize = 500
        for chunk in snapshot.documents.chunked(into: batchSize) {
            let batch = db.batch()

            for doc in chunk {
                // Construct the full document reference from the path
                batch.updateData([
                    "authorNickname": nickname,
                    "authorPhotoUrl": photoUrl ?? ""
                ], forDocument: doc.reference)
            }

            try await batch.commit()
        }

        print("✅ [Posts] Updated \(snapshot.documents.count) comments with new profile data")
    }

    // MARK: - Feed Queries
    
    func fetchFeed(
        filter: FeedFilter,
        limit: Int,
        after: Date?
    ) async throws -> [Post] {
        guard let uid = currentUid else {
            throw PostsError.notAuthenticated
        }
        
        var posts: [Post] = []
        
        switch filter {
        case .all:
            // Fetch public posts + friends' posts
            posts = try await fetchPublicFeed(limit: limit, after: after)
            
        case .friendsOnly:
            // Fetch only posts from mutual follows (friends)
            posts = try await fetchFriendsFeed(uid: uid, limit: limit, after: after)
        }
        
        // Hydrate upvote status
        for i in posts.indices {
            posts[i].hasUpvoted = try? await hasUpvotedInternal(postId: posts[i].id ?? "", uid: uid)
        }
        
        return posts
    }
    
    private func fetchPublicFeed(limit: Int, after: Date?) async throws -> [Post] {
        print("📝 [Posts] Fetching public feed, visibility filter: '\(PostVisibility.public.rawValue)'")
        
        var query: Query = db.collection(FirestoreCollection.posts)
            .whereField("visibility", isEqualTo: PostVisibility.public.rawValue)
            .order(by: "createdAt", descending: true)
        
        if let after = after {
            query = query.start(after: [Timestamp(date: after)])
        }
        
        query = query.limit(to: min(limit, FeedConstants.maxPageSize))
        
        do {
            let snapshot = try await query.getDocuments()
            print("📝 [Posts] Query returned \(snapshot.documents.count) documents")
            
            let posts = snapshot.documents.compactMap { doc -> Post? in
                do {
                    let post = try decodePost(from: doc.data(), id: doc.documentID)
                    print("📝 [Posts] Decoded post: \(post.id ?? "nil") - \(post.text.prefix(30))...")
                    return post
                } catch {
                    print("📝 [Posts] Failed to decode document \(doc.documentID): \(error)")
                    return nil
                }
            }
            
            return posts
        } catch {
            print("📝 [Posts] Query failed with error: \(error)")
            throw error
        }
    }
    
    private func fetchFriendsFeed(uid: String, limit: Int, after: Date?) async throws -> [Post] {
        // Get list of friends (mutual follows)
        let friends = try await socialRepository.fetchMutualFollows(uid: uid)
        
        guard !friends.isEmpty else { return [] }
        
        // Firestore `in` query supports max 30 values, chunk if needed
        let friendUids = friends.map { $0.uid }
        let chunks = friendUids.chunked(into: 30)
        
        var allPosts: [Post] = []
        
        for chunk in chunks {
            var query: Query = db.collection(FirestoreCollection.posts)
                .whereField("authorUid", in: chunk)
                .order(by: "createdAt", descending: true)
            
            if let after = after {
                query = query.start(after: [Timestamp(date: after)])
            }
            
            query = query.limit(to: limit)
            
            let snapshot = try await query.getDocuments()
            let posts = snapshot.documents.compactMap { doc in
                try? decodePost(from: doc.data(), id: doc.documentID)
            }
            allPosts.append(contentsOf: posts)
        }
        
        // Sort and limit
        return allPosts
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .map { $0 }
    }
    
    func fetchUserPosts(
        uid: String,
        limit: Int,
        after: Date?
    ) async throws -> [Post] {
        guard let currentUid = currentUid else {
            throw PostsError.notAuthenticated
        }
        
        var query: Query = db.collection(FirestoreCollection.posts)
            .whereField("authorUid", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
        
        if let after = after {
            query = query.start(after: [Timestamp(date: after)])
        }
        
        query = query.limit(to: min(limit, FeedConstants.maxPageSize))
        
        let snapshot = try await query.getDocuments()
        
        var posts = snapshot.documents.compactMap { doc in
            try? decodePost(from: doc.data(), id: doc.documentID)
        }
        
        // Filter visibility if viewing another user
        if uid != currentUid {
            let isFriend = try await socialRepository.areMutualFollows(uid1: currentUid, uid2: uid)
            posts = posts.filter { post in
                post.visibility == .public || (post.visibility == .friends && isFriend)
            }
        }
        
        return posts
    }
    
    // MARK: - Upvotes

    func toggleUpvote(postId: String) async throws -> Bool {
        guard let uid = currentUid else {
            throw PostsError.notAuthenticated
        }

        let upvoteRef = db.collection(FirestoreCollection.posts)
            .document(postId)
            .collection("upvotes")
            .document(uid)

        // Check current state
        let upvoteDoc = try await upvoteRef.getDocument()
        let wasUpvoted = upvoteDoc.exists

        if wasUpvoted {
            // Remove upvote - Cloud Function will update count asynchronously
            try await upvoteRef.delete()
            return false
        } else {
            // Add upvote - Cloud Function will update count asynchronously
            try await upvoteRef.setData([
                "uid": uid,
                "createdAt": FieldValue.serverTimestamp()
            ])
            return true
        }
    }
    
    func hasUpvoted(postId: String) async throws -> Bool {
        guard let uid = currentUid else { return false }
        return try await hasUpvotedInternal(postId: postId, uid: uid)
    }
    
    private func hasUpvotedInternal(postId: String, uid: String) async throws -> Bool {
        let upvoteDoc = try await db.collection(FirestoreCollection.posts)
            .document(postId)
            .collection("upvotes")
            .document(uid)
            .getDocument()
        
        return upvoteDoc.exists
    }
    
    // MARK: - Comments
    
    func createComment(_ comment: Comment) async throws -> Comment {
        guard let uid = currentUid else {
            throw PostsError.notAuthenticated
        }
        
        guard comment.authorUid == uid else {
            throw PostsError.unauthorized
        }
        
        guard comment.text.count <= Comment.maxTextLength else {
            throw PostsError.commentTooLong
        }
        
        // Get author profile
        let profile = try? await profileRepository.fetchPublicProfile(uid: uid)
        
        var data: [String: Any] = [
            "postId": comment.postId,
            "authorUid": uid,
            "text": comment.text.trimmingCharacters(in: .whitespacesAndNewlines),
            "depth": min(comment.depth, Comment.maxDepth),
            "isEdited": false,
            "authorNickname": profile?.nickname ?? "Unknown",
            "authorPhotoUrl": profile?.photoUrls.first ?? "",
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        if let parentId = comment.parentCommentId {
            data["parentCommentId"] = parentId
        }
        
        if let replyToUid = comment.replyToUid {
            data["replyToUid"] = replyToUid
            // Fetch reply-to nickname
            if let replyToProfile = try? await profileRepository.fetchPublicProfile(uid: replyToUid) {
                data["replyToNickname"] = replyToProfile.nickname
            }
        }
        
        // Add comment
        let docRef = try await db.collection(FirestoreCollection.posts)
            .document(comment.postId)
            .collection("comments")
            .addDocument(data: data)

        // NOTE: commentCount is updated automatically by Cloud Function (onCommentWrite)
        // This ensures consistent counting and prevents race conditions

        var newComment = comment
        newComment.id = docRef.documentID
        newComment.authorNickname = profile?.nickname
        newComment.authorPhotoUrl = profile?.photoUrls.first
        return newComment
    }
    
    func fetchComments(postId: String) async throws -> [Comment] {
        let snapshot = try await db.collection(FirestoreCollection.posts)
            .document(postId)
            .collection("comments")
            .order(by: "createdAt", descending: false)
            .getDocuments()

        var comments = snapshot.documents.compactMap { doc in
            try? decodeComment(from: doc.data(), id: doc.documentID, postId: postId)
        }

        // Enrich with hasLiked for current user
        if let uid = currentUid, !comments.isEmpty {
            // Batch check all likes in parallel
            await withTaskGroup(of: (Int, Bool).self) { group in
                for (index, comment) in comments.enumerated() {
                    guard let commentId = comment.id else { continue }
                    group.addTask {
                        let hasLiked = (try? await self.hasLikedComment(postId: postId, commentId: commentId)) ?? false
                        return (index, hasLiked)
                    }
                }

                for await (index, hasLiked) in group {
                    comments[index].hasLiked = hasLiked
                }
            }
        }

        return comments
    }
    
    func updateComment(_ comment: Comment) async throws {
        guard let uid = currentUid, let commentId = comment.id else {
            throw PostsError.notAuthenticated
        }
        
        guard comment.authorUid == uid else {
            throw PostsError.unauthorized
        }
        
        try await db.collection(FirestoreCollection.posts)
            .document(comment.postId)
            .collection("comments")
            .document(commentId)
            .updateData([
                "text": comment.text.trimmingCharacters(in: .whitespacesAndNewlines),
                "isEdited": true,
                "updatedAt": FieldValue.serverTimestamp()
            ])
    }
    
    func deleteComment(postId: String, commentId: String) async throws {
        guard let uid = currentUid else {
            throw PostsError.notAuthenticated
        }

        // Fetch comment to verify ownership and check depth
        let doc = try await db.collection(FirestoreCollection.posts)
            .document(postId)
            .collection("comments")
            .document(commentId)
            .getDocument()

        guard let data = doc.data(),
              let authorUid = data["authorUid"] as? String,
              authorUid == uid else {
            throw PostsError.unauthorized
        }

        let depth = data["depth"] as? Int ?? 0

        // Determine deletion strategy
        var shouldSoftDelete = false

        if depth == 0 {
            // Check if this level-0 comment has any replies
            let repliesSnapshot = try await db.collection(FirestoreCollection.posts)
                .document(postId)
                .collection("comments")
                .whereField("parentCommentId", isEqualTo: commentId)
                .limit(to: 1)
                .getDocuments()

            shouldSoftDelete = !repliesSnapshot.documents.isEmpty
        }

        if shouldSoftDelete {
            // Soft delete: mark as deleted but preserve document for threading
            try await db.collection(FirestoreCollection.posts)
                .document(postId)
                .collection("comments")
                .document(commentId)
                .updateData([
                    "isDeleted": true,
                    "updatedAt": FieldValue.serverTimestamp()
                ])

            // NOTE: commentCount should NOT decrement for soft deletes
            // The comment is still visible in the UI as a placeholder
        } else {
            // Hard delete: remove document completely
            try await db.collection(FirestoreCollection.posts)
                .document(postId)
                .collection("comments")
                .document(commentId)
                .delete()

            // NOTE: commentCount is decremented automatically by Cloud Function (onCommentWrite)
            // This ensures consistent counting and prevents race conditions
        }
    }

    // MARK: - Comment Likes

    func toggleCommentLike(postId: String, commentId: String) async throws -> Bool {
        guard let uid = currentUid else {
            throw PostsError.notAuthenticated
        }

        let likeRef = db.collection(FirestoreCollection.posts)
            .document(postId)
            .collection("comments")
            .document(commentId)
            .collection("likes")
            .document(uid)

        // Check current state
        let likeDoc = try await likeRef.getDocument()
        let wasLiked = likeDoc.exists

        if wasLiked {
            // Remove like - Cloud Function will update count asynchronously
            try await likeRef.delete()
            return false
        } else {
            // Add like - Cloud Function will update count asynchronously
            try await likeRef.setData([
                "uid": uid,
                "createdAt": FieldValue.serverTimestamp()
            ])
            return true
        }
    }

    func hasLikedComment(postId: String, commentId: String) async throws -> Bool {
        guard let uid = currentUid else { return false }

        let likeRef = db.collection(FirestoreCollection.posts)
            .document(postId)
            .collection("comments")
            .document(commentId)
            .collection("likes")
            .document(uid)

        let doc = try await likeRef.getDocument()
        return doc.exists
    }

    // MARK: - Advanced Feed Queries (Phase 4.2)

    func fetchFriendsPostsCandidates(
        authorUids: [String],
        windowStart: Date,
        limit: Int
    ) async throws -> [Post] {
        guard !authorUids.isEmpty else { return [] }

        let chunk = Array(authorUids.prefix(30))  // Firestore IN limit

        // Fetch ALL posts from following (both public and friends visibility)
        // Friends Feed = posts from people you follow, regardless of visibility
        let snapshot = try await db.collection(FirestoreCollection.posts)
            .whereField("authorUid", in: chunk)
            .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: windowStart))
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()

        let posts = snapshot.documents.compactMap { doc -> Post? in
            do {
                return try decodePost(from: doc.data(), id: doc.documentID)
            } catch {
                print("❌ [Posts] Failed to decode post \(doc.documentID): \(error)")
                return nil
            }
        }.filter { !$0.isDeleted }

        print("✅ [Posts] Friends Feed: Fetched \(snapshot.documents.count) docs, decoded \(posts.count) posts (filtered: \(posts.count))")
        return posts
    }

    func fetchRecentPublicPosts(
        windowStart: Date,
        limit: Int
    ) async throws -> [Post] {
        let snapshot = try await db.collection(FirestoreCollection.posts)
            .whereField("visibility", isEqualTo: PostVisibility.public.rawValue)
            .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: windowStart))
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? decodePost(from: doc.data(), id: doc.documentID)
        }.filter { !$0.isDeleted }
    }

    func fetchTrendingPostIds(limit: Int) async throws -> [(String, Double)] {
        let snapshot = try await db.collection("postStats")
            .order(by: "hotScore7d", descending: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            guard let hotScore = doc.data()["hotScore7d"] as? Double else { return nil }
            return (doc.documentID, hotScore)
        }
    }

    func fetchPostsByIds(_ ids: [String]) async throws -> [Post] {
        guard !ids.isEmpty else { return [] }

        var posts: [Post] = []

        // Firestore getDocuments in batch (10 at a time for efficiency)
        for chunk in ids.chunked(into: 10) {
            let docs = try await withThrowingTaskGroup(of: Post?.self) { group in
                for id in chunk {
                    group.addTask {
                        let doc = try await self.db.collection(FirestoreCollection.posts)
                            .document(id)
                            .getDocument()

                        guard doc.exists, let data = doc.data() else { return nil }
                        return try? self.decodePost(from: data, id: doc.documentID)
                    }
                }

                var results: [Post] = []
                for try await post in group {
                    if let post = post {
                        results.append(post)
                    }
                }
                return results
            }

            posts.append(contentsOf: docs)
        }

        return posts.filter { !$0.isDeleted }
    }

    func fetchNewCreatorsPosts(
        windowStart: Date,
        limit: Int
    ) async throws -> [Post] {
        // Fetch recent public posts
        let posts = try await fetchRecentPublicPosts(windowStart: windowStart, limit: limit)

        // Get unique author UIDs
        let authorUids = Array(Set(posts.map { $0.authorUid }))

        // Fetch userStats for these authors
        let userStatsMap = try await fetchUserStatsBatch(uids: authorUids)

        // Filter to only new authors
        return posts.filter { post in
            guard let stats = userStatsMap[post.authorUid] else { return false }
            return stats.isNewAuthor
        }
    }

    // MARK: - Stats (Phase 4.2)

    func fetchPostStats(postId: String) async throws -> PostStats? {
        let doc = try await db.collection("postStats")
            .document(postId)
            .getDocument()

        guard doc.exists, let data = doc.data() else { return nil }
        return try? decodePostStats(from: data, id: postId)
    }

    func fetchPostStatsBatch(postIds: [String]) async throws -> [String: PostStats] {
        guard !postIds.isEmpty else { return [:] }

        var statsMap: [String: PostStats] = [:]

        for chunk in postIds.chunked(into: 10) {
            let stats = try await withThrowingTaskGroup(of: (String, PostStats?).self) { group in
                for postId in chunk {
                    group.addTask {
                        let stats = try await self.fetchPostStats(postId: postId)
                        return (postId, stats)
                    }
                }

                var results: [(String, PostStats?)] = []
                for try await result in group {
                    results.append(result)
                }
                return results
            }

            for (postId, stat) in stats {
                if let stat = stat {
                    statsMap[postId] = stat
                }
            }
        }

        return statsMap
    }

    func fetchUserStats(uid: String) async throws -> UserStats? {
        let doc = try await db.collection("userStats")
            .document(uid)
            .getDocument()

        guard doc.exists, let data = doc.data() else {
            // Return default for new users
            return UserStats(userId: uid)
        }

        return try? decodeUserStats(from: data, id: uid)
    }

    func fetchUserStatsBatch(uids: [String]) async throws -> [String: UserStats] {
        guard !uids.isEmpty else { return [:] }

        var statsMap: [String: UserStats] = [:]

        for chunk in uids.chunked(into: 10) {
            let stats = try await withThrowingTaskGroup(of: (String, UserStats?).self) { group in
                for uid in chunk {
                    group.addTask {
                        let stats = try await self.fetchUserStats(uid: uid)
                        return (uid, stats)
                    }
                }

                var results: [(String, UserStats?)] = []
                for try await result in group {
                    results.append(result)
                }
                return results
            }

            for (uid, stat) in stats {
                if let stat = stat {
                    statsMap[uid] = stat
                }
            }
        }

        return statsMap
    }

    // MARK: - Decoding

    private func decodePost(from data: [String: Any], id: String) throws -> Post {
        guard let authorUid = data["authorUid"] as? String,
              let text = data["text"] as? String,
              let visibilityRaw = data["visibility"] as? String,
              let visibility = PostVisibility(rawValue: visibilityRaw) else {
            throw PostsError.decodingFailed
        }

        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()

        return Post(
            id: id,
            authorUid: authorUid,
            title: data["title"] as? String,
            text: text,
            photoUrls: data["photoUrls"] as? [String] ?? [],
            linkedRoundId: data["linkedRoundId"] as? String,
            visibility: visibility,
            cityId: data["cityId"] as? String,
            courseId: data["courseId"] as? String,
            tags: data["tags"] as? [String],
            isDeleted: data["isDeleted"] as? Bool ?? false,
            upvoteCount: data["upvoteCount"] as? Int ?? 0,
            commentCount: data["commentCount"] as? Int ?? 0,
            isEdited: data["isEdited"] as? Bool ?? false,
            createdAt: createdAt,
            updatedAt: updatedAt,
            authorNickname: data["authorNickname"] as? String,
            authorPhotoUrl: data["authorPhotoUrl"] as? String
        )
    }
    
    private func decodeComment(from data: [String: Any], id: String, postId: String) throws -> Comment {
        guard let authorUid = data["authorUid"] as? String,
              let text = data["text"] as? String else {
            throw PostsError.decodingFailed
        }

        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()

        return Comment(
            id: id,
            postId: postId,
            authorUid: authorUid,
            text: text,
            parentCommentId: data["parentCommentId"] as? String,
            replyToUid: data["replyToUid"] as? String,
            replyToNickname: data["replyToNickname"] as? String,
            depth: data["depth"] as? Int ?? 0,
            isEdited: data["isEdited"] as? Bool ?? false,
            isDeleted: data["isDeleted"] as? Bool,
            createdAt: createdAt,
            updatedAt: updatedAt,
            likeCount: data["likeCount"] as? Int ?? 0,
            hasLiked: nil,  // Will be enriched in fetchComments
            authorNickname: data["authorNickname"] as? String,
            authorPhotoUrl: data["authorPhotoUrl"] as? String
        )
    }

    private func decodePostStats(from data: [String: Any], id: String) throws -> PostStats {
        guard let upvoteCount = data["upvoteCount"] as? Int,
              let commentCount = data["commentCount"] as? Int else {
            throw PostsError.decodingFailed
        }

        let lastEngagementAt = (data["lastEngagementAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()

        return PostStats(
            postId: id,
            upvoteCount: upvoteCount,
            commentCount: commentCount,
            lastEngagementAt: lastEngagementAt,
            hotScore7d: data["hotScore7d"] as? Double ?? 0,
            updatedAt: updatedAt
        )
    }

    private func decodeUserStats(from data: [String: Any], id: String) throws -> UserStats {
        let accountCreatedAt = (data["accountCreatedAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()

        return UserStats(
            userId: id,
            accountCreatedAt: accountCreatedAt,
            postCount: data["postCount"] as? Int ?? 0,
            isNewAuthor: data["isNewAuthor"] as? Bool ?? true,
            updatedAt: updatedAt
        )
    }
}

// MARK: - Errors

enum PostsError: LocalizedError {
    case notAuthenticated
    case unauthorized
    case textTooLong
    case tooManyPhotos
    case commentTooLong
    case decodingFailed
    case postNotFound
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in."
        case .unauthorized:
            return "You don't have permission to do this."
        case .textTooLong:
            return "Post text is too long."
        case .tooManyPhotos:
            return "Maximum \(Post.maxPhotos) photos allowed."
        case .commentTooLong:
            return "Comment is too long."
        case .decodingFailed:
            return "Failed to load data."
        case .postNotFound:
            return "Post not found."
        }
    }
}

// MARK: - Array Chunking

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}


