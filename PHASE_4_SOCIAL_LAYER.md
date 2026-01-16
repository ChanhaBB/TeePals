# Phase 4 — Social Layer

**Goal:** Community and reputation through posts, comments, and enhanced social features with intelligent feed ranking.

**Status:** In Progress

---

## 1. Overview

Phase 4 introduces a post-based social feed where users can share golf experiences, link rounds, and engage through upvotes and comments. The Home tab becomes the primary feed surface with deterministic, tunable ranking that favors recency, ensures fairness for new posters, and provides soft personalization.

---

## 2. Posts

### 2.1 Post Content
- **Text**: Required, main body of the post
- **Photos**: Optional, up to **4 photos** per post
- **Round Link**: Optional link to any round (completed or pending)
- **No hashtags** for MVP

### 2.2 Post Actions
| Action | Who | Notes |
|--------|-----|-------|
| Create | Author | Tier 2 gated |
| Edit | Author only | Text + photos can be modified |
| Delete | Author only | Soft delete or hard delete TBD |
| Upvote | Any authenticated user | Toggle on/off |
| Comment | Any authenticated user | Tier 2 gated |

### 2.3 Post Visibility
- `public` — visible to all authenticated users
- `friends` — visible only to mutual follows (friends)

---

## 3. Comments

### 3.1 Comment Structure
Comments support **one level of nesting**:

```
Post
├── Comment A (depth: 0)
│   ├── Reply A1 (depth: 1, parentCommentId: A)
│   └── Reply A2 (depth: 1, parentCommentId: A)
├── Comment B (depth: 0)
│   └── Reply B1 (depth: 1, parentCommentId: B)
```

### 3.2 Nesting Rules
- **Depth 0**: Top-level comments on the post
- **Depth 1**: Direct replies to a top-level comment
- **Depth 2+**: NOT nested visually; instead, flat with `@mention` of the user being replied to

### 3.3 @Mentions
- When replying to a depth-1 comment, the reply is stored at depth 1 under the same parent
- `replyToUid` field captures who is being mentioned
- UI renders as: `@nickname your reply text...`

### 3.4 Comment Actions
| Action | Who | Notes |
|--------|-----|-------|
| Create | Any authenticated user | Tier 2 gated |
| Edit | Author only | — |
| Delete | Author only | — |

---

## 4. Feed System (Home Tab)

### 4.1 Feed Architecture

**Two Feed Types:**
1. **Friends Feed** (Following-only) — posts from users you follow
2. **Public Feed** (Discovery) — public posts with intelligent mixing

**Key Design Principles:**
- Deterministic, tunable ranking (no ML)
- Never show empty feed if posts exist
- Favor recency strongly
- Soft personalization (same city, course, tags)
- Fairness: new posters get exposure
- Diversity: avoid long streaks from same author
- Stability: pagination doesn't reshuffle wildly
- Firestore-friendly: bounded reads, indexed queries

**Ranking Implementation:**
- **Client-side** scoring and mixing in Swift (FeedViewModel)
- Fetch candidate buckets from Firestore
- Score, mix, and enforce diversity in app
- Cloud Functions maintain aggregate counters only

---

### 4.2 Friends Feed (Following)

**Query Strategy:**
```
1. Fetch following UIDs for viewer (up to 30 for MVP)
2. Query: posts where visibility == "friends"
   AND authorUid in [followingUids]
   AND createdAt >= now - 7 days
   ORDER BY createdAt DESC
   LIMIT 100
3. Filter out deleted posts and apply scoring
4. Enforce diversity (max 2 consecutive posts from same author)
5. Sort by score DESC, then createdAt DESC
```

**Time Windows (expand if needed):**
- Primary: Last 7 days
- Fallback 1: Last 30 days
- Fallback 2: Last 180 days

**Pagination:**
- Cursor: `{ lastCreatedAt, lastPostId }`
- Stable time-based ranking for consistency

