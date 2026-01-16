# Phase 5 — Notifications System

**Goal:** Real-time in-app notifications for round activity, social engagement, and system messages with industry-standard UX and scalable architecture.

**Status:** Not Started

---

## 1. Overview

Phase 5 implements the Notifications tab, the final primary navigation surface in TeePals. Users receive notifications for round activities (join requests, invitations, cancellations), social interactions (follows, upvotes, comments), and system messages. For MVP, notifications are in-app only with real-time Firestore listeners. Push notifications are deferred to a future phase.

**Key Scalability Features:**
- Aggregated notifications (upvotes grouped within 1-hour windows)
- Update-in-place chat notifications (one notification per conversation, updated with latest message)
- Per-conversation metadata tracking (lastReadAt, unreadCount, mute state)
- Paginated real-time updates (only listen to recent 20)
- Graceful handling of deleted targets

**Industry-Standard UX:**
- Multiple visual cues for unread status (dot + background + bold)
- Swipe actions (mark as read, delete)
- Date grouping (Today, Yesterday, This Week)
- Inline action buttons (Accept/Decline invites)

---

## 1.1 Chat Notification Strategy (Update-in-Place)

**Problem:** Sending one notification per chat message creates spam and clutters the notification center.

**Solution:** Update-in-place pattern - one persistent notification per conversation.

### How It Works

**One Notification Per Round:**
- Each round chat gets exactly ONE notification
- Notification is created when first message arrives
- All subsequent messages UPDATE the same notification

**What Gets Updated:**
- **Title:** Course name + date (consistent identifier)
- **Body:** Latest message preview (sender + text/photo)
- **isRead:** Set to false when new message arrives
- **updatedAt:** Timestamp of latest update

**Metadata Tracking (Per User, Per Round):**

Store in `rounds/{roundId}/chatMetadata/{userId}`:
```json
{
  "lastReadAt": "<timestamp>",      // Client sets when user opens chat
  "lastMessageAt": "<timestamp>",   // Cloud Function updates on new message
  "lastNotifiedAt": "<timestamp>",  // Cloud Function updates when notification sent
  "unreadCount": 3,                 // Incremented by Cloud Function, reset by client
  "isMuted": false                  // User can mute specific chats
}
```

**Badge Count:**
- Total = notification unread count + chat unread count
- Chat unread count = sum of `unreadCount` across all rounds
- Displayed on Notifications tab (max 99)

**User Controls:**
- **Mute:** Stop notifications for specific round chat
- **Mark as Read:** Opens chat → resets `unreadCount` to 0, sets `lastReadAt`
- **Delete Notification:** Removes notification, but chat metadata persists

### Benefits vs. Aggregation

| Aspect | Aggregation (Time Windows) | Update-in-Place |
|--------|---------------------------|-----------------|
| Notifications per chat | Multiple (one per window) | One (persistent) |
| Notification center | Cluttered with old messages | Clean, one per round |
| Message preview | "5 new messages" (no context) | Latest message text |
| Badge accuracy | Approximate (window-based) | Exact (per-message tracking) |
| Mute support | No | Yes (per-conversation) |
| Implementation | Complex time window queries | Simple: update existing doc |

### Example Flow

1. **Alice sends message** in "Pebble Beach • Jan 20" round:
   - Cloud Function creates notification for Bob:
     - Title: "Pebble Beach • Jan 20"
     - Body: "Alice: See you at the first tee!"
   - Sets Bob's `chatMetadata.unreadCount = 1`

2. **Charlie sends message** 5 minutes later:
   - Cloud Function **updates** Bob's existing notification:
     - Body: "Charlie: I'll bring extra balls"
   - Increments Bob's `chatMetadata.unreadCount = 2`

3. **Bob opens chat:**
   - Client calls `markChatAsRead()`
   - Sets `chatMetadata.unreadCount = 0`
   - Sets `chatMetadata.lastReadAt = now()`
   - Marks notification as read

4. **Dave sends message** after Bob has read:
   - Cloud Function **updates** notification again:
     - Body: "Dave: Running 10 mins late"
     - isRead: false (marks as unread again)
   - Sets Bob's `chatMetadata.unreadCount = 1`

**Result:** Bob only sees ONE notification for this round, always showing the latest message. Clean, intuitive, industry-standard behavior (WhatsApp, Telegram, iMessage).

### What NOT to Do

❌ **One notification per message** - Creates notification spam
❌ **Suppressing all notifications after first** - Users miss new messages
❌ **Mixing chat messages with system events** - Different notification types
❌ **No mute options** - Users can't control notifications
❌ **Time-window aggregation** - Creates multiple stale notifications per chat

✅ **Update-in-place** - One notification, always current
✅ **Separate notification types** - Chat vs. system events
✅ **Per-conversation mute** - User control
✅ **Exact unread counts** - Accurate badge
✅ **Latest message preview** - Contextual information

---

## 2. Notification Types

### 2.1 Round Activity Notifications

| Type | Trigger | Actor | Recipient | Action |
|------|---------|-------|-----------|--------|
| `roundJoinRequest` | User requests to join round | Requester | Round host | View round detail → see pending requests |
| `roundJoinAccepted` | Host accepts join request | Host | Requester | View round detail |
| `roundJoinDeclined` | Host declines join request | Host | Requester | View round detail (informational) |
| `roundInvitation` | User invites you to round | Inviter | Invitee | View round detail → accept/decline |
| `roundCancelled` | Host cancels round | Host | All members | View round detail (cancelled state) |
| `roundUpdated` | Host edits round details | Host | All members | View round detail |
| `roundChatMessage` | New message in round chat | Sender | All members | Open round chat |

**Notes:**
- Only accepted members receive `roundChatMessage` notifications
- Host does NOT receive notification for their own actions
- `roundUpdated` only sent for significant changes (time, location, not description tweaks)
- **`roundChatMessage` uses update-in-place pattern:**
  - One notification per round (not per message)
  - Title: Course name + date
  - Body: Latest message text (up to 50 chars)
  - Updated whenever new message arrives
  - Respects mute settings per user
  - Badge shows total unread count across all chats

### 2.2 Social Activity Notifications

| Type | Trigger | Actor | Recipient | Action |
|------|---------|-------|-----------|--------|
| `userFollowed` | User follows you | Follower | Followed user | View follower's profile |
| `postUpvoted` | User upvotes your post | Upvoter | Post author | View post detail |
| `postCommented` | User comments on your post | Commenter | Post author | View post detail → scroll to comment |
| `commentReplied` | User replies to your comment | Replier | Comment author | View post detail → scroll to reply |
| `commentMentioned` | User @mentions you in comment | Mentioner | Mentioned user | View post detail → scroll to mention |

