# Post-Round Player Ratings

## Overview

After a round is marked as completed by the host, participants can rate each other to build trust and encourage positive behavior in the TeePals community.

## Goals

1. **Trust & Safety**: Help users identify reliable, friendly playing partners
2. **Quality Signal**: Surface high-quality community members
3. **Accountability**: Discourage no-shows, toxicity, and dishonesty
4. **Community Building**: Reinforce positive norms and behavior

## Core Flow

```
Host marks round as "Completed"
    ↓
All participants receive notification
    ↓
Rating prompt appears in app
    ↓
User rates other participants (1-5 stars)
    ↓
Ratings aggregate on profiles (after minimum threshold)
```

## Design Principles (Anti-Toxicity)

### 1. **Mutual Blindness**
- Ratings are submitted blindly (you can't see others' ratings of you until you submit yours)
- No one can see who rated them what (only aggregated average)
- Prevents retaliation: "You gave me 3 stars so I'll give you 1 star"

### 2. **Time Window**
- 7-day window after round completion to submit ratings
- Reduces pressure to rate immediately on-site
- Allows reflection time

### 3. **Minimum Threshold**
- Profile rating only visible after 5+ completed rounds
- Prevents single bad rating from defining someone
- New users start with clean slate

### 4. **Optional, Not Required**
- Rating is encouraged but not mandatory
- No penalties for not rating
- Reduces "rage rating" from feeling forced

### 5. **No Public Individual Ratings**
- Only show aggregated average (e.g., 4.7 ⭐️ from 23 rounds)
- Never show "John gave you 2 stars"
- Reduces personal conflicts

### 6. **Recency Weighting**
- Recent ratings (last 6 months) weighted more heavily
- People can improve over time
- Doesn't penalize forever for past mistakes

## Data Model

### Round Status

Add `status` field to `Round` model:

```swift
enum RoundStatus: String, Codable {
    case open          // Accepting join requests
    case confirmed     // Round is happening (has accepted members)
    case inProgress    // Round has started (optional, set by host)
    case completed     // Round finished, ratings can be submitted
    case cancelled     // Round was cancelled
}
```

### Rating Document

**Collection**: `rounds/{roundId}/ratings/{raterUid}`

```swift
struct RoundRating: Codable, Identifiable {
    var id: String?              // raterUid
    let raterUid: String         // Who is rating
    let targetUid: String        // Who is being rated
    let stars: Int               // 1-5
    let timestamp: Date
    let roundId: String          // For reference
}
```

**Security Rules**:
```javascript
// Only participants can rate
// Can only rate after round is completed
// Can't rate yourself
// Can only rate once per person per round
match /rounds/{roundId}/ratings/{raterUid} {
  allow read: if request.auth != null;
  allow create: if request.auth.uid == raterUid
    && exists(/databases/$(database)/documents/rounds/$(roundId)/members/$(raterUid))
    && get(/databases/$(database)/documents/rounds/$(roundId)).data.status == 'completed'
    && request.resource.data.targetUid != request.auth.uid
    && request.resource.data.stars >= 1
    && request.resource.data.stars <= 5;
}
```

### Profile Aggregation

Add to `PublicProfile`:

```swift
// New fields
var avgRating: Double?           // Average rating (1.0-5.0)
var totalRatingsReceived: Int    // Number of ratings received
var completedRoundsCount: Int    // Total completed rounds as participant

// Only show rating if totalRatingsReceived >= 5
var displayRating: Double? {
    guard let avg = avgRating, totalRatingsReceived >= 5 else {
        return nil
    }
    return avg
}
```

### Pending Ratings Tracking

**Collection**: `pendingRatings/{uid}/items/{roundId}`

Track which rounds a user still needs to rate:

```swift
struct PendingRating: Codable, Identifiable {
    var id: String?              // roundId
    let roundId: String
    let completedAt: Date        // When round was marked complete
    let expiresAt: Date          // 7 days after completion
    let participantUids: [String] // Who to rate (excluding self)
}
```

## UI/UX Flow

### 1. Host Marks Round Complete

**RoundDetailView** (Host only):
- Show "Mark as Completed" button after round start time has passed
- Confirmation dialog: "Mark this round as completed? All participants will be able to rate each other."
- Updates `round.status = .completed`
- Creates `pendingRatings` docs for all participants

### 2. Rating Notification

**In-app notification**:
```
"⛳️ Rate your round at [Course Name]"
"How was your experience playing with [Names]?"
```

### 3. Rating Screen

**New view: `RateParticipantsView`**

```
┌─────────────────────────────────┐
│  Rate Your Playing Partners     │
├─────────────────────────────────┤
│                                 │
│  [Photo] John Doe               │
│  ⭐️ ⭐️ ⭐️ ⭐️ ⭐️                  │
│                                 │
│  [Photo] Jane Smith             │
│  ⭐️ ⭐️ ⭐️ ⭐️ ⭐️                  │
│                                 │
│  [Photo] Bob Wilson             │
│  ⭐️ ⭐️ ⭐️ ⭐️ ⭐️                  │
│                                 │
│  [Skip for Now]  [Submit]       │
└─────────────────────────────────┘
```

- Simple, fast interface
- No text review (reduces toxicity)
- Can partially rate (submit some, not all)
- Can skip entirely

### 4. Profile Display

**ProfileView / OtherUserProfileView**:

```
┌─────────────────────────────────┐
│  John Doe                       │
│  4.8 ⭐️ (23 rounds)             │
│  San Jose, CA                   │
└─────────────────────────────────┘
```

- Only show if `totalRatingsReceived >= 5`
- Show count to indicate volume
- Subtle, not prominent

