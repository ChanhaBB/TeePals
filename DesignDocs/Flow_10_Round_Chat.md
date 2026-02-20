# Flow 10: Round Chat

**Purpose**: Enable communication between accepted round participants

---

## Overview

Round Chat is a **group chat scoped to a specific round**. Only accepted members can see and send messages. Chat helps participants:
- Coordinate logistics (meeting point, parking)
- Get to know each other before the round
- Share updates day-of
- Build rapport

**Status**: Phase 3 – Planned, not yet implemented

---

## User Goals

**Primary**: Coordinate with my round participants
**Secondary**: Break the ice before meeting in person

---

## Entry Points

1. **"Chat" button** on Round Detail screen (accepted members only)
2. **Notification** (new message) → Deep link to chat
3. **Badge** on Round Detail if unread messages

---

## Access Control

**Who Can See Chat**:
- Host (always)
- Accepted members only
- NOT: Requested, invited, declined, or outsiders

**When Chat Activates**:
- As soon as first member is accepted (host + 1 person minimum)
- Remains active even after round completes (for 7 days?)
- Archive or lock after X days

---

## Chat Screen

### Header
- **Title**: "[Round name] Chat"
- **Subtitle**: "X participants" (tappable → View participants list)
- **Back button** (top left)
- **Info button** (top right) → Round Detail

### Messages Area

**Layout**: Scrollable message list (reverse chronological, latest at bottom)

**Message Types**:

1. **Text Messages** (from users):
   - Avatar (32pt, left or right based on sender)
   - Nickname (if not current user)
   - Message bubble (chat style)
   - Timestamp (shown on tap or for messages >5min apart)

2. **System Messages** (centered, gray):
   - "[Name] joined the round"
   - "[Name] left the round"
   - "Round time changed to [new time]"
   - "Host canceled the round"

**Message Bubble Styling**:
- Current user: Green, right-aligned
- Others: Gray, left-aligned
- Rounded corners (18pt)
- Max width: 70% of screen
- Padding: 12pt vertical, 16pt horizontal

**Grouping**:
- Consecutive messages from same user: Stack close together
- Different users: More spacing
- Time gaps (>5min): Show timestamp divider

**States**:
- **Loading**: Skeleton loaders
- **Empty**: "Say hello to your round participants!"
- **Error**: "Unable to load messages" with retry

**Real-time Updates**:
- Listen to new messages (Firestore listener)
- Show typing indicator (future)
- Auto-scroll to bottom on new message

---

### Message Input

**Layout**: Sticky bottom bar

**Components**:
- Text input field (expandable, max 3 lines)
- Send button (disabled if empty, green when enabled)
- Optional: Photo attachment button (future)

**Interaction**:
1. Tap input → Keyboard appears, screen scrolls
2. Type message → Send button enables
3. Tap send → Post message, clear input, scroll to bottom
4. Input expands as user types (multi-line)

---

## Message Features

### Basic (Phase 3.1)
- Text messages
- System messages (join/leave/changes)
- Real-time delivery
- Read receipts (count of readers)

### Future (Phase 3.2+)
- Photo sharing
- Location sharing (meeting point)
- Reactions (emoji)
- Reply to specific message
- Typing indicator
- Message editing (within 5 min)
- Message deletion

---

## Data Model

**Collection**: `rounds/{roundId}/messages/{messageId}`

**Message Document**:
```json
{
  "authorUid": "string",
  "authorNickname": "string",
  "authorPhotoUrl": "string",
  "type": "user|system",
  "text": "string",
  "createdAt": "timestamp",
  "readBy": ["uid1", "uid2"]
}
```

**System Message**:
```json
{
  "type": "system",
  "systemEventType": "member_joined|member_left|round_updated|round_canceled",
  "text": "Generated text",
  "createdAt": "timestamp"
}
```

---

## Key Components Used

- Chat message bubbles (custom)
- Avatar views
- Text input (multi-line)
- System message cells (centered)
- Timestamp dividers
- Send button (animated)
- Real-time Firestore listener

---

## Edge Cases

### User Leaves Round
- Lose access to chat immediately
- Past messages still visible? (Decision needed)
- Show "You left this round" banner

### Host Cancels Round
- Chat becomes read-only
- System message: "This round was canceled"
- Archive after X days

### Round Completed
- Chat remains active for 7 days (for post-round discussion)
- Then archived (read-only)
- Or: Delete after 30 days (decision needed)

### Network Offline
- Show cached messages
- Queue outgoing messages
- Retry when online
- Show "Sending..." indicator

### Message Spam/Abuse
- Report message option (future)
- Host can remove abusive member from round (also removes from chat)

### Unread Messages
- Badge on Round Detail "Chat" button
- Badge on Notifications tab
- Push notification (optional, user setting)

---

## Interactions

### Send Message
1. Type text in input
2. Send button enables
3. Tap send
4. Show optimistic message (gray)
5. Post to Firestore
6. Confirm delivery (checkmark)
7. Notify other participants (push optional)

### View Participant
1. Tap message avatar
2. Navigate to that user's profile

### View Round Detail
1. Tap info button (top right)
2. Navigate to Round Detail screen
3. Return to chat with back button

### Scroll to Latest
- Auto-scroll on new message (if near bottom)
- If scrolled up, show "New messages" pill (tap to scroll)

---

## Current Implementation

### Status
**Phase 3 – Planned**: Not implemented yet

### What Needs Implementation
- [ ] Firestore message collection structure
- [ ] Real-time message listener
- [ ] Chat UI (messages list, input)
- [ ] System message generation
- [ ] Push notifications for new messages
- [ ] Unread count tracking
- [ ] Access control (accepted members only)
- [ ] Message delivery confirmation
- [ ] Photo sharing (future)

---

## Design Needed

1. **Chat UI** – Message bubbles, input, layout
2. **System messages** – Centered, gray design
3. **Typing indicator** – "John is typing..."
4. **Empty state** – No messages yet
5. **Timestamp dividers** – Date separators
6. **Photo messages** – Layout for shared photos
7. **Unread badge** – Count indicator

---

## Open Questions for Designer

1. **Chat style**:
   - iMessage style vs. WhatsApp style?
   - Show avatars on every message or just first?
   - Timestamps on every message or just on tap?

2. **System messages**:
   - Should they be more prominent?
   - Should they include CTA buttons ("View changes")?

3. **Features**:
   - Should we add reactions (emoji) to messages?
   - Should we show read receipts (who read each message)?
   - Should typing indicators be visible?

4. **Access after round**:
   - Keep chat accessible forever?
   - Archive after round completes?
   - Allow participants to save/export chat?

5. **Rich content**:
   - Allow photos/videos in chat?
   - Allow location sharing (meeting point pin)?
   - Allow polls (best time to meet)?

---

**Related Flows**:
- Flow 04: Round Detail (entry point via "Chat" button)
- Flow 08: Notifications (new message notifications)
- Flow 07: Profile (tap avatar to view profile)
