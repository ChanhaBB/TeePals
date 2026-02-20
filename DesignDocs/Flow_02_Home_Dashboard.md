# Flow 02: Home Dashboard

**Purpose**: Provide at-a-glance overview of user's golf activity and opportunities

---

## Overview

The Home tab is the landing screen after onboarding. It aggregates:
- User's next upcoming round (or prompt to find one)
- Action items (new invites, pending requests)
- Nearby rounds preview

This is the **reference implementation** for TeePals' polished UI design.

---

## User Goals

**Primary**: Quickly see "what's next" in my golf life
**Secondary**: Discover new rounds nearby, manage action items

---

## Entry Points

1. **Tap Home tab** (bottom navigation)
2. **App launch** (default landing for authenticated users)
3. **Pull to refresh** (reload dashboard data)

---

## Screen Layout

### Header Section
**Purpose**: Personalized greeting + quick profile access

**Components**:
- **Date label**: "FEB 13, THURSDAY" (11pt bold, uppercase, tracking 1.5pt, tertiary text)
- **Greeting**: "Good Morning, [Nickname]" (24pt heavy, primary text)
  - Time-based: "Good Morning" (< 12pm), "Good Afternoon" (12-6pm), "Good Evening" (6pm+)
- **Profile avatar**: Circular photo (48pt, white 2pt border, small shadow)

**Layout**: HStack, left-aligned greeting, right-aligned avatar

**Spacing**: 40pt top padding, 20pt horizontal padding

**Current Implementation**: ✅ Completed
- Location: `Views/Home/HomeView.swift:63-91`
- Uses: `AppTypographyV2.displayHeavy`, `AppSpacingV2.dashboardHeaderTop`

---

### Hero Card: Next Round

**Purpose**: Highlight user's next upcoming golf round

**Variants**:
1. **With next round** → Show `NextRoundHeroCard`
2. **No upcoming rounds** → Show `EmptyNextRoundCard`

#### Variant 1: NextRoundHeroCard

**Background**:
- Course photo (from Google Places API) with gradient overlay
- Fallback: Fairway gradient if no photo

**Badge** (top left):
- "HOSTING" (if user is host) with star icon
- "CONFIRMED" (if user is attending) with checkmark icon
- Pill shape, white text on semi-transparent white background

**Content**:
- **Course name**: 28pt bold, white, 2 lines max
- **Date/time**: "Tomorrow at 2:00 PM" with calendar icon (14pt, white 90% opacity)
- **CTA button**: "View Details" (16pt semibold, white text, green background, 24pt horizontal padding, 14pt vertical padding, 12pt radius, button shadow)

**Dimensions**: 280pt height, 14pt corner radius, hero shadow

**Interaction**: Entire card is tappable → Navigate to Round Detail

**Current Implementation**: ✅ Completed
- Location: `Views/Home/NextRoundHeroCard.swift`
- Uses: `DashboardHeroCard` pattern, `AppShadows.heroShadow()`

#### Variant 2: EmptyNextRoundCard

**Background**: Fairway gradient (green tones)

**Content** (centered):
- **Icon**: figure.golf (52pt, white 95% opacity)
- **Title**: "Ready to Play?" (26pt bold, white)
- **Subtitle**: "Find your first round or host one for friends" (15pt medium, white 90%, center-aligned)
- **Dual CTAs**:
  - "Find Rounds" (15pt semibold, white text, semi-transparent background, 20pt horizontal padding, 12pt vertical padding, 10pt radius)
  - "Host Round" (15pt semibold, green text, white background, subtle shadow)

**Dimensions**: 280pt height, 14pt corner radius, hero shadow

**Interaction**:
- "Find Rounds" → Switch to Rounds tab
- "Host Round" → Open create round sheet

**Current Implementation**: ✅ Completed
- Location: `Views/Home/EmptyNextRoundCard.swift`
- Uses: `AppTypographyV2.displayLarge`, `AppSpacingV2` tokens

---

### Action Center Section

**Purpose**: Show actionable items requiring user attention

**Header**:
- "Action Center" (20pt bold, primary text)
- No action link (always visible)

**Metric Cards**: 2 cards in HStack, equal width

#### Card 1: New Invites
- **Icon**: envelope.fill (24pt, green on light green circle if count > 0, gray on gray if 0)
- **Metric**:
  - If count > 0: Show number (32pt bold, primary text)
  - If count = 0: Show "Will appear here" (14pt medium, tertiary text)
- **Label**: "NEW INVITES" (11pt bold, uppercase, tracking 0.5pt, secondary text)
- **Notification dot**: Red 8pt circle (top right) if count > 0

**Interaction**: Tap → Navigate to Activity tab, Invites section

#### Card 2: Pending Requests
- **Icon**: clock.fill
- **Metric**: Same logic as Card 1
- **Label**: "PENDING REQUESTS"
- **Notification dot**: None (informational only)

**Interaction**: Tap → Navigate to Activity tab, Pending section

**Card Styling**:
- 140pt height
- White background (surface color)
- 14pt corner radius
- 1pt border (border color)
- Card shadow (8pt radius, 3pt y offset)

**Spacing**: 12pt between cards, 20pt horizontal padding

**Current Implementation**: ✅ Completed
- Location: `Views/Home/ActionCenterCard.swift` (renamed to `DashboardMetricCard`)
- Uses: `DashboardMetricCard` component from UIFoundationNew

---

### Nearby Rounds Section

**Purpose**: Preview 3 closest rounds to encourage discovery

