# Abuse Protection Strategy

## Overview

This document outlines protection strategies against spam, bots, and abusive behavior in TeePals. While not critical for initial development, these protections become essential before scaling past 1000 users.

**Current Status:** ⚠️ Minimal protection. Security rules prevent unauthorized access, but no rate limiting exists.

**Risk:** One bad actor with a bot could spam thousands of posts/rounds/comments, making the app unusable.

---

## Current Vulnerabilities

### 1. Spam Posting (CRITICAL)
- **Attack:** Automated bot creates thousands of posts
- **Current Protection:** None (only requires authentication)
- **Impact:** Feed becomes unusable, legitimate content buried, cost spike

### 2. Upvote Manipulation (HIGH)
- **Attack:** Bot artificially boosts spam posts to top of feed
- **Current Protection:** None
- **Impact:** Feed ranking becomes meaningless, spam promoted

### 3. Round Spam (HIGH)
- **Attack:** Bot creates fake rounds to pollute geohash search
- **Current Protection:** None
- **Impact:** Round discovery becomes unusable

### 4. Comment Spam (MEDIUM)
- **Attack:** Bot spams comments with promotional links
- **Current Protection:** None
- **Impact:** Harassment, promotional spam on all posts

### 5. Follow/Unfollow Spam (LOW)
- **Attack:** Bot follows/unfollows users repeatedly to get attention
- **Current Protection:** None
- **Impact:** Notification spam, annoyance

---

## Protection Strategy (Phased Approach)

### Phase 1: Server-Side Rate Limiting (CRITICAL)
**Priority:** HIGH - Implement before public launch
**Effort:** 1-2 days
**Cost:** $0

#### Why This First
- Prevents 95% of automated abuse
- No client changes required (backend only)
- Works even if attacker reverse-engineers app

#### Recommended Rate Limits

```typescript
// Conservative limits for legitimate users:
const RATE_LIMITS = {
  posts: { max: 10, windowMs: 15 * 60 * 1000 },      // 10 posts per 15 min
  comments: { max: 30, windowMs: 15 * 60 * 1000 },   // 30 comments per 15 min
  rounds: { max: 5, windowMs: 60 * 60 * 1000 },      // 5 rounds per hour
  upvotes: { max: 100, windowMs: 15 * 60 * 1000 },   // 100 upvotes per 15 min
  follows: { max: 20, windowMs: 60 * 60 * 1000 },    // 20 follows per hour
  chatMessages: { max: 60, windowMs: 60 * 1000 },    // 60 messages per minute
};
```

#### Implementation

**File:** `functions/src/rateLimit.ts`

```typescript
import * as admin from 'firebase-admin';

const db = admin.firestore();

export interface RateLimitConfig {
  max: number;        // Max operations in window
  windowMs: number;   // Time window in milliseconds
}

export class RateLimiter {
  constructor(
    private collection: string,
    private config: RateLimitConfig
  ) {}

  async checkLimit(uid: string): Promise<void> {
    const rateLimitRef = db
      .collection('rateLimits')
      .doc(this.collection)
      .collection('users')
      .doc(uid);

    const now = Date.now();

    await db.runTransaction(async (transaction) => {
      const doc = await transaction.get(rateLimitRef);

      if (!doc.exists) {
        // First request in window
        transaction.set(rateLimitRef, {
          count: 1,
          windowStart: now,
          resetAt: now + this.config.windowMs,
        });
        return;
      }

      const data = doc.data()!;
      const { count, windowStart } = data;

      // Check if window expired
      if (now - windowStart > this.config.windowMs) {
        // Reset window
        transaction.set(rateLimitRef, {
          count: 1,
          windowStart: now,
          resetAt: now + this.config.windowMs,
        });
        return;
      }

      // Check if limit exceeded
      if (count >= this.config.max) {
        const resetIn = Math.ceil((windowStart + this.config.windowMs - now) / 1000);
        throw new Error(`Rate limit exceeded. Try again in ${resetIn} seconds.`);
      }

      // Increment count
      transaction.update(rateLimitRef, {
        count: admin.firestore.FieldValue.increment(1),
      });
    });
  }
}

// Export pre-configured limiters
export const postLimiter = new RateLimiter('posts', {
  max: 10,
  windowMs: 15 * 60 * 1000,
});

export const commentLimiter = new RateLimiter('comments', {
  max: 30,
  windowMs: 15 * 60 * 1000,
});

export const roundLimiter = new RateLimiter('rounds', {
  max: 5,
  windowMs: 60 * 60 * 1000,
});

export const upvoteLimiter = new RateLimiter('upvotes', {
  max: 100,
  windowMs: 15 * 60 * 1000,
});

export const followLimiter = new RateLimiter('follows', {
  max: 20,
  windowMs: 60 * 60 * 1000,
});

export const chatMessageLimiter = new RateLimiter('chatMessages', {
  max: 60,
  windowMs: 60 * 1000,
});
```

