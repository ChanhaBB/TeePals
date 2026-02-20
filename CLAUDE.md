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

---

## Repository Structure

```
TeePals/TeePals/
├── App/
│   └── AppContainer.swift            # DI container — repositories, services, VM factories
├── Coordinators/
│   ├── DeepLinkCoordinator.swift     # Universal link handling
│   └── ProfileGateCoordinator.swift  # Tier 2 profile gating coordination
├── Fonts/                            # Inter, PlayfairDisplay variable fonts
├── Resources/
│   └── Assets.xcassets/              # App icon, logo, accent color, images
├── UIFoundation/                     # Legacy design tokens + generic primitives (no model deps)
│   ├── AppColors.swift               # Color tokens
│   ├── AppTypography.swift           # Typography tokens (system rounded)
│   ├── AppSpacing.swift              # Spacing & radius tokens (4pt grid)
│   ├── AppButtons.swift              # PrimaryButton, SecondaryButton, TextButton
│   ├── AppCard.swift                 # Card surfaces
│   ├── AppTextField.swift            # Text inputs
│   ├── AppBanners.swift              # Error/Warning/Info/Success banners
│   ├── AsyncContentView.swift        # Generic loading/error/empty/content wrapper
│   ├── EmptyStateView.swift          # Reusable empty states
│   ├── SkeletonViews.swift           # Shimmer loading placeholders
│   ├── CachedAsyncImage.swift        # Cached async image utility
│   ├── SelectableChip.swift          # Single-select chip + ChipGroup
│   ├── MultiSelectChip.swift         # Multi-select chip + group
│   ├── SectionCard.swift             # Section card wrapper + AssistiveText
│   ├── FormFieldRow.swift            # Form row with icon layout
│   ├── AdvancedTextEditor.swift      # UIKit text view wrapper
│   ├── PhotoViewerView.swift         # Fullscreen photo viewer
│   ├── ShareSheet.swift              # UIActivityViewController wrapper
│   ├── RoundedCornerShape.swift      # Custom corner shape
│   └── KeyboardDismissModifier.swift # Keyboard dismiss toolbar
├── UIFoundationNew/                  # V3 design tokens + generic primitives (no model deps)
│   ├── AppColorsV3.swift             # V3 color tokens (hex, forest green palette)
│   ├── AppTypographyV3.swift         # V3 typography (Playfair Display serif + system sans)
│   ├── AppSpacingV3.swift            # V3 spacing tokens (8/12/16/24 scale)
│   ├── AppShadowsV3.swift            # Shadow tokens
│   ├── AppGradientsV3.swift          # Gradient tokens (hero cards)
│   ├── PrimaryButtonV3.swift         # V3 primary CTA button
│   ├── HeroCardV3.swift              # Large hero cards with photo/gradient
│   ├── IOSSegmentedControl.swift     # iOS-style segmented control
│   ├── SectionHeaderV3.swift         # Section headers
│   └── MetricCardV3.swift            # Metric display cards
├── UIComponents/                     # Feature-specific composed components (may reference Models)
│   ├── RoundCardView.swift           # Round cards (depends on Round model)
│   ├── CompactRoundCard.swift        # Compact round card (round-domain API)
│   ├── InvitedRoundCard.swift        # Invited round card
│   ├── PostCardView.swift            # Post cards
│   ├── CommentComposer.swift         # Comment input bar
│   ├── PublicProfileCardView.swift   # Profile summary card
│   ├── ProfilePhotoGrid.swift        # Profile photo grid
│   ├── ProfileIdentitySection.swift  # Profile identity section
│   ├── FilterSummaryViewV3.swift     # Active filter summary
│   ├── ActivityFilterChips.swift     # Activity filter chips
│   ├── CollapsibleSection.swift      # Collapsible content
│   ├── LocationFieldView.swift       # Location input
│   ├── CitySearchSheet.swift         # City search
│   └── RangeSliderView.swift         # Range slider
├── Views/                            # SwiftUI screens (organized by feature)
│   ├── Auth/                         # Sign-in, onboarding carousel
│   ├── Chat/                         # Round chat
│   ├── Feed/                         # Social feed, posts, comments
│   ├── Feedback/                     # Post-round feedback
│   ├── Home/                         # Home tab (V3)
│   ├── Main/                         # MainTabView (root tab bar)
│   ├── Notifications/                # Notifications tab
│   ├── Onboarding/                   # Tier 1 onboarding steps
│   ├── Profile/                      # Profile, editing, gating
│   ├── Rounds/                       # Round CRUD, detail, search, activity
│   ├── Social/                       # Followers list
│   └── Testing/                      # Debug-only test data views + TestDataHelper
├── ViewModels/                       # @MainActor ObservableObject VMs
├── Models/                           # Pure Codable structs + config types
├── Services/                         # Business logic (protocols + concrete implementations)
├── Repositories/                     # Protocol definitions for data access (no Firebase)
├── FirebaseRepositories/             # Firestore/Firebase implementations
├── Utilities/                        # GeoHash, distance, Firestore constants, shared extensions
├── TeePalsApp.swift                  # @main entry, Firebase bootstrap
├── Info.plist
├── TeePals.entitlements
└── GoogleService-Info.plist
```

