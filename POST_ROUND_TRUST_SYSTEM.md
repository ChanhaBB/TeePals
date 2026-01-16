# Post-Round Trust System (Badges & Tiers)

## Overview

After a round completes, participants provide structured feedback that builds trust profiles through badges and tiers - NOT star ratings. This positive, progressive system celebrates good behavior rather than punishing bad.

## Why Not Star Ratings?

**Problems with star ratings:**
- Rating inflation (everyone expects 5 stars, 4.2 feels like failure)
- Retaliation ("you gave me 3, I'll give you 2")
- Ambiguous meaning (what does 3 stars mean?)
- Negative focus (fear bad ratings vs. earn good standing)
- Single bad round tanks your average

**Our approach: Trust Badges & Tiers**
- Positive framing ("earned Reliable badge!")
- Clear behavioral expectations
- Gamification in positive direction (collect vs. fear)
- Resilient to single bad experience (patterns matter)
- Progressive system shows growth journey

## Core Concept: Trust Passport

Every user has a **Trust Passport** with:
1. **Trust Tier** (Bronze → Silver → Gold → Verified)
2. **Trust Badges** (Punctual, Friendly, Honest Skill, Good Sport)
3. **Completed Rounds** (total count)
4. **Member Since** (tenure signal)

Think: Airbnb Superhost, LinkedIn endorsements, Stack Overflow reputation.

---

## Trust Tiers

### Bronze (Default)
- **Requirements**: New user, 0-2 completed rounds
- **Badge**: 🥉 Bronze Member
- **Benefits**: Can join rounds, normal visibility

### Silver (Established)
- **Requirements**: 3+ completed rounds, 80%+ positive feedback
- **Badge**: 🥈 Silver Member
- **Benefits**:
  - Profile boosted in round discovery
  - Can create rounds without waitlist

### Gold (Trusted)
- **Requirements**: 10+ completed rounds, 90%+ positive feedback, 6+ months active
- **Badge**: 🥇 Gold Member
- **Benefits**:
  - Priority consideration for join requests
  - Can host private rounds
  - Gold badge on profile/cards

### Verified (Elite)
- **Requirements**: 25+ completed rounds, 95%+ positive feedback, 1+ year active, no violations
- **Badge**: ✅ Verified Member
- **Benefits**:
  - Highest trust signal
  - Featured in search
  - Can host premium rounds
  - Access to exclusive features

---

## Trust Badges

Earned through consistent positive feedback:

### 🎯 Punctual
- **Meaning**: Shows up on time, rarely cancels
- **Criteria**: 90%+ "on time" feedback across 5+ rounds
- **Display**: "Punctual" badge on profile

### 😊 Friendly
- **Meaning**: Pleasant to play with, good conversation
- **Criteria**: 90%+ "friendly" feedback across 5+ rounds
- **Display**: "Friendly" badge on profile

### ⛳️ Honest Skill
- **Meaning**: Skill level matches profile (no sandbagging)
- **Criteria**: 90%+ "honest skill" feedback across 5+ rounds
- **Display**: "Honest Skill" badge on profile

### 🏆 Good Sport
- **Meaning**: Positive attitude, handles wins/losses well
- **Criteria**: 90%+ "good sport" feedback across 5+ rounds
- **Display**: "Good Sport" badge on profile

**Badge Loss**: If feedback drops below 80% in any category over rolling 10-round window, badge is removed. Can be re-earned.

---

## Post-Round Feedback Form

**Simple, structured questions** (not free-form ratings):

```
┌─────────────────────────────────────────┐
│  How was your round at Pebble Beach?   │
├─────────────────────────────────────────┤
│                                         │
│  Rate these players:                    │
│                                         │
│  [Photo] John Doe                       │
│  ───────────────────────────────────    │
│  ✓ Showed up on time                    │
│  ✓ Friendly & fun to play with          │
│  ✓ Skill level matched profile          │
│  ✓ Good sport & positive attitude       │
│                                         │
│  [Photo] Jane Smith                     │
│  ───────────────────────────────────    │
│  ✓ Showed up on time                    │
│  ✓ Friendly & fun to play with          │
│  ✓ Skill level matched profile          │
│  ☐ Good sport & positive attitude       │
│                                         │
│  [Skip for Now]  [Submit]               │
└─────────────────────────────────────────┘
```

