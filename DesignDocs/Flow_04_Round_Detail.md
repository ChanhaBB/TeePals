# Flow 04: Round Detail

**Purpose**: Show complete round information and enable join/manage actions

---

## Overview

Round Detail is the central screen for viewing and interacting with a golf round. Content and actions vary based on:
- User's relationship to round (host, member, invitee, outsider)
- Round status (active, completed, canceled)
- Member status (accepted, requested, invited, declined)

---

## User Goals

**Primary**: Understand round details and decide whether to join
**Secondary**: As host, manage participants and round settings

---

## Entry Points

1. **Tap round card** from Rounds Browse
2. **Tap round card** from Rounds Activity
3. **Tap next round hero card** from Home
4. **Deep link** from notification or share
5. **Tap round** from user's profile (posts, activity)

---

## Screen Layout

### Header (Hero Section)

**Background**: Course photo with gradient overlay (similar to Home hero card)

**Content**:
- **Status badge** (top left):
  - Host: "HOSTING" with star icon
  - Accepted member: "CONFIRMED" with checkmark
  - Invited: "INVITED" with envelope icon
  - Requested: "PENDING" with clock icon
  - Outsider: No badge

- **Course name**: Large, bold, white text (28pt)
- **City**: Smaller, white 90% opacity (15pt)
- **Date + time**: With calendar icon
- **Distance**: "3.2 miles away" (for non-hosts)

**Height**: ~280-320pt
**Interaction**: Tap course name → View course details (future)

---

### Details Section

**Layout**: Grouped cards/sections with spacing

#### Round Information Card

**Title**: "Round Details"

**Fields**:
- **Holes**: "18 holes" (with icon)
- **Format**: "Stroke Play" / "Match Play" / "Scramble" / etc. (if set)
- **Skill Level**: "All levels welcome" or "Intermediate+"
- **Slots**: "2 of 4 spots filled" (progress bar visual)
- **Price**: "$45/person" or "Free"
- **Notes**: Optional host message (expandable if long)

**Styling**: White card, 16pt padding, dividers between fields

---

#### Host Information Card

**Title**: "Hosted by"

**Content**:
- Profile photo (64pt avatar)
- Nickname + skill level badge
- Mini stats: "Hosted 12 rounds · Avg score 85"
- "View Profile" link

**Interaction**: Tap anywhere → Navigate to host's profile

---

#### Participants Card

**Title**: "Participants (3)" – Shows accepted members only

**Layout**: Vertical list of mini profiles
- Avatar (44pt)
- Nickname
- Skill level badge
- "Host" badge for host

**States**:
- If < max slots: Show "X spots available"
- If full: Show "Round is full"

**Interaction**: Tap participant → View their profile

---

#### Actions Section (Conditional)

Varies based on user's relationship to round:

##### Non-Member (Outsider)
- **Primary CTA**: "Request to Join" (green, sticky bottom)
  - Disabled if round full
  - Shows "Full" if no spots
  - Requires Tier 2 (shows gate modal if incomplete)

##### Invited User
- **Accept** button (green, prominent)
- **Decline** button (secondary, outline)
- Both in HStack, equal width

##### Requested User (Pending)
- **"Request Pending"** disabled button showing status
- **"Withdraw Request"** secondary button below

##### Accepted Member (Not Host)
- **"Leave Round"** destructive button
  - Shows confirmation: "Are you sure? The host will be notified."

##### Host (Round Creator)
- **"Manage Requests"** button (if pending requests > 0)
  - Badge showing count
  - Opens requests sheet
- **"Invite Friends"** button (secondary)
  - Opens friend selector
- **"Edit Round"** button (text button)
- **"Cancel Round"** button (destructive, requires confirmation)

---

### Requests Sheet (Host Only)

**Trigger**: Tap "Manage Requests" (only shown if pending requests)

**Layout**: Bottom sheet modal

**Title**: "Join Requests (X)"

**Content**: List of pending requests
- User avatar (48pt)
- Nickname + skill level
- Request date: "Requested 2 hours ago"
- Actions (HStack):
  - "Accept" button (green)
  - "Decline" button (gray)

**Interactions**:
- Accept → Add to participants, notify user, close if last request
- Decline → Remove from requests, notify user
- Dismiss → Close sheet

**Empty state**: "No pending requests"

---

### Invite Friends Sheet (Host Only)

**Trigger**: Tap "Invite Friends"

**Layout**: Full screen sheet

**Title**: "Invite Friends"

**Content**:
- Search bar (filter friends by nickname)
- List of friends (mutual follows only)
  - Avatar + nickname
  - Already invited: Show "Invited" checkmark (disabled)
  - Already in round: Show "Joined" (disabled)
  - Available: Show checkbox

**Actions**:
- "Cancel" (top left)
- "Send Invites" (top right, count badge if selected)

**Interaction**:
- Tap friend → Toggle selection
- "Send Invites" → Send invites, show success toast, close sheet

---

## Key Components Used

- `DashboardHeroCard` – Hero section with course photo
- `AppCard` – Information cards
- Profile mini-cards
- `PrimaryButton` / `SecondaryButton` / `DestructiveButton`
- Bottom sheet modals
- Progress bar (for slots)
- Badges (status, skill level)
- `ProfileAvatarView`

---

## States

### Loading
- Skeleton for entire screen
- Hero section loads first (if basic data passed from list)
- Details load next

### Error
- "Unable to load round details"
- Retry button
- Back navigation available

### Round Completed
- Show "COMPLETED" badge instead of status
- Disable all actions except "View"
- Show final participant list
- Maybe show scorecards (future)

### Round Canceled
- Show "CANCELED" badge
- Explanation text (if provided)
- Disable all actions
- Show who canceled and when