**MVP Constraint:**
- Assume users follow <30 people (single Firestore query)
- If >30 following needed later: chunk queries or use collection group

---

### 4.3 Public Feed (Discovery)

**Bucket Strategy:**

Fetch 3 candidate buckets and interleave client-side:

1. **Recent Bucket** (60% weight)
   ```
   Query: posts where visibility == "public"
     AND createdAt >= now - 7 days
     ORDER BY createdAt DESC
     LIMIT 100
   ```

2. **Trending-Lite Bucket** (20% weight)
   ```
   Query: postStats ORDER BY hotScore7d DESC LIMIT 50
   Then: batch fetch corresponding posts by IDs
   ```

3. **New Creators Bucket** (20% weight)
   ```
   Query: posts where visibility == "public"
     AND createdAt >= now - 14 days
     ORDER BY createdAt DESC
     LIMIT 50
   Filter: keep only posts where userStats.isNewAuthor == true
   ```

**Mixing Pattern:**
- Per 10 posts: 6 recent, 2 trending, 2 new creators
- Hard injection rule: every 5 posts, inject 1 from new creators if available
- Deterministic seeding: `hash(viewerId + YYYY-MM-DD)` for stable daily ordering

**Diversity Enforcement:**
- Max 2 consecutive posts from same author
- If violation, push down and pick next best

**Pagination:**
- Opaque cursor containing:
  - `dateKey` (YYYY-MM-DD)
  - Bucket offsets (recentOffset, trendingOffset, newOffset)
  - `lastReturnedPostIds` (for dedupe)

---

### 4.4 Feed Scoring Algorithm (Client-Side)

**Implemented in Swift (`FeedRankingService.swift`)**

```swift
func computeScore(
    viewerContext: ViewerContext,
    post: Post,
    postStats: PostStats,
    authorStats: UserStats
) -> FeedScore {
    let ageHours = Date().timeIntervalSince(post.createdAt) / 3600

    // 1. Time decay (strongest signal)
    let timeScore = exp(-ageHours / config.halfLifeHours)

    // 2. Engagement boost (bounded)
    let engagement = postStats.upvoteCount + 2 * postStats.commentCount
    let engagementBoost = min(
        config.maxEngagementBoost,
        config.engagementWeight * log(1 + Double(engagement))
    )

    // 3. New author boost (fairness)
    let newAuthorBoost = authorStats.isNewAuthor ? config.newAuthorBoostValue : 0

    // 4. Geo/Course/Tag boosts (soft personalization)
    let geoBoost = post.cityId == viewerContext.cityId ? config.sameCityBoost : 0
    let courseBoost = post.courseId == viewerContext.homeCourseId ? config.sameCourseBoost : 0
    let tagBoost = config.tagBoost * tagOverlapCount(post.tags, viewerContext.interests)

    let finalScore = timeScore + engagementBoost + newAuthorBoost + geoBoost + courseBoost + tagBoost

    return FeedScore(
        total: finalScore,
        breakdown: FeedScoreBreakdown(
            time: timeScore,
            engagement: engagementBoost,
            newAuthor: newAuthorBoost,
            geo: geoBoost,
            course: courseBoost,
            tags: tagBoost
        )
    )
}
```

**Configuration Constants (`FeedRankingConfig.swift`):**
```swift
struct FeedRankingConfig {
    // Time decay
    let friendsHalfLifeHours: Double = 24.0
    let publicHalfLifeHours: Double = 18.0

    // Engagement
    let engagementWeight: Double = 0.3
    let maxEngagementBoost: Double = 2.0

    // Personalization
    let sameCityBoost: Double = 0.5
    let sameCourseBoost: Double = 0.8
    let tagBoost: Double = 0.2

    // Fairness
    let newAuthorBoostValue: Double = 1.0
    let newAuthorDaysThreshold: Int = 30
    let newAuthorPostCountThreshold: Int = 5

    // Diversity
    let maxConsecutiveSameAuthor: Int = 2

    // Bucket mixing (Public Feed)
    let recentBucketWeight: Double = 0.6
    let trendingBucketWeight: Double = 0.2
    let newCreatorsBucketWeight: Double = 0.2
    let injectionIntervalK: Int = 5

    // Query limits
    let bucketFetchLimit: Int = 100
    let feedPageSize: Int = 20

    // Time windows
    let primaryWindowDays: Int = 7
    let fallbackWindow1Days: Int = 30
    let fallbackWindow2Days: Int = 180

    // Debug
    let enableScoreExplanations: Bool = false  // Dev builds only
}
```