**Key Design:**
- Simple checkboxes (yes/no per attribute)
- All boxes checked by default (positive framing)
- Uncheck only if issue occurred
- No text comments (reduces toxicity)
- Optional to submit
- Blind (can't see others' feedback)

---

## Data Model

### Round Feedback

**Collection**: `rounds/{roundId}/feedback/{raterUid}`

```swift
struct RoundFeedback: Codable, Identifiable {
    var id: String?              // raterUid
    let raterUid: String         // Who is providing feedback
    let targetUid: String        // Who is being evaluated
    let roundId: String

    // Structured feedback (not ratings)
    let punctual: Bool           // Showed up on time
    let friendly: Bool           // Pleasant to play with
    let honestSkill: Bool        // Skill level accurate
    let goodSport: Bool          // Positive attitude

    let timestamp: Date
}
```

### Trust Profile

**Add to `PublicProfile`:**

```swift
// Trust Tier
var trustTier: TrustTier = .bronze
var trustTierEarnedAt: Date?

// Trust Badges (earned, not given)
var hasPunctualBadge: Bool = false
var hasFriendlyBadge: Bool = false
var hasHonestSkillBadge: Bool = false
var hasGoodSportBadge: Bool = false

// Stats
var completedRoundsCount: Int = 0
var totalFeedbackReceived: Int = 0
var punctualPercentage: Double = 0.0
var friendlyPercentage: Double = 0.0
var honestSkillPercentage: Double = 0.0
var goodSportPercentage: Double = 0.0

// Overall trust score (weighted composite)
var trustScore: Double = 0.0  // 0-100

enum TrustTier: String, Codable {
    case bronze = "bronze"
    case silver = "silver"
    case gold = "gold"
    case verified = "verified"
}
```

### Pending Feedback

**Collection**: `pendingFeedback/{uid}/items/{roundId}`

```swift
struct PendingFeedback: Codable, Identifiable {
    var id: String?              // roundId
    let roundId: String
    let completedAt: Date
    let expiresAt: Date          // 7 days
    let participantUids: [String] // Who to evaluate
}
```

---

## UI Display Examples

### Profile Card in Round Discovery
```
┌─────────────────────────────────┐
│  [Photo] John Doe               │
│  🥇 Gold Member                 │
│  🎯 Punctual  😊 Friendly       │
│  ⛳️ Honest Skill                 │
│                                 │
│  42 completed rounds            │
│  San Jose, CA                   │
└─────────────────────────────────┘
```

### Full Profile View
```
┌──────────────────────────────────────┐
│  John Doe                            │
│  🥇 Gold Member since Jan 2026       │
├──────────────────────────────────────┤
│  Trust Badges                        │
│  🎯 Punctual        95% (40 rounds)  │
│  😊 Friendly        92% (40 rounds)  │
│  ⛳️ Honest Skill    97% (40 rounds)  │
│  🏆 Good Sport      88% (40 rounds)  │
├──────────────────────────────────────┤
│  42 completed rounds                 │
│  Member since Aug 2025               │
└──────────────────────────────────────┘
```

### Notification After Earning Badge
```
🎉 You earned the "Punctual" badge!
Your playing partners appreciate your reliability.
Keep it up to maintain your Gold status.
```

---

## Trust Score Algorithm

**Composite score (0-100) based on:**

```swift
trustScore = (
    punctualPercentage * 0.35 +      // Most important
    friendlyPercentage * 0.25 +      // Social fit
    honestSkillPercentage * 0.25 +   // Expectation matching
    goodSportPercentage * 0.15       // Attitude
) * completedRoundsMultiplier

// Multiplier for round count (caps at 1.0)
completedRoundsMultiplier = min(1.0, completedRoundsCount / 10)
```

**Example:**
- 95% punctual, 90% friendly, 98% honest, 85% sport, 15 rounds
- Score = (33.25 + 22.5 + 24.5 + 12.75) * 1.0 = **93.0**

**Tier Thresholds:**
- Bronze: 0-59
- Silver: 60-79
- Gold: 80-94
- Verified: 95-100 (+ time requirements)

---

## Implementation Phases

### Phase 1: Data Foundation (Week 1)
- [ ] Add `status` field to Round model
- [ ] Create `RoundFeedback` model
- [ ] Create `PendingFeedback` model
- [ ] Add trust fields to `PublicProfile`
- [ ] Update Firestore security rules
- [ ] Create `TrustRepository` protocol
- [ ] Implement `FirestoreTrustRepository`

