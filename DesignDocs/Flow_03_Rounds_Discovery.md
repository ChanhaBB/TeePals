# Flow 03: Rounds Discovery & Browse

**Purpose**: Let users discover and filter golf rounds near them

---

## Overview

The Rounds tab is where users browse all available rounds. It includes:
- Location-based search (geohash indexing)
- Filters (distance, date range)
- Sort options (distance, date)
- Toggle between "Nearby" and "My Activity"

---

## User Goals

**Primary**: Find golf rounds to join near me
**Secondary**: Filter by date/distance, see round details before requesting

---

## Entry Points

1. **Tap Rounds tab** (bottom navigation)
2. **Tap "Find Rounds"** from Home empty state
3. **Tap "View All"** from Home nearby section
4. **Deep link** from notification or shared round

---

## Screen Layout

### Top Navigation
**Segmented Control**: 2 tabs
- **Nearby** – All rounds within search radius
- **My Activity** – User's hosting/attending/invited/requested rounds

**Default**: Nearby tab

---

## Tab 1: Nearby Rounds

### Header
- **Title**: "Nearby Rounds" (20pt bold)
- **Filter button**: Icon button (top right) → Opens filter sheet

### Filters (Bottom Sheet)

**Sections**:

1. **Distance**
   - Slider: 0-100 miles
   - Default: 30 miles
   - Live preview: "Within X miles"

2. **Date Range**
   - Options (radio):
     - Today
     - This Weekend
     - Next 7 Days
     - Next 30 Days (default)
     - Custom Range (date picker)

3. **Sort By**
   - Options (radio):
     - Distance (closest first) – default
     - Date (soonest first)

**Actions**:
- "Reset" button (secondary, top left) → Reset to defaults
- "Apply" button (primary, sticky bottom) → Apply filters and close

**Current Implementation**: ✅ Partially completed
- Location: `Views/Rounds/RoundsFilterSheet.swift`
- Missing: Some filter options, polish

### Round List

**Content**: Scrollable list of `RoundCardView` components

**Round Card** (compact):
- Course photo thumbnail (if available)
- Course name + city
- Date + time (human-readable: "Tomorrow at 2:00 PM")
- Distance from user ("3.2 mi")
- Slots: "2 of 4 spots filled"
- Price (if set): "$45/person" or "Free"
- Host mini-profile (photo + nickname, 32pt avatar)

**Layout**: Vertical list, 12pt spacing between cards

**Interaction**: Tap card → Navigate to Round Detail

**States**:
- **Loading**: Skeleton loaders (3-5 cards)
- **Empty**: "No rounds found nearby"
  - Suggestions: "Try expanding your search distance or date range"
  - CTA: "Adjust Filters" or "Host a Round"
- **Error**: "Unable to load rounds" with retry

**Pagination**: Load more on scroll to bottom (if more results)

**Current Implementation**: ✅ Mostly completed
- Location: `Views/Rounds/RoundsView.swift`
- Uses: `RoundsListViewModel`, geohash search

---

## Tab 2: My Activity

### Purpose
Show rounds user is involved with, organized by status

**Sections** (collapsible):

1. **Hosting** (user created these rounds)
   - Round cards with "Host" badge
   - Shows pending requests count badge
   - Sort: Soonest first

2. **Attending** (user was accepted)
   - Round cards with "Confirmed" badge
   - Sort: Soonest first

3. **Invited** (host invited user, awaiting response)
   - Round cards with "Invited" badge
   - Shows "Accept / Decline" action buttons on card
   - Sort: Invitation date (newest first)

4. **Requested** (user requested to join, awaiting host approval)
   - Round cards with "Pending" badge
   - Shows "Withdraw Request" button
   - Sort: Request date (newest first)

**Section Headers**:
- Title + count: "Hosting (3)"
- Collapse/expand chevron
- Default: All expanded

**Empty States**:
- "No hosting rounds" → "Host your first round"
- "No confirmed rounds" → "Find a round to join"
- "No invites" → "Invites from hosts will appear here"
- "No pending requests" → "Your join requests will appear here"

**Current Implementation**: ✅ Completed (V2 refactor)
- Location: `Views/Rounds/ActivityRoundsViewV2.swift`
- Uses: `ActivityRoundsViewModelV2`

---

## Key Components Used

- `RoundCardView` – Primary round display component
- `RoundsFilterSheet` – Filter bottom sheet
- `DashboardSectionHeader` – Section headers (My Activity)
- `CollapsibleSection` – Expandable sections (My Activity)
- `ActivityFilterChips` – Quick filters (My Activity)
- Segmented control (iOS native)
- Skeleton loaders

---

## Data Loading

### Nearby Tab
1. Get user's location from profile
2. Query rounds using geohash search:
   - Center: User's primary location
   - Radius: Filter distance (default 30 miles)
   - Date range: Filter date range (default next 30 days)
3. Apply sort (distance or date)
4. Paginate results (fetch 20 at a time)

**Technical**: Uses `RoundsSearchService` with geohash indexing for efficient location queries

