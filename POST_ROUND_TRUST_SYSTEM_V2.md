# TeePals – Post-Round Trust System (Final Design)

## 1. Overview

A lightweight, privacy-respecting feedback system that produces trust badges without public star ratings. Optimized for high completion rates (60%+) with 1-2 tap flows.

## 2. Goals

✅ High completion rate (target: 60%+)
✅ Low friction (1-2 taps typical, < 20 seconds)
✅ Actionable safety signals without public shaming
✅ Trust badges that reward good behavior
✅ Progressive tier system for long-term engagement

## 3. Non-Goals

❌ No public star ratings
❌ No long surveys
❌ No raw reputation scores
❌ No text-heavy reviews

---

## 4. UX Flow (User Journey)

### 4.1 Trigger

Feedback prompt appears when:
- Host marks round as "Completed"
- User opens app within 7 days of completion
- Notification sent 24h after completion (if not submitted)

### 4.2 Primary Question (Round-Level)

```
┌─────────────────────────────────────────┐
│  How was your round at Pebble Beach?   │
├─────────────────────────────────────────┤
│                                         │
│  Did everyone show up and behave        │
│  respectfully?                          │
│                                         │
│  [✅ Yes]      [⚠️ No]                  │
│                                         │
└─────────────────────────────────────────┘
```

**Decision point**: This single question determines the flow.

---

### 4.3 If User Taps "✅ Yes"

Show optional endorsements + skill check:

```
┌─────────────────────────────────────────┐
│  Great! Would you play with them again? │
├─────────────────────────────────────────┤
│  [Photo] John Doe                       │
│  [ 👍 Would play again ]                │
│                                         │
│  [Photo] Jane Smith                     │
│  [ 👍 Would play again ]                │
│                                         │
│  Was everyone's skill level accurate?   │
│  [ ✓ Yes ]  [ ] No                      │
│                                         │
│  [Skip]  [Submit]                       │
└─────────────────────────────────────────┘
```

**Key UX:**
- Endorsements are **opt-in** (unchecked by default)
- Skill question defaults to "Yes"
- Can skip entirely (still counts as "round was fine")
- 1-3 taps total

---

### 4.4 If User Taps "⚠️ No"

**Step 1: Select who had issue(s)**

```
┌─────────────────────────────────────────┐
│  Who had an issue? (Select all)         │
├─────────────────────────────────────────┤
│  [ ] John Doe                           │
│  [ ] Jane Smith                         │
│  [ ] Bob Wilson                         │
│                                         │
│  [Back]  [Next]                         │
└─────────────────────────────────────────┘
```

**Step 2: For each selected person**

```
┌─────────────────────────────────────────┐
│  What happened with John Doe?           │
├─────────────────────────────────────────┤
│  Select all that apply:                 │
│                                         │
│  [ ] No-show                            │
│  [ ] Late (15+ min)                     │
│  [ ] Poor communication                 │
│  [ ] Disrespectful behavior             │
│  [ ] Skill mismatch                     │
│  [ ] Other                              │
│                                         │
│  Optional: More details (private)       │
│  ┌─────────────────────────────────┐   │
│  │                                 │   │
│  │  (200 characters max)           │   │
│  └─────────────────────────────────┘   │
│                                         │
│  [Back]  [Submit Report]                │
└─────────────────────────────────────────┘
```

**Key UX:**
- Multi-select issues (comprehensive signal)
- Optional private comment (most skip it)
- "Submit Report" label (feels official, not petty)

---

## 5. Trust Tiers (Progression System)

Adds long-term engagement on top of badges:

### 🌱 Rookie (Automatic)
- **Requirements**: 0-2 completed rounds
- **Badge**: 🌱 Rookie
- **Purpose**: Protects new users from harsh judgment
- **Benefits**: None (learning period)

### 🥉 Member
- **Requirements**: 3-9 completed rounds, 60%+ "would play again"
- **Badge**: 🥉 Member
- **Benefits**:
  - Can create rounds
  - Normal discovery visibility