### Phase 2: Round Completion (Week 1)
- [ ] Add "Mark as Completed" button (host only)
- [ ] Create pending feedback docs for participants
- [ ] Send notification to participants
- [ ] Handle edge cases (cancellation, removal)

### Phase 3: Feedback UI (Week 2)
- [ ] Create `PostRoundFeedbackView`
- [ ] Create `PostRoundFeedbackViewModel`
- [ ] Implement checkbox form
- [ ] Submit feedback to backend
- [ ] Show confirmation

### Phase 4: Trust Aggregation (Week 2)
- [ ] Cloud Function: `aggregateTrustProfile`
- [ ] Calculate percentages for each attribute
- [ ] Compute trust score
- [ ] Award/revoke badges
- [ ] Update trust tier
- [ ] Send tier-up notifications

### Phase 5: Profile Display (Week 3)
- [ ] Display trust tier on profiles
- [ ] Display trust badges on profiles
- [ ] Show percentages & round count
- [ ] Add trust tier to round cards
- [ ] Add trust tier to search results

### Phase 6: Discovery Boost (Week 3)
- [ ] Boost Gold/Verified profiles in search
- [ ] Filter rounds by host tier
- [ ] Priority join requests for high-tier users
- [ ] Analytics & monitoring

---

## Cloud Functions

### `aggregateTrustProfile`
**Trigger**: onCreate on `rounds/{roundId}/feedback/{raterUid}`

```typescript
export const aggregateTrustProfile = functions.firestore
  .document('rounds/{roundId}/feedback/{raterUid}')
  .onCreate(async (snap, context) => {
    const feedback = snap.data();
    const targetUid = feedback.targetUid;

    // 1. Fetch all feedback for this user (last 10 rounds for rolling badges)
    const allFeedback = await fetchUserFeedback(targetUid);

    // 2. Calculate percentages
    const stats = {
      punctualPct: calculatePercentage(allFeedback, 'punctual'),
      friendlyPct: calculatePercentage(allFeedback, 'friendly'),
      honestSkillPct: calculatePercentage(allFeedback, 'honestSkill'),
      goodSportPct: calculatePercentage(allFeedback, 'goodSport'),
      completedRoundsCount: allFeedback.length
    };

    // 3. Award/revoke badges
    const badges = {
      hasPunctualBadge: stats.punctualPct >= 90 && allFeedback.length >= 5,
      hasFriendlyBadge: stats.friendlyPct >= 90 && allFeedback.length >= 5,
      hasHonestSkillBadge: stats.honestSkillPct >= 90 && allFeedback.length >= 5,
      hasGoodSportBadge: stats.goodSportPct >= 90 && allFeedback.length >= 5
    };

    // 4. Calculate trust score
    const trustScore = calculateTrustScore(stats);

    // 5. Determine tier
    const newTier = determineTier(trustScore, stats.completedRoundsCount, userCreatedAt);
    const oldTier = await getUserTier(targetUid);

    // 6. Update profile
    await admin.firestore()
      .collection('profiles_public')
      .doc(targetUid)
      .update({
        ...stats,
        ...badges,
        trustScore,
        trustTier: newTier,
        trustTierEarnedAt: newTier !== oldTier ? admin.firestore.FieldValue.serverTimestamp() : null
      });

    // 7. Send notification if tier changed
    if (newTier !== oldTier && shouldCelebrate(newTier)) {
      await sendTierUpNotification(targetUid, newTier);
    }
  });
```

### `createPendingFeedback`
**Trigger**: onUpdate on `rounds/{roundId}` when status → completed

```typescript
export const createPendingFeedback = functions.firestore
  .document('rounds/{roundId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Only trigger when status changes to completed
    if (before.status !== 'completed' && after.status === 'completed') {
      const roundId = context.params.roundId;

      // 1. Fetch all accepted members
      const members = await fetchAcceptedMembers(roundId);

      // 2. Create pending feedback docs for each member
      const batch = admin.firestore().batch();

      for (const memberUid of members) {
        const otherMembers = members.filter(uid => uid !== memberUid);

        const pendingRef = admin.firestore()
          .collection('pendingFeedback')
          .doc(memberUid)
          .collection('items')
          .doc(roundId);

        batch.set(pendingRef, {
          roundId,
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days
          participantUids: otherMembers
        });
      }

      await batch.commit();

      // 3. Send notifications
      for (const memberUid of members) {
        await sendFeedbackNotification(memberUid, roundId);
      }
    }
  });
```