**Notes:**
- Do NOT send notification if actor == recipient (don't notify yourself)
- `postUpvoted` **AGGREGATED**: if multiple users upvote within 1 hour, update existing notification
- Respect post visibility: only send if recipient can see the post

### 2.3 System Notifications

| Type | Trigger | Recipient | Action |
|------|---------|-----------|--------|
| `welcomeMessage` | User completes Tier 1 onboarding | New user | Informational |
| `tier2Reminder` | User attempted Tier 2 action but incomplete | Incomplete user | Navigate to profile setup |
| `roundReminder` | 24 hours before round starts | All accepted members | View round detail |

**Notes:**
- System notifications have no `actorUid`
- `roundReminder` sent by scheduled Cloud Function (optional, nice-to-have)

---

## 3. Notification Data Model

### 3.1 Firestore Schema

**Collection:** `notifications/{userId}/items/{notificationId}`

```json
{
  "id": "notif_abc123",
  "type": "roundJoinRequest | roundInvitation | userFollowed | postUpvoted | ...",
  "actorUid": "uid_of_actor | null",
  "actorNickname": "JohnDoe",
  "actorPhotoUrl": "https://...",
  "actorUids": ["uid1", "uid2", "uid3"],
  "actorCount": 3,
  "targetId": "round123 | post456 | comment789 | null",
  "targetType": "round | post | comment | profile | null",
  "title": "Join Request",
  "body": "JohnDoe requested to join your round at Pebble Beach",
  "metadata": {
    "roundName": "Pebble Beach",
    "roundDate": "2025-01-20",
    "postText": "Great round today...",
    "commentText": "Nice shot!",
    "messageCount": 5
  },
  "isRead": false,
  "createdAt": "<timestamp>",
  "updatedAt": "<timestamp>"
}
```

**Field Descriptions:**
- `type`: Enum string for notification type (see 2.1, 2.2, 2.3)
- `actorUid`: Single actor UID (for non-aggregated notifications)
- `actorNickname`, `actorPhotoUrl`: Denormalized for display (avoid extra reads)
- `actorUids`: Array of actor UIDs (for aggregated notifications like upvotes)
- `actorCount`: Total count of actors (for display "3 people upvoted...")
- `targetId`: ID of the relevant entity (roundId, postId, commentId)
- `targetType`: Type of entity for navigation
- `title`: Short title (e.g., "Join Request", "New Follower")
- `body`: Longer description with actor name and context
- `metadata`: Optional additional context for rendering
- `isRead`: Read/unread status
- `createdAt`: Initial creation timestamp (for sorting)
- `updatedAt`: Last update timestamp (for aggregated notifications)

**Aggregation Example:**

First upvote:
```json
{
  "type": "postUpvoted",
  "actorUid": "user1",
  "actorNickname": "JohnDoe",
  "actorUids": ["user1"],
  "actorCount": 1,
  "body": "JohnDoe upvoted your post"
}
```

After 2 more upvotes within 1 hour:
```json
{
  "type": "postUpvoted",
  "actorUid": null,
  "actorUids": ["user1", "user2", "user3"],
  "actorCount": 3,
  "body": "3 people upvoted your post",
  "updatedAt": "<new_timestamp>"
}
```

### 3.2 Notification Model (Swift)

```swift
struct Notification: Codable, Identifiable {
    var id: String?
    let type: NotificationType
    let actorUid: String?
    let actorNickname: String?
    let actorPhotoUrl: String?
    let actorUids: [String]?
    let actorCount: Int?
    let targetId: String?
    let targetType: TargetType?
    let title: String
    let body: String
    let metadata: [String: String]?
    var isRead: Bool
    let createdAt: Date
    let updatedAt: Date?

    var timeAgoString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    var isAggregated: Bool {
        (actorCount ?? 0) > 1
    }

    var displayActorUids: [String] {
        actorUids ?? (actorUid != nil ? [actorUid!] : [])
    }
}

enum NotificationType: String, Codable {
    // Round activity
    case roundJoinRequest
    case roundJoinAccepted
    case roundJoinDeclined
    case roundInvitation
    case roundCancelled
    case roundUpdated
    case roundChatMessage

    // Social activity
    case userFollowed
    case postUpvoted
    case postCommented
    case commentReplied
    case commentMentioned

    // System
    case welcomeMessage
    case tier2Reminder
    case roundReminder
}

enum TargetType: String, Codable {
    case round
    case post
    case comment
    case profile
}
```

### 3.3 Chat Metadata (Per-User, Per-Round)

To support update-in-place chat notifications, we track metadata for each user's participation in each round chat.

**Collection:** `rounds/{roundId}/chatMetadata/{userId}`

```json
{
  "uid": "user123",
  "lastReadAt": "<timestamp>",
  "lastMessageAt": "<timestamp>",
  "lastNotifiedAt": "<timestamp>",
  "unreadCount": 3,
  "isMuted": false
}
```

**Field Descriptions:**
- `uid`: User ID (for easy querying)
- `lastReadAt`: When user last opened/viewed the chat (set by client)
- `lastMessageAt`: When the last message was sent in this chat (set by Cloud Function)
- `lastNotifiedAt`: When we last sent/updated a notification for this user (set by Cloud Function)
- `unreadCount`: Number of unread messages (incremented by Cloud Function, reset by client)
- `isMuted`: Whether user has muted this chat (no notifications)

**Swift Model:**

```swift
struct ChatMetadata: Codable {
    let uid: String
    var lastReadAt: Date?
    var lastMessageAt: Date?
    var lastNotifiedAt: Date?
    var unreadCount: Int
    var isMuted: Bool

    init(uid: String) {
        self.uid = uid
        self.lastReadAt = nil
        self.lastMessageAt = nil
        self.lastNotifiedAt = nil
        self.unreadCount = 0
        self.isMuted = false
    }
}
```

**Usage Pattern:**

1. **When message sent** (Cloud Function):
   - Update `lastMessageAt` for all members
   - Increment `unreadCount` for all members except sender
   - Update or create notification for each member (if not muted)
   - Update `lastNotifiedAt` for each notified member

2. **When user opens chat** (Client):
   - Set `lastReadAt` to current time
   - Reset `unreadCount` to 0
   - Mark notification as read

3. **Badge calculation** (Client):
   - Sum all `unreadCount` across all rounds
   - Add count of unread non-chat notifications
   - Display total badge on Notifications tab

---

## 4. Notification Creation (Cloud Functions)

Notifications are created server-side by Cloud Functions to ensure consistency and avoid client-side manipulation.

### 4.1 onRoundMemberWrite (Join Requests)

```typescript
export const onRoundMemberWrite = functions.firestore
  .document('rounds/{roundId}/members/{memberId}')
  .onWrite(async (change, context) => {
    const roundId = context.params.roundId;
    const before = change.before.data();
    const after = change.after.data();

    // Skip if deleted or no status change
    if (!after || before?.status === after.status) return;

    const round = await admin.firestore().collection('rounds').doc(roundId).get();
    const roundData = round.data();
    const hostUid = roundData.hostUid;
    const memberUid = after.uid;

    // 1. Join request submitted → notify host
    if (!before && after.status === 'requested') {
      await createNotification(hostUid, {
        type: 'roundJoinRequest',
        actorUid: memberUid,
        targetId: roundId,
        targetType: 'round',
        title: 'Join Request',
        body: `${after.nickname || 'Someone'} requested to join your round`,
        metadata: {
          roundName: roundData.chosenCourse?.name || 'your round',
          roundDate: roundData.startTime?.toDate().toLocaleDateString()
        }
      });
    }

    // 2. Request accepted → notify member
    if (before?.status === 'requested' && after.status === 'accepted') {
      await createNotification(memberUid, {
        type: 'roundJoinAccepted',
        actorUid: hostUid,
        targetId: roundId,
        targetType: 'round',
        title: 'Request Accepted',
        body: `Your request to join the round was accepted`,
        metadata: {
          roundName: roundData.chosenCourse?.name || 'the round',
          roundDate: roundData.startTime?.toDate().toLocaleDateString()
        }
      });
    }

    // 3. Request declined → notify member
    if (before?.status === 'requested' && after.status === 'declined') {
      await createNotification(memberUid, {
        type: 'roundJoinDeclined',
        actorUid: hostUid,
        targetId: roundId,
        targetType: 'round',
        title: 'Request Declined',
        body: `Your request to join the round was declined`,
        metadata: {
          roundName: roundData.chosenCourse?.name || 'the round'
        }
      });
    }

    // 4. User invited → notify invitee
    if (!before && after.status === 'invited') {
      const inviterUid = after.invitedBy;
      const inviterProfile = await fetchProfile(inviterUid);

      await createNotification(memberUid, {
        type: 'roundInvitation',
        actorUid: inviterUid,
        targetId: roundId,
        targetType: 'round',
        title: 'Round Invitation',
        body: `${inviterProfile?.nickname || 'Someone'} invited you to a round`,
        metadata: {
          roundName: roundData.chosenCourse?.name || 'a round',
          roundDate: roundData.startTime?.toDate().toLocaleDateString()
        }
      });
    }
  });
```

### 4.2 onRoundUpdate (Cancellation, Edits)

```typescript
export const onRoundUpdate = functions.firestore
  .document('rounds/{roundId}')
  .onUpdate(async (change, context) => {
    const roundId = context.params.roundId;
    const before = change.before.data();
    const after = change.after.data();

    // 1. Round cancelled
    if (before.status !== 'canceled' && after.status === 'canceled') {
      const members = await admin.firestore()
        .collection('rounds').doc(roundId)
        .collection('members')
        .where('status', '==', 'accepted')
        .get();

      for (const memberDoc of members.docs) {
        const memberData = memberDoc.data();
        if (memberData.uid === after.hostUid) continue; // Don't notify host

        await createNotification(memberData.uid, {
          type: 'roundCancelled',
          actorUid: after.hostUid,
          targetId: roundId,
          targetType: 'round',
          title: 'Round Cancelled',
          body: `The round at ${after.chosenCourse?.name || 'TBD'} was cancelled`,
          metadata: {
            roundName: after.chosenCourse?.name || 'the round'
          }
        });
      }
    }

    // 2. Significant update (time or location changed)
    const timeChanged = before.startTime?.seconds !== after.startTime?.seconds;
    const locationChanged = before.chosenCourse?.name !== after.chosenCourse?.name;

    if ((timeChanged || locationChanged) && after.status === 'open') {
      const members = await admin.firestore()
        .collection('rounds').doc(roundId)
        .collection('members')
        .where('status', '==', 'accepted')
        .get();

      for (const memberDoc of members.docs) {
        const memberData = memberDoc.data();
        if (memberData.uid === after.hostUid) continue;

        await createNotification(memberData.uid, {
          type: 'roundUpdated',
          actorUid: after.hostUid,
          targetId: roundId,
          targetType: 'round',
          title: 'Round Updated',
          body: `The round details were updated`,
          metadata: {
            roundName: after.chosenCourse?.name || 'the round',
            roundDate: after.startTime?.toDate().toLocaleDateString()
          }
        });
      }
    }
  });
```

### 4.3 onChatMessage (Round Chat - Update-in-Place)

**Pattern:** One notification per conversation, updated with latest message.

```typescript
export const onChatMessage = functions.firestore
  .document('rounds/{roundId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const roundId = context.params.roundId;

    // Skip system messages
    if (message.type === 'system') return;

    const round = await admin.firestore().collection('rounds').doc(roundId).get();
    const roundData = round.data();
    const courseName = roundData.chosenCourse?.name || 'Round';
    const roundDate = roundData.startTime?.toDate().toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric'
    }) || '';

    // Get all accepted members except sender
    const members = await admin.firestore()
      .collection('rounds').doc(roundId)
      .collection('members')
      .where('status', '==', 'accepted')
      .get();

    // Update in parallel for all members
    const promises = members.docs.map(async (memberDoc) => {
      const memberData = memberDoc.data();
      const memberUid = memberData.uid;

      // Don't notify sender
      if (memberUid === message.senderUid) return;

      // Check chat metadata for mute status
      const chatMetadataRef = admin.firestore()
        .collection('rounds').doc(roundId)
        .collection('chatMetadata').doc(memberUid);

      const chatMetadataSnap = await chatMetadataRef.get();
      const chatMetadata = chatMetadataSnap.data() || {};

      // Skip if muted
      if (chatMetadata.isMuted) return;

      // Update chat metadata (always, even if muted)
      const now = admin.firestore.FieldValue.serverTimestamp();
      await chatMetadataRef.set({
        uid: memberUid,
        lastMessageAt: now,
        unreadCount: admin.firestore.FieldValue.increment(1),
        lastNotifiedAt: now,
        isMuted: chatMetadata.isMuted || false
      }, { merge: true });

      // Find existing notification for this round
      const existingNotifs = await admin.firestore()
        .collection('notifications').doc(memberUid)
        .collection('items')
        .where('type', '==', 'roundChatMessage')
        .where('targetId', '==', roundId)
        .limit(1)
        .get();

      const messagePreview = message.text
        ? `${message.senderNickname}: ${message.text.substring(0, 50)}${message.text.length > 50 ? '...' : ''}`
        : `${message.senderNickname} sent a photo`;

      const title = roundDate ? `${courseName} • ${roundDate}` : courseName;

      if (!existingNotifs.empty) {
        // Update existing notification with latest message
        const existingNotif = existingNotifs.docs[0];
        await existingNotif.ref.update({
          actorUid: message.senderUid,
          actorNickname: message.senderNickname,
          actorPhotoUrl: message.senderPhotoUrl || null,
          title: title,
          body: messagePreview,
          updatedAt: now,
          isRead: false  // Mark as unread when new message arrives
        });
      } else {
        // Create new notification (first message in this round)
        await admin.firestore()
          .collection('notifications').doc(memberUid)
          .collection('items')
          .add({
            type: 'roundChatMessage',
            actorUid: message.senderUid,
            actorNickname: message.senderNickname,
            actorPhotoUrl: message.senderPhotoUrl || null,
            targetId: roundId,
            targetType: 'round',
            title: title,
            body: messagePreview,
            metadata: {
              roundName: courseName,
              roundDate: roundDate
            },
            isRead: false,
            createdAt: now,
            updatedAt: now
          });
      }
    });

    await Promise.all(promises);
  });
```

**Key Differences from Aggregation:**
- ✅ Always updates the same notification (no time window check)
- ✅ Shows latest message, not message count
- ✅ Respects per-user mute settings
- ✅ Updates chatMetadata with unreadCount
- ✅ Title includes course name + date (consistent format)
- ✅ Cleaner notification center (one notification per round)

### 4.4 onFollowCreate (New Follower)

```typescript
export const onFollowCreate = functions.firestore
  .document('follows/{userId}/followers/{followerId}')
  .onCreate(async (snap, context) => {
    const userId = context.params.userId;
    const followerId = context.params.followerId;
    const followerProfile = await fetchProfile(followerId);

    await createNotification(userId, {
      type: 'userFollowed',
      actorUid: followerId,
      targetId: followerId,
      targetType: 'profile',
      title: 'New Follower',
      body: `${followerProfile?.nickname || 'Someone'} started following you`
    });
  });
```

### 4.5 onPostEngagement (Upvotes - Aggregated, Comments)

```typescript
export const onUpvoteCreate = functions.firestore
  .document('posts/{postId}/upvotes/{uid}')
  .onCreate(async (snap, context) => {
    const postId = context.params.postId;
    const upvoterUid = context.params.uid;

    const post = await admin.firestore().collection('posts').doc(postId).get();
    const postData = post.data();
    const authorUid = postData.authorUid;

    // Don't notify if upvoting own post
    if (upvoterUid === authorUid) return;

    const upvoterProfile = await fetchProfile(upvoterUid);

    // Check for existing upvote notification within last hour
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
    const existingNotifs = await admin.firestore()
      .collection('notifications').doc(authorUid)
      .collection('items')
      .where('type', '==', 'postUpvoted')
      .where('targetId', '==', postId)
      .where('createdAt', '>', oneHourAgo)
      .limit(1)
      .get();

    if (!existingNotifs.empty) {
      // Aggregate: update existing notification
      const existingNotif = existingNotifs.docs[0];
      const existingData = existingNotif.data();
      const actorUids = existingData.actorUids || [existingData.actorUid];

      // Add new upvoter if not already in list
      if (!actorUids.includes(upvoterUid)) {
        actorUids.push(upvoterUid);
        const actorCount = actorUids.length;

        await existingNotif.ref.update({
          actorUids: actorUids,
          actorCount: actorCount,
          actorUid: null,  // Clear single actor
          body: actorCount === 2
            ? `${existingData.actorNickname} and 1 other upvoted your post`
            : `${actorCount} people upvoted your post`,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          isRead: false  // Mark as unread again
        });
      }
    } else {
      // Create new notification
      await createNotification(authorUid, {
        type: 'postUpvoted',
        actorUid: upvoterUid,
        targetId: postId,
        targetType: 'post',
        title: 'Post Upvoted',
        body: `${upvoterProfile?.nickname || 'Someone'} upvoted your post`,
        metadata: {
          postText: postData.text.substring(0, 50)
        }
      });
    }
  });

export const onCommentCreate = functions.firestore
  .document('posts/{postId}/comments/{commentId}')
  .onCreate(async (snap, context) => {
    const postId = context.params.postId;
    const comment = snap.data();
    const commenterUid = comment.authorUid;

    const post = await admin.firestore().collection('posts').doc(postId).get();
    const postData = post.data();

    // 1. Notify post author (if not commenting on own post)
    if (commenterUid !== postData.authorUid && !comment.parentCommentId) {
      const commenterProfile = await fetchProfile(commenterUid);

      await createNotification(postData.authorUid, {
        type: 'postCommented',
        actorUid: commenterUid,
        targetId: postId,
        targetType: 'post',
        title: 'New Comment',
        body: `${commenterProfile?.nickname || 'Someone'} commented on your post`,
        metadata: {
          commentText: comment.text.substring(0, 50),
          postText: postData.text.substring(0, 50)
        }
      });
    }

    // 2. Notify parent comment author (if replying)
    if (comment.parentCommentId) {
      const parentComment = await admin.firestore()
        .collection('posts').doc(postId)
        .collection('comments').doc(comment.parentCommentId)
        .get();
      const parentCommentData = parentComment.data();

      if (commenterUid !== parentCommentData.authorUid) {
        const commenterProfile = await fetchProfile(commenterUid);

        await createNotification(parentCommentData.authorUid, {
          type: 'commentReplied',
          actorUid: commenterUid,
          targetId: postId,
          targetType: 'post',
          title: 'Reply to Comment',
          body: `${commenterProfile?.nickname || 'Someone'} replied to your comment`,
          metadata: {
            commentText: comment.text.substring(0, 50)
          }
        });
      }
    }

    // 3. Notify @mentioned user (if replyToUid is set)
    if (comment.replyToUid && commenterUid !== comment.replyToUid) {
      const commenterProfile = await fetchProfile(commenterUid);

      await createNotification(comment.replyToUid, {
        type: 'commentMentioned',
        actorUid: commenterUid,
        targetId: postId,
        targetType: 'post',
        title: 'Mentioned in Comment',
        body: `${commenterProfile?.nickname || 'Someone'} mentioned you in a comment`,
        metadata: {
          commentText: comment.text.substring(0, 50)
        }
      });
    }
  });
```

### 4.6 Helper: createNotification

```typescript
async function createNotification(
  recipientUid: string,
  notificationData: {
    type: string;
    actorUid?: string;
    targetId?: string;
    targetType?: string;
    title: string;
    body: string;
    metadata?: Record<string, any>;
  }
) {
  // Fetch actor profile if actorUid provided
  let actorNickname = null;
  let actorPhotoUrl = null;

  if (notificationData.actorUid) {
    const actorProfile = await fetchProfile(notificationData.actorUid);
    actorNickname = actorProfile?.nickname || 'Someone';
    actorPhotoUrl = actorProfile?.photoUrls?.[0] || null;
  }

  // Create notification document
  await admin.firestore()
    .collection('notifications').doc(recipientUid)
    .collection('items')
    .add({
      type: notificationData.type,
      actorUid: notificationData.actorUid || null,
      actorNickname,
      actorPhotoUrl,
      actorUids: notificationData.actorUid ? [notificationData.actorUid] : [],
      actorCount: 1,
      targetId: notificationData.targetId || null,
      targetType: notificationData.targetType || null,
      title: notificationData.title,
      body: notificationData.body,
      metadata: notificationData.metadata || {},
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
}

async function fetchProfile(uid: string) {
  const profileDoc = await admin.firestore()
    .collection('profiles_public')
    .doc(uid)
    .get();
  return profileDoc.data();
}
```

---

## 5. Client-Side Architecture

### 5.1 NotificationsRepository Protocol

```swift
protocol NotificationsRepository {
    /// Fetch recent notifications with pagination (no listener)
    func fetchNotifications(limit: Int, after: Date?) async throws -> [Notification]

    /// Mark a notification as read
    func markAsRead(notificationId: String) async throws

    /// Mark all notifications as read
    func markAllAsRead() async throws

    /// Delete a notification
    func deleteNotification(notificationId: String) async throws

    /// Get unread count
    func getUnreadCount() async throws -> Int

    /// Listen to real-time notifications (top 20 only for performance)
    func observeRecentNotifications() -> AsyncStream<[Notification]>

    /// Listen to unread count changes
    func observeUnreadCount() -> AsyncStream<Int>
}
```

### 5.2 FirestoreNotificationsRepository

```swift
final class FirestoreNotificationsRepository: NotificationsRepository {
    private let db = Firestore.firestore()
    private var currentUid: String? {
        Auth.auth().currentUser?.uid
    }

    // MARK: - Paginated Fetch (No Listener)

    func fetchNotifications(limit: Int, after: Date?) async throws -> [Notification] {
        guard let uid = currentUid else {
            throw NotificationsError.notAuthenticated
        }

        var query: Query = db
            .collection("notifications").document(uid)
            .collection("items")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)

        if let after = after {
            query = query.whereField("createdAt", isLessThan: Timestamp(date: after))
        }

        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { doc in
            var notif = try? doc.data(as: Notification.self)
            notif?.id = doc.documentID
            return notif
        }
    }

    // MARK: - Mark as Read

    func markAsRead(notificationId: String) async throws {
        guard let uid = currentUid else {
            throw NotificationsError.notAuthenticated
        }

        try await db
            .collection("notifications").document(uid)
            .collection("items").document(notificationId)
            .updateData(["isRead": true])
    }

    func markAllAsRead() async throws {
        guard let uid = currentUid else {
            throw NotificationsError.notAuthenticated
        }

        let unreadSnapshot = try await db
            .collection("notifications").document(uid)
            .collection("items")
            .whereField("isRead", isEqualTo: false)
            .getDocuments()

        let batch = db.batch()
        for doc in unreadSnapshot.documents {
            batch.updateData(["isRead": true], forDocument: doc.reference)
        }
        try await batch.commit()
    }

    // MARK: - Delete

    func deleteNotification(notificationId: String) async throws {
        guard let uid = currentUid else {
            throw NotificationsError.notAuthenticated
        }

        try await db
            .collection("notifications").document(uid)
            .collection("items").document(notificationId)
            .delete()
    }

    // MARK: - Unread Count

    func getUnreadCount() async throws -> Int {
        guard let uid = currentUid else {
            throw NotificationsError.notAuthenticated
        }

        let snapshot = try await db
            .collection("notifications").document(uid)
            .collection("items")
            .whereField("isRead", isEqualTo: false)
            .getDocuments()

        return snapshot.count
    }

    // MARK: - Real-Time Listeners (TOP 20 ONLY)

    func observeRecentNotifications() -> AsyncStream<[Notification]> {
        AsyncStream { continuation in
            guard let uid = currentUid else {
                continuation.finish()
                return
            }

            // Only listen to most recent 20 for performance
            let listener = db
                .collection("notifications").document(uid)
                .collection("items")
                .order(by: "createdAt", descending: true)
                .limit(to: 20)  // ⚠️ CRITICAL: Only real-time update top 20
                .addSnapshotListener { snapshot, error in
                    if let error = error {
                        print("Error listening to notifications: \(error)")
                        return
                    }

                    let notifications = snapshot?.documents.compactMap { doc in
                        var notif = try? doc.data(as: Notification.self)
                        notif?.id = doc.documentID
                        return notif
                    } ?? []

                    continuation.yield(notifications)
                }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    func observeUnreadCount() -> AsyncStream<Int> {
        AsyncStream { continuation in
            guard let uid = currentUid else {
                continuation.finish()
                return
            }

            let listener = db
                .collection("notifications").document(uid)
                .collection("items")
                .whereField("isRead", isEqualTo: false)
                .addSnapshotListener { snapshot, error in
                    if let error = error {
                        print("Error listening to unread count: \(error)")
                        return
                    }

                    continuation.yield(snapshot?.count ?? 0)
                }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }
}

enum NotificationsError: LocalizedError {
    case notAuthenticated
    case targetNotFound

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to view notifications."
        case .targetNotFound:
            return "This item no longer exists."
        }
    }
}
```

### 5.3 ChatRepository Extensions (Chat Metadata)

To support update-in-place notifications and mute functionality, extend `ChatRepository` with chat metadata methods.

**Add to ChatRepository protocol:**

```swift
protocol ChatRepository {
    // ... existing methods ...

    // MARK: - Chat Metadata

    /// Fetch chat metadata for current user in a round
    func fetchChatMetadata(roundId: String) async throws -> ChatMetadata?

    /// Mark chat as read (reset unread count, update lastReadAt)
    func markChatAsRead(roundId: String) async throws

    /// Mute/unmute chat notifications for a round
    func setChatMuted(roundId: String, isMuted: Bool) async throws

    /// Get total unread count across all rounds
    func getTotalChatUnreadCount() async throws -> Int

    /// Observe total unread count changes
    func observeTotalChatUnreadCount() -> AsyncStream<Int>
}
```

**Add to FirestoreChatRepository:**

```swift
func fetchChatMetadata(roundId: String) async throws -> ChatMetadata? {
    guard let uid = currentUid else {
        throw ChatError.notAuthenticated
    }

    let doc = try await db
        .collection("rounds").document(roundId)
        .collection("chatMetadata").document(uid)
        .getDocument()

    guard doc.exists else { return nil }
    return try doc.data(as: ChatMetadata.self)
}

func markChatAsRead(roundId: String) async throws {
    guard let uid = currentUid else {
        throw ChatError.notAuthenticated
    }

    try await db
        .collection("rounds").document(roundId)
        .collection("chatMetadata").document(uid)
        .setData([
            "uid": uid,
            "lastReadAt": FieldValue.serverTimestamp(),
            "unreadCount": 0
        ], merge: true)
}

func setChatMuted(roundId: String, isMuted: Bool) async throws {
    guard let uid = currentUid else {
        throw ChatError.notAuthenticated
    }

    try await db
        .collection("rounds").document(roundId)
        .collection("chatMetadata").document(uid)
        .setData([
            "uid": uid,
            "isMuted": isMuted
        ], merge: true)
}

func getTotalChatUnreadCount() async throws -> Int {
    guard let uid = currentUid else { return 0 }

    // Query all rounds where user is accepted member
    let membershipSnapshot = try await db
        .collectionGroup("members")
        .whereField("uid", isEqualTo: uid)
        .whereField("status", isEqualTo: "accepted")
        .getDocuments()

    var totalUnread = 0

    // For each round, fetch chat metadata
    for memberDoc in membershipSnapshot.documents {
        let roundId = memberDoc.reference.parent.parent?.documentID ?? ""
        if roundId.isEmpty { continue }

        let metadataDoc = try await db
            .collection("rounds").document(roundId)
            .collection("chatMetadata").document(uid)
            .getDocument()

        if let metadata = try? metadataDoc.data(as: ChatMetadata.self) {
            totalUnread += metadata.unreadCount
        }
    }

    return totalUnread
}

func observeTotalChatUnreadCount() -> AsyncStream<Int> {
    AsyncStream { continuation in
        guard let uid = currentUid else {
            continuation.yield(0)
            continuation.finish()
            return
        }

        // Listen to all chatMetadata documents for this user
        // This requires a composite query across multiple rounds
        // For simplicity, we'll poll periodically (every 5 seconds)
        // In production, consider using a denormalized count in user doc

        let task = Task {
            while !Task.isCancelled {
                if let count = try? await getTotalChatUnreadCount() {
                    continuation.yield(count)
                }
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            }
        }

        continuation.onTermination = { _ in
            task.cancel()
        }
    }
}
```

**Usage in RoundChatViewModel:**

```swift
// When user opens chat
func onChatAppeared() async {
    await markChatAsRead()
}

private func markChatAsRead() async {
    do {
        try await chatRepository.markChatAsRead(roundId: roundId)
        // Also mark notification as read if exists
        // (handled by NotificationsViewModel)
    } catch {
        print("Failed to mark chat as read: \(error)")
    }
}

// Mute/unmute functionality
func toggleMute() async {
    isMuted.toggle()
    do {
        try await chatRepository.setChatMuted(roundId: roundId, isMuted: isMuted)
    } catch {
        print("Failed to toggle mute: \(error)")
        isMuted.toggle() // Revert on error
    }
}
```

### 5.4 NotificationsViewModel

```swift
@MainActor
final class NotificationsViewModel: ObservableObject {
    private let notificationsRepository: NotificationsRepository
    private let chatRepository: ChatRepository
    private let currentUid: () -> String?

    @Published var recentNotifications: [Notification] = []  // Top 20 from listener
    @Published var olderNotifications: [Notification] = []   // Loaded via pagination
    @Published var notificationUnreadCount: Int = 0          // Unread non-chat notifications
    @Published var chatUnreadCount: Int = 0                  // Unread chat messages
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var hasMoreNotifications = true

    /// Total unread count (notifications + chat messages)
    var totalUnreadCount: Int {
        notificationUnreadCount + chatUnreadCount
    }

    var allNotifications: [Notification] {
        recentNotifications + olderNotifications
    }

    var isEmpty: Bool {
        allNotifications.isEmpty && !isLoading
    }

    // Group notifications by date
    var groupedNotifications: [(String, [Notification])] {
        let calendar = Calendar.current
        let now = Date()

        var groups: [String: [Notification]] = [:]

        for notif in allNotifications {
            let section: String
            if calendar.isDateInToday(notif.createdAt) {
                section = "Today"
            } else if calendar.isDateInYesterday(notif.createdAt) {
                section = "Yesterday"
            } else if calendar.dateComponents([.day], from: notif.createdAt, to: now).day! < 7 {
                section = "This Week"
            } else if calendar.dateComponents([.day], from: notif.createdAt, to: now).day! < 30 {
                section = "This Month"
            } else {
                section = "Earlier"
            }

            groups[section, default: []].append(notif)
        }

        // Sort sections
        let sectionOrder = ["Today", "Yesterday", "This Week", "This Month", "Earlier"]
        return sectionOrder.compactMap { section in
            guard let notifs = groups[section] else { return nil }
            return (section, notifs.sorted { $0.createdAt > $1.createdAt })
        }
    }

    init(
        notificationsRepository: NotificationsRepository,
        chatRepository: ChatRepository,
        currentUid: @escaping () -> String?
    ) {
        self.notificationsRepository = notificationsRepository
        self.chatRepository = chatRepository
        self.currentUid = currentUid
    }

    // MARK: - Listeners

    func startListening() {
        // Listen to recent 20 notifications
        Task {
            for await notifications in notificationsRepository.observeRecentNotifications() {
                self.recentNotifications = notifications
            }
        }

        // Listen to notification unread count (non-chat)
        Task {
            for await count in notificationsRepository.observeUnreadCount() {
                self.notificationUnreadCount = count
            }
        }

        // Listen to chat unread count (across all rounds)
        Task {
            for await count in chatRepository.observeTotalChatUnreadCount() {
                self.chatUnreadCount = count
            }
        }
    }

    // MARK: - Load Older Notifications (Pagination)

    func loadOlderNotifications() async {
        guard !isLoadingMore, hasMoreNotifications else { return }

        isLoadingMore = true

        do {
            let lastDate = allNotifications.last?.createdAt
            let moreNotifications = try await notificationsRepository.fetchNotifications(
                limit: 20,
                after: lastDate
            )

            olderNotifications.append(contentsOf: moreNotifications)
            hasMoreNotifications = moreNotifications.count >= 20
        } catch {
            print("Failed to load older notifications: \(error)")
            errorMessage = error.localizedDescription
        }

        isLoadingMore = false
    }

    // MARK: - Actions

    func markAsRead(_ notification: Notification) async {
        guard let id = notification.id, !notification.isRead else { return }

        do {
            try await notificationsRepository.markAsRead(notificationId: id)
        } catch {
            print("Failed to mark as read: \(error)")
        }
    }

    func markAllAsRead() async {
        do {
            try await notificationsRepository.markAllAsRead()
        } catch {
            print("Failed to mark all as read: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func deleteNotification(_ notification: Notification) async {
        guard let id = notification.id else { return }

        do {
            try await notificationsRepository.deleteNotification(notificationId: id)
        } catch {
            print("Failed to delete notification: \(error)")
            errorMessage = error.localizedDescription
        }
    }
}
```

---

## 6. UI Components

### 6.1 NotificationsView

Main view for the Notifications tab with industry-standard UX.

**Features:**
- Real-time updates for top 20
- Pagination for older notifications
- Date grouping (Today, Yesterday, This Week, etc.)
- Mark all as read button
- Swipe actions (mark as read, delete)
- Tap to navigate to target
- Multiple visual cues for unread status
- Graceful error handling for deleted targets
- Empty state

**Layout:**
```
┌─────────────────────────────┐
│ Notifications        ✓ Mark │  ← Navigation bar
│                       All    │
├─────────────────────────────┤
│ TODAY                        │  ← Date section header
├─────────────────────────────┤
│ ● Join Request      [2h ago]│  ← Unread (blue bg + dot + bold)
│   JohnDoe requested to join │
│   your round at Pebble       │
│   [Avatar] [Text] [>]        │
│   [Light blue background]    │
├─────────────────────────────┤
│   New Follower      [5h ago]│  ← Read (white bg, no dot)
│   JaneSmith started follow..│
│   [Avatar] [Text] [>]        │
├─────────────────────────────┤
│ YESTERDAY                    │
├─────────────────────────────┤
│   Post Upvoted      [1d ago]│
│   3 people upvoted your post │
│   [3 Avatars] [Text] [>]     │
└─────────────────────────────┘
```

**Implementation:**
```swift
struct NotificationsView: View {
    @StateObject private var viewModel: NotificationsViewModel
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) private var dismiss

    // Navigation state
    @State private var selectedRoundId: String?
    @State private var selectedPostId: String?
    @State private var selectedProfileUid: String?
    @State private var showingChat = false
    @State private var chatRoundId: String?
    @State private var showingError = false
    @State private var errorAlertMessage: String?

    init(viewModel: NotificationsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGrouped.ignoresSafeArea()

                if viewModel.isEmpty {
                    emptyState
                } else {
                    notificationsList
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !viewModel.isEmpty && viewModel.unreadCount > 0 {
                        Button {
                            Task { await viewModel.markAllAsRead() }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                Text("Mark All")
                                    .font(AppTypography.caption)
                            }
                            .foregroundColor(AppColors.primary)
                        }
                    }
                }
            }
            .task {
                viewModel.startListening()
            }
            .navigationDestination(item: $selectedRoundId) { roundId in
                RoundDetailView(viewModel: container.makeRoundDetailViewModel(roundId: roundId))
                    .onAppear {
                        // Mark notification as read when navigating
                        if let notif = viewModel.allNotifications.first(where: { $0.targetId == roundId }) {
                            Task { await viewModel.markAsRead(notif) }
                        }
                    }
            }
            .navigationDestination(item: $selectedPostId) { postId in
                PostDetailView(viewModel: container.makePostDetailViewModel(postId: postId))
                    .onAppear {
                        if let notif = viewModel.allNotifications.first(where: { $0.targetId == postId }) {
                            Task { await viewModel.markAsRead(notif) }
                        }
                    }
            }
            .navigationDestination(item: $selectedProfileUid) { uid in
                OtherUserProfileView(viewModel: container.makeOtherUserProfileViewModel(uid: uid))
                    .onAppear {
                        if let notif = viewModel.allNotifications.first(where: { $0.actorUid == uid }) {
                            Task { await viewModel.markAsRead(notif) }
                        }
                    }
            }
            .sheet(isPresented: $showingChat) {
                if let roundId = chatRoundId {
                    NavigationStack {
                        RoundChatView(viewModel: container.makeRoundChatViewModel(roundId: roundId))
                            .toolbar {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button("Done") { showingChat = false }
                                }
                            }
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { errorAlertMessage = nil }
            } message: {
                Text(errorAlertMessage ?? "")
            }
        }
    }

    // MARK: - Notifications List

    private var notificationsList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(viewModel.groupedNotifications, id: \.0) { section, notifications in
                    Section {
                        ForEach(notifications) { notification in
                            NotificationRow(
                                notification: notification,
                                onTap: {
                                    handleNotificationTap(notification)
                                },
                                onMarkAsRead: {
                                    Task { await viewModel.markAsRead(notification) }
                                },
                                onDelete: {
                                    Task { await viewModel.deleteNotification(notification) }
                                }
                            )
                            Divider()
                                .padding(.leading, 72)
                        }
                    } header: {
                        HStack {
                            Text(section)
                                .font(AppTypography.labelMedium)
                                .foregroundColor(AppColors.textSecondary)
                                .textCase(.uppercase)
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.contentPadding)
                        .padding(.vertical, AppSpacing.xs)
                        .background(AppColors.backgroundGrouped)
                    }
                }

                // Load more trigger
                if viewModel.hasMoreNotifications {
                    loadMoreView
                }
            }
        }
        .refreshable {
            // Refresh handled automatically by real-time listener
        }
    }

    private var loadMoreView: some View {
        HStack {
            Spacer()
            if viewModel.isLoadingMore {
                ProgressView()
            } else {
                Text("Load older notifications")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
        }
        .padding(.vertical, AppSpacing.md)
        .onAppear {
            Task {
                await viewModel.loadOlderNotifications()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            Image(systemName: "bell.slash")
                .font(.system(size: 56))
                .foregroundStyle(AppColors.textTertiary)

            VStack(spacing: AppSpacing.sm) {
                Text("No Notifications Yet")
                    .font(AppTypography.headlineMedium)
                    .foregroundColor(AppColors.textPrimary)

                Text("You'll see updates about rounds, posts, and followers here")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(AppSpacing.contentPadding)
    }

    // MARK: - Navigation Handler

    private func handleNotificationTap(_ notification: Notification) {
        // Gracefully handle deleted targets
        switch notification.targetType {
        case .round:
            if let roundId = notification.targetId {
                selectedRoundId = roundId
            }

        case .post:
            if let postId = notification.targetId {
                selectedPostId = postId
            }

        case .profile:
            if let actorUid = notification.actorUid {
                selectedProfileUid = actorUid
            }

        case .none:
            // System notifications or no action
            break
        }

        // Special handling for chat messages
        if notification.type == .roundChatMessage, let roundId = notification.targetId {
            chatRoundId = roundId
            showingChat = true
        }
    }
}
```

### 6.2 NotificationRow

Single notification row with industry-standard visual cues.

**Visual States:**
- **Unread**: Blue dot (8pt) + light blue background + bold text + primary time color
- **Read**: No dot + white background + regular text + secondary time color

**Swipe Actions:**
- Swipe left → Mark as Read (blue) + Delete (red)

**Implementation:**
```swift
struct NotificationRow: View {
    let notification: Notification
    let onTap: () -> Void
    let onMarkAsRead: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.md) {
                // Unread indicator (blue dot or spacer)
                if !notification.isRead {
                    Circle()
                        .fill(AppColors.primary)
                        .frame(width: 8, height: 8)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 8, height: 8)
                }

                // Actor avatar(s)
                actorAvatars

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(notification.title)
                            .font(notification.isRead ? AppTypography.labelMedium : AppTypography.labelLarge)
                            .foregroundColor(AppColors.textPrimary)

                        Spacer()

                        Text(notification.timeAgoString)
                            .font(AppTypography.caption)
                            .foregroundColor(notification.isRead ? AppColors.textTertiary : AppColors.primary)
                    }

                    Text(notification.body)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(AppSpacing.md)
            .background(notification.isRead ? Color.clear : AppColors.primary.opacity(0.08))
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // Delete action (red)
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }

            // Mark as read action (blue) - only show if unread
            if !notification.isRead {
                Button {
                    onMarkAsRead()
                } label: {
                    Label("Mark Read", systemImage: "checkmark")
                }
                .tint(AppColors.primary)
            }
        }
    }

    // MARK: - Actor Avatars

    @ViewBuilder
    private var actorAvatars: some View {
        if notification.isAggregated {
            // Show 2-3 overlapping avatars
            aggregatedAvatars
        } else if let actorUid = notification.actorUid {
            // Show single avatar
            singleAvatar(photoUrl: notification.actorPhotoUrl, nickname: notification.actorNickname)
        } else {
            // System notification - show app icon
            systemIcon
        }
    }

    private var aggregatedAvatars: some View {
        ZStack(alignment: .leading) {
            ForEach(Array(notification.displayActorUids.prefix(3).enumerated()), id: \.offset) { index, _ in
                Circle()
                    .fill(AppColors.primary.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text("\(notification.actorCount ?? 0)")
                            .font(AppTypography.labelMedium)
                            .foregroundColor(AppColors.primary)
                    )
                    .offset(x: CGFloat(index * 12))
            }
        }
        .frame(width: 40 + CGFloat((min(3, notification.displayActorUids.count) - 1) * 12), height: 40)
    }

    private func singleAvatar(photoUrl: String?, nickname: String?) -> some View {
        Group {
            if let photoUrl = photoUrl, let url = URL(string: photoUrl) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    initialsView(nickname: nickname)
                }
            } else {
                initialsView(nickname: nickname)
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
    }

    private func initialsView(nickname: String?) -> some View {
        Circle()
            .fill(AppColors.primary.opacity(0.15))
            .overlay(
                Text(String(nickname?.prefix(1) ?? "?"))
                    .font(AppTypography.labelLarge)
                    .foregroundColor(AppColors.primary)
            )
    }

    private var systemIcon: some View {
        Circle()
            .fill(AppColors.primary.opacity(0.15))
            .frame(width: 40, height: 40)
            .overlay(
                Image(systemName: "bell.fill")
                    .font(.body)
                    .foregroundColor(AppColors.primary)
            )
    }
}
```

### 6.3 Inline Action Buttons (Nice-to-Have)

For round invitations, show Accept/Decline buttons directly in notification row.

```swift
// Add to NotificationRow for .roundInvitation type
if notification.type == .roundInvitation && !notification.isRead {
    HStack(spacing: AppSpacing.sm) {
        SecondaryButton("Decline") {
            handleDeclineInvite(notification)
        }
        PrimaryButton("Accept") {
            handleAcceptInvite(notification)
        }
    }
    .padding(.top, AppSpacing.sm)
}
```

---

## 7. Navigation & Error Handling

### 7.1 Tap Actions by Type

| Type | Target Screen | Parameters | Error Handling |
|------|--------------|------------|----------------|
| `roundJoinRequest` | RoundDetailView | roundId | Show "Round no longer exists" if 404 |
| `roundJoinAccepted` | RoundDetailView | roundId | Show error if round deleted/cancelled |
| `roundJoinDeclined` | RoundDetailView | roundId | Graceful fallback |
| `roundInvitation` | RoundDetailView | roundId | Allow accept even if round changed |
| `roundCancelled` | RoundDetailView | roundId | Show cancelled state |
| `roundUpdated` | RoundDetailView | roundId | Show current state |
| `roundChatMessage` | RoundChatView | roundId | Check membership before opening |
| `userFollowed` | OtherUserProfileView | actorUid | Handle blocked/deleted users |
| `postUpvoted` | PostDetailView | targetId (postId) | Show "Post deleted" if 404 |
| `postCommented` | PostDetailView | targetId (postId) | Handle visibility changes |
| `commentReplied` | PostDetailView | targetId (postId) | Scroll to comment if exists |
| `commentMentioned` | PostDetailView | targetId (postId) | Highlight mention |
| `welcomeMessage` | No action | - | - |
| `tier2Reminder` | ProfileGateView | - | - |

### 7.2 Error Handling Implementation

```swift
// In RoundDetailViewModel
func loadRound() async {
    isLoading = true
    errorMessage = nil

    do {
        round = try await roundsRepository.fetchRound(id: roundId)

        if round == nil {
            // Round not found - graceful error
            errorMessage = "This round no longer exists."
        }
    } catch {
        errorMessage = error.localizedDescription
    }

    isLoading = false
}

// In RoundDetailView
if let error = viewModel.errorMessage, viewModel.round == nil {
    VStack(spacing: AppSpacing.lg) {
        Image(systemName: "exclamationmark.triangle")
            .font(.largeTitle)
            .foregroundColor(AppColors.textSecondary)

        Text(error)
            .font(AppTypography.bodyMedium)
            .foregroundColor(AppColors.textSecondary)
            .multilineTextAlignment(.center)

        SecondaryButton("Go Back") {
            dismiss()
        }
    }
    .padding()
}
```

### 7.3 Access Control Checks

```swift
// Before opening chat, verify user is still member
func openRoundChat(_ roundId: String) {
    Task {
        do {
            let membership = try await roundsRepository.fetchMembershipStatus(roundId: roundId)

            if membership?.status == .accepted {
                chatRoundId = roundId
                showingChat = true
            } else {
                errorAlertMessage = "You must be a member to view this chat."
                showingError = true
            }
        } catch {
            errorAlertMessage = "Unable to open chat. \(error.localizedDescription)"
            showingError = true
        }
    }
}
```

---

## 8. Tab Bar Badge

### 8.1 Unread Count Badge

Show red badge on Notifications tab icon with unread count.

**Rules:**
- Show count up to 99 (display "99+" if more)
- Update in real-time via Firestore listener
- Badge disappears when count = 0

**Implementation:**
```swift
// In MainTabView
TabView(selection: $selectedTab) {
    NotificationsView(viewModel: container.makeNotificationsViewModel())
        .tabItem {
            Label("Notifications", systemImage: "bell")
        }
        .badge(notificationsViewModel.totalUnreadCount > 0 ? min(notificationsViewModel.totalUnreadCount, 99) : nil)
        .tag(Tab.notifications)
}

// AppContainer needs to expose notificationsViewModel as @Published
@Published var notificationsViewModel: NotificationsViewModel?

func makeNotificationsViewModel() -> NotificationsViewModel {
    if notificationsViewModel == nil {
        notificationsViewModel = NotificationsViewModel(
            notificationsRepository: notificationsRepository,
            chatRepository: chatRepository,
            currentUid: { [weak self] in self?.currentUid }
        )
        notificationsViewModel?.startListening()
    }
    return notificationsViewModel!
}
```

---

## 9. Firestore Security Rules

```javascript
// Notifications - user can only read/write their own
match /notifications/{userId}/items/{notificationId} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow write: if false;  // Only Cloud Functions can write
}

// Chat metadata - user can read/write their own metadata
match /rounds/{roundId}/chatMetadata/{userId} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow write: if request.auth != null && request.auth.uid == userId
               && request.resource.data.uid == userId;  // Can't change UID
}
```

**Notes:**
- Users can only read their own notifications
- Cloud Functions have elevated privileges to write notifications
- No client-side creation of notifications allowed (prevents spam)
- Users can update their own chat metadata (lastReadAt, isMuted)
- Cloud Functions can update any chat metadata (unreadCount, lastMessageAt)

---

## 10. Performance & Optimization

### 10.1 Query Limits & Pagination Strategy

**Real-Time Listener:**
- Top 20 most recent notifications only
- Updates automatically when new notifications arrive
- Minimal Firestore reads (only changed documents)

**Pagination:**
- Load 20 older notifications at a time
- No listener on paginated results (static fetch)
- Triggered when user scrolls near bottom

**Benefits:**
- Reduces Firestore reads by 60% compared to listening to all 50
- Faster initial load
- Scales to thousands of notifications per user

### 10.2 Aggregation Strategy

**Upvotes:**
- Within 1-hour window: Update existing notification
- After 1 hour: Create new notification
- Prevents spam from viral posts

**Chat Messages (Update-in-Place):**
- Always updates existing notification (no time window)
- Shows latest message preview
- Tracks exact unread count per user
- Respects per-conversation mute settings
- One notification per round, always current

**Implementation Benefit:**
- 100 upvotes → 1 notification (100x reduction)
- 50 chat messages → 1 notification (50x reduction)

### 10.3 Auto-Cleanup (Cloud Function)

Delete notifications older than 30 days to keep collection size manageable.

```typescript
export const cleanupOldNotifications = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    const cutoff = Date.now() - 30 * 24 * 60 * 60 * 1000; // 30 days ago
    const cutoffDate = new Date(cutoff);

    const usersSnapshot = await admin.firestore()
      .collection('notifications')
      .listDocuments();

    for (const userDoc of usersSnapshot) {
      const oldNotifs = await userDoc
        .collection('items')
        .where('createdAt', '<', cutoffDate)
        .limit(100)  // Batch delete to avoid timeout
        .get();

      if (oldNotifs.empty) continue;

      const batch = admin.firestore().batch();
      oldNotifs.docs.forEach(doc => batch.delete(doc.ref));

      await batch.commit();
    }
  });
```

### 10.4 Denormalization Trade-Offs

**Stored:**
- `actorNickname`, `actorPhotoUrl`: Faster rendering, avoid profile fetches

**Trade-off:**
- Stale data if user changes nickname/photo
- **Decision:** Acceptable for MVP (notifications are ephemeral)

**Future Enhancement:**
- Scheduled function to update denormalized data in recent notifications (last 7 days only)

---

## 11. Implementation Plan

### Week 1: Data Layer & Cloud Functions

**Day 1: Models & Repository**
- [ ] Create `Notification`, `NotificationType`, `TargetType` models
- [ ] Add aggregation fields (`actorUids`, `actorCount`, `updatedAt`)
- [ ] Create `NotificationsRepository` protocol
- [ ] Create `FirestoreNotificationsRepository`
- [ ] Implement paginated real-time listener (top 20 only)
- [ ] Add Firestore security rules

**Day 2: Cloud Functions - Round Activity**
- [ ] Implement `onRoundMemberWrite` (join requests, invitations)
- [ ] Implement `onRoundUpdate` (cancellations, edits)
- [ ] Implement `onChatMessage` with update-in-place pattern
- [ ] Test triggers locally with emulator

**Day 3: Cloud Functions - Social Activity**
- [ ] Implement `onFollowCreate` (new followers)
- [ ] Implement `onUpvoteCreate` with aggregation logic
- [ ] Implement `onCommentCreate` (comments, replies, mentions)
- [ ] Test all social triggers

**Day 4: Cloud Functions Deployment**
- [ ] Deploy all notification functions to production
- [ ] Monitor Cloud Functions logs
- [ ] Test end-to-end notification creation
- [ ] Verify aggregation works correctly
- [ ] Fix any bugs or missing cases

### Week 2: UI & Real-Time Updates

**Day 5: NotificationsViewModel**
- [ ] Create `NotificationsViewModel`
- [ ] Implement real-time listener (recent 20)
- [ ] Implement pagination for older notifications
- [ ] Implement date grouping logic
- [ ] Implement mark as read / mark all as read
- [ ] Implement delete notification
- [ ] Add factory method to AppContainer

**Day 6: NotificationsView**
- [ ] Create `NotificationsView` with grouped list
- [ ] Implement date section headers
- [ ] Add "Mark All as Read" toolbar button
- [ ] Implement pagination trigger (load more)
- [ ] Handle loading/empty/error states
- [ ] Add pull-to-refresh (no-op, handled by listener)

**Day 7: NotificationRow Component**
- [ ] Create `NotificationRow` view
- [ ] Implement multiple visual cues (dot + background + bold)
- [ ] Render actor avatar(s) - single vs aggregated
- [ ] Show title, body, time ago
- [ ] Add swipe actions (mark as read, delete)
- [ ] Handle single vs aggregated actors

**Day 8: Navigation & Error Handling**
- [ ] Implement tap handlers for all notification types
- [ ] Navigate to RoundDetailView, PostDetailView, etc.
- [ ] Pass correct targetId to ViewModels
- [ ] Mark notification as read on tap
- [ ] Add error handling for deleted targets (404)
- [ ] Add access control checks (membership, visibility)
- [ ] Test all navigation flows

**Day 9: Tab Bar Badge**
- [ ] Add unread count listener to AppContainer
- [ ] Display badge on Notifications tab
- [ ] Update badge in real-time
- [ ] Test badge behavior (show/hide)
- [ ] Handle "99+" for counts over 99

**Day 10: Polish & Testing**
- [ ] Empty state view
- [ ] Error handling for all operations
- [ ] UI polish per UI_RULES.md
- [ ] Test with various notification types
- [ ] Test aggregation UX (multiple upvotes)
- [ ] Test pagination performance
- [ ] Edge cases (deleted posts, blocked users, cancelled rounds)
- [ ] End-to-end testing of all notification flows

---

## 12. Components to Create

### Swift Models
- `Notification`
- `NotificationType` enum
- `TargetType` enum

### Views
- `NotificationsView` - Main notifications tab with date grouping
- `NotificationRow` - Single notification row with swipe actions
- `EmptyNotificationsView` - Empty state (integrated in NotificationsView)

### ViewModels
- `NotificationsViewModel` - Notifications state + actions + pagination

### Repositories
- `NotificationsRepository` protocol
- `FirestoreNotificationsRepository` implementation

### Cloud Functions (TypeScript)
- `onRoundMemberWrite` - Join requests, invitations, acceptances
- `onRoundUpdate` - Cancellations, edits
- `onChatMessage` - Round chat messages (update-in-place)
- `onFollowCreate` - New followers
- `onUpvoteCreate` - Post upvotes (aggregated within 1 hour)
- `onCommentCreate` - Comments, replies, mentions
- `cleanupOldNotifications` - Delete notifications older than 30 days

---

## 13. Success Criteria

**Core Functionality:**
- [ ] All notification types are created correctly by Cloud Functions
- [ ] Real-time updates work for top 20 notifications
- [ ] Pagination loads older notifications without listener
- [ ] Unread count badge on tab bar updates in real-time
- [ ] Tapping notification navigates to correct screen
- [ ] Mark as read / mark all as read works
- [ ] Swipe to delete works
- [ ] Swipe to mark as read works (unread only)
- [ ] Empty state shown when no notifications
- [ ] No Firebase imports in Views
- [ ] Firestore security rules enforce user-only access

**Aggregation & Throttling:**
- [ ] Multiple upvotes within 1 hour show as "3 people upvoted..."
- [ ] Chat messages update existing notification (one per round)
- [ ] Aggregated notifications update `actorUids` and `actorCount` correctly
- [ ] Aggregation doesn't create duplicate notifications

**UX & Accessibility:**
- [ ] Unread notifications have 3 visual cues (dot + background + bold)
- [ ] Date grouping works (Today, Yesterday, This Week, etc.)
- [ ] Section headers are sticky during scroll
- [ ] Time display is human-readable (relative time)
- [ ] Avatars render correctly for single/aggregated/system notifications

**Error Handling:**
- [ ] Deleted rounds/posts show graceful error message
- [ ] Navigation fails gracefully (no crashes)
- [ ] Access control enforced (chat requires membership)
- [ ] Network errors show user-friendly messages

**Performance:**
- [ ] Real-time listener only queries 20 notifications (not 50+)
- [ ] Pagination doesn't refetch entire dataset
- [ ] Aggregation reduces notification count by 80%+ for popular posts
- [ ] Initial load completes in <2 seconds

---

## 14. Open Questions & Decisions

1. **Aggregated upvotes time window**: 1 hour → **CONFIRMED**
2. **Chat notification update-in-place**: One persistent notification per round, updated with latest message → **CONFIRMED**
3. **Notification retention**: 30 days, then auto-delete → **CONFIRMED**
4. **Real-time listener limit**: Top 20 only → **CONFIRMED**
5. **Push notifications**: When to implement? → **Defer to Phase 6**
6. **Round reminders**: 24h reminder? → **Nice-to-have, not required for MVP**
7. **Sound/vibration**: Play sound? → **No for MVP (in-app only)**
8. **Notification settings**: Per-type toggles? → **Defer to Phase 6**
9. **Mark read automatically**: On view or on tap? → **On tap**
10. **Inline action buttons**: Accept/Decline in row? → **Nice-to-have, implement if time allows**
11. **Multiple visual cues**: Dot + background + bold? → **YES - Required for accessibility**

---

## 15. Dependencies

- Phase 1 (Identity): User profiles for denormalized actor data
- Phase 2 (Rounds): Round activity notifications
- Phase 3 (Chat): Round chat message notifications
- Phase 4 (Social): Follow, upvote, comment notifications
- Firebase Cloud Functions: Server-side notification creation

---

## 16. Push Notification Readiness

**Question:** How hard will it be to add push notifications later?

**Answer:** Very easy. The current architecture is perfectly positioned for push. Estimated effort: **2-3 days**.

### What's Already Built (Push-Ready)

✅ **Server-side notification creation**
- Cloud Functions already create all notifications
- Just need to add FCM send after writing Firestore doc
- No client-side changes to notification creation logic

✅ **Structured notification data**
- `title`, `body` already perfect for push payload
- `targetType` + `targetId` ready for deep linking
- `actorPhotoUrl` ready for rich notifications (iOS)

✅ **Update-in-place chat pattern**
- Perfect for push: always shows latest message
- Cloud Function checks `chatMetadata.lastReadAt` before sending push
- If user already read, skip push (avoid duplicate)

✅ **Mute functionality**
- Already tracking `isMuted` per conversation
- Cloud Function just checks before sending push

✅ **Badge count**
- `totalUnreadCount` already calculated
- Include in push payload for iOS badge

✅ **Aggregation strategy**
- Upvotes aggregate within 1 hour → fewer pushes
- Chat updates in-place → one push per round
- Prevents push notification spam

### What Needs to Be Added (2-3 Days)

**Day 1: FCM Token Management**

1. Add device token collection:
```typescript
users/{uid}/devices/{deviceId}
{
  fcmToken: "string",
  platform: "ios",
  lastActive: timestamp,
  appVersion: "1.0.0"
}
```

2. Client registers token on app launch:
```swift
func application(_ application: UIApplication,
                didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    // Save to Firestore
    try await userRepository.saveDeviceToken(token)
}
```

**Day 2: Update Cloud Functions**

Add FCM send to existing functions:
```typescript
async function createNotification(userId: string, notifData: any) {
    // 1. Write to Firestore (already doing this)
    await db.collection('notifications').doc(userId)
        .collection('items').add(notifData);

    // 2. NEW: Send push notification
    const userDevices = await db.collection('users').doc(userId)
        .collection('devices').get();

    const tokens = userDevices.docs.map(d => d.data().fcmToken);

    if (tokens.length > 0) {
        await admin.messaging().sendMulticast({
            tokens: tokens,
            notification: {
                title: notifData.title,
                body: notifData.body
            },
            data: {
                targetType: notifData.targetType,
                targetId: notifData.targetId,
                notificationId: notifData.id
            },
            apns: {
                payload: {
                    aps: {
                        badge: notifData.badgeCount || 0  // iOS badge
                    }
                }
            }
        });
    }
}
```

**Day 3: Deep Linking & Foreground Handling**

1. Handle push tap (already have navigation logic):
```swift
func userNotificationCenter(_ center: UNUserNotificationCenter,
                           didReceive response: UNNotificationResponse) {
    let userInfo = response.notification.request.content.userInfo

    // Use existing navigation helper
    if let targetType = userInfo["targetType"] as? String,
       let targetId = userInfo["targetId"] as? String {
        navigationHelper.navigate(to: targetType, id: targetId)
    }
}
```

2. Suppress push when app is in foreground:
```swift
func userNotificationCenter(_ center: UNUserNotificationCenter,
                           willPresent notification: UNNotification) -> UNNotificationPresentationOptions {
    // App is open - don't show push, in-app notification handles it
    return []
}
```

### Why This Architecture Is Push-Ready

| Design Decision | Push Benefit |
|----------------|-------------|
| Server-side creation | Single place to add FCM send |
| Update-in-place chat | Fewer pushes, always relevant |
| Mute per conversation | Easy to respect in Cloud Function |
| Structured payload | title/body/targetType/targetId ready |
| Badge count calculated | Include in push immediately |
| Denormalized actor data | Rich notifications without extra fetches |

### What Makes It Easy

1. **No architectural changes needed** - just add FCM calls to existing functions
2. **Deep linking already designed** - targetType + targetId navigation exists
3. **Badge count already tracked** - totalUnreadCount available
4. **Mute logic already built** - just check isMuted before sending
5. **Update-in-place reduces complexity** - don't need to handle "update" pushes separately

### Complexity Comparison

**If we had used other patterns:**
- ❌ Client-side notification creation → Would need major refactor to move to server
- ❌ One push per message → Would need throttling logic later
- ❌ Time-window aggregation → Would need complex "update push" logic
- ❌ No mute support → Would need to add later (breaking change)

**With current architecture:**
- ✅ Add FCM token storage (1 day)
- ✅ Add FCM send to existing functions (1 day)
- ✅ Add deep linking handler (1 day)
- ✅ Done!

### Push Notification Flow (Future)

```
New message arrives
    ↓
Cloud Function (onChatMessage)
    ↓
1. Check if user muted → Skip if muted
    ↓
2. Update/create Firestore notification
    ↓
3. Fetch user's device tokens
    ↓
4. Send FCM push with:
   - title: "Pebble Beach • Jan 20"
   - body: "Alice: See you at first tee!"
   - badge: totalUnreadCount
   - data: {targetType: "round", targetId: "abc123"}
    ↓
User taps push
    ↓
Deep link handler navigates to RoundChatView
    ↓
Client marks chat as read → badge decrements
```

**Conclusion:** Push notifications will be a straightforward 2-3 day addition with zero architectural changes needed. The current design is production-ready for push.

---

## 17. Future Enhancements (Post-MVP / Phase 6+)

**Push Notifications:**
- APNs integration for iOS push *(2-3 days)*
- Notification settings (toggle types on/off)
- Rich notifications (images, action buttons)
- Critical alerts (round starting soon)

**Advanced UX:**
- Email digests (daily/weekly summary)
- In-app notification banner (toast/snackbar)
- Notification sounds and haptics
- Notification grouping by conversation
- "Seen by" receipts for round chat
- Notification preferences per type

**Analytics:**
- Track notification open rates
- Measure time-to-action (invitation → accept)
- A/B test notification copy

---

This document is the source of truth for Phase 5 implementation.
