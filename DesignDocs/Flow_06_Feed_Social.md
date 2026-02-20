# Flow 06: Feed & Social Posts

**Purpose**: Community engagement through posts, comments, and social feed

---

## Overview

The Feed tab is where users share experiences, connect with the golf community, and build their social circle. Features:
- Create posts (text + photos, optional round linking)
- Upvote posts
- Comment on posts (with nesting)
- Toggle between "All" posts and "Friends only"

---

## User Goals

**Primary**: See what's happening in my golf community
**Secondary**: Share my own golf experiences, engage with others

---

## Entry Points

1. **Tap Feed tab** (bottom navigation)
2. **Tap post** from user profile
3. **Deep link** from notification (comment, upvote)

---

## Feed Screen

### Header
- **Title**: "Feed"
- **Create Post** button (top right): "+" icon → Navigate to Create Post
- **Toggle** (below title):
  - "All Posts" (default)
  - "Friends Only" (mutual follows)

### Feed List

**Layout**: Vertical scrollable list of posts

**Post Card**:
- **Author header**:
  - Avatar (44pt) → Tap to view profile
  - Nickname + skill level badge
  - Post date: "2 hours ago"
  - Menu (•••) → Options: Report, etc. (if not own post)
    - If own post: Edit, Delete options

- **Linked round** (if present):
  - Small card showing: Course name, date, "Tap to view"
  - Tap → Navigate to Round Detail

- **Content**:
  - Text body (multi-line, expandable if > 5 lines)
  - "Read more" link if truncated

- **Photos** (if present):
  - Grid layout (1-4 photos)
  - 1 photo: Large
  - 2 photos: 2 columns
  - 3 photos: 1 large + 2 small
  - 4 photos: 2x2 grid
  - Tap photo → Full-screen gallery

- **Engagement bar**:
  - Upvote button: Arrow icon + count
    - Filled green if user upvoted
    - Tap to toggle upvote
  - Comment button: Speech bubble icon + count
    - Tap → Navigate to Post Detail (comments view)

**Spacing**: 16pt between posts

**States**:
- **Loading**: Skeleton loaders (3-5 posts)
- **Empty**: "No posts yet"
  - If "Friends Only": "Follow more golfers to see their posts"
  - If "All Posts": "Be the first to share something!"
- **Error**: "Unable to load feed" with retry

**Pull to Refresh**: Reload latest posts

**Pagination**: Infinite scroll, load more at bottom

**Current Implementation**: ✅ Completed
- Location: `Views/Feed/FeedView.swift`
- Uses: `FeedViewModel`

---

## Create Post Screen

**Trigger**: Tap "+" from Feed header

**Layout**: Full screen modal

**Navigation**:
- "Cancel" (top left) → Discard, go back
- "Post" (top right) → Publish post

**Form**:

1. **Text Input**:
   - Multi-line text area
   - Placeholder: "Share your golf story..."
   - Max 1000 characters
   - Character counter: "420/1000"

2. **Photo Picker**:
   - Horizontal scrollable list
   - "Add Photos" button (up to 4 photos)
   - Tap photo → Preview/remove
   - Drag to reorder