---

### 4.5 Deduplication & Seen Control

**MVP Approach (No Firestore Writes):**
- In-memory deduplication per session
- Store `seenPostIds: Set<String>` in ViewModel
- Filter seen posts before displaying
- Reset on app restart or after 24 hours

**Future Enhancement (if needed):**
- Add `impressions/{userId}/posts/{postId}` collection
- Write impressions when posts displayed
- Query to filter seen posts within last 24-48 hours

---

### 4.6 Feed Toggle & Refresh

**Toggle Options:**
- **Friends Only**: Show Friends Feed algorithm
- **All Posts**: Show Public Feed algorithm (includes discovery)

**Pull-to-Refresh:**
- Refetch top buckets
- Preserve seen IDs to filter duplicates
- Scroll to top

**Pagination:**
- Load more button or infinite scroll
- Use cursor-based pagination per feed type
- Maintain stable ordering

---

## 5. Profile Posts Tab

### 5.1 Location
- New tab/section on user's profile: **Posts**
- Shows all posts authored by that user

### 5.2 Visibility Rules
- If viewing your own profile: see all your posts
- If viewing another user's profile:
  - See their `public` posts
  - See their `friends` posts only if you are mutual follows

---

## 6. Followers / Following Enhancements

### 6.1 Viewable Lists
- Followers list accessible from profile
- Following list accessible from profile

### 6.2 Friends First
- **Friends (mutual follows)** shown at the top of both lists
- Visual indicator (badge/icon) showing mutual follow status

### 6.3 Search
- Search bar to filter followers/following by nickname

---

## 7. Firestore Schema

### 7.1 Posts Collection
`posts/{postId}`

```json
{
  "authorUid": "uid",
  "text": "Great round today at Pebble Beach!",
  "photoUrls": ["url1", "url2", "url3", "url4"],
  "linkedRoundId": "roundId | null",
  "visibility": "public | friends",
  "cityId": "san_jose_ca",
  "courseId": "pebble_beach_golf_links",
  "tags": ["birdie", "bestRound"],
  "upvoteCount": 0,
  "commentCount": 0,
  "isEdited": false,
  "isDeleted": false,
  "createdAt": "<timestamp>",
  "updatedAt": "<timestamp>"
}
```

**Notes:**
- `photoUrls`: Array of up to 4 Firebase Storage URLs
- `linkedRoundId`: Optional reference to a round document
- `cityId`: Normalized city key (e.g., "san_jose_ca") for geo personalization
- `courseId`: Normalized course identifier for course personalization
- `tags`: Optional array of string tags (e.g., ["birdie", "eagle", "firstTime"])
- `upvoteCount` / `commentCount`: Denormalized, maintained by Cloud Functions
- `isDeleted`: Soft delete flag

### 7.1.1 Post Stats Collection
`postStats/{postId}`

**Purpose:** Aggregate statistics for ranking, maintained by Cloud Functions

```json
{
  "postId": "postId",
  "upvoteCount": 12,
  "commentCount": 5,
  "lastEngagementAt": "<timestamp>",
  "hotScore7d": 3.45,
  "updatedAt": "<timestamp>"
}
```

**Notes:**
- `hotScore7d`: Precomputed trending score (updated every 15 min or on engagement)
- Formula: `log(1 + upvoteCount + 2*commentCount) + recencyBoost`
- Used for Trending Bucket queries