### Folder Placement Rules

| Folder | What goes here | Key test |
|--------|---------------|----------|
| `UIFoundation/` | Legacy design tokens + generic primitive components | No model dependencies, uses legacy tokens |
| `UIFoundationNew/` | V3 design tokens + generic primitive components | No model dependencies, uses V3 tokens |
| `UIComponents/` | Feature-specific composed components | References domain models OR API is shaped around a specific domain |
| `Models/` | Pure data types (`struct`, `enum`, `Codable`) + config types | No business logic beyond computed properties |
| `Services/` | Business logic, protocols + concrete implementations | Logic that doesn't fit in ViewModels or Repositories |
| `Repositories/` | Protocol definitions for data access | No Firebase imports, no concrete implementations |
| `FirebaseRepositories/` | Concrete Firestore/Firebase implementations | Only layer that imports Firebase (with Services/AuthService and StorageService) |
| `ViewModels/` | Screen-level `@MainActor ObservableObject` VMs | Depend on protocol types, never concrete Firebase |
| `Coordinators/` | Cross-cutting navigation/state coordinators | Not tied to a single screen |
| `Utilities/` | Generic helpers, extensions, constants | No Firebase (except `FirestoreConstants` for collection names) |

---

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
   - Must handle loading/empty/error/success states (use `AsyncContentView`)
   - Keep files under 250 lines — extract subviews into `*Section.swift` files

2. **ViewModels** (`TeePals/ViewModels/`)
   - `@MainActor` classes conforming to `ObservableObject`
   - Depend on Repository **protocols**, never concrete implementations
   - Receive `currentUid` closure from AppContainer
   - Contain presentation logic only
   - Expose `isLoading: Bool`, `errorMessage: String?`, and domain-specific `isEmpty` computed property

3. **Repositories** (`TeePals/Repositories/`)
   - Protocol definitions (e.g., `ProfileRepository`, `RoundsRepository`)
   - Define async/await interfaces for data access
   - No Firebase imports

4. **Firebase Repositories** (`TeePals/FirebaseRepositories/`)
   - Concrete implementations (e.g., `FirestoreProfileRepository`)
   - **Only layer that imports Firebase** (along with `Services/AuthService` and `Services/StorageService`)
   - Handle Firestore queries, encoding/decoding, error mapping

5. **Models** (`TeePals/Models/`)
   - Pure Swift structs, `Codable` for Firestore serialization
   - No business logic beyond computed properties
   - Examples: `PublicProfile`, `PrivateProfile`, `Round`, `Post`, `Comment`

6. **Services** (`TeePals/Services/`)
   - Business logic that doesn't fit in ViewModels or Repositories
   - Protocol-based where possible (`ActivityRoundsService`, `RoundsSearchService`, `StorageServiceProtocol`, `ShareLinkServiceProtocol`, `FeedRankingServiceProtocol`)
   - `AuthService` and `StorageService` are the only non-repository files that import Firebase
   - `ProfileCompletionEvaluator` lives here (evaluates profile tier status)

7. **UIFoundation** (`TeePals/UIFoundation/`) — legacy design system
   - Tokens: `AppColors`, `AppTypography`, `AppSpacing`
   - Components: `AppCard`, `PrimaryButton`, `SecondaryButton`, `AppTextField`, `EmptyStateView`, `SkeletonViews`, `AsyncContentView`
   - Still used by ~40 views — do not delete until migration completes

8. **UIFoundationNew** (`TeePals/UIFoundationNew/`) — V3 design system (target)
   - Tokens: `AppColorsV3`, `AppTypographyV3`, `AppSpacingV3`, `AppShadowsV3`, `AppGradientsV3`
   - Components: `PrimaryButtonV3`, `HeroCardV3`, `CompactRoundCard`, `SectionHeaderV3`, `MetricCardV3`
   - **All new or redesigned screens must use V3 tokens** (see Design System section)