3. **Link Round** (optional):
   - "Link to a Round" button
   - Opens round selector (user's completed or upcoming rounds)
   - Selected round shows as small card
   - "Remove" button to unlink

**Validation**:
- Must have text OR photos (can't post empty)
- "Post" button disabled until valid

**Post Behavior**:
1. Validate content
2. Show loading on "Post" button
3. Upload photos to Firebase Storage
4. Create post document in Firestore
5. Navigate back to Feed
6. Show new post at top
7. Show success toast: "Posted!"

**Current Implementation**: ✅ Completed
- Location: `Views/Feed/CreatePostSheet.swift`

---

## Post Detail Screen

**Entry**: Tap post card (or comment button)

**Layout**: Full screen with post at top, comments below

### Post Section
Same as feed post card, but:
- Not tappable (already viewing)
- Photos can be viewed full-screen

### Comments Section

**Title**: "Comments (X)"

**Comment Item**:
- Avatar (40pt)
- Nickname
- Comment text (multi-line)
- Timestamp: "1 hour ago"
- Actions:
  - "Reply" button → Opens reply input for this comment
  - Menu (•••) → Edit/Delete (if own comment), Report (if not)

**Nested Comments** (1 level deep):
- Indented 40pt from left
- Smaller avatar (32pt)
- Same layout as parent comment
- Shows "@parentNickname" at start of text

**Reply Input** (bottom, sticky):
- Avatar (32pt) of current user
- Text input: "Write a comment..."
- Send button (disabled until text entered)

**Interaction**:
- Tap "Reply" → Focus input, set reply target
- Type comment → Enable send
- Tap send → Post comment, clear input, show in list
- Tap avatar → View commenter's profile

**States**:
- **Loading**: Skeleton loaders for comments
- **Empty**: "No comments yet. Be the first!"
- **Error**: "Unable to load comments" with retry

**Current Implementation**: ✅ Completed
- Location: `Views/Feed/PostDetailView.swift`
- Supports 1-level nesting with @mentions

---

## Edit Post Screen

**Trigger**: Tap "Edit" from post menu (own posts only)

**Layout**: Same as Create Post, but pre-filled

**Changes Allowed**:
- Edit text
- Add/remove photos (up to 4 total)
- Add/remove linked round

**Cannot Change**:
- Author
- Original post date

**Save Behavior**:
1. Validate changes
2. Show loading
3. Update post document
4. Navigate back
5. Show success toast: "Post updated"

**Current Implementation**: ✅ Completed

---

## Delete Post Flow

**Trigger**: Tap "Delete" from post menu

**Confirmation**: "Delete this post? This can't be undone."

**Actions**:
- "Cancel" (secondary)
- "Delete" (destructive)

**Delete Behavior**:
1. Mark post as deleted (soft delete)
2. Remove from feed
3. Show toast: "Post deleted"
4. Navigate back if on Post Detail

**Current Implementation**: ✅ Completed

---

## Key Components Used

- Post card (custom)
- Comment item (custom)
- Photo grid (1-4 photos)
- `AppTextField` – Comment input
- Photo picker (native)
- Round selector (custom)
- Full-screen photo gallery
- Pull-to-refresh
- Infinite scroll

---

## Edge Cases

### No Photos, Just Text
- Post shows without photo grid
- Text can be longer (more visible)

### No Text, Just Photos
- Allowed
- Photos are the primary content

### Linked Round Deleted
- Post still exists
- Linked round section shows "Round no longer available"

### Comment on Deleted Post
- Comments remain but post is hidden
- Maybe show "Original post deleted"

### User Deletes Account
- Posts remain but show "[Deleted User]"
- Profile link disabled

### Post While Offline
- Queue for upload
- Show "Posting..." state
- Retry when back online

### Photo Upload Fails
- Show error
- Allow retry or remove photo
- Don't create post until photos uploaded

### Upvote Quota
- No quota currently
- Future: Prevent spam upvoting

### Comment Too Long
- Enforce max length (500 chars?)
- Show character counter

### Deep Nesting Replies
- Only 1 level supported
- Deeper replies use flat @mentions

---

## Current Implementation

### What's Working Well
✅ Post creation with photos and round linking
✅ Upvote toggle system
✅ Nested comments (1 level)
✅ Edit and delete posts
✅ Feed toggle (all vs. friends)
✅ Pull to refresh
✅ Photo grid layouts

### What Needs Improvement
- [ ] UI design needs polish
- [ ] No skeleton loaders
- [ ] Photo grid could be more elegant
- [ ] Round selector UX unclear
- [ ] No image compression
- [ ] No full-screen photo gallery yet
- [ ] Comment input could stick to keyboard
- [ ] No @ mention autocomplete
- [ ] No hashtag support
- [ ] No post search/filter
- [ ] No "Most Popular" sorting

---

## Open Questions for Designer

1. **Feed layout**:
   - Should posts have more visual separation?
   - Should photos be shown as thumbnails vs. full-width?
   - Should linked rounds be more prominent?

2. **Engagement**:
   - Should we show who upvoted (like Instagram)?
   - Should there be reactions beyond upvote (love, laugh, etc.)?
   - Should we show "Trending" posts?

3. **Comments**:
   - Should comments be collapsible on long threads?
   - Should we allow photo comments?
   - Should there be comment upvotes?

4. **Create post**:
   - Should we add location tagging?
   - Should we add hashtag suggestions?
   - Should we allow post scheduling?
   - Should we add templates ("Round Recap", "Course Review")?

5. **Feed filtering**:
   - Should we add "Following Courses" filter?
   - Should we add "Local Only" filter?
   - Should we allow hiding posts?

---

## Design Assets Needed

1. **Post card designs** – Various content types (text, photos, linked rounds)
2. **Empty states** – No posts, no friends, no comments
3. **Photo grid layouts** – 1, 2, 3, 4 photo arrangements
4. **Engagement indicators** – Upvote button states, counts
5. **Loading states** – Skeleton loaders for posts and comments
6. **Full-screen gallery** – Photo viewer with swipe

---

**Related Flows**:
- Flow 07: Profile (posts show on user profiles)
- Flow 04: Round Detail (linked rounds navigate here)
- Flow 08: Notifications (engagement notifications)
