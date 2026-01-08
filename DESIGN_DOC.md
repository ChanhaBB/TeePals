# TeePals (iOS) — 4-Day MVP Design Doc (SwiftUI + Firebase)

## 0) Decisions Locked
- Platform: iOS-first
- UI: SwiftUI
- Backend: Firebase (Auth + Firestore; Storage optional)
- Auth: Apple Sign-In only
- MVP Profile Fields (privacy-first):
  - homeLocation (GeoPoint) + homeCityLabel
  - locationSource (gps | search)
  - ageBucket (string) — NOT exact age
  - avgScore18 (int) — optional
  - skillLevel (enum string) — optional
- Discovery: rounds ordered by (distance asc, teeTime asc) using client-side distance calc
- Iteration rule: future features must be additive (no schema rewrites)

---

## 1) Product Goal
Ship in 4 days a working MVP where golfers can:
- create/join rounds
- coordinate via round chat
- discover rounds near a chosen location
- basic guardrails (block/report)

Non-goal: a full social network (feeds, comments, follows, ratings) in MVP.

---

## 2) Core UX
Bottom tabs:
1. Rounds
2. Create
3. Profile

Primary flow:
Auth → Profile setup (location + basics) → Browse rounds → Join → Chat

---

## 3) MVP Requirements

### 3.1 Must-have
- Apple Sign-In
- Profile setup:
  - set home location (Use my location OR Search city)
  - choose ageBucket (e.g., 18–24, 25–34, 35–44, 45+)
  - optional avgScore18 input
  - optional skillLevel
- Create round:
  - course name (free text)
  - tee time
  - max players
  - location defaults to profile homeLocation (host can override via search)
- Browse rounds:
  - time window: next 7 days
  - exclude canceled
  - sort by closest distance then teeTime
  - show distance in list
- Join/leave round with capacity enforcement
- Round detail:
  - info + participants list + join/leave
  - chat button visible only if participant
  - host can cancel
- Round chat (realtime)
- Block/report users (basic)

### 3.2 Out of scope
- Map view
- Tee time booking
- Course database integration
- Reviews/ratings/feed
- Push notifications
- DM outside of round chat
- Advanced geo indexing (geohash)

---

## 4) Data Model (Firestore Schema)

### Collections
- users/{userId}
- profiles/{userId}
- rounds/{roundId}
- rounds/{roundId}/participants/{userId}
- rounds/{roundId}/messages/{messageId}
- blocks/{userId}/blocked/{blockedUserId}
- reports/{reportId}

### users/{userId}
```json
{
  "displayName": "First Last",
  "createdAt": "<timestamp>",
  "lastActiveAt": "<timestamp>"
}
```

### profiles/{userId}
```json
{
  "homeCityLabel": "San Jose, CA",
  "homeLocation": "<GeoPoint>",
  "locationSource": "gps|search",
  "ageBucket": "18-24|25-34|35-44|45+",
  "avgScore18": 92,
  "skillLevel": "beginner|intermediate|advanced",
  "updatedAt": "<timestamp>"
}
```

### rounds/{roundId}
```json
{
  "hostUserId": "uid123",
  "courseName": "Preserve GC",
  "cityLabel": "San Jose, CA",
  "location": "<GeoPoint>",
  "teeTime": "<timestamp>",
  "maxPlayers": 4,
  "participantCount": 1,
  "status": "open|full|canceled",
  "createdAt": "<timestamp>"
}
```

### participants
```json
{
  "userId": "uid123",
  "role": "host|player",
  "joinedAt": "<timestamp>"
}
```

### messages
```json
{
  "senderUserId": "uid123",
  "text": "Meet at the clubhouse 10 mins early",
  "createdAt": "<timestamp>"
}
```

---

## 5) Distance Sorting (MVP)
1. Query upcoming rounds (next 7 days).
2. Compute distance client-side (Haversine).
3. Sort by distance asc, then teeTime asc.

---

## 6) Join/Leave/Cancel Logic
- Join: Firestore transaction enforcing capacity.
- Leave: decrement participantCount.
- Cancel: host sets status=canceled.

---

## 7) 4-Day Execution Plan
**Day 1:** Auth + Profile + Location  
**Day 2:** Rounds CRUD + Distance sort  
**Day 3:** Round chat  
**Day 4:** Guardrails + polish

---

## 8) Additive Roadmap
- Phone verification
- Reviews & reputation
- Course normalization
- Geo indexing
- Push notifications