### 7.1.2 User Stats Collection
`userStats/{userId}`

**Purpose:** Author metadata for new creator detection

```json
{
  "userId": "uid",
  "accountCreatedAt": "<timestamp>",
  "postCount": 8,
  "isNewAuthor": true,
  "updatedAt": "<timestamp>"
}
```

**Notes:**
- `isNewAuthor`: `true` if `accountCreatedAt < 30 days` OR `postCount < 5`
- Updated by Cloud Function on post creation
- Indexed for New Creators Bucket filtering

### 7.2 Post Upvotes (Subcollection)
`posts/{postId}/upvotes/{uid}`

```json
{
  "uid": "uid",
  "createdAt": "<timestamp>"
}
```

**Notes:**
- Document ID = user's UID (ensures one upvote per user)
- To toggle off, delete the document

### 7.3 Comments Collection
`posts/{postId}/comments/{commentId}`

```json
{
  "authorUid": "uid",
  "text": "Nice shot!",
  "parentCommentId": "commentId | null",
  "replyToUid": "uid | null",
  "depth": 0,
  "isEdited": false,
  "createdAt": "<timestamp>",
  "updatedAt": "<timestamp>"
}
```

**Notes:**
- `parentCommentId`: `null` for top-level, comment ID for replies
- `replyToUid`: UID of user being @mentioned (for flat replies)
- `depth`: 0 = top-level, 1 = nested reply (max depth)

---

## 8. Firestore Security Rules

```javascript
// Posts
match /posts/{postId} {
  allow read: if request.auth != null && (
    resource.data.visibility == 'public' ||
    resource.data.authorUid == request.auth.uid ||
    isFriend(resource.data.authorUid)
  );
  allow create: if request.auth != null
    && request.resource.data.authorUid == request.auth.uid
    && isTier2Complete();
  allow update: if request.auth != null
    && resource.data.authorUid == request.auth.uid;
  allow delete: if request.auth != null
    && resource.data.authorUid == request.auth.uid;

  // Upvotes subcollection
  match /upvotes/{uid} {
    allow read: if request.auth != null;
    allow create, delete: if request.auth != null && request.auth.uid == uid;
  }

  // Comments subcollection
  match /comments/{commentId} {
    allow read: if request.auth != null;
    allow create: if request.auth != null
      && request.resource.data.authorUid == request.auth.uid
      && isTier2Complete();
    allow update, delete: if request.auth != null
      && resource.data.authorUid == request.auth.uid;
  }
}

// Post Stats (read-only for clients, Cloud Functions write)
match /postStats/{postId} {
  allow read: if request.auth != null;
  allow write: if false;  // Cloud Functions only
}

// User Stats (read-only for clients, Cloud Functions write)
match /userStats/{userId} {
  allow read: if request.auth != null;
  allow write: if false;  // Cloud Functions only
}
```

---

## 9. Cloud Functions (Counter Maintenance)

**Purpose:** Maintain aggregate statistics efficiently without client-side counting

### 9.1 onUpvoteWrite
```typescript
// Trigger on posts/{postId}/upvotes/{uid} create/delete
export const onUpvoteWrite = functions.firestore
  .document('posts/{postId}/upvotes/{uid}')
  .onWrite(async (change, context) => {
    const postId = context.params.postId;
    const postRef = admin.firestore().collection('posts').doc(postId);
    const statsRef = admin.firestore().collection('postStats').doc(postId);

    const increment = change.after.exists && !change.before.exists ? 1 : -1;

    await admin.firestore().runTransaction(async (t) => {
      t.update(postRef, { upvoteCount: FieldValue.increment(increment) });
      t.set(statsRef, {
        upvoteCount: FieldValue.increment(increment),
        lastEngagementAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp()
      }, { merge: true });
    });
  });
```