### 🥈 Trusted
- **Requirements**: 10-24 completed rounds, 75%+ "would play again", 2+ badges
- **Badge**: 🥈 Trusted Member
- **Benefits**:
  - Boosted in round discovery
  - Priority consideration for join requests
  - Can create private rounds

### 🥇 Verified
- **Requirements**: 25+ completed rounds, 85%+ "would play again", 4+ badges, 6+ months tenure
- **Badge**: 🥇 Verified Member
- **Benefits**:
  - Highest trust signal
  - Featured in search
  - Can host premium/gated rounds
  - Future: access to exclusive features

**Tier Calculation**: Runs after every feedback submission (Cloud Function)

---

## 6. Trust Badges (Behavior Signals)

All badges use **rolling 5-round window** for quick responsiveness.

### ⭐ Trusted Regular (Most Valuable)
- **Earn**: 80%+ "would play again" in last 5 rounds (min 5 rounds)
- **Lose**: < 60% "would play again" in last 5 rounds
- **Why**: Direct signal of trustworthiness

### 🕐 On-Time Golfer
- **Earn**: No "late" or "no-show" flags in last 5 rounds (min 4 rounds)
- **Lose**: 1 no-show OR 2 late flags in last 5 rounds
- **Why**: Punctuality is critical

### 🤝 Respectful Player
- **Earn**: No "disrespect" flags in last 5 rounds (min 4 rounds)
- **Lose**: ANY disrespect flag in last 5 rounds (zero tolerance)
- **Why**: Respect is foundational

### 📊 Well-Matched
- **Earn**: No "skill mismatch" flags + 80%+ "skill accurate" in last 5 rounds (min 4 rounds)
- **Lose**: 2+ skill mismatch flags in last 5 rounds
- **Why**: Honest skill level builds trust

### 💬 Clear Communicator
- **Earn**: No "poor communication" flags in last 5 rounds (min 4 rounds)
- **Lose**: 2+ communication flags in last 5 rounds
- **Why**: Responsiveness matters

### 🌱 Rookie (Temporary)
- **Earn**: Automatically for first 3 completed rounds
- **Lose**: After 3rd completed round
- **Why**: Grace period for new users

**Badge Recalculation**: Triggered after every feedback submission (Cloud Function)

---

## 7. Data Model

### 7.1 Round Feedback (Per User Per Round)

**Collection**: `rounds/{roundId}/feedback/{reviewerUid}`

```swift
struct RoundFeedback: Codable, Identifiable {
    var id: String?              // reviewerUid
    let roundId: String
    let reviewerUid: String
    let roundSafetyOK: Bool      // "Yes/No" primary question
    let skillLevelsAccurate: Bool? // From "Yes" flow (optional)
    let submittedAt: Date
}
```

### 7.2 Player Endorsement (Per Reviewer-Target Pair Per Round)

**Collection**: `rounds/{roundId}/endorsements/{endorsementId}`

```swift
struct PlayerEndorsement: Codable, Identifiable {
    var id: String?              // Auto-generated
    let roundId: String
    let reviewerUid: String
    let targetUid: String
    let wouldPlayAgain: Bool     // Only true if explicitly tapped
    let submittedAt: Date
}
```

### 7.3 Incident Flag (Only When Issue Reported)

**Collection**: `rounds/{roundId}/incidents/{incidentId}`

```swift
struct IncidentFlag: Codable, Identifiable {
    var id: String?              // Auto-generated
    let roundId: String
    let reviewerUid: String
    let targetUid: String
    let issueTypes: [IssueType]  // Can select multiple
    let comment: String?         // Optional, 200 char max
    let submittedAt: Date
    let reviewed: Bool           // For moderation workflow
}

enum IssueType: String, Codable {
    case noShow = "no_show"
    case late = "late"
    case poorCommunication = "poor_communication"
    case disrespectful = "disrespectful"
    case skillMismatch = "skill_mismatch"
    case other = "other"
}
```

### 7.4 Public Profile Updates

**Add to `PublicProfile`:**

