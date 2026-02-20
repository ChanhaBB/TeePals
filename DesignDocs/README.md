# TeePals Design Documentation

**Purpose**: Comprehensive design requirements for TeePals iOS app redesign

**Created**: February 2026
**Platform**: iOS (SwiftUI)

---

## 📚 Documentation Structure

This design documentation package is organized into:
1. **Master Overview** – Project context, principles, design system
2. **Individual Flow Documents** – Detailed requirements for each user flow

---

## 📖 How to Use This Documentation

### For Designers
1. **Start with**: `TeePals_Design_Overview.md` – Get project context
2. **Then read**: Individual flow documents for screens you're designing
3. **Reference**: Current implementation notes to see what exists
4. **Ask**: Open questions at the end of each document

### For Developers
- Use flow documents as implementation specs
- Reference "Current Implementation" sections
- Check "What Needs Improvement" for known issues
- Follow component references to UIFoundationNew

### For Product/PM
- Review flows for completeness
- Identify missing requirements
- Prioritize "Open Questions" that need decisions

---

## 📄 Master Document

**[TeePals_Design_Overview.md](TeePals_Design_Overview.md)**
- Product vision and principles
- Navigation structure (5 tabs)
- Profile gating system (Tier 1 & 2)
- Design system reference (UIFoundationNew)
- Visual direction and brand
- Technical constraints
- Privacy and content safety

**Read this first** to understand the overall product.

---

## 🔄 User Flow Documents

### Core Flows (Must-Have)

#### [Flow 01: Onboarding & Authentication](Flow_01_Onboarding_Auth.md)
**Status**: ✅ Implemented, needs polish
**Covers**:
- Onboarding carousel (3 posters)
- Sign in with Apple
- Tier 1 wizard (nickname, location, birthdate, gender)
- Tier 2 gate (photo, skill level)

**Key Screens**: Carousel (3), Sign In, Wizard (4 steps), Profile Gate

---

#### [Flow 02: Home Dashboard](Flow_02_Home_Dashboard.md)
**Status**: ✅ Polished reference implementation
**Covers**:
- Dashboard overview (next round, action center, nearby rounds)
- Hero cards (with/without next round)
- Metric cards (invites, requests)
- Section headers

**Key Screens**: Home Dashboard (1)

**Note**: This is the **reference design** for TeePals' polished UI.

---

#### [Flow 03: Rounds Discovery & Browse](Flow_03_Rounds_Discovery.md)
**Status**: ✅ Mostly implemented, needs polish
**Covers**:
- Browse nearby rounds (geohash search)
- Filter by distance and date
- Sort by distance or date
- My Activity tab (hosting, attending, invited, requested)

**Key Screens**: Rounds Browse, Filter Sheet, Activity Sections

---

#### [Flow 04: Round Detail](Flow_04_Round_Detail.md)
**Status**: ✅ Functional, needs redesign
**Covers**:
- View round details (course, date, participants)
- Join/request actions (varies by user role)
- Host management (requests, invites, edit, cancel)
- Member actions (leave, accept invite)

**Key Screens**: Round Detail, Requests Sheet, Invite Friends Sheet

---

#### [Flow 07: Profile View & Edit](Flow_07_Profile.md)
**Status**: ✅ Functional, needs redesign
**Covers**:
- Own profile (view, edit, stats)
- Other user profiles (follow/unfollow)
- Photo carousel (up to 6 photos)
- Golf stats and social metrics
- Followers/following lists

**Key Screens**: Profile View, Profile Edit, Followers List

---

#### [Flow 06: Feed & Social Posts](Flow_06_Feed_Social.md)
**Status**: ✅ Implemented, needs polish
**Covers**:
- Social feed (all posts / friends only)
- Create posts (text + photos, link rounds)
- Upvote and comment on posts
- Nested comments (1 level)

**Key Screens**: Feed, Create Post, Post Detail, Edit Post

---

#### [Flow 09: Create Round](Flow_09_Create_Round.md)
**Status**: ✅ Functional, needs polish
**Covers**:
- Create new golf round
- Course search (Google Places API)
- Date/time, participants, cost
- Form validation and submission

**Key Screens**: Create Round Form (1)

---

### Future Flows (Planned)