9. **UIComponents** (`TeePals/UIComponents/`)
   - Feature-specific composed components (may reference Models)
   - Reusable across multiple screens but not pure design-system primitives
   - Examples: `RoundCardView`, `PostCardView`, `CachedAsyncImage`, `SelectableChip`

10. **AppContainer** (`TeePals/App/AppContainer.swift`)
    - Dependency injection container
    - Creates repository singletons (lazy)
    - Factory methods for ViewModels (`makeXViewModel()`)
    - Provides `currentUid` closure from Firebase Auth
    - Tab-level VMs cached as `@Published` singletons

---

## Design System Migration

The app is migrating from **UIFoundation** (legacy) to **UIFoundationNew** (V3).

### Status

| Design System | Folder | Token Names | Used By |
|---------------|--------|-------------|---------|
| Legacy | `UIFoundation/` | `AppColors`, `AppTypography`, `AppSpacing` | ~40 views |
| V3 (target) | `UIFoundationNew/` | `AppColorsV3`, `AppTypographyV3`, `AppSpacingV3` | ~10 views |

### Rules

- **New screens / redesigned screens**: Use V3 tokens (`AppColorsV3`, `AppTypographyV3`, `AppSpacingV3`, `PrimaryButtonV3`, etc.)
- **Existing screens not yet redesigned**: Keep using legacy tokens — do not mix V3 and legacy in the same view
- **Generic utilities** (`AsyncContentView`, `EmptyStateView`, `SkeletonViews`, banners): Use legacy tokens since they're consumed by both old and new screens. Will be migrated last.
- **When redesigning a screen**: Switch all token references in that file from legacy → V3 in one pass

### V3 Visual Language

- **Colors**: Forest green palette (`#0B3D2E`), nature-inspired, hex-based
- **Typography**: Playfair Display (serif) for display/headlines, system sans-serif for body
- **Spacing**: Simplified 8/12/16/24 scale
- **Shadows**: Premium green-tinted shadows (`AppShadowsV3`)
- **Gradients**: Forest green hero card overlays (`AppGradientsV3`)

### Screens Already on V3

- `HomeViewV3` (Home tab)
- `OnboardingCarouselView` (Auth)
- `Tier1OnboardingFlow` + all onboarding steps (`NameStepView`, `NicknameStepView`, `GenderStepView`, `BirthdateStepView`, `LocationStepView`)
- `Tier2GatePopup`
- `RoundsView` (partially — uses V3 colors/spacing)
- `NearbyRoundsContent` (partially)

---

## Reusable Patterns

### AsyncContentView (loading/empty/error/content)

Every screen that loads data should use `AsyncContentView` to avoid repeating the loading/error/empty boilerplate:

```swift
AsyncContentView(
    isLoading: viewModel.isLoading,
    errorMessage: viewModel.errorMessage,
    isEmpty: viewModel.items.isEmpty,
    onRetry: { await viewModel.load() },
    loading: { SkeletonList(count: 5) },
    empty: { EmptyStateView.noRounds(onCreate: { }) },
    content: {
        ForEach(viewModel.items) { item in
            // ...
        }
    }
)
```

A convenience initializer uses `SkeletonList` as the default loading state:

```swift
AsyncContentView(
    isLoading: viewModel.isLoading,
    isEmpty: viewModel.items.isEmpty,
    empty: { EmptyStateView.noNotifications },
    content: { /* ... */ }
)
```

### Splitting Large Views

When a view exceeds ~250 lines, extract sections into companion files:

```
RoundDetailView.swift           (main view, navigation, state)
RoundDetailSections.swift       (info sections as extracted subviews)
RoundDetailMembersSection.swift (members section)
RoundDetailMoreSections.swift   (additional sections)
```

Name convention: `{ViewName}Section.swift` or `{ViewName}Sections.swift`.

### ViewModel Ownership

- Parent view owns the ViewModel with `@StateObject`:
  ```swift
  @StateObject private var viewModel: FeedViewModel
  init(viewModel: FeedViewModel) {
      _viewModel = StateObject(wrappedValue: viewModel)
  }
  ```
- Child subviews receive it via `@ObservedObject`
- ViewModels are created by `AppContainer.makeXViewModel()` factories
- Tab-level VMs are cached as singletons in AppContainer

---

## Authentication Flow

- **Sign in with Apple** only (no other providers)
- Firebase Auth UID is canonical user identifier
- States: `loading` → `unauthenticated` / `needsProfile` / `authenticated`
- After auth, checks if `profiles_public/{uid}` exists to determine state

## Profile Gating System

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