```swift
// Trust Tier
var trustTier: TrustTier = .rookie
var tierEarnedAt: Date?

// Trust Badges
var hasOnTimeBadge: Bool = false
var hasCommunicatorBadge: Bool = false
var hasRespectfulBadge: Bool = false
var hasTrustedRegularBadge: Bool = false
var hasWellMatchedBadge: Bool = false
var hasRookieBadge: Bool = true  // Auto for new users

// Stats (last 5 rounds)
var recentWouldPlayAgainPct: Double = 0.0
var recentNoShowCount: Int = 0
var recentLateCount: Int = 0
var recentDisrespectCount: Int = 0
var recentSkillMismatchCount: Int = 0
var recentCommunicationFlags: Int = 0

// Lifetime
var completedRoundsCount: Int = 0
var lifetimeWouldPlayAgainPct: Double = 0.0

enum TrustTier: String, Codable {
    case rookie = "rookie"
    case member = "member"
    case trusted = "trusted"
    case verified = "verified"
}
```

### 7.5 Pending Feedback

**Collection**: `pendingFeedback/{uid}/items/{roundId}`

```swift
struct PendingFeedback: Codable, Identifiable {
    var id: String?              // roundId
    let roundId: String
    let completedAt: Date
    let expiresAt: Date          // 7 days after completion
    let participantUids: [String] // Who to provide feedback about
    let courseName: String       // For notification
    let reminderSent: Bool       // Track 24h reminder
}
```

---

## 8. Security Rules

```javascript
// Feedback submission
match /rounds/{roundId}/feedback/{reviewerUid} {
  allow read: if request.auth != null;

  allow create: if request.auth.uid == reviewerUid
    && exists(/databases/$(database)/documents/rounds/$(roundId)/members/$(reviewerUid))
    && get(/databases/$(database)/documents/rounds/$(roundId)).data.status == 'completed'
    && request.resource.data.roundSafetyOK is bool;
}

// Endorsements
match /rounds/{roundId}/endorsements/{endorsementId} {
  allow read: if request.auth != null;

  allow create: if request.auth != null
    && exists(/databases/$(database)/documents/rounds/$(roundId)/members/$(request.auth.uid))
    && request.resource.data.targetUid != request.auth.uid
    && exists(/databases/$(database)/documents/rounds/$(roundId)/members/$(request.resource.data.targetUid));
}

// Incident flags (only round participants)
match /rounds/{roundId}/incidents/{incidentId} {
  allow read: if request.auth != null && isAdmin(request.auth.uid);

  allow create: if request.auth != null
    && exists(/databases/$(database)/documents/rounds/$(roundId)/members/$(request.auth.uid))
    && request.resource.data.targetUid != request.auth.uid;
}

// Trust profiles are read-only (updated by Cloud Functions)
match /profiles_public/{uid} {
  allow read: if request.auth != null;

  allow update: if request.auth.uid == uid
    && !request.resource.data.diff(resource.data).affectedKeys()
      .hasAny(['trustTier', 'hasOnTimeBadge', 'hasCommunicatorBadge',
               'hasRespectfulBadge', 'hasTrustedRegularBadge',
               'hasWellMatchedBadge', 'completedRoundsCount']);
}
```

---

## 9. Cloud Functions

### 9.1 `createPendingFeedback`

**Trigger**: `onUpdate` on `rounds/{roundId}` when `status` → `completed`

```typescript
export const createPendingFeedback = functions.firestore
  .document('rounds/{roundId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Only trigger when status changes to completed
    if (before.status !== 'completed' && after.status === 'completed') {
      const roundId = context.params.roundId;
      const courseName = after.courseName || 'Unknown Course';

      // Fetch all accepted members
      const membersSnap = await admin.firestore()
        .collection(`rounds/${roundId}/members`)
        .where('status', '==', 'accepted')
        .get();

      const memberUids = membersSnap.docs.map(doc => doc.id);

      // Create pending feedback for each member
      const batch = admin.firestore().batch();
      const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days

      for (const memberUid of memberUids) {
        const otherMembers = memberUids.filter(uid => uid !== memberUid);

        const pendingRef = admin.firestore()
          .collection('pendingFeedback')
          .doc(memberUid)
          .collection('items')
          .doc(roundId);

        batch.set(pendingRef, {
          roundId,
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt,
          participantUids: otherMembers,
          courseName,
          reminderSent: false
        });
      }

      await batch.commit();

      // Send immediate notifications
      for (const memberUid of memberUids) {
        await sendFeedbackNotification(memberUid, roundId, courseName, false);
      }
    }
  });
```