### 9.2 onCommentWrite
```typescript
// Trigger on posts/{postId}/comments/{commentId} create/delete
export const onCommentWrite = functions.firestore
  .document('posts/{postId}/comments/{commentId}')
  .onWrite(async (change, context) => {
    const postId = context.params.postId;
    const postRef = admin.firestore().collection('posts').doc(postId);
    const statsRef = admin.firestore().collection('postStats').doc(postId);

    const increment = change.after.exists && !change.before.exists ? 1 : -1;

    await admin.firestore().runTransaction(async (t) => {
      t.update(postRef, { commentCount: FieldValue.increment(increment) });
      t.set(statsRef, {
        commentCount: FieldValue.increment(increment),
        lastEngagementAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp()
      }, { merge: true });
    });
  });
```

### 9.3 onPostCreate
```typescript
// Trigger on posts/{postId} create
export const onPostCreate = functions.firestore
  .document('posts/{postId}')
  .onCreate(async (snap, context) => {
    const post = snap.data();
    const authorId = post.authorUid;

    // Update userStats
    const statsRef = admin.firestore().collection('userStats').doc(authorId);
    await statsRef.set({
      userId: authorId,
      postCount: FieldValue.increment(1),
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });

    // Recompute isNewAuthor
    const statsSnap = await statsRef.get();
    const stats = statsSnap.data();
    if (stats) {
      const accountAge = Date.now() - stats.accountCreatedAt.toMillis();
      const isNew = accountAge < 30 * 24 * 60 * 60 * 1000 || stats.postCount < 5;
      await statsRef.update({ isNewAuthor: isNew });
    }

    // Initialize postStats
    await admin.firestore().collection('postStats').doc(context.params.postId).set({
      postId: context.params.postId,
      upvoteCount: 0,
      commentCount: 0,
      lastEngagementAt: post.createdAt,
      hotScore7d: 0,
      updatedAt: FieldValue.serverTimestamp()
    });
  });
```

### 9.4 computeHotScores (Scheduled)
```typescript
// Run every 15 minutes
export const computeHotScores = functions.pubsub
  .schedule('every 15 minutes')
  .onRun(async (context) => {
    const cutoff = Date.now() - 7 * 24 * 60 * 60 * 1000; // 7 days
    const statsSnapshot = await admin.firestore()
      .collection('postStats')
      .where('lastEngagementAt', '>', new Date(cutoff))
      .get();

    const batch = admin.firestore().batch();
    let count = 0;

    statsSnapshot.docs.forEach(doc => {
      const stats = doc.data();
      const ageHours = (Date.now() - stats.lastEngagementAt.toMillis()) / (1000 * 60 * 60);
      const recencyBoost = Math.max(0, 5 - ageHours / 24); // Decay over days
      const engagementScore = Math.log(1 + stats.upvoteCount + 2 * stats.commentCount);
      const hotScore = engagementScore + recencyBoost;

      batch.update(doc.ref, { hotScore7d: hotScore });
      count++;

      if (count >= 500) {
        // Firestore batch limit
        return;
      }
    });

    await batch.commit();
  });
```

**Notes:**
- All functions are idempotent for retry safety
- Use transactions for consistency
- Batch operations where possible
- Monitor costs via Firebase console

---

## 10. Firestore Composite Indexes

**Required for efficient queries:**

```json
{
  "indexes": [
    {
      "collectionGroup": "posts",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "visibility", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "posts",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "visibility", "order": "ASCENDING" },
        { "fieldPath": "authorUid", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "postStats",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "hotScore7d", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "postStats",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "lastEngagementAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "userStats",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "isNewAuthor", "order": "ASCENDING" },
        { "fieldPath": "postCount", "order": "ASCENDING" }
      ]
    }
  ]
}
```

**Add to `firestore.indexes.json` and deploy:**
```bash
firebase deploy --only firestore:indexes
```

---

## 11. Implementation Plan

### Phase 4.1: Core Posts & Basic Feed (Week 1)