---

## Security Rules

```javascript
// Feedback submission
match /rounds/{roundId}/feedback/{raterUid} {
  allow read: if request.auth != null;

  allow create: if request.auth.uid == raterUid
    // Must be a participant
    && exists(/databases/$(database)/documents/rounds/$(roundId)/members/$(raterUid))
    // Round must be completed
    && get(/databases/$(database)/documents/rounds/$(roundId)).data.status == 'completed'
    // Can't rate yourself
    && request.resource.data.targetUid != request.auth.uid
    // Must rate another participant
    && exists(/databases/$(database)/documents/rounds/$(roundId)/members/$(request.resource.data.targetUid))
    // All fields must be booleans
    && request.resource.data.punctual is bool
    && request.resource.data.friendly is bool
    && request.resource.data.honestSkill is bool
    && request.resource.data.goodSport is bool;
}

// Trust profiles are read-only (updated by Cloud Functions)
match /profiles_public/{uid} {
  allow read: if request.auth != null;

  // Users can't update their own trust fields
  allow update: if request.auth.uid == uid
    && !request.resource.data.diff(resource.data).affectedKeys()
      .hasAny(['trustTier', 'trustScore', 'hasPunctualBadge', 'hasFriendlyBadge',
               'hasHonestSkillBadge', 'hasGoodSportBadge', 'completedRoundsCount']);
}
```

---

## Anti-Abuse Measures

### Rate Limiting
- Max 10 feedback submissions per user per day
- Can't submit feedback twice for same person in same round

### Pattern Detection
- Flag users who consistently give all-negative feedback (trolling)
- Flag users who receive consistently poor feedback (investigate)
- Admin dashboard to review flagged patterns

### Appeal Process
- Users can appeal tier/badge loss through support
- Manual review by team for edge cases
- Transparent reasons for tier changes

---

## Success Metrics

### Adoption
- **Target**: 60%+ feedback submission rate
- Users who submit feedback within 7 days of round completion

### Trust Distribution
- **Target**: 40% Silver+, 15% Gold+, 5% Verified
- Healthy pyramid shape

### Positive Feedback Rate
- **Target**: 85-95% average across all attributes
- Too high = inflation, too low = too harsh

### User Satisfaction
- **Survey**: "Do trust badges help you feel safer?"
- **Target**: 70%+ agree

### No-Show Rate
- Track if higher-tier users have lower cancellation rate
- **Target**: Gold users have 50% fewer cancellations

---

## Why This Works

### 1. Positive Psychology
- Focus on earning vs. avoiding
- Celebrate achievements (badges, tier-ups)
- Clear path to improvement

### 2. Behavioral Clarity
- Users know exactly what behaviors earn trust
- Not subjective ("be nice") but measurable ("show up on time")

### 3. Resilient System
- One bad round doesn't ruin you
- Patterns matter, not single events
- Can always improve and re-earn badges

### 4. Low Toxicity
- No public shaming
- No ambiguous ratings
- Blind feedback
- Positive default (all checked)

### 5. Progressive Rewards
- Tiers unlock real benefits
- Motivation to maintain good standing
- Long-term engagement

---

## Comparison: Trust Badges vs Star Ratings

| Aspect | Star Ratings | Trust Badges |
|--------|-------------|--------------|
| **Framing** | Negative (avoid bad) | Positive (earn good) |
| **Clarity** | Ambiguous | Specific behaviors |
| **Toxicity** | High (retaliation) | Low (structured) |
| **Resilience** | Fragile (one bad = tank) | Robust (patterns) |
| **Motivation** | Fear-based | Achievement-based |
| **Display** | 4.2 ⭐️ (feels bad) | 🥇 Gold (feels good) |
| **Gaming** | Inflate to 5s | Try to earn badges |
| **Interpretation** | Subjective | Objective |

---

## Recommendation

✅ **Use Trust Badges & Tiers** - This is significantly better than star ratings for a trust-first community like TeePals.

**Timeline**: Implement in Phase 5 (after core features stable)

**Launch Strategy**:
1. Start with Bronze/Silver only (simpler)
2. Add Gold/Verified after 6 months (need data)
3. Monitor feedback rates and adjust thresholds
4. Iterate based on user feedback

**Key Success Factor**: Make it feel like **earning** membership levels (like airline status) rather than avoiding punishment.