### My Activity Tab
1. Fetch 4 separate queries in parallel:
   - `fetchHostingRounds(dateRange)`
   - `fetchRequestedRounds(dateRange)` where status = accepted
   - `fetchInvitedRounds(dateRange)`
   - `fetchRequestedRounds(dateRange)` where status = requested
2. Group by status
3. Sort within each group

**Technical**: Uses `ActivityRoundsService`

---

## States

### Loading
- **First load**: 3-5 skeleton round cards
- **Pagination**: Small spinner at bottom
- **Refresh**: Native pull-to-refresh indicator

### Empty
**Nearby**: "No rounds found nearby"
- Illustration or icon
- Suggestion text
- "Adjust Filters" or "Host a Round" CTAs

**My Activity (each section)**:
- Contextual empty message
- Relevant CTA

### Error
- "Unable to load rounds"
- Network error message
- "Try Again" button

### Success
- List of round cards
- Smooth scroll performance
- Infinite scroll pagination

---

## Edge Cases

### User in Remote Location (No Rounds Nearby)
- Show empty state
- Suggest expanding search radius
- Offer "Host a Round" as alternative

### All Rounds Full (No Available Spots)
- Still show rounds
- Mark as "Full" on card
- Allow viewing detail (maybe waitlist in future)

### Past Rounds in Results
- Only show future rounds (start time > now)
- Backend filters, but client should validate

### User Has No Primary Location
- Can't search nearby rounds
- Prompt to set location in profile

### Distance Calculation Inaccurate
- Use geohash approximation for queries
- Calculate exact distance for display
- Note: Distance is "as the crow flies", not driving distance

### Filter Produces No Results
- Show empty state with current filters displayed
- Suggest loosening filters
- "Reset Filters" CTA

### Pagination Reaches End
- Show "No more rounds" footer
- Don't show loading spinner

---

## Interactions

### Tap Round Card
- Navigate to Round Detail (Flow 04)
- Pass round ID and basic data

### Tap Filter Button
- Open filter sheet (modal)
- Sheet slides up from bottom
- Dismiss: Drag down or tap outside

### Apply Filters
- Show loading state
- Fetch new results
- Scroll to top
- Close filter sheet

### Pull to Refresh
- Refresh current tab
- Keep filters applied
- Show refresh indicator

### Switch Tabs
- Smoothly switch between Nearby and My Activity
- Each tab maintains own scroll position
- Lazy load data on first tab visit

### Tap "Accept" on Invited Card (Activity Tab)
- Show loading spinner on button
- Send accept request
- Move card to "Attending" section
- Show success toast

### Tap "Decline" on Invited Card
- Show confirmation dialog ("Are you sure?")
- Send decline request
- Remove card from list
- Show brief toast

### Tap "Withdraw Request"
- Show confirmation dialog
- Send withdrawal request
- Remove card from "Requested" section

---

## Current Implementation

### What's Working Well
✅ Geohash-based search is fast and accurate
✅ Filter sheet functional
✅ Activity tab organized by status
✅ Round cards display all key info
✅ Pagination working

### What Needs Improvement
- [ ] Filter sheet visual design needs polish
- [ ] No skeleton loaders (just spinner)
- [ ] Round card photos sometimes don't load
- [ ] Empty states could be more engaging
- [ ] No haptic feedback on actions
- [ ] Distance filter slider could show radius on map
- [ ] Date filter could show calendar preview
- [ ] "Full" rounds not visually distinct enough
- [ ] No quick actions on cards (must go to detail)

---

## Open Questions for Designer

1. **Round cards**:
   - Should we show host's skill level or stats?
   - Should "Full" rounds be grayed out or have a badge?
   - Should there be quick-join button directly on card?
   - Should we show number of friends/connections in round?

2. **Filter sheet**:
   - Should distance slider show a map with radius visualization?
   - Should date range show a calendar picker?
   - Should there be preset filter combinations ("Beginner-friendly", "This week")?
   - Should filters show result count preview ("23 rounds match")?

3. **Activity tab**:
   - Should sections be collapsible? (Currently yes)
   - Should there be quick filters (chips: "This week", "Today", etc.)?
   - Should hosting rounds show pending request previews on card?
   - Should there be a timeline view option?

4. **List view**:
   - Should there be a map view toggle?
   - Should there be a compact vs. expanded card view toggle?
   - Should rounds be groupable by course or date?

5. **Empty states**:
   - Should we show popular courses the user could host at?
   - Should we suggest connecting with more golf pals to see their rounds?
   - Should there be a "notify me" option for new rounds in area?

6. **Performance**:
   - Should we show approximate result count before loading all?
   - Should we cache nearby rounds for offline viewing?

---

## Design Assets Needed

1. **Empty state illustrations** – No rounds found, no activity
2. **Filter icons** – Distance, date, sort icons
3. **Badge designs** – "Host", "Confirmed", "Invited", "Pending", "Full"
4. **Skeleton loaders** – Round card skeleton states
5. **Map view** (if added) – Map with pins for rounds

---

**Related Flows**:
- Flow 02: Home Dashboard (entry point from "Find Rounds")
- Flow 04: Round Detail (tap round card)
- Flow 05: Activity My Rounds (My Activity tab)
- Flow 09: Create Round (from empty state CTA)
