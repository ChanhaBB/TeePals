# TeePals – Design Doc v2 (Cursor Source of Truth)
SwiftUI + Firebase

This document is the **authoritative implementation guide** for TeePals.
Cursor must follow this document exactly and prefer it over assumptions.

---

## 0. Branding (LOCKED)

**App Name:** TeePals  
**Subtitle / Slogan:** **“Golf, better together.”**

Usage:
- App splash / loading screen
- App Store listing subtitle
- Marketing surfaces

Cursor must NOT invent alternative slogans or taglines.

---

## 1. Product Vision

TeePals is a **golf social platform focused on forming real-life rounds**.

Core principles:
- Rounds are the core object
- Trust and safety over virality
- Private-by-default identity
- Social features emerge from real play
- All features must be additive (no refactors)

---

## 2. Navigation (LOCKED)

Bottom tab bar:
1. Home
2. Rounds
3. Notifications
4. Profile

No additional tabs unless explicitly added in a future design doc.

---

## 3. Identity & Authentication

- Authentication: **Sign in with Apple**
- Firebase Auth UID is the canonical user identifier
- Session auto-restores on app launch
- No other auth providers unless added later

---

## 4. Profiles (Privacy-First)

Profiles are split into **public** and **private** documents.

### 4.1 Public Profile
`profiles_public/{uid}`

```json
{
  "nickname": "Nick",
  "photoUrl": "https://...",
  "gender": "male|female|nonbinary|prefer_not",
  "occupation": "Software Engineer",
  "bio": "Short intro",
  "primaryCityLabel": "San Jose, CA",
  "primaryLocation": "<GeoPoint>",
  "avgScore18": 92,
  "experienceYears": 3,
  "playsPerMonth": 4,
  "skillLevel": "beginner|intermediate|advanced",
  "ageDecade": "20s",
  "createdAt": "<timestamp>",
  "updatedAt": "<timestamp>"
}
```

Public profiles are readable by authenticated users.

---

### 4.2 Private Profile
`profiles_private/{uid}`

```json
{
  "birthDate": "1998-04-23",
  "createdAt": "<timestamp>",
  "updatedAt": "<timestamp>"
}
```

Private profiles are **only readable/writable by the owner**.

Birthdate is never shown publicly and is used only for internal age computation.

---

## 5. Social Graph

- Follow = one-way relationship
- Friend = **mutual follow**

Collections:
- `follows/{uid}/following/{otherUid}`
- `follows/{uid}/followers/{otherUid}`

Friends-only logic requires mutual follow.

---

## 6. Rounds (CORE DOMAIN)

### 6.1 Round Document
`rounds/{roundId}`

```json
{
  "hostUid": "uid",
  "title": "Weekend morning round",
  "visibility": "public|friends|invite",
  "joinPolicy": "instant|request",

  "courseCandidates": [
    { "name": "Course A", "cityLabel": "San Jose, CA", "location": "<GeoPoint>" }
  ],

  "teeTimeCandidates": ["<timestamp>"],
  "chosenCourse": { "name": "Course A", "cityLabel": "San Jose, CA", "location": "<GeoPoint>" },
  "chosenTeeTime": "<timestamp>",

  "requirements": {
    "genderAllowed": ["male","female","any"],
    "minAge": 25,
    "maxAge": 35,
    "skillLevelsAllowed": ["beginner","intermediate"],
    "minAvgScore": 80,
    "maxAvgScore": 110,
    "maxDistanceMiles": 25
  },

  "price": {
    "type": "estimate|range|free|unknown",
    "min": 60,
    "max": 90,
    "currency": "USD",
    "notes": "Walking rate, cart extra"
  },

  "priceTier": "$$",
  "maxPlayers": 4,
  "acceptedCount": 1,
  "requestCount": 0,
  "status": "open|closed|canceled|completed",
  "createdAt": "<timestamp>",
  "updatedAt": "<timestamp>"
}
```

Price is **informational only** and non-transactional.

---

## 6.2 Round Members
`rounds/{roundId}/members/{uid}`

```json
{
  "uid": "uid",
  "role": "host|member",
  "status": "accepted|requested|invited|declined|removed|left",
  "createdAt": "<timestamp>",
  "updatedAt": "<timestamp>"
}
```

Only members with `status = accepted` may participate in chat.

---

## 6.3 Round Chat
`rounds/{roundId}/messages/{messageId}`

```json
{
  "senderUid": "uid",
  "text": "Meet at clubhouse 10 mins early",
  "createdAt": "<timestamp>"
}
```

Chat is round-scoped only.

---

## 7. Posts & Reviews

Reviews are implemented as posts.

### 7.1 Posts
`posts/{postId}`

```json
{
  "authorUid": "uid",
  "type": "round_review|general",
  "roundId": "roundId",
  "courseName": "Course A",
  "score": 92,
  "text": "Great pace, fun group",
  "visibility": "public|friends",
  "likeCount": 0,
  "commentCount": 0,
  "createdAt": "<timestamp>",
  "updatedAt": "<timestamp>"
}
```

---

## 8. Notifications

`notifications/{uid}/items/{notifId}`

```json
{
  "type": "round_request|round_invited|round_accepted|post_liked|post_commented|system",
  "actorUid": "uid",
  "targetId": "roundId_or_postId",
  "read": false,
  "createdAt": "<timestamp>"
}
```

Notifications are user-scoped and append-only.

---

## 9. Enforcement Strategy

### MVP Enforcement
- Client-side filtering for age, skill, distance
- Chat access gated by membership status

### Hardened Enforcement (Later)
- Cloud Functions validate join requests
- Friends-only visibility enforced via denormalized friends list

---

## 10. Architecture Rules (FOR CURSOR)

- SwiftUI + MVVM
- Views must NOT import Firebase
- Firebase access only via Repository implementations
- Use async/await
- Files should remain under ~250 lines
- Never rename or delete Firestore fields
- All new functionality must be additive

---

## 11. Definition of Done

A feature is complete only if:
- Firestore writes are correct
- Permissions are respected
- Loading / empty / error states exist
- No breaking schema changes

---

## Profile Gating (LOCKED)

Tier 1 required immediately after Apple Sign-In:
- nickname
- primary city/location
- birthDate (private doc)
- gender (prefer_not allowed)

Tier 2 required for ANY social or participation action:
Tier 2 requires:
- profile photo
- skillLevel

Tier 2 gates:
- request/join rounds
- create/edit/cancel rounds
- invite users
- accept/decline join requests
- read/write round chat
- follow/unfollow
- like/comment
- create posts/reviews and any other engagement actions

Avg score and other golf stats are optional and must never gate actions.

## This document is the single source of truth.
Cursor must follow it exactly.