#### [Flow 08: Notifications](Flow_08_Notifications.md)
**Status**: 📋 Phase 5 – Not implemented
**Covers**:
- In-app notification center
- Push notifications
- Notification types (requests, social, system)
- Deep linking from notifications

**Key Screens**: Notifications List

---

#### [Flow 10: Round Chat](Flow_10_Round_Chat.md)
**Status**: 📋 Phase 3 – Not implemented
**Covers**:
- Group chat for accepted round participants
- Real-time messaging
- System messages (join/leave/changes)
- Future: Photo sharing, reactions

**Key Screens**: Chat Screen

---

## 🎨 Design System

All new designs should use **UIFoundationNew**:

**Location**: `/Users/chanhak/TeePals/TeePals/UIFoundationNew/`

**Documentation**: `UIFoundationNew/README.md`

**Key Files**:
- `AppTypographyV2.swift` – Typography tokens
- `AppShadows.swift` – Shadow system
- `AppSpacingV2.swift` – Spacing and radii
- `DashboardSectionHeader.swift` – Reusable section headers
- `DashboardMetricCard.swift` – Metric/action cards
- `DashboardHeroCard.swift` – Hero card pattern

**See Flow 02 (Home Dashboard) for reference implementation.**

---

## ✅ Implementation Status

### ✅ Completed (Phases 0-4.1)
- Onboarding and authentication
- Profile system (Tier 1 & 2 gating)
- Rounds creation and discovery
- Request/invite system
- Social feed (posts, comments, upvotes)
- Follow/unfollow system
- Home dashboard (polished)

### 🚧 In Progress (Phase 4.2)
- Advanced feed ranking algorithm
- Feed pagination and scoring

### 📋 Planned (Phase 5-6)
- Notifications system (Phase 5)
- Round chat (Phase 3)
- UI polish pass (Phase 6)
- Performance optimization (Phase 6)

---

## 🎯 Design Priorities

### High Priority (Redesign Needed)
1. **Round Detail** – Most complex screen, needs full redesign
2. **Rounds Browse/Filter** – Core discovery flow, needs polish
3. **Profile View** – Identity showcase, needs visual upgrade
4. **Create Round** – Critical conversion point, simplify UX

### Medium Priority (Polish Needed)
5. **Feed** – Functional but needs visual consistency
6. **Onboarding Wizard** – Works but could be more engaging
7. **Profile Edit** – Form layout needs improvement

### Low Priority (Reference Quality)
8. **Home Dashboard** – Already polished, use as reference

---

## ❓ Key Open Questions

Questions that need product/design decisions:

### User Experience
- Should rounds have a map view option?
- Should we add skeleton loaders vs. spinners?
- How should we handle "full" rounds visually?
- Should photo carousels support reordering?

### Features
- Should notifications be batched or real-time?
- Should chat remain after round completes?
- Should we add reactions beyond upvote?
- Should rounds support flexible scheduling?

### Visual Design
- Cover photo + avatar vs. photo carousel?
- Card shadows: subtle vs. prominent?
- Button styles: filled vs. outline?
- Empty states: illustrations vs. icons?

**See individual flow documents for complete lists.**

---

## 📦 Deliverables Needed

For each flow, we need:
1. **User flow diagram** – Steps and decision points
2. **Screen designs** – High-fidelity mockups (light + dark mode)
3. **Component specs** – Dimensions, spacing, states
4. **Interaction specs** – Animations, transitions, gestures
5. **Edge cases** – Empty, error, loading states
6. **Responsive behavior** – Different iPhone sizes

---

## 🚀 Next Steps

1. **Designer**: Review master overview + prioritized flows
2. **Stakeholders**: Answer open questions in each flow doc
3. **Designer**: Create designs based on specs
4. **Team**: Review designs against requirements
5. **Developer**: Implement using UIFoundationNew components

---

## 📞 Questions?

For clarification on any flow or requirement, refer to:
- Product spec: `TEE_PALS_DESIGN_DOC_V2.md`
- UI rules: `UI_RULES.md`
- Development phases: `PHASES.md`
- Design system: `UIFoundationNew/README.md`

---

**Version**: 1.0
**Last Updated**: February 13, 2026