**Header**:
- "Nearby for You" (20pt bold, primary text)
- "View All" link (14pt semibold, green) → Navigate to Rounds tab

**Content**:
- List of up to 3 `RoundCardView` components
- 12pt spacing between cards
- If no rounds nearby: Don't show this section at all

**Round Card** (existing component):
- Course name + city
- Date + time
- Distance from user
- Slots remaining
- Host mini-profile
- Compact layout (~120pt height)

**Interaction**: Tap round → Navigate to Round Detail

**Current Implementation**: ✅ Completed
- Location: `Views/Home/HomeView.swift:151-180`
- Uses: Existing `RoundCardView` component

---

## Data Loading

### On Load
1. Fetch user's public profile (need location for nearby search)
2. In parallel:
   - Fetch hosting rounds (next 30 days)
   - Fetch requested rounds (next 30 days, accepted only)
   - Search nearby rounds (30 miles radius, next 30 days, limit 3)
3. Process activity data to determine next round
4. Count pending invites (TODO: not yet implemented)
5. Count pending requests (status = requested)

### Next Round Logic
- Find soonest future round from:
  - Hosting rounds (user is host)
  - Accepted requested rounds (user is attending)
- Compare start times, show soonest
- If none: Show empty state

### Refresh
- Pull to refresh reloads all data
- Loading indicator during refresh
- Optimistic UI (don't clear data while refreshing)

**Current Implementation**: ✅ Completed
- Location: `ViewModels/HomeViewModel.swift`
- Uses: `ActivityRoundsService`, `RoundsSearchService`, `ProfileRepository`

---

## Key Components Used

### From UIFoundationNew
- `DashboardSectionHeader` – Section titles with optional action
- `DashboardMetricCard` – Action center cards
- `AppTypographyV2` – All text styling
- `AppShadows` – Card and button shadows
- `AppSpacingV2` – Spacing and padding

### From UIFoundation
- `AppColors` – Color tokens
- `ProfileAvatarView` – User avatar
- `RoundCardView` – Round preview cards
- `EmptyStateView` – Error states

---

## States

### Loading
- First load: Show spinner + "Loading dashboard..." (center screen)
- Subsequent loads (refresh): Show optimistic UI with refresh indicator

### Empty (No next round)
- Show `EmptyNextRoundCard` with dual CTAs
- Action center still shows (even with 0 counts)
- Hide nearby section if no rounds

### Error
- Network error: Show EmptyStateView with retry button
- Partial failure: Show what loaded successfully

### Success
- All sections populated
- Smooth animations on data load

---

## Edge Cases

### First-Time User (No Rounds Yet)
- Show empty next round card
- Action center shows 0s with "Will appear here"
- Nearby section may show rounds (if any available)

### No Nearby Rounds (Remote Location)
- Hide "Nearby for You" section entirely
- Empty card emphasizes "Find Rounds" CTA

### Network Offline
- Show error state with retry
- Cache last loaded data if possible

### Profile Photo Missing
- Header avatar section doesn't render
- Rest of dashboard works normally

### Next Round is Today
- Date shows "Today at 2:00 PM" (not "Feb 13 at 2:00 PM")

### Multiple Rounds Same Day
- Show only the soonest one
- Other rounds accessible via Rounds tab

---

## Current Implementation

### What's Working Well
✅ Clean, polished visual design
✅ Proper use of design system tokens
✅ Smooth data loading with parallel requests
✅ Smart empty states ("Will appear here")
✅ Clear visual hierarchy
✅ Consistent shadows and spacing
✅ Optimistic loading (refresh doesn't clear data)

### What Needs Improvement
- [ ] Invite counting not implemented (hardcoded to 0)
- [ ] Navigation from action cards not wired up
- [ ] "Host Round" button doesn't open sheet yet
- [ ] Round card taps don't navigate to detail
- [ ] No skeleton loading states (just spinner)
- [ ] Course photo loading could be cached better
- [ ] No haptic feedback on interactions

---

## Open Questions for Designer

1. **Header**:
   - Should avatar be tappable (navigate to own profile)?
   - Should there be additional quick actions (notifications bell, settings)?

2. **Hero card**:
   - Should we show more details (participant count, distance)?
   - Should there be a swipeable carousel if multiple upcoming rounds?
   - Should empty state offer "Explore Popular Courses" as 3rd option?

3. **Action center**:
   - Should we add more metric cards (rounds played this month, new pals)?
   - Should cards have different layouts based on content type?
   - Should we show a preview of actual invites (not just count)?

4. **Nearby rounds**:
   - Should we show a map view toggle option?
   - Should we show "Just posted" badges for very recent rounds?
   - Should there be quick-join actions from cards?

5. **Overall**:
   - Should there be a "Getting Started" checklist for new users?
   - Should we add pull-to-refresh hint animation?
   - Should there be skeleton loaders instead of spinner?
   - Should sections be collapsible?

---

## Design Assets Needed

1. **Hero card backgrounds** – More placeholder gradients or default course images
2. **Empty state illustrations** – Consider custom illustration for empty next round
3. **Action icons** – Custom icons for invite/request actions?
4. **Loading states** – Skeleton loaders for each section
5. **Animations** – Subtle entrance animations for cards

---

**Related Flows**:
- Flow 03: Rounds Discovery (where "Find Rounds" navigates)
- Flow 04: Round Detail (where hero card navigates)
- Flow 05: Activity (where action cards navigate)
- Flow 09: Create Round (where "Host Round" navigates)