**File:** `functions/src/index.ts`

Add rate limiting to Cloud Functions:

```typescript
import { postLimiter, commentLimiter, upvoteLimiter } from './rateLimit';

// Example: Rate limit post creation
export const onPostCreate = functions.firestore
  .document('posts/{postId}')
  .onCreate(async (snap, context) => {
    const post = snap.data();
    const authorUid = post.authorUid as string;

    try {
      // Check rate limit FIRST
      await postLimiter.checkLimit(authorUid);

      // ... rest of existing logic (initialize postStats, update userStats)

    } catch (error) {
      if (error.message.includes('Rate limit exceeded')) {
        // Delete the post and log violation
        await snap.ref.delete();

        await db.collection('violations').add({
          type: 'rate_limit_exceeded',
          collection: 'posts',
          uid: authorUid,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.error(`❌ Rate limit exceeded for user ${authorUid}`);
        return;
      }
      throw error;
    }
  });

// Example: Rate limit upvotes
export const onUpvoteWrite = functions.firestore
  .document('posts/{postId}/upvotes/{uid}')
  .onWrite(async (change, context) => {
    const uid = context.params.uid as string;
    const wasCreated = !change.before.exists && change.after.exists;

    if (wasCreated) {
      try {
        await upvoteLimiter.checkLimit(uid);
      } catch (error) {
        if (error.message.includes('Rate limit exceeded')) {
          // Delete the upvote
          await change.after.ref.delete();

          await db.collection('violations').add({
            type: 'rate_limit_exceeded',
            collection: 'upvotes',
            uid: uid,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          });

          console.error(`❌ Upvote rate limit exceeded for user ${uid}`);
          return;
        }
        throw error;
      }
    }

    // ... rest of existing logic
  });
```

#### Deployment

```bash
cd functions
npm install
npm run build
firebase deploy --only functions
```

#### Testing Rate Limits

```bash
# Test post rate limit
for i in {1..15}; do
  curl -X POST "https://YOUR_PROJECT.firebaseapp.com/createPost" \
    -H "Authorization: Bearer $USER_TOKEN" \
    -d '{"text": "Test post '$i'"}' \
    && echo "Post $i: SUCCESS" \
    || echo "Post $i: RATE LIMITED"
done
```

---

### Phase 2: Firebase App Check (HIGH)
**Priority:** HIGH - Implement before public launch
**Effort:** 1 day
**Cost:** $0 (free tier: 1M verifications/month)

#### Why This Matters
- Prevents bots from calling Firebase SDK directly
- Ensures requests come from legitimate iOS app
- Blocks requests from modified/jailbroken apps

#### Implementation

**Step 1: Register App with App Check**

```bash
# Install Firebase CLI if needed
npm install -g firebase-tools

# Register your app
firebase apps:sdkconfig IOS
```

**Step 2: Add to iOS App**