Use `ProfileGateCoordinator` (singleton in AppContainer) to check tier status before gated actions. Show `ProfileGateView` or `Tier2GatePopup` if incomplete.

---

## Data Model

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

---

## Critical Rules

### Schema & Firestore
- **Never rename or delete Firestore fields** — all changes must be additive
- Always compute `geo.geohash` atomically with lat/lng when creating or updating locations
- Use `Codable` for Firestore serialization
- Security rules are in `firestore.rules` — respect them

### UI Rules
- No Firebase imports in Views
- No business logic inside `View.body`
- No view files larger than 250 lines — split into section files
- Every screen must support: loading, empty, error, success states (use `AsyncContentView`)
- Use design system tokens instead of inline styling (V3 for new screens, legacy for existing)
- Primary CTA is sticky at bottom when applicable
- Buttons must include disabled, loading, and pressed states

### Code Style
- Use async/await (not callbacks)
- Use `@MainActor` for ViewModels
- Use `@StateObject` for ViewModel ownership, `@ObservedObject` for passed-in VMs
- Files should remain under ~250 lines
- Prefer composition over large files
- ViewModels depend on protocols, never concrete Firebase types

### Navigation

Bottom tab bar (5 tabs):
1. Home (V3 redesigned)
2. Rounds (nearby + activity)
3. Feed (social posts)
4. Notifications
5. Profile

---

## Refactoring Backlog

Tracked issues to address incrementally during UI migration:

### Large View Files (> 250 lines, needs splitting)

| File | Lines | Priority |
|------|-------|----------|
| `ProfileView.swift` | 875 | Critical |
| `PostRoundFeedbackView.swift` | 755 | Critical |
| `PostDetailView.swift` | 614 | Critical |
| `CreatePostView.swift` | 504 | Critical |
| `RoundDetailView.swift` | 441 | High |
| `RoundChatView.swift` | 423 | High |
| `OtherUserProfileView.swift` | 399 | High |
| `FeedView.swift` | 349 | High |
| `NotificationsView.swift` | 348 | High |
| `HomeViewV3.swift` | 337 | High |
| `CommentRowView.swift` | 335 | High |
| `ChatMessageRow.swift` | 313 | High |

**Strategy:** When redesigning a screen with V3 tokens, also split it below 250 lines.

### Large FirebaseRepository Files (needs splitting)

| File | Lines |
|------|-------|
| `FirestoreRoundsRepository.swift` | 970 |
| `FirestorePostsRepository.swift` | 952 |
| `FirestoreGeoHashRoundsSearchService.swift` | 622 |

`FirestoreGeoHashRoundsSearchService` duplicates Round decoding logic — should use `FirestoreRoundDecoder`.

### Remaining Architecture Improvements

- `ActivityRoundsService`, `FollowingRoundsService`, `RoundsSearchService` protocols are in `Services/` but act as repository interfaces — consider renaming/moving to `Repositories/`
- `UserStats.computeIsNewAuthor(config:)` has business logic in a model — consider moving to `FeedRankingService`

### TODOs in Code

14 TODO comments scattered across the codebase. Address as encountered during feature work.

---

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

---

## Common Patterns

### Creating a new feature with data access

1. Define a protocol in `Repositories/` (e.g., `ExampleRepository`)
2. Create Firestore implementation in `FirebaseRepositories/` (e.g., `FirestoreExampleRepository`)
3. Add repository to `AppContainer` as lazy singleton
4. Create ViewModel in `ViewModels/` that depends on protocol
5. Add ViewModel factory method to `AppContainer`
6. Create View in `Views/` using V3 design system components
7. Use `AsyncContentView` for loading/error/empty states
8. Update Firestore security rules in `firestore.rules`

### Adding a new screen

1. Create View in appropriate `Views/` subdirectory
2. Use `@StateObject` to instantiate ViewModel via `container.makeXViewModel()`
3. Inject `@EnvironmentObject var container: AppContainer`
4. Wrap content in `AsyncContentView` for state handling
5. Use V3 design system tokens (`AppColorsV3`, `AppTypographyV3`, `AppSpacingV3`)
6. Keep file under 250 lines — extract sections into `*Section.swift` files

### Redesigning an existing screen

1. Switch all token references from legacy → V3 in one pass
2. Split the view if it exceeds 250 lines
3. Adopt `AsyncContentView` if still using manual loading/error/empty pattern
4. Verify all four states still work after migration

---

## Branding

**App Name:** TeePals
**Slogan:** "Golf, better together."

Do not invent alternative slogans or taglines.