**Day 1: Data Layer**
- [ ] Create `Post`, `PostStats`, `UserStats` models
- [ ] Create `Comment` model
- [ ] Update `PostsRepository` protocol (add stats methods)
- [ ] Update `FirestorePostsRepository` implementation
- [ ] Update Firestore security rules
- [ ] Add Firebase Storage rules for post photos

**Day 2: Create Post Flow**
- [ ] Create `CreatePostView` (text input + photo picker)
- [ ] Create `CreatePostViewModel`
- [ ] Implement photo upload to Firebase Storage
- [ ] Implement round linking UI (recent rounds picker)
- [ ] Add cityId/courseId/tags extraction
- [ ] Wire up post creation

**Day 3: Cloud Functions Setup**
- [ ] Initialize Firebase Functions project
- [ ] Implement `onUpvoteWrite` trigger
- [ ] Implement `onCommentWrite` trigger
- [ ] Implement `onPostCreate` trigger
- [ ] Deploy functions
- [ ] Test counter updates

**Day 4: Feed Ranking Infrastructure**
- [ ] Create `FeedRankingConfig.swift` with all constants
- [ ] Create `FeedScore` model (total + breakdown)
- [ ] Create `ViewerContext` model (cityId, courseId, interests)
- [ ] Create `FeedRankingService.swift` with scoring algorithm
- [ ] Unit tests for scoring function
- [ ] Unit tests for diversity enforcement

**Day 5: Basic Feed View**
- [ ] Create `FeedView` (replaces current Home placeholder)
- [ ] Create `FeedViewModel` (basic chronological first)
- [ ] Implement `PostCardView` component
- [ ] Add pull-to-refresh
- [ ] Handle loading/empty/error states
- [ ] Add friends-only toggle (basic filter)

**Day 6: Post Detail & Interactions**
- [ ] Create `PostDetailView`
- [ ] Create `PostDetailViewModel`
- [ ] Implement upvote toggle (write to subcollection)
- [ ] Implement edit post flow
- [ ] Implement delete post flow (soft delete)
- [ ] Show linked round preview

**Day 7: Comments**
- [ ] Create `CommentsView` (list + composer)
- [ ] Create `CommentsViewModel`
- [ ] Implement nested comment rendering (depth 0 + 1)
- [ ] Implement @mention for flat replies
- [ ] Implement edit/delete comment

---

### Phase 4.2: Advanced Feed Ranking (Week 2)

**Day 8: Friends Feed Algorithm**
- [ ] Implement Friends Feed query in `FeedViewModel`
- [ ] Fetch following UIDs (up to 30)
- [ ] Query posts with authorUid IN filter
- [ ] Apply scoring algorithm
- [ ] Enforce diversity (max 2 consecutive same author)
- [ ] Implement cursor-based pagination
- [ ] Test with multiple time windows (7d → 30d → 180d)

**Day 9: Public Feed - Bucket Infrastructure**
- [ ] Implement Recent Bucket fetching
- [ ] Implement Trending Bucket fetching (via postStats.hotScore7d)
- [ ] Implement New Creators Bucket fetching (filter by userStats.isNewAuthor)
- [ ] Add batch fetch for postStats → posts mapping
- [ ] Unit tests for bucket queries

**Day 10: Public Feed - Mixing & Interleaving**
- [ ] Implement deterministic seeding (hash viewerId + date)
- [ ] Implement bucket interleaving (6:2:2 ratio)
- [ ] Implement hard injection rule (every 5 posts)
- [ ] Apply diversity enforcement across mixed feed
- [ ] Implement Public Feed pagination with opaque cursor

**Day 11: Hot Score Computation**
- [ ] Implement `computeHotScores` scheduled Cloud Function
- [ ] Test locally with Firebase Emulator
- [ ] Deploy to production
- [ ] Schedule every 15 minutes
- [ ] Monitor execution logs

**Day 12: Personalization Enhancements**
- [ ] Extract ViewerContext from user profile (cityId, homeCourseId)
- [ ] Add geo/course/tag boost calculation
- [ ] Test personalization scoring
- [ ] Add debug mode for score explanations (dev builds only)