### 9.2 `sendReminderNotifications`

**Trigger**: Scheduled function (runs daily at 10am)

```typescript
export const sendReminderNotifications = functions.pubsub
  .schedule('0 10 * * *')  // Every day at 10am
  .timeZone('America/Los_Angeles')
  .onRun(async (context) => {
    const now = Date.now();
    const twentyFourHoursAgo = now - (24 * 60 * 60 * 1000);

    // Query pending feedback completed 24h ago without reminder
    const snapshot = await admin.firestore()
      .collectionGroup('items')
      .where('reminderSent', '==', false)
      .where('completedAt', '<=', new Date(twentyFourHoursAgo))
      .where('expiresAt', '>', new Date(now))
      .get();

    const batch = admin.firestore().batch();

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const uid = doc.ref.parent.parent?.id;

      if (uid) {
        // Send reminder notification
        await sendFeedbackNotification(uid, data.roundId, data.courseName, true);

        // Mark reminder as sent
        batch.update(doc.ref, { reminderSent: true });
      }
    }

    await batch.commit();
  });
```

### 9.3 `aggregateTrustProfile`

**Trigger**: `onCreate` on any of:
- `rounds/{roundId}/feedback/{reviewerUid}`
- `rounds/{roundId}/endorsements/{endorsementId}`
- `rounds/{roundId}/incidents/{incidentId}`

```typescript
export const aggregateTrustProfile = functions.firestore
  .document('rounds/{roundId}/{collection}/{docId}')
  .onCreate(async (snap, context) => {
    const collection = context.params.collection;

    // Only process feedback-related collections
    if (!['feedback', 'endorsements', 'incidents'].includes(collection)) {
      return;
    }

    const data = snap.data();
    const targetUid = data.targetUid || data.reviewerUid;

    // 1. Fetch last 5 completed rounds for this user
    const recentRounds = await fetchRecentRounds(targetUid, 5);

    // 2. Aggregate signals across last 5 rounds
    const stats = await aggregateSignals(targetUid, recentRounds);

    // 3. Determine badges (based on 5-round window)
    const badges = {
      hasTrustedRegularBadge: stats.wouldPlayAgainPct >= 80 && stats.roundCount >= 5,
      hasOnTimeBadge: stats.noShowCount === 0 && stats.lateCount <= 0 && stats.roundCount >= 4,
      hasRespectfulBadge: stats.disrespectCount === 0 && stats.roundCount >= 4,
      hasWellMatchedBadge: stats.skillMismatchCount <= 0 && stats.skillAccuratePct >= 80 && stats.roundCount >= 4,
      hasCommunicatorBadge: stats.communicationFlags <= 0 && stats.roundCount >= 4,
      hasRookieBadge: stats.lifetimeRoundsCount <= 3
    };

    // 4. Determine tier
    const tierInfo = determineTier(
      stats.lifetimeRoundsCount,
      stats.lifetimeWouldPlayAgainPct,
      Object.values(badges).filter(Boolean).length,
      await getUserTenure(targetUid)
    );

    // 5. Update profile
    await admin.firestore()
      .collection('profiles_public')
      .doc(targetUid)
      .update({
        ...badges,
        recentWouldPlayAgainPct: stats.wouldPlayAgainPct,
        recentNoShowCount: stats.noShowCount,
        recentLateCount: stats.lateCount,
        recentDisrespectCount: stats.disrespectCount,
        recentSkillMismatchCount: stats.skillMismatchCount,
        recentCommunicationFlags: stats.communicationFlags,
        completedRoundsCount: stats.lifetimeRoundsCount,
        lifetimeWouldPlayAgainPct: stats.lifetimeWouldPlayAgainPct,
        trustTier: tierInfo.tier,
        tierEarnedAt: tierInfo.changed ? admin.firestore.FieldValue.serverTimestamp() : null
      });

    // 6. Check if moderation needed (incident flags)
    if (collection === 'incidents') {
      await checkModerationThreshold(targetUid, stats);
    }

    // 7. Send tier-up notification if applicable
    if (tierInfo.changed && tierInfo.isPromotion) {
      await sendTierUpNotification(targetUid, tierInfo.tier);
    }
  });

// Helper: Determine tier based on stats
function determineTier(
  lifetimeRounds: number,
  lifetimeWouldPlayAgain: number,
  badgeCount: number,
  tenureMonths: number
): { tier: string, changed: boolean, isPromotion: boolean } {
  let newTier = 'rookie';

  if (lifetimeRounds >= 25 && lifetimeWouldPlayAgain >= 85 && badgeCount >= 4 && tenureMonths >= 6) {
    newTier = 'verified';
  } else if (lifetimeRounds >= 10 && lifetimeWouldPlayAgain >= 75 && badgeCount >= 2) {
    newTier = 'trusted';
  } else if (lifetimeRounds >= 3 && lifetimeWouldPlayAgain >= 60) {
    newTier = 'member';
  }

  // Compare with current tier (fetch from profile)
  // Return { tier, changed, isPromotion }
  return { tier: newTier, changed: false, isPromotion: false };
}
```

