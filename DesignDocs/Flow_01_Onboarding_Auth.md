# Flow 01: Onboarding & Authentication

**Purpose**: Get new users from first launch to fully participating member

---

## Overview

New users must complete a 2-tier onboarding process:
- **Tier 1**: Required immediately (nickname, location, birthdate, gender) – Gates app access
- **Tier 2**: Required for participation (photo, skill level) – Gates social actions

---

## User Goals

**Primary**: Complete profile setup to start finding golf rounds
**Secondary**: Understand what TeePals is about, feel excited to use it

---

## Entry Points

1. **First app launch** → Onboarding carousel
2. **Logged out state** → Sign in screen
3. **Incomplete profile** → Resume onboarding at first missing field

---

## Flow Steps

### Step 1: Onboarding Carousel (NEW USERS ONLY)

**Purpose**: Show value proposition before requiring sign-in

**Screens**: 3 poster carousel with swipeable horizontal navigation

**Poster 1**: Find Your **Next Round**
- Background: Golf course photo
- Gradient overlay (black, bottom-heavy)
- Headline: "Find Your **Next Round**" (green highlight on "Next Round")
- Subheading: "Find nearby rounds and meet golfers who match your vibe"
- Sign in with Apple button (below carousel)

**Poster 2**: Host Like a **Pro**
- Background: Golf course photo
- Gradient overlay
- Headline: "Host Like a **Pro**" (green highlight on "Pro")
- Subheading: "Organize rounds and build the perfect group"
- Sign in with Apple button (below carousel)

**Poster 3**: Golf is Better **Together**
- Background: Golf course photo
- Gradient overlay
- Headline: "Golf is Better **Together**" (green highlight on "Together")
- Subheading: "Connect, share your game, and build your golf circle"
- Sign in with Apple button (below carousel)