**Day 13: Profile & Social Lists**
- [ ] Add Posts tab to profile
- [ ] Create `UserPostsView`
- [ ] Enhance `FollowersListView` with search
- [ ] Enhance `FollowingListView` with search
- [ ] Sort friends to top in both lists
- [ ] Add mutual follow indicator

**Day 14: Polish & Testing**
- [ ] Edge cases (deleted posts, blocked users, empty following)
- [ ] Loading states for all feed views
- [ ] Error handling and retry logic
- [ ] UI polish per `UI_RULES.md`
- [ ] End-to-end testing of both feed types
- [ ] Performance testing with large datasets
- [ ] Cost analysis (Firestore reads)

---

## 12. Components to Create

### Swift Models
| Component | Purpose |
|-----------|---------|
| `Post` | Post document model (with cityId, courseId, tags) |
| `PostStats` | Post stats model (upvotes, comments, hotScore) |
| `UserStats` | User stats model (postCount, isNewAuthor) |
| `Comment` | Comment model (with nesting support) |
| `FeedScore` | Scoring result (total + breakdown) |
| `FeedScoreBreakdown` | Debug breakdown of score components |
| `ViewerContext` | Viewer preferences (cityId, courseId, interests) |
| `FeedCursor` | Pagination cursor (Friends or Public) |
| `FeedBucket` | Bucket metadata (type, offset) |

### Views
| Component | Purpose |
|-----------|---------|
| `FeedView` | Home tab feed (toggle Friends/Public) |
| `PostCardView` | Single post in feed |
| `CreatePostView` | Post creation flow |
| `PostDetailView` | Full post with comments |
| `CommentsView` | Comment list + composer |
| `CommentRowView` | Single comment (supports nesting) |
| `UserPostsView` | Posts tab on profile |
| `RoundLinkPickerSheet` | Select round to link |
| `FollowersListView` | Enhanced with search |
| `FollowingListView` | Enhanced with search |

### ViewModels
| Component | Purpose |
|-----------|---------|
| `FeedViewModel` | Feed state + fetching + ranking |
| `CreatePostViewModel` | Post creation logic |
| `PostDetailViewModel` | Post detail + interactions |
| `CommentsViewModel` | Comments state + CRUD |
| `UserPostsViewModel` | Profile posts fetching |

### Services
| Component | Purpose |
|-----------|---------|
| `FeedRankingService` | Client-side scoring + mixing + diversity |
| `FeedRankingConfig` | Configuration constants (tunable) |

### Repositories
| Component | Purpose |
|-----------|---------|
| `PostsRepository` | Protocol for posts CRUD + stats |
| `FirestorePostsRepository` | Firestore implementation |

### Cloud Functions (TypeScript)
| Component | Purpose |
|-----------|---------|
| `onUpvoteWrite` | Maintain upvote counts + lastEngagementAt |
| `onCommentWrite` | Maintain comment counts + lastEngagementAt |
| `onPostCreate` | Initialize postStats, update userStats |
| `computeHotScores` | Scheduled: recompute hotScore7d for trending |

---

## 13. Open Questions & Decisions

1. **Feed algorithm**: ~~Pure chronological~~ → **Deterministic ranking with scoring** ✅
2. **Photo compression**: Resize before upload? → **Yes, max 1080px** ✅
3. **Delete behavior**: Soft delete (mark deleted) or hard delete? → **Soft delete (isDeleted flag)** ✅
4. **Report post**: Add report functionality? → Defer to Phase 6
5. **Notifications**: Post likes/comments trigger notifications? → Yes, handled in Phase 5
6. **Impressions tracking**: Firestore writes? → **No, in-memory deduplication for MVP** ✅
7. **Following limit**: Support >30 following? → **MVP: assume <30, add chunking later** ✅
8. **Trending bucket**: Scheduled function frequency? → **Every 15 minutes** ✅