**File:** `TeePals/TeePalsApp.swift`

```swift
import FirebaseAppCheck

@main
struct TeePalsApp: App {
    @StateObject private var container = AppContainer()

    init() {
        FirebaseApp.configure()

        // Configure App Check
        #if DEBUG
        // Use debug provider in development
        let providerFactory = AppCheckDebugProviderFactory()
        #else
        // Use DeviceCheck provider in production
        let providerFactory = AppAttestProviderFactory()
        #endif

        AppCheck.setAppCheckProviderFactory(providerFactory)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
        }
    }
}
```

**Step 3: Update Firestore Security Rules**

**File:** `firestore.rules`

Add `request.app.check.isValid()` to critical operations:

```javascript
match /posts/{postId} {
  // Read doesn't need App Check (allows web viewers later)
  allow read: if isSignedIn();

  // Write operations require App Check
  allow create: if isSignedIn()
    && request.auth.uid == request.resource.data.authorUid
    && request.resource.data.text is string
    && request.resource.data.text.size() <= 2000
    && request.resource.data.photoUrls.size() <= 4
    && request.app.check.isValid(); // NEW: Require App Check

  allow update: if isSignedIn()
    && resource.data.authorUid == request.auth.uid
    && request.app.check.isValid();

  allow delete: if isSignedIn()
    && resource.data.authorUid == request.auth.uid
    && request.app.check.isValid();
}

// Apply same pattern to rounds, comments, upvotes
match /rounds/{roundId} {
  allow create: if isSignedIn()
    && request.resource.data.hostUid == request.auth.uid
    && request.app.check.isValid(); // NEW
}
```

**Step 4: Deploy**

```bash
# Deploy updated security rules
firebase deploy --only firestore:rules

# Test in debug mode
# Get debug token from Xcode console and register it:
firebase appcheck:debug add --app-id YOUR_IOS_APP_ID --debug-token DEBUG_TOKEN
```

#### Monitoring

Check Firebase Console → App Check dashboard for:
- Valid vs invalid request ratio
- Blocked requests
- Suspicious patterns

---

### Phase 3: Content Moderation (MEDIUM)
**Priority:** MEDIUM - Implement within 1 month of launch
**Effort:** 2-3 days
**Cost:** ~$5/month for ML API calls

#### Automated Spam Detection

**File:** `functions/src/moderation.ts`

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import Filter from 'bad-words';

const db = admin.firestore();
const filter = new Filter();

// Spam detection patterns
const SPAM_PATTERNS = {
  urls: /https?:\/\//i,
  emails: /[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}/i,
  repeatedChars: /(.)\1{10,}/,
  excessiveEmojis: /([\u{1F300}-\u{1F9FF}]){10,}/u,
  promotionalKeywords: /(buy now|click here|limited offer|act now|free money)/i,
};