## Implementation Phases

### Phase 1: Data Layer (Week 1)
- [ ] Add `status` field to `Round` model
- [ ] Create `RoundRating` model
- [ ] Create `PendingRating` model
- [ ] Update `PublicProfile` with rating fields
- [ ] Add Firestore security rules
- [ ] Create `RatingsRepository` protocol
- [ ] Implement `FirestoreRatingsRepository`

### Phase 2: Host Completion (Week 1)
- [ ] Add "Mark as Completed" button to RoundDetailView
- [ ] Update round status in backend
- [ ] Create pending rating docs for all participants
- [ ] Send notifications to participants

### Phase 3: Rating UI (Week 2)
- [ ] Create `RateParticipantsView`
- [ ] Create `RateParticipantsViewModel`
- [ ] Add navigation from notifications
- [ ] Implement star rating component
- [ ] Submit ratings to backend

### Phase 4: Aggregation & Display (Week 2)
- [ ] Cloud Function to aggregate ratings on profile
- [ ] Update profile fetching to include ratings
- [ ] Display ratings on ProfileView
- [ ] Display ratings on OtherUserProfileView
- [ ] Display ratings on round cards (host's rating)

### Phase 5: Edge Cases & Polish (Week 3)
- [ ] Handle rating expiration (7 days)
- [ ] Handle round cancellation (delete pending ratings)
- [ ] Handle member removal (don't let them rate)
- [ ] Add "Pending Ratings" section to Profile tab
- [ ] Analytics & monitoring

## Cloud Functions

### `aggregateRatingsOnProfile`
**Trigger**: onCreate on `rounds/{roundId}/ratings/{raterUid}`

```typescript
// When a rating is submitted:
1. Fetch all ratings for targetUid across all rounds
2. Calculate average (with recency weighting)
3. Update profiles_public/{targetUid} with avgRating and count
4. Update completedRoundsCount if needed
```

### `createPendingRatings`
**Trigger**: onUpdate on `rounds/{roundId}` when status → completed

```typescript
// When round is marked complete:
1. Fetch all accepted members
2. For each member:
   - Create pendingRatings/{uid}/items/{roundId}
   - List all other members as targets
   - Set expiresAt = 7 days from now
3. Send notification to each member
```

### `cleanupExpiredPendingRatings`
**Trigger**: Scheduled daily at midnight

```typescript
// Clean up expired pending ratings
1. Query pendingRatings where expiresAt < now
2. Delete expired documents
3. Log metrics
```

## Security & Abuse Prevention

### Spam Protection
- Rate limit: Max 10 ratings per user per day
- Can't rate same person twice in same round

### Malicious Ratings
- Investigate users with consistently low ratings (< 2.0)
- Allow appeals through support system
- Admin dashboard to view rating patterns

### Gaming Prevention
- No way to see individual ratings (only aggregate)
- Minimum 5 ratings before display (can't be gamed by single person)
- Recency weighting prevents holding grudges

## Open Questions

1. **Should hosts be rateable?**
   - Pro: Hosts can be flaky too (cancel last minute, no-show)
   - Con: Might discourage hosting if fear of bad ratings
   - **Recommendation**: Yes, but show "Host Rating" separately from "Player Rating"

2. **Should rating affect round matching/discovery?**
   - Could filter rounds by host rating (4.5+ only)
   - Could boost high-rated users in search
   - **Recommendation**: Phase 2 feature, not initial launch

3. **What happens to ratings when someone is blocked?**
   - **Recommendation**: Keep ratings (they happened), but hide from both parties

4. **Allow rating removal after block?**
   - **Recommendation**: No, ratings are immutable (prevents gaming)

5. **Show rating trend (improving/declining)?**
   - Could show arrow: 4.3 ⭐️ ↗️
   - **Recommendation**: Nice-to-have for Phase 2

## Success Metrics

1. **Adoption**: % of completed rounds that receive ratings
   - Target: 60%+ rating submission rate
2. **Distribution**: Histogram of ratings (should be skewed positive)
   - Target: Average rating 4.2-4.5 (healthy, not inflated)
3. **Abuse**: % of ratings flagged/removed
   - Target: < 1% malicious ratings
4. **Trust**: Survey participants on feeling safer with ratings
   - Target: 70%+ feel ratings help them choose rounds

## Alternative Approaches Considered

### 1. Binary Thumbs Up/Down
- **Pro**: Simpler, less pressure
- **Con**: Less nuanced, "down" feels harsh
- **Verdict**: Stars are industry standard, more gradual

### 2. Category Ratings
- Rate punctuality, friendliness, skill honesty separately
- **Pro**: More detailed feedback
- **Con**: Too complex, takes too long
- **Verdict**: Start simple with overall rating

### 3. Text Reviews
- Allow written comments
- **Pro**: More context
- **Con**: Much higher toxicity risk, moderation burden
- **Verdict**: No text reviews (at least initially)

### 4. Mandatory Ratings
- Force users to rate before joining new rounds
- **Pro**: Higher submission rate
- **Con**: Coercion leads to "rage ratings"
- **Verdict**: Keep optional

## Recommendation

✅ **Build this feature** - It aligns well with TeePals' trust-first philosophy and will improve community quality.

**Timing**: Implement after core features are stable (Phase 5 or 6), not MVP. Need enough active rounds for ratings to be meaningful.

**Start Conservative**: Launch with most restrictive anti-toxicity measures, can relax later if needed.

**Key Success Factor**: Clear communication to users about why ratings exist (trust & safety) and how they work (blind, aggregated, optional).