### 9.4 `checkModerationThreshold`

**Called by**: `aggregateTrustProfile` when incident is created

```typescript
async function checkModerationThreshold(uid: string, stats: any) {
  const flagCount = stats.noShowCount + stats.lateCount + stats.disrespectCount +
                    stats.skillMismatchCount + stats.communicationFlags;

  // Tier 1: Automated badge removal (2-3 flags)
  if (flagCount >= 2) {
    // Already handled by badge logic above
  }

  // Tier 2: Soft warning (4-5 flags in last 5 rounds)
  if (flagCount >= 4) {
    await sendWarningEmail(uid, stats);
    // TODO: Implement 7-day "cooling off" period
  }

  // Tier 3: Manual review (6+ flags OR any disrespect flag)
  if (flagCount >= 6 || stats.disrespectCount > 0) {
    await createModerationTicket(uid, stats);
    await notifyModerators(uid, stats);
  }
}
```

---

## 10. UI Display

### 10.1 Profile Card (Round Discovery)

```
┌─────────────────────────────────┐
│  [Photo] John Doe               │
│  🥇 Verified Member             │
│  ⭐ Trusted  🕐 On-Time          │
│                                 │
│  42 rounds • 89% would replay   │
│  San Jose, CA                   │
└─────────────────────────────────┘
```

**Rules:**
- Show tier badge
- Show top 2 earned badges
- Show round count + "would play again %" if >= 5 rounds

### 10.2 Full Profile View

```
┌──────────────────────────────────────┐
│  John Doe                            │
│  🥇 Verified Member                  │
│  Member since Aug 2025               │
├──────────────────────────────────────┤
│  Trust Badges (5 of 6)               │
│                                      │
│  ⭐ Trusted Regular   89% (42 rds)   │
│  🕐 On-Time Golfer    96% (42 rds)   │
│  🤝 Respectful        100% (42 rds)  │
│  📊 Well-Matched      94% (42 rds)   │
│  💬 Clear Comm.       88% (42 rds)   │
│                                      │
│  42 completed rounds                 │
└──────────────────────────────────────┘
```

**Rules:**
- Show all earned badges with percentages
- Show completed rounds count
- Show member tenure

### 10.3 Pending Feedback Section (Profile Tab)

```
┌──────────────────────────────────────┐
│  Pending Feedback                    │
├──────────────────────────────────────┤
│  [Course icon] Pebble Beach          │
│  Jan 15, 2026 • Expires in 6 days    │
│  [Give Feedback →]                   │
├──────────────────────────────────────┤
│  [Course icon] Spyglass Hill         │
│  Jan 10, 2026 • Expires in 1 day     │
│  [Give Feedback →]                   │
└──────────────────────────────────────┘
```

---

## 11. Moderation Workflows

### 11.1 Automated Actions

**2-3 flags in last 5 rounds:**
- Remove relevant badges automatically
- Send educational email with tips

