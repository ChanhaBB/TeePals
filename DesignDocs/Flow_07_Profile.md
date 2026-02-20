# Flow 07: Profile View & Edit

**Purpose**: Display user profiles and enable profile management

---

## Overview

Profiles are the identity layer of TeePals. Users can:
- View their own profile
- View other users' profiles
- Edit their own profile
- Follow/unfollow other users
- View followers/following lists

Profile data is split: **public** (visible to all) and **private** (owner only).

---

## User Goals

**Own Profile**: Manage my identity, see my stats, edit information
**Other's Profile**: Learn about another golfer, decide whether to follow/play with them

---

## Entry Points

1. **Tap Profile tab** (bottom navigation) → Own profile
2. **Tap participant avatar** (round detail, posts, comments) → Other's profile
3. **Tap follower/following** from profile → Other's profile
4. **Search users** (future) → Other's profile

---

## Own Profile Screen

### Header Section

**Background**: Primary gradient or pattern

**Content**:
- **Profile photos**: Horizontal scrollable carousel (up to 6 photos)
  - Main photo (first) larger, others smaller
  - Tap photo → Full screen view
  - "+" button to add more (if < 6)
- **Edit button** (top right): Pencil icon → Navigate to Edit Profile

**Layout**: Full width, ~320pt height

---

### Info Section

**Layout**: White card below header

**Fields**:
- **Nickname**: Large, bold (24pt)
- **Age decade + Gender**: "30s · Male" (13pt, secondary text)
- **Location**: "San Jose, CA" with pin icon
- **Bio**: Multi-line text (if set)
  - Placeholder: "Add a bio to tell other golfers about yourself"
  - Max 200 characters
- **Occupation**: "Software Engineer" (if set)

**Divider**

**Golf Stats** (grid layout, 2 columns):
- **Skill Level**: Badge ("Beginner" / "Intermediate" / "Advanced")
- **Avg Score (18)**: "92" (if set, else "Not set")
- **Experience**: "3 years" (if set)
- **Plays**: "4 times/month" (if set)

**Optional Fields** (only shown if set):
- **Handicap**: "12.5"
- **Favorite Course**: "Pebble Beach"

---

### Stats Section

**Title**: "My Stats" (section header)

**Metrics** (horizontal cards):
- **Rounds Played**: "12" (count of completed rounds)
- **Rounds Hosted**: "5" (count hosted)
- **Golf Pals**: "48" (followers + following, unique)

**Interaction**: Tap metric → Navigate to relevant screen
- Rounds Played → Past rounds list
- Rounds Hosted → Hosting history
- Golf Pals → Followers/Following lists

---

### Social Section

**Title**: "Social" (section header)

**Buttons**:
- **Followers**: "24 followers" → Navigate to Followers list
- **Following**: "32 following" → Navigate to Following list

**Layout**: HStack, equal width buttons

---

### Posts Section

**Title**: "Posts" (section header)

**Content**: Grid or list of user's posts (same as Feed but filtered to this user)

**Empty**: "No posts yet"

**Interaction**: Tap post → View post detail

---

### Settings Section (Own Profile Only)

**Title**: "Settings"

**Options**:
- Edit Profile
- Privacy Settings (future)
- Notifications (future)
- Help & Support
- Sign Out

---

## Other User's Profile Screen

### Header Section
Same layout as own profile, but:
- **No edit button**
- **No "+" button on photos**
- **Follow/Unfollow button** (top right)
  - "Follow" (outline) if not following
  - "Following" (filled green) if following
  - Toggle on tap

---

### Info Section
Same fields as own profile (except all are read-only)

---

### Stats Section
**Metrics**:
- **Rounds Played**: "12"
- **Rounds Hosted**: "5"
- **Mutual Friends**: "3 friends in common" (if any)

**Interaction**: Tap "Mutual Friends" → Show list of mutual followers

---

### Social Section
Same as own profile but viewing their followers/following

---

### Posts Section
Their public posts (same as own profile)

---

## Edit Profile Screen

**Trigger**: Tap "Edit" button on own profile

**Layout**: Full screen, scrollable form

**Navigation**:
- "Cancel" (top left) → Discard changes, go back
- "Save" (top right) → Save changes, show loading, go back

**Sections**:

### Photos
- Horizontal scrollable list (up to 6)
- Drag to reorder
- Tap photo → Options: "Remove", "View"
- "Add Photo" button → Photo picker (camera roll)
- Validation: At least 1 photo required (Tier 2)

### Basic Info
- **Nickname**: Text field (required, 2-30 chars)
- **Bio**: Multi-line text field (optional, max 200 chars)
  - Character counter: "142/200"
- **Occupation**: Text field (optional)

### Location
- **Primary City**: Searchable dropdown (autocomplete)
  - Shows current: "San Jose, CA"
  - Tap → Search for new city

### Golf Profile
- **Skill Level**: Segmented control (required for Tier 2)
  - Beginner / Intermediate / Advanced
- **Avg Score (18)**: Number picker or text field (optional)
- **Experience Years**: Number picker (optional)
- **Plays per Month**: Number picker (optional)

### Optional Stats
- **Handicap**: Decimal number field (optional)
- **Favorite Course**: Text field (optional)

**Validation**:
- Nickname required
- Location required
- Skill level required (Tier 2)
- At least 1 photo required (Tier 2)
- Show inline errors below fields

**Save Behavior**:
- Validate all fields
- If invalid, show errors and stay on screen
- If valid, show loading on "Save" button
- Update Firestore (public and private docs)
- Navigate back
- Show success toast: "Profile updated"

---

## Followers/Following Lists

**Entry**: Tap "Followers" or "Following" from profile

**Layout**: Full screen, searchable list