---

## 14. Dependencies

- Phase 1 (Identity): User profiles, Tier 2 gating
- Phase 2 (Rounds): Round linking requires round data, cityId from rounds
- Phase 3 (Chat): N/A (independent)
- Firebase Storage: Photo uploads
- **Firebase Cloud Functions**: Counter maintenance + hotScore computation (NEW)

---

## 15. Success Criteria

**Core Features:**
- [ ] Users can create posts with text + up to 4 photos
- [ ] Users can link posts to rounds (extracts cityId/courseId)
- [ ] Users can upvote posts (toggle)
- [ ] Users can comment with 1-level nesting
- [ ] All actions respect Tier 2 gating
- [ ] No Firebase imports in Views

**Friends Feed:**
- [ ] Friends Feed shows posts from followed users only
- [ ] Time-based ranking with scoring algorithm
- [ ] Diversity enforcement (max 2 consecutive same author)
- [ ] Cursor-based pagination works stably
- [ ] Expands time window if <7d posts insufficient

**Public Feed:**
- [ ] Public Feed fetches 3 buckets (Recent, Trending, New Creators)
- [ ] Deterministic mixing with 6:2:2 ratio
- [ ] Hard injection rule enforced (every 5 posts)
- [ ] New creators get exposure via dedicated bucket
- [ ] Trending based on hotScore7d from Cloud Function

**Feed System:**
- [ ] Toggle between Friends/Public feeds works correctly
- [ ] Pull-to-refresh refetches top candidates
- [ ] Score explanations available in debug mode
- [ ] Seen posts deduplicated (in-memory)
- [ ] Empty state never shown if posts exist

**Cloud Functions:**
- [ ] onUpvoteWrite maintains counts correctly
- [ ] onCommentWrite maintains counts correctly
- [ ] onPostCreate initializes stats + updates userStats
- [ ] computeHotScores runs every 15 min
- [ ] All functions are idempotent

**Performance:**
- [ ] Friends Feed: <100 reads per load
- [ ] Public Feed: <200 reads per load (3 buckets)
- [ ] Pagination doesn't refetch entire dataset
- [ ] Firestore indexes deployed and working

**Profile & Social:**
- [ ] Profile shows user's posts
- [ ] Followers/Following lists are searchable with friends at top

---

## 16. Configuration Tuning Guide

All ranking constants live in `FeedRankingConfig.swift` and can be tuned via:

**Time Decay:**
- `friendsHalfLifeHours`: How fast friends posts decay (default: 24h)
- `publicHalfLifeHours`: How fast public posts decay (default: 18h)

**Engagement:**
- `engagementWeight`: Multiplier for engagement boost (default: 0.3)
- `maxEngagementBoost`: Cap to prevent viral dominance (default: 2.0)

**Personalization:**
- `sameCityBoost`: Boost for same city (default: 0.5)
- `sameCourseBoost`: Boost for same course (default: 0.8)
- `tagBoost`: Boost per tag overlap (default: 0.2)

**Fairness:**
- `newAuthorBoostValue`: Fixed boost for new creators (default: 1.0)
- `newAuthorDaysThreshold`: Days to qualify as new (default: 30)
- `newAuthorPostCountThreshold`: Post count to qualify as new (default: 5)

**Diversity:**
- `maxConsecutiveSameAuthor`: Prevent streaks (default: 2)

**Bucket Mixing:**
- `recentBucketWeight`: Weight for recent posts (default: 0.6)
- `trendingBucketWeight`: Weight for trending (default: 0.2)
- `newCreatorsBucketWeight`: Weight for new creators (default: 0.2)
- `injectionIntervalK`: Force inject every K posts (default: 5)

**Query Limits:**
- `bucketFetchLimit`: Posts per bucket (default: 100)
- `feedPageSize`: Posts per page (default: 20)
- `primaryWindowDays`: Primary time window (default: 7)

---

This document is the source of truth for Phase 4 implementation.



