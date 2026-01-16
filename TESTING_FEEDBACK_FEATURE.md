# Testing the Post-Round Feedback Feature

This guide explains how to test the post-round feedback and trust badges feature.

## 📋 Prerequisites

1. **Add new files to Xcode:**
   - `TeePals/Models/RoundFeedback.swift`
   - `TeePals/Repositories/TrustRepository.swift`
   - `TeePals/FirebaseRepositories/FirestoreTrustRepository.swift`
   - `TeePals/ViewModels/PostRoundFeedbackViewModel.swift`
   - `TeePals/Views/Feedback/PostRoundFeedbackView.swift`
   - `TeePals/Views/Feedback/PendingFeedbackSection.swift`
   - `TeePals/Utilities/TestDataHelper.swift`
   - `TeePals/Views/Testing/TestDataSection.swift`

2. **Deploy Firestore rules:**
   ```bash
   firebase deploy --only firestore:rules
   ```

3. **Build the app** - ensure it compiles without errors

## 🧪 Testing Methods

### Method 1: Using Test Data Helper (Easiest)

#### Step 1: Add Test Data Section to ProfileView

Temporarily add this to ProfileView (after `signOutSection` in profileContent):

```swift
// TESTING ONLY - Remove before production
#if DEBUG
TestDataSection()
#endif
```

#### Step 2: Create Test Data

1. Run the app
2. Navigate to Profile tab
3. Scroll to bottom - you'll see "🧪 Test Data" section
4. Tap **"Create 3 Pending Feedback Items"**
5. Pull to refresh Profile - you should see "Pending Feedback" section appear
6. Tap a pending feedback item → feedback flow opens

#### Step 3: Complete Feedback Flow

**YES Flow (Good Experience):**
1. Tap "✅ Yes, all good"
2. Toggle "Would play again" for players (optional)
3. Answer skill accuracy question
4. Tap "Submit"
5. See success screen

**NO Flow (Issue Reporting):**
1. Tap "⚠️ No, there was an issue"
2. Select users with issues (checkboxes)
3. Tap "Next"
4. For each user, select issue types
5. Add optional comment (max 200 chars)
6. Tap "Submit Report" or "Next" for multiple users
7. See success screen

### Method 2: Using Real Rounds

#### Step 1: Create a Round

1. Go to Rounds tab
2. Create a new round (or use existing round)
3. Accept members or have instant join enabled

#### Step 2: Mark Round as Completed (Host Only)

1. Open the round detail
2. As the host, you'll see **"Mark Complete"** button
3. Tap it and confirm
4. Round status changes to "Completed"
5. Feedback banner appears for all members

#### Step 3: Give Feedback

**For Host:**
- Banner shows: "This round is complete. Rate your playing partners"
- Tap banner → feedback flow opens

**For Members:**
- Navigate to round detail
- See feedback banner
- Tap banner → feedback flow opens

**Or from Profile:**
- Navigate to Profile tab
- See "Pending Feedback" section
- Tap any round → feedback flow opens

### Method 3: Direct Firestore Creation

Use Firebase Console to manually create documents:

#### Create Pending Feedback Item

Collection: `pendingFeedback/{yourUid}/items/{roundId}`

```json
{
  "roundId": "test-round-123",
  "completedAt": "2025-01-14T10:00:00Z",
  "expiresAt": "2025-01-21T10:00:00Z",
  "participantUids": ["uid1", "uid2"],
  "courseName": "Pebble Beach",
  "reminderSent": false
}
```

#### Create Completed Round

Collection: `rounds/{roundId}`

```json
{
  "hostUid": "yourUid",
  "title": "Morning Round",
  "status": "completed",
  "courseCandidates": [...],
  "chosenCourse": {...},
  "maxPlayers": 4,
  "acceptedCount": 2,
  ...other fields
}
```

Add yourself as member:
Collection: `rounds/{roundId}/members/{yourUid}`

```json
{
  "uid": "yourUid",
  "status": "accepted",
  "role": "host",
  "joinedAt": "2025-01-14T09:00:00Z"
}
```

## ✅ What to Test

### 1. Primary Question Screen
- [ ] Displays course name correctly
- [ ] "Yes" button leads to endorsement screen
- [ ] "No" button leads to issue selection
- [ ] Loading state works
- [ ] Error handling works

### 2. Endorsement Screen (Yes Flow)
- [ ] Shows all participants with photos
- [ ] Toggle endorsements (turns green when selected)
- [ ] Skill accuracy radio buttons work
- [ ] "Skip for Now" skips endorsements
- [ ] "Submit" submits feedback
- [ ] Loading state during submission
- [ ] Success screen appears