**Components**:
- Full-screen background images
- Static gradient overlay (doesn't rebuild on swipe)
- Page indicators (dots, green)
- Sign in with Apple button (persistent on all 3 posters)

**Interaction**:
- Horizontal swipe between posters
- Infinite loop (Poster 3 → Poster 1)
- Tap "Sign in with Apple" → Firebase Auth flow

**Current Implementation**: ✅ Completed
- Location: `Views/Auth/OnboardingCarouselView.swift`
- Status: Working, smooth transitions

---

### Step 2: Apple Sign-In

**Purpose**: Authenticate user securely

**Flow**:
1. User taps "Sign in with Apple"
2. Native Apple Sign-In sheet appears
3. User authenticates with Face ID / Touch ID / Password
4. Firebase Auth creates account (or signs in existing user)
5. App checks: Does `profiles_public/{uid}` exist?
   - **No** → Start Tier 1 onboarding
   - **Yes** → Check profile completeness
     - Tier 1 incomplete → Resume Tier 1
     - Tier 1 complete, Tier 2 incomplete → User can browse but gets gated
     - Both complete → Go to Home

**Components**:
- Native SignInWithAppleButton (Apple)
- Loading indicator during auth

**Current Implementation**: ✅ Completed

---

### Step 3: Tier 1 Onboarding Wizard

**Purpose**: Collect required information immediately

**Format**: One question per screen, locked order

**Progress Indicator**: "1/4", "2/4", etc.

**Screens**:

#### 3.1: Nickname
- **Title**: "What should we call you?"
- **Input**: Text field (AppTextField)
- **Validation**: 2-30 characters, alphanumeric + spaces
- **CTA**: "Continue" (sticky bottom, disabled until valid)
- **Helper**: "This is how other golfers will see you"

#### 3.2: Birthdate
- **Title**: "When's your birthday?"
- **Input**: Date picker (wheel style)
- **Validation**: Must be 13+ years old
- **CTA**: "Continue"
- **Helper**: "We keep this private (age verification only)"

#### 3.3: Location
- **Title**: "Where do you usually golf?"
- **Input**: City search (autocomplete)
- **Validation**: Must select valid city from results
- **CTA**: "Continue"
- **Helper**: "We'll show you rounds nearby"
- **Technical**: Stores city label + GeoPoint coordinates

#### 3.4: Gender
- **Title**: "How do you identify?"
- **Input**: Radio buttons
  - Male
  - Female
  - Non-binary
  - Prefer not to say
- **CTA**: "Complete Setup"
- **Helper**: "This helps build diverse groups"

**Components**:
- `AppTextField` for nickname
- Native DatePicker for birthdate
- Search field + results list for location
- Radio button group for gender
- `PrimaryButton` for CTA
- Progress indicator (top)

**Transition**: Smooth slide animations between screens

**Current Implementation**: ✅ Completed (needs visual polish)

---

### Step 4: Tier 2 Gate (ON DEMAND)

**Purpose**: Require photo + skill level before participation

**Trigger**: User attempts gated action (join round, create post, etc.)

**Modal**: ProfileGateView

**Content**:
- **Title**: "Complete Your Profile"
- **Message**: "To join rounds and connect with golfers, please add:"
- **Checklist**:
  - ☐ Profile photo
  - ☐ Skill level
- **CTA**: "Add Photo & Skill Level"
- **Dismiss**: X button (returns to previous screen)

**Flow After CTA**:
1. Navigate to Profile Edit screen
2. User adds photo(s) and selects skill level
3. User saves changes
4. Modal dismisses
5. User returns to original intended action
6. Action now allowed

**Components**:
- Bottom sheet modal
- Checklist with checkmarks (green when complete)
- `PrimaryButton`

**Current Implementation**: ✅ Completed

---

## Key Components Used

- `OnboardingCarouselView` – 3-poster carousel
- `OnboardingPosterView` – Individual poster
- `SignInWithAppleButton` – Native Apple component
- `AppTextField` – Text input
- `PrimaryButton` – CTAs
- `ProfileGateView` – Tier 2 gate modal
- Progress indicators
- Radio button groups
- Date picker
- City search autocomplete

---

## States

### Loading
- Show spinner during Apple Sign-In
- Show spinner during profile check
- Show spinner during save

### Empty
- N/A (onboarding is required)

### Error
- Apple Sign-In failed → Show error banner with retry
- Network error during save → Show error, allow retry
- Invalid input → Inline error below field

### Success
- Smooth transition to next screen
- No explicit success message (flow continues)
- Final screen → Navigate to Home

---

## Edge Cases

### User Closes App Mid-Onboarding
- Resume from first incomplete field on next launch
- Don't make user start over

### User Changes Apple ID
- Treat as new user, start onboarding fresh

### Network Failure During Save
- Show error message
- Keep user on current screen
- Allow retry without losing entered data

### Invalid Location Search
- Show "No results found"
- Allow user to try different search
- Require valid city selection (can't proceed with freeform text)

### Underage User (< 13)
- Show error: "You must be 13+ to use TeePals"
- Don't create account
- Return to sign-in screen

---

## Current Implementation

### What's Working Well
✅ Carousel transitions are smooth
✅ Sign in with Apple integration
✅ Tier 1 wizard flow complete
✅ Profile gating system functional

### What Needs Improvement
- [ ] Visual polish on Tier 1 wizard screens
- [ ] Better input validation feedback
- [ ] Smooth transitions between wizard steps
- [ ] Tier 2 modal styling could be more engaging
- [ ] City search UX could be improved (current implementation unclear)

---

## Open Questions for Designer

1. **Onboarding carousel**:
   - Should we add animations when swiping (parallax, fade)?
   - Should we add a "Skip" option for returning users?

2. **Tier 1 wizard**:
   - Should there be illustrations/icons for each question?
   - Should we show a preview of what the profile will look like?
   - Should we animate between steps (slide, fade, etc.)?

3. **City search**:
   - How should autocomplete results appear?
   - Should we show a map preview of selected city?
   - Should we allow "Use Current Location" option?

4. **Tier 2 gate**:
   - Should we show examples of good profile photos?
   - Should we gamify completion (progress bar, badge)?
   - How prominent should this gate be vs. letting users explore first?

5. **Overall flow**:
   - Is 4 steps for Tier 1 too many? Should we combine any?
   - Should we show estimated time ("2 minutes to complete")?
   - Should there be a celebration/welcome screen after completion?

---

**Related Flows**:
- Flow 07: Profile (for editing profile after onboarding)
- Flow 02: Home Dashboard (first screen after onboarding)