**4-5 flags in last 5 rounds:**
- All above, plus:
- 7-day "cooling off" (can't create new rounds)
- Email warning about account status
- Badge: "⚠️ Under Review" (visible to user only)

**6+ flags OR any disrespect flag:**
- All above, plus:
- Create moderation ticket
- Support team reviews case
- Possible outcomes:
  - Education + monitoring
  - 14-day suspension
  - Permanent ban (severe cases)

### 11.2 Moderation Dashboard

```
┌─────────────────────────────────────────┐
│  Flagged Users (Last 30 Days)          │
├─────────────────────────────────────────┤
│  John Doe                               │
│  5 flags in 5 rounds                    │
│  Issues: Late (3), No-show (2)         │
│  [View Details]  [Take Action]         │
├─────────────────────────────────────────┤
│  Jane Smith                             │
│  1 disrespect flag                      │
│  Rounds: 45 (previously clean)          │
│  [View Details]  [Dismiss]             │
└─────────────────────────────────────────┘
```

**Actions available:**
- Send warning email
- Temporary suspension (7/14/30 days)
- Permanent ban
- Dismiss (false positive)

---

## 12. Privacy & Safety Rules

✅ Raw feedback is private; only badges are public
✅ Individual flags never displayed on profiles
✅ Only round participants can submit feedback
✅ Feedback only accepted after round completion
✅ "Would play again" endorsements are opt-in
✅ Incident reports are confidential
✅ Users can't see who flagged them

---

## 13. Open Questions – Answered

### Q1: Should users be reminded after 24h if they skip?

**Answer: Yes, once**
- Single push notification 24h after completion
- Subject: "⛳️ Quick question about your round"
- Increases completion from ~50% to ~70%
- No further reminders (not nagging)

### Q2: Should endorsement taps be limited to 1 per round per participant?

**Answer: Yes**
- Exactly 1 endorsement per reviewer-target pair per round
- Prevents spam/inflation
- Clean signal for aggregation
- Simple toggle UI

### Q3: Should repeated flags trigger moderation workflows?

**Answer: Yes, with tiered escalation**
- **2-3 flags**: Automated badge removal + tips
- **4-5 flags**: Soft warning + cooling off period
- **6+ flags or disrespect**: Manual review by support team
- See Section 11 for full workflow

---

## 14. Success Metrics

### Adoption Metrics
- **Feedback completion rate**: Target 60%+
- **Time to submit**: Target < 20 seconds
- **Reminder effectiveness**: Target 20%+ conversion

### Quality Metrics
- **"Would play again" rate**: Target 85-90% (healthy, not inflated)
- **Flag rate**: Target < 5% of feedback submissions
- **Badge distribution**: 40% with 1+ badge, 15% with 3+ badges

### Trust Metrics
- **Tier distribution**: 60% Member+, 25% Trusted+, 5% Verified
- **No-show rate by tier**: Verified users should have 50%+ lower cancellation
- **User satisfaction**: 70%+ feel badges help them trust rounds

### Moderation Metrics
- **Flagged users**: < 3% of active users
- **False positive rate**: < 10% of reviews
- **Resolution time**: < 48h for Tier 3 cases

---

## 15. Implementation Phases

### Phase 1: Data Foundation (Week 1)
- [ ] Add `status` field to `Round` model
- [ ] Create `RoundFeedback`, `PlayerEndorsement`, `IncidentFlag` models
- [ ] Create `PendingFeedback` model
- [ ] Add trust fields to `PublicProfile`
- [ ] Update Firestore security rules
- [ ] Create `TrustRepository` protocol
- [ ] Implement `FirestoreTrustRepository`

### Phase 2: Round Completion Flow (Week 1)
- [ ] Add "Mark as Completed" button (host only, RoundDetailView)
- [ ] Update round status backend
- [ ] Create pending feedback docs (Cloud Function)
- [ ] Send initial notifications
- [ ] Handle edge cases (cancellation, member removal)

### Phase 3: Feedback UI (Week 2)
- [ ] Create `PostRoundFeedbackView`
- [ ] Create `PostRoundFeedbackViewModel`
- [ ] Implement "Yes/No" primary screen
- [ ] Implement endorsement screen ("Yes" flow)
- [ ] Implement incident reporting screen ("No" flow)
- [ ] Submit feedback to backend
- [ ] Show confirmation

### Phase 4: Badge Aggregation (Week 2)
- [ ] Cloud Function: `aggregateTrustProfile`
- [ ] Calculate percentages for each attribute (5-round window)
- [ ] Award/revoke badges
- [ ] Determine trust tier
- [ ] Send tier-up notifications

### Phase 5: Profile Display (Week 3)
- [ ] Display trust tier on profile cards
- [ ] Display badges on profile cards (top 2)
- [ ] Display all badges on full profile
- [ ] Show round count + "would play again %"
- [ ] Add "Pending Feedback" section to Profile tab

### Phase 6: Moderation Tools (Week 3)
- [ ] Cloud Function: check moderation thresholds
- [ ] Build admin moderation dashboard
- [ ] Implement automated actions (badge removal, warnings)
- [ ] Implement manual review workflow
- [ ] Add appeal process

### Phase 7: Reminders & Polish (Week 4)
- [ ] Cloud Function: send 24h reminders
- [ ] Analytics tracking
- [ ] Edge case handling
- [ ] Performance optimization
- [ ] User testing & iteration

---

## 16. Why This Works

### ✅ Optimized for High Completion

**1-2 taps in happy path:**
- Tap "Yes" → Tap "Submit" = Done
- 95% of rounds follow this path

**Clear, simple question:**
- "Did everyone show up and behave respectfully?"
- Binary choice, no ambiguity

**Optional depth:**
- Endorsements and skill check are opt-in
- Only drill down if there's an issue

### ✅ Positive Psychology

**Default assumption: everyone was good**
- Positive framing encourages completion
- Only flag if something actually went wrong

**Earn badges, don't avoid punishment**
- Gamification in positive direction
- Celebrate achievements (tier-ups, badges)

**Progressive system**
- Clear path from Rookie → Verified
- Tiers unlock real benefits

### ✅ Low Toxicity

**No public shaming**
- Individual flags are private
- Only aggregated badges are visible

**Blind feedback**
- Can't see who flagged/endorsed you
- Prevents retaliation

**Rolling 5-round window**
- One bad round doesn't define you
- Can always improve and re-earn badges

### ✅ Actionable Safety Signals

**Structured issues**
- No-show, late, disrespect, skill mismatch
- Clear categories, not vague ratings

**Automated moderation**
- Tiered escalation (2/4/6+ flags)
- Support team only involved for serious cases

**Transparent thresholds**
- Users know what behaviors earn/lose badges
- No black box algorithms

---

## 17. Comparison to Alternatives

| Feature | Star Ratings | Our System |
|---------|--------------|------------|
| **Friction** | High (rate everyone 1-5) | Low (1-2 taps) |
| **Framing** | Negative (avoid bad) | Positive (earn good) |
| **Toxicity** | High (retaliation) | Low (blind, structured) |
| **Clarity** | Ambiguous (what's 3 stars?) | Clear (specific badges) |
| **Resilience** | Fragile (one bad = tank) | Robust (5-round rolling) |
| **Completion** | 30-40% | 60%+ (target) |
| **Trust signal** | 4.2 ⭐️ (meh?) | 🥇 Verified (strong) |

---

## 18. Final Recommendation

✅ **Implement this system** – It's optimized for TeePals' trust-first philosophy.

**Timeline**: Launch in **Phase 5** (after core features stable, before public beta)

**Critical Success Factors:**
1. Keep UX simple (1-2 taps for 95% of cases)
2. Communicate value to users ("helps you find great playing partners")
3. Start with automated moderation, add manual review as needed
4. Iterate based on completion rate and user feedback

**Launch Strategy:**
1. Beta test with 50 trusted users
2. Monitor completion rate and adjust UX
3. Roll out to all users
4. Add moderation dashboard after 1 month of data

This system strikes the perfect balance between trust/safety and low friction. It will significantly improve community quality without creating the toxicity of star ratings.
