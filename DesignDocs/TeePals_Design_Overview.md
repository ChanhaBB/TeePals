# TeePals – Design Overview

**Version:** 1.0
**Date:** February 2026
**Platform:** iOS (SwiftUI)

---

## Product Vision

**TeePals** is a golf social platform focused on forming **real-life rounds**.

### Tagline
**"Golf, better together."**

### Core Principles
1. **Rounds are the core object** – Everything revolves around creating and joining real golf rounds
2. **Trust and safety over virality** – Quality connections over growth hacking
3. **Private-by-default identity** – Users control what they share
4. **Social features emerge from real play** – Community builds through actual golf
5. **Additive development** – No breaking changes, always forward

---

## User Journey Overview

### New User
1. **Sign in** with Apple
2. **Complete Tier 1 profile** (name, location, birthdate, gender) – Required immediately
3. **Browse rounds** – Can view but not join yet
4. **Complete Tier 2 profile** (photo, skill level) – Required to participate
5. **Join or host rounds** – Now fully unlocked
6. **Build golf circle** – Follow users, engage with posts
7. **Repeat play** – Build reputation and friendships

### Returning User
1. **View home dashboard** – See next round, action center, nearby rounds
2. **Check activity** – Manage hosting/attending rounds
3. **Browse feed** – Engage with golf community
4. **Respond to notifications** – Accept requests, respond to invites

---

## Navigation Structure (LOCKED)

Bottom tab bar with 5 tabs:

1. **Home** 🏠
   - Dashboard view
   - Next upcoming round (hero card)
   - Action center (invites, requests)
   - Nearby rounds preview

2. **Rounds** ⛳
   - Browse all rounds
   - Filter by distance, date

3. **Feed** 📰
   - Social posts from golf community
   - Toggle: All posts / Friends only
   - Create post, like, comment

4. **Notifications** 🔔
   - Round requests, acceptances
   - Invites, social activity
   - System notifications

5. **Profile** 👤
   - View/edit own profile
   - View other profiles
   - Followers/following lists
   - Settings

---

## Profile Gating System

TeePals uses a **tiered profile system** to ensure trust and safety.

### Tier 1 (Required Immediately After Sign-In)
Users **cannot proceed** until completing:
- Nickname
- Primary city/location
- Birthdate (stored privately)
- Gender (prefer_not_to_say allowed)

### Tier 2 (Required for Social Actions)
Users can browse but **cannot participate** until completing:
- At least 1 profile photo
- Skill level

### Gated Actions (Require Tier 2)
- Request/join rounds
- Create/edit/cancel rounds
- Follow/unfollow users
- Invite users to rounds
- Accept/decline join requests
- Read/write round chat
- Like/comment on posts
- Create posts

### Enforcement
- Show **ProfileGateView modal** with checklist when user attempts gated action
- Return user to intended action after completion

---

## Key Terminology

| Term | Definition |
|------|------------|
| **Round** | A golf outing (9 or 18 holes) with date, time, course, and participants |
| **Host** | User who created the round |
| **Member** | Participant in a round (various statuses) |
| **Golf Pal** | Any other user on TeePals |
| **Friend** | Mutual follow (both users follow each other) |
| **Requested** | User asked to join, waiting for host approval |
| **Invited** | Host invited user, waiting for user acceptance |
| **Accepted** | User is confirmed for the round |
| **Declined** | User/host declined participation |
| **Skill Level** | Beginner, Intermediate, Advanced |
| **Distance** | Miles from user's primary location |

---

## Design System Reference

TeePals uses **UIFoundationNew** for all new UI work.

### Design Tokens

**Typography** (`AppTypographyV2`)
- Display: `.displayHeavy` (24pt heavy), `.displayLarge` (26pt bold)
- Section headers: `.sectionHeader` (20pt bold)
- Body: `.bodyMedium` (15pt medium), `.bodyRegular` (15pt regular)
- Labels: `.labelBoldUppercase` (11pt bold), `.labelMedium` (13pt)
- Buttons: `.buttonSemibold` (16pt), `.buttonMedium` (15pt)
- Links: `.linkSemibold` (14pt semibold)

**Shadows** (`AppShadows`)
- `.cardShadow()` – Standard cards
- `.heroShadow()` – Hero cards, prominent elements
- `.buttonShadow()` – Primary CTAs
- `.smallShadow()` – Avatars, chips

**Spacing** (`AppSpacingV2`)
- Section spacing: `.sectionCompact` (20pt)
- Item spacing: `.itemCompact` (12pt)
- Button padding: `.buttonHorizontalLarge` (24pt), `.buttonVerticalLarge` (14pt)
- Corner radius: `.cardRadius` (14pt), `.buttonRadiusMedium` (12pt)