**Navigation**:
- Back button (top left)
- Search bar (top)

**Sections**:

### Friends First (Mutual Follows)
- **Title**: "Friends (X)" – Mutual follows only
- List of users with "Friends" badge

### Followers / Following
- **Title**: "Followers (X)" or "Following (X)"
- List of users
- If viewing "Following", show "Following" button (can unfollow)

**User Item**:
- Avatar (48pt)
- Nickname + skill level badge
- Follow/Unfollow button (conditional)

**Search**:
- Filter list by nickname
- Live search (no submit)

**Empty**:
- "No followers yet" or "Not following anyone"

**Interaction**:
- Tap user → Navigate to their profile
- Tap Follow/Unfollow → Toggle state, update Firestore

---

## Key Components Used

- Photo carousel (custom)
- `AppCard` – Info sections
- `AppTextField` – Edit inputs
- `PrimaryButton` / `SecondaryButton`
- Badge components (skill level)
- Metric cards (stats)
- User list items
- Search bar
- Photo picker (native)

---

## States

### Loading
- Skeleton for profile screen
- Photo placeholders

### Empty (Own Profile)
- Missing bio → Show placeholder
- Missing optional fields → Don't show fields
- No posts → "No posts yet"

### Empty (Other's Profile)
- No posts → "No posts yet"
- No mutual friends → Don't show metric

### Error
- Failed to load → Show error with retry
- Failed to save → Show error banner, keep form data

---

## Edge Cases

### Tier 2 Incomplete Profile
- Own profile shows missing fields prominently
- "Complete Profile" CTA
- Other users see limited profile (no photo, maybe restricted)

### No Profile Photo
- Show placeholder avatar
- Edit: Prompt to add photo

### User Changes Nickname
- Validate uniqueness (if required in future)
- Update everywhere (posts, comments, rounds)

### User Deletes All Photos
- Must keep at least 1 (Tier 2 requirement)
- Show error: "You must have at least one profile photo"

### Following Already Following
- Button shows "Following"
- Tap → Unfollow with confirmation? Or immediate toggle?

### Blocked User (Future)
- Can't view their profile
- Can't follow them
- Don't show in searches

### Private Profile (Future)
- Only followers can see posts
- Basic info still visible

---

## Interactions

### Follow User
1. Tap "Follow" button
2. Show loading on button
3. Create follow document in Firestore
4. Update button to "Following"
5. Show haptic feedback
6. Notify user (if notifications enabled)

### Unfollow User
1. Tap "Following" button
2. Show confirmation: "Unfollow [Name]?"
3. Confirm → Delete follow document
4. Update button to "Follow"
5. Show haptic feedback

### Edit Profile Photos
1. Tap "+" to add photo
2. Open photo picker (native)
3. Select photo
4. Crop/adjust (native)
5. Add to carousel
6. Save button enabled
7. On save, upload to Firebase Storage
8. Update profile with URLs

### Reorder Photos
1. Long press on photo
2. Drag to new position
3. Drop to place
4. Save button enabled
5. On save, update order in profile

### Change Location
1. Tap location field
2. Open search sheet
3. Type city name
4. See autocomplete results (Google Places)
5. Tap result
6. Preview on map (optional)
7. Confirm selection
8. Save button enabled

### View Full-Screen Photo
1. Tap photo in carousel
2. Open full-screen viewer
3. Swipe between photos
4. Pinch to zoom
5. Tap X or swipe down to close

---

## Current Implementation

### What's Working Well
✅ Public/private profile split
✅ Follow/unfollow system
✅ Profile edit functionality
✅ Photo upload and storage
✅ Tier 2 gating enforcement
✅ Followers/following lists

### What Needs Improvement
- [ ] Profile UI needs complete redesign
- [ ] Photo carousel could be more polished
- [ ] Edit form layout could be better
- [ ] No photo reordering yet
- [ ] Stats section doesn't exist yet
- [ ] Mutual friends calculation not shown
- [ ] No full-screen photo viewer
- [ ] Bio character counter missing
- [ ] Location search UX unclear
- [ ] No image compression before upload
- [ ] No haptic feedback

---

## Open Questions for Designer

1. **Profile header**:
   - Should we use a cover photo + profile photo design?
   - Should photos be a grid instead of carousel?
   - Should main photo be larger with thumbnails?

2. **Golf stats**:
   - Should we show charts (score history, progress)?
   - Should we show badges/achievements?
   - Should skill level be more prominent?

3. **Social proof**:
   - Should we show recent activity ("Played at Pebble Beach yesterday")?
   - Should we show endorsements from other users?
   - Should we show verified badge for active users?

4. **Edit experience**:
   - Should edit be inline (not separate screen)?
   - Should we guide users to complete optional fields?
   - Should there be a profile completeness meter?

5. **Privacy controls**:
   - Should users be able to hide certain fields?
   - Should there be a "private profile" mode?
   - Should users control who can follow them?

6. **Photos**:
   - Should we require photo verification (ensure it's the user)?
   - Should we allow photo captions?
   - Should there be action shots vs. profile shots?

---

## Design Assets Needed

1. **Profile header designs** – Various layouts for header
2. **Placeholder avatars** – Default avatar for no photo
3. **Skill level badges** – Beginner, Intermediate, Advanced designs
4. **Empty states** – No posts, no followers, incomplete profile
5. **Photo picker UI** – Custom picker vs. native
6. **Stats visualizations** – Charts, graphs for golf stats
7. **Loading states** – Skeleton for profile screen

---

**Related Flows**:
- Flow 01: Onboarding (initial profile creation)
- Flow 04: Round Detail (view participant profiles)
- Flow 06: Feed (posts show on profile)
- All flows (profile is referenced everywhere)
