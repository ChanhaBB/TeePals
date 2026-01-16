# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**TeePals** is a golf social platform iOS app built with SwiftUI and Firebase, focused on forming real-life rounds. The app operates on a privacy-first model with tiered profile completion, location-based round discovery using geohash indexing, and social features emerging from actual golf play.

**Core Principles:**
- Rounds are the core domain object
- Trust and safety over virality
- Private-by-default identity with public/private profile split
- All features must be additive (no breaking schema changes or refactors)

## Development Commands

### Building and Running
```bash
# Open in Xcode
open TeePals.xcodeproj

# Build from command line
xcodebuild -project TeePals.xcodeproj -scheme TeePals -configuration Debug build

# The app requires Xcode and runs on iOS simulator or device
# No separate build system (e.g., no npm, gradle, etc.)
```

### Firebase
```bash
# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Firestore indexes
firebase deploy --only firestore:indexes

# Deploy Storage rules
firebase deploy --only storage
```

## Architecture

### Layered Architecture (MVVM + Repository Pattern)

**Critical Rule:** Views MUST NOT import Firebase. All Firebase access goes through Repository implementations.

```
Views (SwiftUI)
    ↓
ViewModels (@MainActor, @Published state)
    ↓
Repository Protocols (domain interfaces)
    ↓
Firestore*Repository (Firebase implementations)
```

### Key Layers

1. **Views** (`TeePals/Views/`)
   - Pure SwiftUI, no Firebase imports
   - Observe ViewModels via `@StateObject` or `@ObservedObject`
   - Must handle loading/empty/error/success states
   - Keep files under 250 lines

2. **ViewModels** (`TeePals/ViewModels/`)
   - `@MainActor` classes conforming to `ObservableObject`
   - Depend on Repository protocols, never concrete implementations
   - Receive `currentUid` closure from AppContainer
   - Contain presentation logic only

3. **Repositories** (`TeePals/Repositories/`)
   - Protocol definitions (e.g., `ProfileRepository`, `RoundsRepository`)
   - Define async/await interfaces for data access
   - No Firebase imports here

4. **Firebase Repositories** (`TeePals/FirebaseRepositories/`)
   - Concrete implementations (e.g., `FirestoreProfileRepository`)
   - Only layer that imports Firebase
   - Handle Firestore queries, encoding/decoding, error mapping

5. **Models** (`TeePals/Models/`)
   - Pure Swift structs, `Codable` for Firestore serialization
   - No business logic beyond computed properties
   - Examples: `PublicProfile`, `PrivateProfile`, `Round`, `Post`, `Comment`

6. **UIFoundation** (`TeePals/UIFoundation/`)
   - Reusable design system components
   - Token files: `AppColors`, `AppTypography`, `AppSpacing`
   - Components: `AppCard`, `PrimaryButton`, `SecondaryButton`, `AppTextField`, `EmptyStateView`, `SkeletonViews`
   - **Must use these instead of inline styling**

7. **AppContainer** (`TeePals/App/AppContainer.swift`)
   - Dependency injection container
   - Creates repository singletons
   - Factory methods for ViewModels
   - Provides `currentUid` closure from Firebase Auth

### Authentication Flow

- **Sign in with Apple** only (no other providers)
- Firebase Auth UID is canonical user identifier
- States: `loading` → `unauthenticated` / `needsProfile` / `authenticated`
- After auth, checks if `profiles_public/{uid}` exists to determine state

### Profile Gating System

**Tier 1** (required immediately after Apple Sign-In):
- `nickname`
- `primaryCityLabel` + `primaryLocation` (GeoPoint)
- `birthDate` (stored in `profiles_private/{uid}`)
- `gender` (prefer_not allowed)

**Tier 2** (required for all social/participation actions):
- At least 1 profile photo (`photoUrls.count >= 1`)
- `skillLevel`

**Tier 2 gates:**
- Request/join rounds, create/edit/cancel rounds
- Follow/unfollow, invite users
- Accept/decline join requests, read/write round chat
- Like/comment, create posts/reviews

Avg score and other golf stats are optional and never gate actions.

### Data Model

**Profiles:**
- `profiles_public/{uid}` - readable by all authenticated users
- `profiles_private/{uid}` - readable/writable only by owner (contains birthDate)