**Colors** (`AppColors`)
- Primary: Forest green
- Background: `.backgroundGrouped`, `.surface`
- Text: `.textPrimary`, `.textSecondary`, `.textTertiary`

### Reusable Components

1. **DashboardSectionHeader** – Section titles with optional "View All" link
2. **DashboardMetricCard** – Metric cards (shows "Will appear here" when count is 0)
3. **DashboardHeroCard** – Full-width cards with background image and gradient overlay
4. **RoundCardView** – Compact round preview card
5. **ProfileAvatarView** – User profile photo
6. **EmptyStateView** – Empty states with icon, title, message, CTA
7. **PrimaryButton** / **SecondaryButton** – Standard buttons with loading/disabled states

---

## Visual Direction

### Brand Colors
- **Primary**: Forest green (golf-inspired)
- **Accent**: Light green tint for highlights
- **Gradients**: Fairway gradient (green tones)

### Visual Style
- **Premium but approachable** – Clean, modern iOS design
- **Card-based layouts** – Grouped content in cards with shadows
- **Hero imagery** – Course photos where available
- **Clear hierarchy** – Bold section headers, proper spacing

### Photography
- Golf courses (via Google Places API)
- User profile photos (up to 6)
- Post photos (up to 4 per post)

---

## Technical Constraints

### SwiftUI Implementation
- All views built in SwiftUI (no UIKit unless necessary)
- Design must be implementable with SwiftUI components
- No Firebase imports in View files

### Performance
- Views must be under **250 lines** per file
- No business logic in `View.body`
- Avoid real-time listeners for large lists
- Use pagination for long lists

### UI States (Required for Every Screen)
1. **Loading** – Show skeleton or progress indicator
2. **Empty** – Use EmptyStateView with clear CTA
3. **Error** – Show error message with retry option
4. **Success** – Display content

### Component Reuse
- Must use UIFoundationNew tokens instead of hardcoded values
- No inline styling where a component exists
- No repeated patterns – extract to reusable components

---

## User Experience Principles

### Clarity Over Cleverness
- Clear labels and actions
- No hidden gestures
- Obvious navigation

### Progressive Disclosure
- Show essential info first
- Details available on demand
- Don't overwhelm with options

### Feedback & Confirmation
- Loading states for async actions
- Success confirmation (toast/banner)
- Destructive actions require confirmation

### Accessibility
- Support dark mode
- Reasonable Dynamic Type support
- Maintain WCAG contrast ratios
- Clear tap targets (min 44pt)

---

## Data Privacy

### What Users See
- **Public**: Nickname, photos, bio, location (city level), skill level, age decade
- **Private**: Exact birthdate, contact info (never shared)

### Location Privacy
- Only city-level location shown publicly
- Exact coordinates used for distance calculations (not shown)
- Course locations shown for rounds

### Photo Privacy
- User controls which photos to upload (up to 6)
- Photos appear in profile and posts
- No automatic photo access

---

## Content Safety

### Community Guidelines
- Golf-focused content
- Respectful communication
- No harassment or hate speech
- No spam or commercial promotion (unless authorized)

### Moderation (Future)
- Report post/comment/profile
- Host can remove participants
- Block/unfollow users

---

## Current Implementation Status

### ✅ Completed (Phase 1-4.1)
- Sign in with Apple
- Onboarding (Tier 1 & 2)
- Profile view/edit
- Follow/unfollow system
- Create/browse/join rounds
- Activity management (hosting, attending, requests)
- Social feed (posts, comments, upvotes)
- Profile posts tab
- Followers/following lists

### 🚧 In Progress (Phase 4.2)
- Advanced feed ranking algorithm
- Feed pagination and scoring
- New creator discovery

### 📋 Planned (Phase 5-6)
- Push notifications
- Round chat
- UI polish pass
- Performance optimization
- Analytics

---

## Design Deliverables Needed

For each flow, we need:
1. **User flow diagram** – Steps and decision points
2. **Screen designs** – High-fidelity mockups for each screen
3. **Component specs** – Dimensions, spacing, states
4. **Interaction specs** – Tap targets, transitions, animations
5. **Edge cases** – Empty states, errors, loading
6. **Responsive behavior** – Different screen sizes
7. **Dark mode** – All screens in dark mode

---

## Reference Materials

- **Design system**: `UIFoundationNew/README.md`
- **UI rules**: `UI_RULES.md`
- **Product spec**: `TEE_PALS_DESIGN_DOC_V2.md`
- **Development phases**: `PHASES.md`
- **Current screenshots**: See flow documents

---

## Questions for Designer

Before starting each flow, consider:
1. What existing patterns should we maintain?
2. What needs improvement or redesign?
3. Are there new patterns/components to introduce?
4. How does this flow connect to others?
5. What edge cases need visual treatment?

---

**Next Steps**: Review individual flow documents for detailed requirements.
