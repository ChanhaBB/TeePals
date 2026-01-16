# TeePals Project Phases

This document defines the **official development phases** for TeePals.
Each phase builds on the previous one. Work must remain **additive** — no refactors across phases.

---

## Phase 0 — Foundation (Completed)

**Goal:** App boots cleanly, rules and structure are locked.

### Deliverables
- Apple Sign-In
- Firebase project setup (Auth + Firestore)
- AppContainer / dependency injection
- Navigation skeleton (tab bar)
- Loading screen + app icon
- Design documents:
  - `TEE_PALS_DESIGN_DOC_V2.md`
  - `UI_RULES.md`
- Secure Firestore rules (no test mode)

---

## Phase 1 — Identity & Trust (Completed)

**Goal:** Every user has a real, safe, private-by-default identity.

### Deliverables
- Tier 1 onboarding wizard (required after sign-in):
  - Nickname
  - Birthdate (stored privately)
  - Primary city / location
  - Gender (prefer_not allowed)
- Public vs private profile split
- Tier 2 profile requirements defined:
  - Profile photo
  - Skill level
- Profile view
- Follow / unfollow system
- Mutual follow = friends
- Profile gating logic

---

## Phase 2 — Rounds (CORE DOMAIN)

**Goal:** Enable real-world golf meetups.

### Deliverables
- Full Round data model (v2 schema)
- Create round flow:
  - Course candidates
  - Date / time candidates
  - Informational price
- Browse rounds:
  - Location-based
  - Filter by Distance away from you (0 to 100 miles)
  - Filter by Date Range (select same day twice for one day)
  - Sort by Distance
  - Sort by Date (closest to furthest)
  - Pagination (cost control)
  - 
- Join flow:
  - Request / accept / decline
  - Invite users (can only invite friends) 
  - Host can kick already accepted member
- Round membership state machine
- Round can be canceled(aborted), active, private (friends only), and it can also be completed. 
- Tier 2 gating enforced for all actions (user needs a profile photo)

---

## Phase 3 — Round Chat

**Goal:** Communication only between real participants.

### Deliverables
- Round-scoped group chat
- Accepted members only
- Basic text messaging but also future proof and clean
- System messages (join/accept/cancel)
- Active chat should appear in the Activity section or not? Should chat be an independent entity with link to the round details? 

---

## Phase 4 — Social Layer (In Progress)

**Goal:** Community and reputation through posts, comments, and intelligent feed ranking.

> **Full spec:** See `PHASE_4_SOCIAL_LAYER.md`

### Phase 4.1: Core Posts & Basic Feed ✅

**Posts**
- ✅ Create posts with text + up to 4 photos
- ✅ Optional round linking (completed or pending)
- ✅ Edit and delete own posts
- ✅ Upvote system (toggle)

**Comments**
- ✅ Nested comments (1 level deep)
- ✅ Flat @mentions for deeper replies
- ✅ Edit and delete own comments

**Feed (Home Tab)**
- ✅ Home tab becomes the social feed
- ✅ Toggle: All posts vs Friends-only
- ✅ Pull to refresh
- ✅ Reverse chronological sort

**Profile Posts Tab**
- ✅ User's posts displayed on profile

**Followers / Following**
- ✅ Viewable lists from profile
- ✅ Friends (mutual follows) shown at top
- ✅ Search by nickname

### Phase 4.2: Advanced Feed Ranking 🚧

**Feed Infrastructure**
- [ ] Client-side deterministic scoring algorithm
- [ ] postStats collection with aggregate counters
- [ ] userStats collection with new author detection
- [ ] Cloud Functions for counter maintenance
- [ ] Firestore composite indexes

**Friends Feed**
- [ ] Time-based ranking with scoring
- [ ] Diversity enforcement (max 2 consecutive same author)
- [ ] Cursor-based pagination
- [ ] Multi-window fallback (7d → 30d → 180d)

**Public Feed**
- [ ] 3-bucket strategy (Recent, Trending, New Creators)
- [ ] Deterministic bucket mixing (6:2:2 ratio)
- [ ] Hard injection for new creators (every 5 posts)
- [ ] Soft personalization (same city, course, tags)
- [ ] hotScore7d scheduled computation

**Configuration**
- [ ] Tunable ranking parameters in FeedRankingConfig
- [ ] Debug mode for score explanations

---

## Phase 5 — Notifications

**Goal:** Timely engagement without spam.

### Deliverables
- Join request notifications
- Accept / decline notifications
- Invites
- Social interactions (likes/comments)
- System notifications
- In-app notification center

---

## Phase 6 — Polish & Scale

**Goal:** Production readiness.

### Deliverables
- UI polish (premium feel)
- Performance tuning
- Firestore index optimization
- Edge-case handling
- Analytics (basic)
- App Store preparation

---

## Phase Rules
- Phases must be completed in order
- No refactors between phases
- Schema changes must be additive only
- If a phase becomes messy, pause and clean before continuing

---

This file is the source of truth for project sequencing.