export const moderatePost = functions.firestore
  .document('posts/{postId}')
  .onCreate(async (snap, context) => {
    const post = snap.data();
    const postId = context.params.postId;
    const text = post.text.toLowerCase();

    let spamScore = 0;
    const flags: string[] = [];

    // Check profanity
    if (filter.isProfane(text)) {
      spamScore += 50;
      flags.push('profanity');
    }

    // Check for URLs (not allowed in posts)
    if (SPAM_PATTERNS.urls.test(text)) {
      spamScore += 70;
      flags.push('contains_url');
    }

    // Check for emails
    if (SPAM_PATTERNS.emails.test(text)) {
      spamScore += 60;
      flags.push('contains_email');
    }

    // Check for repeated characters (aaaaaaaaaa)
    if (SPAM_PATTERNS.repeatedChars.test(text)) {
      spamScore += 30;
      flags.push('repeated_chars');
    }

    // Check for promotional keywords
    if (SPAM_PATTERNS.promotionalKeywords.test(text)) {
      spamScore += 40;
      flags.push('promotional');
    }

    // Check for photo spam (photo with minimal text)
    if (post.photoUrls.length > 0 && text.length < 5) {
      spamScore += 20;
      flags.push('photo_spam');
    }

    // Check new user behavior
    const userStats = await db.collection('userStats').doc(post.authorUid).get();
    if (userStats.exists) {
      const stats = userStats.data()!;
      const accountAgeDays = stats.accountCreatedAt
        ? (Date.now() - stats.accountCreatedAt.toMillis()) / (1000 * 60 * 60 * 24)
        : 0;

      // New accounts posting immediately is suspicious
      if (accountAgeDays < 1 && stats.postCount <= 1) {
        spamScore += 25;
        flags.push('new_account_immediate_post');
      }
    }

    // Take action based on spam score
    if (spamScore >= 100) {
      // High confidence spam - auto-hide
      await snap.ref.update({
        visibility: 'hidden',
        flaggedAsSpam: true,
        spamScore,
        spamFlags: flags,
      });

      // Create automatic report
      await db.collection('reports').add({
        type: 'auto_spam_detection',
        contentType: 'post',
        contentId: postId,
        authorUid: post.authorUid,
        reason: `Automated spam detection (score: ${spamScore})`,
        flags,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`🚫 Auto-hidden spam post ${postId} (score: ${spamScore})`);

    } else if (spamScore >= 50) {
      // Medium confidence - flag for review
      await db.collection('reports').add({
        type: 'auto_spam_detection',
        contentType: 'post',
        contentId: postId,
        authorUid: post.authorUid,
        reason: `Potential spam (score: ${spamScore})`,
        flags,
        priority: 'medium',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`⚠️ Flagged post ${postId} for review (score: ${spamScore})`);
    }
  });

// Apply same logic to comments
export const moderateComment = functions.firestore
  .document('posts/{postId}/comments/{commentId}')
  .onCreate(async (snap, context) => {
    // Similar logic to moderatePost
  });
```

**Install dependencies:**

```bash
cd functions
npm install bad-words
```

**Deploy:**

```bash
npm run build
firebase deploy --only functions:moderatePost,functions:moderateComment
```

---

### Phase 4: User Reporting + Admin Dashboard (MEDIUM)
**Priority:** MEDIUM - Implement within 1 month of launch
**Effort:** 3-4 days
**Cost:** $0

#### Client-Side Reporting UI

**File:** `TeePals/Repositories/ReportsRepository.swift`

```swift
import Foundation
import FirebaseFirestore

protocol ReportsRepository {
    func createReport(
        type: ReportType,
        contentType: ContentType,
        contentId: String,
        reason: String
    ) async throws
}

enum ReportType: String, Codable {
    case spam
    case harassment
    case inappropriate
    case impersonation
    case other
}

enum ContentType: String, Codable {
    case post
    case comment
    case round
    case profile
    case chatMessage
}

final class FirestoreReportsRepository: ReportsRepository {
    private let db = Firestore.firestore()
    private let currentUid: () -> String?

    init(currentUid: @escaping () -> String?) {
        self.currentUid = currentUid
    }

    func createReport(
        type: ReportType,
        contentType: ContentType,
        contentId: String,
        reason: String
    ) async throws {
        guard let uid = currentUid() else {
            throw NSError(domain: "ReportsRepository", code: 401, userInfo: nil)
        }

        try await db.collection("reports").addDocument(data: [
            "reporterUid": uid,
            "type": type.rawValue,
            "contentType": contentType.rawValue,
            "contentId": contentId,
            "reason": reason,
            "status": "pending",
            "createdAt": FieldValue.serverTimestamp(),
        ])
    }
}
```

**Add Report Button to PostCardView:**

```swift
Menu {
    if isOwnPost {
        Button("Edit", systemImage: "pencil") { /* edit */ }
        Button("Delete", systemImage: "trash", role: .destructive) { /* delete */ }
    } else {
        Button("Report", systemImage: "exclamationmark.triangle") {
            showReportSheet = true
        }
    }
} label: {
    Image(systemName: "ellipsis")
        .foregroundColor(AppColors.textSecondary)
}
.sheet(isPresented: $showReportSheet) {
    ReportContentSheet(
        contentType: .post,
        contentId: post.id ?? "",
        onSubmit: { reportType, reason in
            Task {
                try await container.reportsRepository.createReport(
                    type: reportType,
                    contentType: .post,
                    contentId: post.id ?? "",
                    reason: reason
                )
            }
        }
    )
}
```

**File:** `TeePals/Views/Moderation/ReportContentSheet.swift`

```swift
import SwiftUI

struct ReportContentSheet: View {
    let contentType: ContentType
    let contentId: String
    let onSubmit: (ReportType, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: ReportType = .spam
    @State private var reason: String = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Report Type") {
                    Picker("Type", selection: $selectedType) {
                        Text("Spam").tag(ReportType.spam)
                        Text("Harassment").tag(ReportType.harassment)
                        Text("Inappropriate Content").tag(ReportType.inappropriate)
                        Text("Impersonation").tag(ReportType.impersonation)
                        Text("Other").tag(ReportType.other)
                    }
                    .pickerStyle(.menu)
                }

                Section("Details (Optional)") {
                    TextEditor(text: $reason)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Report Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        isSubmitting = true
                        onSubmit(selectedType, reason)
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }
            }
        }
    }
}
```

#### Admin Dashboard (Simple Web App)

**File:** `admin-dashboard/index.html`

```html
<!DOCTYPE html>
<html>
<head>
    <title>TeePals Admin - Reports</title>
    <script src="https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js"></script>
    <script src="https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore-compat.js"></script>
    <script src="https://www.gstatic.com/firebasejs/10.7.1/firebase-auth-compat.js"></script>
    <style>
        body { font-family: system-ui; padding: 20px; }
        .report { border: 1px solid #ccc; padding: 15px; margin: 10px 0; border-radius: 8px; }
        .report.pending { background: #fff3cd; }
        .report.resolved { background: #d4edda; }
        .report.dismissed { background: #f8d7da; }
        button { margin: 5px; padding: 8px 15px; border-radius: 5px; border: none; cursor: pointer; }
        .ban { background: #dc3545; color: white; }
        .delete { background: #ffc107; }
        .dismiss { background: #6c757d; color: white; }
    </style>
</head>
<body>
    <h1>TeePals Admin - Reports Dashboard</h1>
    <div id="auth">
        <button onclick="signIn()">Sign In with Google</button>
    </div>
    <div id="reports"></div>

    <script>
        // Initialize Firebase (replace with your config)
        const firebaseConfig = {
            apiKey: "YOUR_API_KEY",
            authDomain: "YOUR_PROJECT.firebaseapp.com",
            projectId: "YOUR_PROJECT_ID",
        };
        firebase.initializeApp(firebaseConfig);
        const db = firebase.firestore();
        const auth = firebase.auth();

        // Simple auth
        function signIn() {
            const provider = new firebase.auth.GoogleAuthProvider();
            auth.signInWithPopup(provider);
        }

        auth.onAuthStateChanged(user => {
            if (user) {
                document.getElementById('auth').innerHTML = `Signed in as ${user.email}`;
                loadReports();
            }
        });

        // Load reports
        function loadReports() {
            db.collection('reports')
                .where('status', '==', 'pending')
                .orderBy('createdAt', 'desc')
                .onSnapshot(snapshot => {
                    const reportsDiv = document.getElementById('reports');
                    reportsDiv.innerHTML = '';

                    snapshot.docs.forEach(doc => {
                        const report = doc.data();
                        const div = document.createElement('div');
                        div.className = `report ${report.status}`;
                        div.innerHTML = `
                            <h3>${report.type} - ${report.contentType}</h3>
                            <p><strong>Reporter:</strong> ${report.reporterUid}</p>
                            <p><strong>Content ID:</strong> ${report.contentId}</p>
                            <p><strong>Reason:</strong> ${report.reason || 'N/A'}</p>
                            <p><strong>Date:</strong> ${report.createdAt?.toDate().toLocaleString()}</p>
                            ${report.flags ? `<p><strong>Flags:</strong> ${report.flags.join(', ')}</p>` : ''}
                            <button class="delete" onclick="deleteContent('${report.contentType}', '${report.contentId}', '${doc.id}')">Delete Content</button>
                            <button class="ban" onclick="banUser('${report.authorUid}', '${doc.id}')">Ban User</button>
                            <button class="dismiss" onclick="dismissReport('${doc.id}')">Dismiss</button>
                        `;
                        reportsDiv.appendChild(div);
                    });
                });
        }

        async function deleteContent(contentType, contentId, reportId) {
            if (!confirm('Delete this content?')) return;

            // Delete content based on type
            if (contentType === 'post') {
                await db.collection('posts').doc(contentId).delete();
            } else if (contentType === 'comment') {
                // Parse postId/commentId from contentId
                const [postId, commentId] = contentId.split('/');
                await db.collection('posts').doc(postId).collection('comments').doc(commentId).delete();
            }

            // Mark report as resolved
            await db.collection('reports').doc(reportId).update({
                status: 'resolved',
                action: 'content_deleted',
                resolvedAt: firebase.firestore.FieldValue.serverTimestamp(),
            });

            alert('Content deleted');
        }

        async function banUser(uid, reportId) {
            if (!confirm('Ban this user? This will disable their account.')) return;

            // Add to banned users collection
            await db.collection('bannedUsers').doc(uid).set({
                bannedAt: firebase.firestore.FieldValue.serverTimestamp(),
                reason: 'Admin action from report',
            });

            // Mark report as resolved
            await db.collection('reports').doc(reportId).update({
                status: 'resolved',
                action: 'user_banned',
                resolvedAt: firebase.firestore.FieldValue.serverTimestamp(),
            });

            alert('User banned');
        }

        async function dismissReport(reportId) {
            await db.collection('reports').doc(reportId).update({
                status: 'dismissed',
                resolvedAt: firebase.firestore.FieldValue.serverTimestamp(),
            });
        }
    </script>
</body>
</html>
```

**Deploy Admin Dashboard:**

```bash
# Host on Firebase Hosting
firebase init hosting
# Select admin-dashboard as public directory

firebase deploy --only hosting
```

---

### Phase 5: Advanced Protection (LOW PRIORITY)
**Priority:** LOW - Implement if abuse becomes an issue
**Effort:** 5-7 days

#### 5.1 Account Age Restrictions

New accounts have stricter limits:

```typescript
// In rateLimit.ts
export async function getAdjustedLimit(
  uid: string,
  baseLimit: number
): Promise<number> {
  const userStats = await db.collection('userStats').doc(uid).get();

  if (!userStats.exists) return Math.floor(baseLimit * 0.3); // New user

  const stats = userStats.data()!;
  const accountAgeDays = stats.accountCreatedAt
    ? (Date.now() - stats.accountCreatedAt.toMillis()) / (1000 * 60 * 60 * 24)
    : 0;

  // New accounts (< 7 days) get 30% of normal limit
  if (accountAgeDays < 7) return Math.floor(baseLimit * 0.3);

  // Medium accounts (7-30 days) get 60% of normal limit
  if (accountAgeDays < 30) return Math.floor(baseLimit * 0.6);

  // Established accounts get full limit
  return baseLimit;
}
```

#### 5.2 Reputation System

Track user behavior:

```typescript
// userStats collection
interface UserStats {
  userId: string;
  accountCreatedAt: Timestamp;
  postCount: number;
  commentCount: number;
  upvotesReceived: number;
  reportsReceived: number;
  reportsSubmitted: number;
  violationCount: number;
  reputation: number; // 0-100 score
}

// Calculate reputation
function calculateReputation(stats: UserStats): number {
  let score = 50; // Start neutral

  // Positive signals
  score += Math.min(stats.upvotesReceived / 10, 20); // Max +20 from upvotes
  score += Math.min(stats.postCount / 5, 10); // Max +10 from posts

  // Negative signals
  score -= stats.reportsReceived * 5; // -5 per report
  score -= stats.violationCount * 10; // -10 per violation

  return Math.max(0, Math.min(100, score));
}
```

#### 5.3 Shadow Banning

Hide spam user's content without telling them:

```typescript
export const shadowBanUser = functions.https.onCall(async (data, context) => {
  // Admin only
  if (!context.auth) throw new Error('Unauthorized');

  const { uid } = data;

  // Mark user as shadow banned
  await db.collection('userStats').doc(uid).update({
    shadowBanned: true,
    shadowBannedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Hide all their content
  const posts = await db.collection('posts').where('authorUid', '==', uid).get();
  const batch = db.batch();

  posts.docs.forEach(doc => {
    batch.update(doc.ref, { visibility: 'shadow_banned' });
  });

  await batch.commit();

  return { success: true };
});
```

---

## Testing Abuse Protection

### Manual Testing Checklist

**Rate Limiting:**
- [ ] Create 10 posts rapidly → 11th should fail
- [ ] Wait 15 minutes → can post again
- [ ] Toggle upvote 100 times → 101st fails
- [ ] Create 5 rounds → 6th fails within 1 hour

**App Check:**
- [ ] Request from iOS app → succeeds
- [ ] Request from curl with valid token → fails
- [ ] Modified app binary → fails

**Content Moderation:**
- [ ] Post with profanity → auto-flagged
- [ ] Post with URL → auto-hidden
- [ ] Post "Buy now cheap Rolex" → auto-hidden
- [ ] Legitimate post → not flagged

**User Reporting:**
- [ ] Report post → appears in admin dashboard
- [ ] Delete reported content → post removed
- [ ] Ban user → cannot create new content

### Automated Testing

```typescript
// functions/src/__tests__/rateLimit.test.ts
import { RateLimiter } from '../rateLimit';

describe('RateLimiter', () => {
  it('allows requests within limit', async () => {
    const limiter = new RateLimiter('test', { max: 5, windowMs: 60000 });

    for (let i = 0; i < 5; i++) {
      await expect(limiter.checkLimit('user1')).resolves.not.toThrow();
    }
  });

  it('blocks requests over limit', async () => {
    const limiter = new RateLimiter('test', { max: 5, windowMs: 60000 });

    for (let i = 0; i < 5; i++) {
      await limiter.checkLimit('user1');
    }

    await expect(limiter.checkLimit('user1')).rejects.toThrow('Rate limit exceeded');
  });

  it('resets after window expires', async () => {
    // Mock Date.now()
    const limiter = new RateLimiter('test', { max: 5, windowMs: 1000 });

    for (let i = 0; i < 5; i++) {
      await limiter.checkLimit('user1');
    }

    // Wait for window to expire
    await new Promise(resolve => setTimeout(resolve, 1100));

    await expect(limiter.checkLimit('user1')).resolves.not.toThrow();
  });
});
```

---

## Monitoring & Alerts

### Firebase Alerts

Set up alerts in Firebase Console:

1. **Cloud Functions Errors** → Alert if >10 errors/hour
2. **Storage Usage** → Alert if >50GB used
3. **Firestore Reads** → Alert if >1M reads/day
4. **App Check** → Alert if invalid request rate >5%

### Custom Logging

```typescript
// Log violations for analysis
export async function logViolation(
  type: string,
  uid: string,
  details: any
) {
  await db.collection('violations').add({
    type,
    uid,
    details,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Increment violation counter
  await db.collection('userStats').doc(uid).update({
    violationCount: admin.firestore.FieldValue.increment(1),
  });

  // Auto-ban if too many violations
  const userStats = await db.collection('userStats').doc(uid).get();
  if (userStats.exists && userStats.data()!.violationCount >= 5) {
    await db.collection('bannedUsers').doc(uid).set({
      reason: 'Automatic ban - 5+ violations',
      bannedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}
```

---

## Cost Estimates

### With Protection (1000 users)

**Phase 1 (Rate Limiting):**
- Additional Firestore reads: ~10K/day for rate limit checks = **$0.02/month**
- Additional writes: ~5K/day = **$0.01/month**

**Phase 2 (App Check):**
- Verifications: ~50K/day = 1.5M/month = **$0** (under free tier)

**Phase 3 (Content Moderation):**
- Cloud Function invocations: ~1K/day = **$0** (under free tier)
- Additional Firestore writes: ~100/day for reports = **$0.01/month**

**Total Additional Cost: ~$0.05/month** 🎉

### Cost of NOT Having Protection

One spammer:
- 10,000 spam posts × $0.18 per 100K writes = **$18**
- User churn from unusable app = **Priceless loss**

---

## Implementation Priority

### Before Launch (CRITICAL)
1. ✅ Phase 1: Server-Side Rate Limiting
2. ✅ Phase 2: Firebase App Check

**Why:** Prevents app from becoming unusable due to spam. Takes 2-3 days total.

### First Month After Launch (HIGH)
3. ✅ Phase 3: Content Moderation
4. ✅ Phase 4: User Reporting + Admin Dashboard

**Why:** Legitimate users need ability to report abuse. You need tools to moderate.

### As Needed (LOW)
5. Phase 5: Advanced protection (account age restrictions, reputation, shadow banning)

**Why:** Only needed if abuse becomes systematic issue.

---

## Security Rules Update

**File:** `firestore.rules`

After implementing App Check, update rules to require it:

```javascript
// Add helper function
function hasValidAppCheck() {
  return request.app.check.isValid();
}

// Update write operations
match /posts/{postId} {
  allow read: if isSignedIn();

  allow create: if isSignedIn()
    && hasValidAppCheck() // NEW
    && request.auth.uid == request.resource.data.authorUid
    && request.resource.data.text.size() <= 2000;

  allow update, delete: if isSignedIn()
    && hasValidAppCheck() // NEW
    && resource.data.authorUid == request.auth.uid;
}

match /rounds/{roundId} {
  allow create: if isSignedIn()
    && hasValidAppCheck() // NEW
    && request.resource.data.hostUid == request.auth.uid;
}

// Apply to all write operations
```

---

## Next Steps

When ready to implement:

1. **Week 1:** Implement Phase 1 (Rate Limiting)
   - Create `functions/src/rateLimit.ts`
   - Update Cloud Functions to check limits
   - Deploy and test

2. **Week 1-2:** Implement Phase 2 (App Check)
   - Add App Check to iOS app
   - Update Firestore rules
   - Test with debug tokens

3. **Week 3:** Implement Phase 3 (Content Moderation)
   - Create moderation Cloud Functions
   - Deploy and monitor logs

4. **Week 4:** Implement Phase 4 (Reporting)
   - Add reporting UI to iOS app
   - Create admin dashboard
   - Test report workflow

5. **Ongoing:** Monitor and adjust
   - Watch Firebase Console for patterns
   - Adjust rate limits based on usage
   - Respond to reports within 24 hours

---

## Questions?

If you need help implementing any of these protections, check:
- Firebase App Check docs: https://firebase.google.com/docs/app-check
- Firestore Security Rules: https://firebase.google.com/docs/firestore/security/get-started
- Rate limiting patterns: https://firebase.google.com/docs/firestore/solutions/counters

Good luck! 🏌️