**Social Graph:**
- `follows/{uid}/following/{targetUid}` - who the user follows
- `follows/{uid}/followers/{followerUid}` - who follows the user
- Friend = mutual follow

**Rounds:**
- `rounds/{roundId}` - main document
- `rounds/{roundId}/members/{uid}` - membership status
- `rounds/{roundId}/messages/{messageId}` - round chat
- Uses geohash indexing for location-based search (see GEOHASH_PLAN.md)
- Must always atomically persist `geo.lat`, `geo.lng`, and `geo.geohash`

**Posts & Social:**
- `posts/{postId}` - main document
- `posts/{postId}/upvotes/{uid}` - toggle upvotes
- `posts/{postId}/comments/{commentId}` - supports 1-level nesting

**Notifications:**
- `notifications/{uid}/items/{notifId}` - user-scoped

## Critical Rules

### Schema & Firestore
- **Never rename or delete Firestore fields** - all changes must be additive
- Always compute `geo.geohash` atomically with lat/lng when creating or updating locations
- Use `Codable` for Firestore serialization
- Security rules are in `firestore.rules` - respect them

### UI Rules (from UI_RULES.md)
- No Firebase imports in Views
- No business logic inside `View.body`
- No view files larger than 250 lines
- Every screen must support: loading, empty, error, success states
- UIFoundation components must be used instead of inline styling
- Primary CTA is sticky at bottom when applicable
- Buttons must include disabled, loading, and pressed states

### Code Style
- Use async/await (not callbacks)
- Use `@MainActor` for ViewModels
- Use `@StateObject` for ViewModel ownership, `@ObservedObject` for passed-in VMs
- Files should remain under ~250 lines
- Prefer composition over large files

### Navigation
Bottom tab bar (locked):
1. Home (social feed)
2. Rounds
3. Notifications
4. Profile

## Geohash Search Implementation

When working with location-based round search:
- Read `GEOHASH_PLAN.md` for detailed requirements
- Use utilities: `GeoHashUtil`, `DistanceUtil`, `GeoPrecisionPolicy`
- Always dedupe across geohash query bounds
- Apply date windows to bound Firestore reads
- Implement safety caps: `perBoundLimit`, `maxCandidatesTotal`

## Project Phases

Development follows a phased approach (see PHASES.md):
- Phase 0: Foundation ✅
- Phase 1: Identity & Trust ✅
- Phase 2: Rounds (CORE DOMAIN)
- Phase 3: Round Chat
- Phase 4: Social Layer ✅
- Phase 5: Notifications
- Phase 6: Polish & Scale

**Current status:** Phase 4 completed. Phases must be completed in order with no cross-phase refactors.

## Design Documents

The following docs are the **authoritative source of truth**:
- `TEE_PALS_DESIGN_DOC_V2.md` - Product spec, data models, enforcement strategy
- `UI_RULES.md` - Non-negotiable UI standards
- `PHASES.md` - Development sequencing
- `PHASE_4_SOCIAL_LAYER.md` - Social features spec (posts, comments, feed)
- `GEOHASH_PLAN.md` - Geo search implementation requirements

**Always prefer these documents over assumptions.**

## Common Patterns

### Creating a new feature with data access

1. Define a protocol in `Repositories/` (e.g., `ExampleRepository`)
2. Create Firestore implementation in `FirebaseRepositories/` (e.g., `FirestoreExampleRepository`)
3. Add repository to `AppContainer` as lazy singleton
4. Create ViewModel in `ViewModels/` that depends on protocol
5. Add ViewModel factory method to `AppContainer`
6. Create View in `Views/` using UIFoundation components
7. Update Firestore security rules in `firestore.rules`

### Adding a new screen

1. Create View in appropriate `Views/` subdirectory
2. Use `@StateObject` to instantiate ViewModel via `container.makeXViewModel()`
3. Inject `@EnvironmentObject var container: AppContainer`
4. Handle all four UI states: loading, empty, error, success
5. Use UIFoundation components for consistency
6. Keep file under 250 lines

### Testing profile gating

Use `ProfileGateCoordinator` (singleton in AppContainer) to check tier status before gated actions. Show `ProfileGateView` popup if incomplete.

## Branding

**App Name:** TeePals
**Slogan:** "Golf, better together."

Do not invent alternative slogans or taglines.