### Round Full
- "Request to Join" button shows "Full"
- Grayed out state
- Note: "This round is full" above button

---

## Edge Cases

### Round Starts in < 2 Hours
- Show "Starting soon" indicator
- Prevent new requests
- Show "Too late to join" message

### Round in Past (Missed Start Time)
- Treat as completed
- Show as historical data

### User Already Requested/Invited
- Update button state accordingly
- Don't allow duplicate actions

### Host Leaves Own Round
- Not allowed
- Must cancel round or transfer host (future)

### Last Participant Leaves
- If host + 1 other, and other leaves, round continues
- Host can cancel or find new members

### Network Error During Action
- Show error toast
- Revert optimistic UI
- Allow retry

### Request Quota Exceeded
- If user has too many pending requests (anti-spam)
- Show message: "You have too many pending requests. Wait for hosts to respond."

### Tier 2 Gate
- Non-Tier-2 users see round but can't request
- "Request to Join" button triggers gate modal
- After completion, return to this screen with action enabled

---

## Interactions

### Request to Join
1. User taps "Request to Join"
2. Check Tier 2 → Show gate if incomplete
3. Show loading on button
4. Send request to Firestore
5. Update button to "Request Pending"
6. Show success toast: "Request sent to [Host Name]"
7. Notify host (push + in-app notification)

### Accept Invite
1. User taps "Accept"
2. Show loading
3. Update member status to accepted
4. Navigate to Rounds Activity tab
5. Show success toast: "You're in! Check Activity for details"
6. Notify host

### Decline Invite
1. User taps "Decline"
2. Show confirmation: "Decline invitation?"
3. Confirm → Update status, remove from round
4. Navigate back
5. Show toast: "Invitation declined"
6. Notify host

### Leave Round (Member)
1. User taps "Leave Round"
2. Show confirmation: "Leave this round? The host will be notified."
3. Confirm → Remove from participants
4. Navigate back to Rounds Browse
5. Show toast: "You've left the round"
6. Notify host and other participants

### Cancel Round (Host)
1. User taps "Cancel Round"
2. Show confirmation: "Cancel this round? All participants will be notified."
3. Confirm → Mark round as canceled
4. Navigate back
5. Show toast: "Round canceled"
6. Notify all participants

### Edit Round (Host)
1. User taps "Edit Round"
2. Navigate to Edit Round screen (similar to Create)
3. Can edit: date, time, slots, price, notes
4. Cannot edit: course (would break continuity)
5. Save → Update round, notify participants of changes

### Invite Friends (Host)
1. User taps "Invite Friends"
2. Open friend selector sheet
3. Select friends
4. Tap "Send Invites"
5. Create invitations in Firestore
6. Show toast: "Invites sent to X friends"
7. Notify invited users

### Accept Request (Host)
1. Open "Manage Requests" sheet
2. Tap "Accept" on a request
3. Show loading
4. Update member status to accepted
5. Remove from pending list
6. Show toast: "[Name] accepted"
7. Notify user

### Decline Request (Host)
1. Tap "Decline" on a request
2. Show confirmation: "Decline [Name]'s request?"
3. Confirm → Update status to declined
4. Remove from list
5. Show toast: "Request declined"
6. Notify user

---

## Current Implementation

### What's Working Well
✅ Round detail data model complete
✅ Member status state machine works
✅ Request/accept/decline logic functional
✅ Profile linking works

### What Needs Improvement
- [ ] UI design needs polish (currently basic)
- [ ] No hero section with course photo
- [ ] Requests sheet needs visual design
- [ ] Invite friends sheet not fully implemented
- [ ] No confirmation dialogs on destructive actions
- [ ] Participants section could be more visual
- [ ] No progress bar for slots
- [ ] Status badges need better design
- [ ] Button states (loading, disabled) need polish
- [ ] No haptic feedback

---

## Open Questions for Designer

1. **Hero section**:
   - Should we show all course photo candidates in a carousel?
   - Should we show a map with course location pin?
   - Should distance be shown for members too (not just outsiders)?

2. **Information cards**:
   - Should we use icons for each field?
   - Should host notes be always visible or collapsed by default?
   - Should we show weather forecast for round date?

3. **Participants section**:
   - Should we show skill level distribution chart?
   - Should friends in the round be highlighted?
   - Should we show who invited whom?
   - Should there be a chat preview (if Phase 3 round chat added)?

4. **Actions**:
   - Should "Request to Join" show a message preview field?
   - Should there be quick chat with host before requesting?
   - Should leaving a round require giving a reason?

5. **Requests management (host)**:
   - Should we show requester profiles inline or require tap to view?
   - Should we allow accepting multiple at once (batch select)?
   - Should there be a "maybe" option (not just accept/decline)?

6. **Invite friends**:
   - Should we show friend's stats to help host decide?
   - Should we allow adding a personal message with invite?
   - Should we suggest friends based on skill level match?

7. **Completed rounds**:
   - Should we show scorecards?
   - Should there be a "Play Again" CTA?
   - Should participants be able to rate/review the round?

---

## Design Assets Needed

1. **Hero section backgrounds** – Default gradients for missing course photos
2. **Status badges** – Hosting, Confirmed, Invited, Pending, Full, Completed, Canceled
3. **Icons** – Holes, format, skill level, slots, price, etc.
4. **Empty states** – No participants yet, no requests
5. **Loading states** – Skeleton for entire screen
6. **Confirmation dialogs** – Leave, cancel, decline designs

---

**Related Flows**:
- Flow 03: Rounds Discovery (entry point)
- Flow 02: Home Dashboard (entry from next round card)
- Flow 05: Activity (entry from activity tab)
- Flow 07: Profile (view host/participant profiles)
- Flow 09: Create Round (edit round uses similar UI)
- Flow 10: Round Chat (if chat button added)
