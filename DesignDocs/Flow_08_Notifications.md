# Flow 08: Notifications

**Purpose**: Keep users informed of activity and requests without overwhelming them

---

## Overview

Notifications inform users about:
- Round requests (someone wants to join your round)
- Request responses (host accepted/declined you)
- Invitations (host invited you to a round)
- Social activity (upvotes, comments, new followers)
- System messages (round canceled, time changed, etc.)

---

## User Goals

**Primary**: Stay informed of important activity
**Secondary**: Quickly act on time-sensitive items

---

## Entry Points

1. **Tap Notifications tab** (bottom navigation)
2. **Push notification** → Deep link to relevant screen
3. **Badge count** on tab bar

---

## Notifications Screen

### Header
- **Title**: "Notifications"
- **Mark all read** button (text, top right)

### Unread Badge
- Red badge on tab bar icon shows unread count
- Clears when user views notifications

### Notification List

**Layout**: Grouped by date (Today, Yesterday, This Week, Earlier)

**Notification Item**:
- **Icon** (left, 40pt circle with background):
  - Round requests: Person icon (green)
  - Acceptances: Checkmark (green)
  - Invites: Envelope (blue)
  - Social: Heart/comment icon (orange)
  - System: Info icon (gray)

- **Content** (middle):
  - **Title**: Action description
    - "John requested to join your round"
    - "Sarah accepted your join request"
    - "Mike invited you to a round"
    - "Alex upvoted your post"
  - **Time**: "2 hours ago"
  - **Preview**: Additional context (round name, post preview)

- **CTA** (right, conditional):
  - Round request: "View" button
  - Invite: "Respond" button
  - No action needed: Chevron only

- **Read state**:
  - Unread: Bold title, blue dot indicator
  - Read: Normal weight, no dot

**Interaction**:
- Tap notification → Navigate to relevant screen:
  - Round request → Round Detail (requests sheet)
  - Invite → Round Detail (accept/decline visible)
  - Social → Post Detail or Profile
  - System → Round Detail or relevant screen

**States**:
- **Loading**: Skeleton loaders
- **Empty**: "No notifications yet"
- **Error**: "Unable to load notifications" with retry

**Pull to Refresh**: Reload notifications

---

## Notification Types

### 1. Round Request
**When**: Someone requests to join your hosted round
**Title**: "[Name] requested to join your round"
**Preview**: "[Round name] at [Course]"
**Action**: Navigate to Round Detail → Open requests sheet
**Push**: Yes (real-time)

### 2. Request Accepted
**When**: Host accepts your join request
**Title**: "[Host name] accepted your request"
**Preview**: "[Round name] at [Course] on [Date]"
**Action**: Navigate to Round Detail
**Push**: Yes

### 3. Request Declined
**When**: Host declines your join request
**Title**: "[Host name] declined your request"
**Preview**: "[Round name] at [Course]"
**Action**: Navigate to Round Detail (read-only)
**Push**: Yes

### 4. Round Invitation
**When**: Host invites you to a round
**Title**: "[Host name] invited you to a round"
**Preview**: "[Round name] at [Course] on [Date]"
**Action**: Navigate to Round Detail (accept/decline visible)
**Push**: Yes

### 5. Invite Accepted
**When**: Invited user accepts
**Title**: "[Name] accepted your invitation"
**Preview**: "[Round name]"
**Action**: Navigate to Round Detail
**Push**: Yes (for host)

### 6. Member Joined
**When**: New member joins your round
**Title**: "[Name] joined your round"
**Preview**: "[Round name] - X of Y spots filled"
**Action**: Navigate to Round Detail
**Push**: Yes (for host)

### 7. Member Left
**When**: Member leaves your round
**Title**: "[Name] left your round"
**Preview**: "[Round name]"
**Action**: Navigate to Round Detail
**Push**: Yes (for host)

### 8. Round Canceled
**When**: Host cancels round you're in
**Title**: "Round canceled: [Round name]"
**Preview**: "[Reason if provided]"
**Action**: Navigate to Round Detail (canceled state)
**Push**: Yes (urgent)

### 9. Round Time Changed
**When**: Host changes date/time
**Title**: "Time changed for [Round name]"
**Preview**: "New time: [Date] at [Time]"
**Action**: Navigate to Round Detail
**Push**: Yes

### 10. New Follower
**When**: Someone follows you
**Title**: "[Name] started following you"
**Preview**: "[Their bio preview]"
**Action**: Navigate to their profile
**Push**: Optional (user setting)

### 11. Post Upvoted
**When**: Someone upvotes your post
**Title**: "[Name] upvoted your post"
**Preview**: "[Post preview]"
**Action**: Navigate to Post Detail
**Push**: Optional (batch: "X people upvoted your post")

### 12. Post Comment
**When**: Someone comments on your post
**Title**: "[Name] commented on your post"
**Preview**: "[Comment text]"
**Action**: Navigate to Post Detail (comments visible)
**Push**: Yes

### 13. Comment Reply
**When**: Someone replies to your comment
**Title**: "[Name] replied to your comment"
**Preview**: "[Reply text]"
**Action**: Navigate to Post Detail (comment thread)
**Push**: Yes

---

## Push Notifications

### Delivery
- iOS native push notifications (APNs)
- Firebase Cloud Messaging (FCM)

### Permission
- Request on first app launch (after onboarding)
- Can be changed in Settings

### Grouping
- Group similar notifications ("3 new round requests")
- Expandable to see individual items

### Timing
- Real-time: Requests, invites, cancellations
- Batched: Upvotes, new followers (max once per hour)
- Quiet hours: Respect iOS Focus modes

---

## Current Implementation

### Status
**Phase 5 – Planned**: Not yet implemented

### What Needs Implementation
- [ ] Notification data model in Firestore
- [ ] Cloud Functions to create notifications
- [ ] Push notification service
- [ ] Notification list UI
- [ ] Deep linking from push to screens
- [ ] Notification preferences
- [ ] Badge count management

---

## Design Needed

1. **Notification items** – Design for each notification type
2. **Icons** – Icon system for notification categories
3. **Empty state** – "No notifications yet"
4. **Badge** – Unread count badge design
5. **Grouping** – How grouped notifications appear
6. **Push notification** – Design of push banner

---

**Related Flows**:
- All flows (notifications come from all activities)
- Flow 04: Round Detail (most common destination)
- Flow 06: Feed (social notifications)
- Flow 07: Profile (follower notifications)