### 3. Issue Reporting (No Flow)
- [ ] User selection screen shows all participants
- [ ] Checkboxes toggle correctly
- [ ] "Next" disabled when no users selected
- [ ] Issue details screen shows per user
- [ ] All 6 issue types are selectable
- [ ] Comment field limits to 200 characters
- [ ] Multi-user flow (Next/Submit changes)
- [ ] Success screen appears

### 4. Already Submitted
- [ ] If feedback already submitted, shows "Already Submitted" screen
- [ ] Cannot submit twice for same round

### 5. Profile Integration
- [ ] Pending feedback section appears in Profile
- [ ] Shows up to 3 items
- [ ] Items sorted by expiration (urgent first)
- [ ] Urgency colors correct (red < 1 day, orange 1-3 days, gray 4+ days)
- [ ] Tapping item opens feedback flow
- [ ] Section disappears when empty

### 6. Round Detail Integration
- [ ] Host sees "Mark Complete" button (when round is open/confirmed)
- [ ] Confirmation alert shows before marking
- [ ] Round status updates to "Completed"
- [ ] Feedback banner appears for members
- [ ] Banner is tappable and opens feedback
- [ ] Chat button still works after completion

### 7. Navigation & Dismissal
- [ ] X button closes feedback flow
- [ ] Back button works in issue flow
- [ ] Auto-dismiss after success (or manual dismiss)
- [ ] Pending feedback removed after submission

### 8. Edge Cases
- [ ] Solo round (no participants) - skips endorsement, submits immediately
- [ ] Round not found - shows error
- [ ] Network failure - shows error
- [ ] Non-participant trying to submit - blocked by rules
- [ ] Round not completed - blocked by rules

## 🧹 Cleanup After Testing

1. **Remove Test Data Section from ProfileView:**
   ```swift
   // Delete the #if DEBUG TestDataSection() #endif block
   ```

2. **Clear test data:**
   - Use "Clear All Pending Feedback" button in test section
   - Or manually delete from Firebase Console

3. **Delete test rounds:**
   - Navigate to Firebase Console
   - Delete any test rounds from `rounds` collection

## 📊 Verifying Data in Firestore

After submitting feedback, check these collections:

### 1. Round Feedback
Collection: `rounds/{roundId}/feedback/{reviewerUid}`

Should contain:
- `roundSafetyOK: bool`
- `skillLevelsAccurate: bool` (if Yes flow)
- `submittedAt: timestamp`

### 2. Endorsements (If Yes Flow)
Collection: `rounds/{roundId}/endorsements/{endorsementId}`

Should contain multiple docs (one per endorsed player):
- `reviewerUid: string`
- `targetUid: string`
- `wouldPlayAgain: true`
- `submittedAt: timestamp`

### 3. Incidents (If No Flow)
Collection: `rounds/{roundId}/incidents/{incidentId}`

Should contain:
- `reviewerUid: string`
- `targetUid: string`
- `issueTypes: array`
- `comment: string` (if provided)
- `reviewed: false`
- `submittedAt: timestamp`

### 4. Pending Feedback (Should be Deleted)
Collection: `pendingFeedback/{yourUid}/items/{roundId}`

Should be **deleted** after successful submission.

## 🚨 Known Limitations

### Cloud Functions Not Implemented Yet

The following features require Cloud Functions (not yet implemented):

1. **Auto-create pending feedback** when round marked complete
   - Workaround: Use test data helper

2. **Send notifications** to participants
   - Workaround: Manually navigate to feedback

3. **Aggregate trust scores** and badges
   - Workaround: Badges won't update yet (data is stored, not calculated)

4. **Cleanup expired** pending feedback
   - Workaround: Manually delete via test helper

5. **Moderation** of incident reports
   - Reports are stored but not visible/actionable yet

### What Works Now (Client-Side Only)

✅ Full feedback submission flow (Yes and No paths)
✅ Endorsement submission
✅ Incident report submission
✅ Firestore security rules enforcement
✅ Pending feedback display
✅ Mark round as completed
✅ Feedback banners and navigation
✅ All UI screens and error handling

## 🎯 Next Steps After Testing

1. **Verify all flows work end-to-end**
2. **Test on real device** (not just simulator)
3. **Test with multiple users** (different accounts)
4. **Implement Cloud Functions** for:
   - createPendingRatings
   - aggregateTrustProfiles
   - sendFeedbackNotifications
   - cleanupExpiredFeedback
5. **Add analytics** events for feedback submissions
6. **Add admin dashboard** for incident reports

## 📝 Reporting Issues

If you find bugs during testing:

1. **Note the exact steps** to reproduce
2. **Check Xcode console** for error messages
3. **Check Firebase Console** for data consistency
4. **Try the same flow** with test data helper
5. **Document expected vs actual** behavior

Common issues to watch for:
- UI not updating after submission
- Data not persisting to Firestore
- Navigation getting stuck
- State not resetting between flows
- Memory leaks (check Instruments)
