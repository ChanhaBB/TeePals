# Post-Round Feedback – UI Specification

**Version**: 1.0
**Last Updated**: 2026-01-15
**Status**: Ready for Implementation

---

## 1. Overview

This document specifies every screen, state, interaction, and piece of copy for the post-round feedback feature. This is the **source of truth** for implementation.

### 1.1 Goals

- ✅ Crystal clear UI (no ambiguity)
- ✅ 1-2 taps for 95% of users
- ✅ Positive, non-accusatory tone
- ✅ Accessible (VoiceOver, Dynamic Type)
- ✅ Handles all edge cases gracefully

### 1.2 Non-Goals

- ❌ No complex animations
- ❌ No gamification in feedback flow
- ❌ No social features (sharing, comments)

---

## 2. Design System Usage

### 2.1 Colors

From `AppColors`:
- `primary` - CTA buttons, selected states
- `backgroundGrouped` - Screen background
- `cardBackground` - Card surfaces
- `textPrimary` - Headings, main text
- `textSecondary` - Supporting text
- `textTertiary` - Placeholder text
- `border` - Dividers, outlines
- `destructive` - Negative actions (report incident)
- `success` - Positive feedback (checkmarks)

### 2.2 Typography

From `AppTypography`:
- `headlineLarge` - Screen titles (24pt, semibold)
- `headlineMedium` - Section headers (20pt, semibold)
- `bodyLarge` - Primary question text (18pt, regular)
- `bodyMedium` - Standard body copy (16pt, regular)
- `labelMedium` - Button labels (16pt, semibold)
- `labelSmall` - Secondary labels (14pt, regular)
- `caption` - Helper text (12pt, regular)

### 2.3 Spacing

From `AppSpacing`:
- `contentPadding` - Screen edges (16pt)
- `lg` - Large gaps (20pt)
- `md` - Medium gaps (12pt)
- `sm` - Small gaps (8pt)
- `xs` - Tiny gaps (4pt)

### 2.4 Components

From `UIFoundation`:
- `PrimaryButton` - Main CTAs
- `SecondaryButton` - Secondary actions
- `AppCard` - Content containers
- `EmptyStateView` - No pending feedback
- `InlineErrorBanner` - Error messages
- `ProgressView` - Loading indicators
- `CachedAsyncImage` - Profile photos

---

## 3. Navigation & Entry Points

### 3.1 Entry Point 1: Push Notification

**Notification Content:**
```
Title: "Rate your round at Pebble Beach"
Body: "Quick 5-second feedback helps the community"
Badge: None
Sound: Default
```

**Deep Link**: `teepals://feedback?roundId=xyz123`

**Behavior:**
- Tap notification → Opens app → Navigates to FeedbackFlowView(roundId)
- If not authenticated → Show auth flow first → Then navigate to feedback
- If round not found → Show error screen

### 3.2 Entry Point 2: 24h Reminder Notification

**Notification Content:**
```
Title: "⛳️ Quick question about your round"
Body: "Tap to give 5-second feedback"
Badge: 1
Sound: Default
```

**Deep Link**: Same as above

**Behavior:** Same as above

### 3.3 Entry Point 3: Profile Tab "Pending Feedback" Section

**Location:** ProfileView → "Pending Feedback" card (below stats)

**Visual:**
```
┌──────────────────────────────────────┐
│  Pending Feedback                    │
│  ───────────────────────────────     │
│  ⛳️ Pebble Beach                     │
│  Jan 15, 2026 • 6 days left          │
│  [Give Feedback →]                   │
│  ───────────────────────────────     │
│  ⛳️ Spyglass Hill                    │
│  Jan 10, 2026 • 1 day left           │
│  [Give Feedback →]                   │
└──────────────────────────────────────┘
```

**Behavior:**
- Tap row → Navigates to FeedbackFlowView(roundId)
- Shows up to 3 pending items
- Sorted by expiration (soonest first)
- After 3, show "View All (2 more)"

### 3.4 Entry Point 4: Round Detail View

**Location:** RoundDetailView → After round status changes to "Completed"

**Visual:** Banner at top of screen
```
┌──────────────────────────────────────┐
│  ℹ️ This round is complete.          │
│  [Rate Playing Partners →]           │
└──────────────────────────────────────┘
```

**Behavior:**
- Banner appears when round.status == .completed
- Dismissible (X button in corner)
- Only shows if user hasn't submitted feedback yet
- Tap → Navigates to FeedbackFlowView(roundId)

---

## 4. Screen Specifications

### 4.1 Screen 1: Primary Question Screen

**File Name**: `PostRoundFeedbackView.swift` (root view)

**Layout:**
```
┌────────────────────────────────────────────────┐
│  [← Back]                    [X Close]         │  ← Navigation Bar
│                                                │
│  How was your round at                         │  ← Title (headlineLarge)
│  Pebble Beach?                                 │
│                                                │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━     │  ← Divider
│                                                │
│  ┌──────────────────────────────────────────┐ │
│  │  Did everyone show up and behave         │ │
│  │  respectfully?                           │ │  ← Question (bodyLarge, centered)
│  │                                          │ │
│  │  [        ✅ Yes, all good        ]      │ │  ← Primary button (full width)
│  │                                          │ │
│  │  [        ⚠️ No, there was an issue  ]   │ │  ← Secondary button (full width)
│  │                                          │ │
│  └──────────────────────────────────────────┘ │
│                                                │
│  Your feedback is private and helps            │  ← Helper text (caption, centered)
│  build a trusted community                     │     color: textSecondary
│                                                │
└────────────────────────────────────────────────┘
```

**Component Breakdown:**
```swift
struct PostRoundFeedbackView: View {
    @ObservedObject var viewModel: PostRoundFeedbackViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGrouped.ignoresSafeArea()

                VStack(spacing: AppSpacing.xl) {
                    // Title
                    Text("How was your round at")
                        .font(AppTypography.headlineLarge)
                        .foregroundColor(AppColors.textPrimary)

                    Text(viewModel.courseName)
                        .font(AppTypography.headlineLarge)
                        .foregroundColor(AppColors.textPrimary)

                    Divider()
                        .padding(.vertical, AppSpacing.md)

                    // Question card
                    AppCard {
                        VStack(spacing: AppSpacing.lg) {
                            Text("Did everyone show up and behave respectfully?")
                                .font(AppTypography.bodyLarge)
                                .foregroundColor(AppColors.textPrimary)
                                .multilineTextAlignment(.center)
                                .padding(.top, AppSpacing.md)

                            // Yes button
                            PrimaryButton(
                                title: "✅ Yes, all good",
                                action: { viewModel.answerYes() }
                            )

                            // No button
                            SecondaryButton(
                                title: "⚠️ No, there was an issue",
                                action: { viewModel.answerNo() }
                            )
                        }
                        .padding(AppSpacing.contentPadding)
                    }

                    // Helper text
                    Text("Your feedback is private and helps build a trusted community")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)

                    Spacer()
                }
                .padding(.horizontal, AppSpacing.contentPadding)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
    }
}
```

**States:**

**Loading State** (fetching round data):
```
┌────────────────────────────────────────────────┐
│  [← Back]                    [X Close]         │
│                                                │
│  Loading...                                    │
│                                                │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━     │
│                                                │
│  ┌──────────────────────────────────────────┐ │
│  │                                          │ │
│  │         [ProgressView spinning]          │ │  ← System ProgressView
│  │                                          │ │
│  └──────────────────────────────────────────┘ │
│                                                │
└────────────────────────────────────────────────┘
```

**Error State** (failed to load):
```
┌────────────────────────────────────────────────┐
│  [← Back]                    [X Close]         │
│                                                │
│  ⚠️ Unable to Load Feedback                    │  ← headlineLarge
│                                                │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━     │
│                                                │
│  [!] This round couldn't be loaded.            │  ← InlineErrorBanner
│      Please try again.                         │
│                                                │
│  [Retry]                                       │  ← PrimaryButton
│                                                │
└────────────────────────────────────────────────┘
```

**Already Submitted State**:
```
┌────────────────────────────────────────────────┐
│  [← Back]                    [X Close]         │
│                                                │
│  ✅ Feedback Submitted                         │  ← headlineLarge
│                                                │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━     │
│                                                │
│  You already provided feedback for this        │  ← bodyMedium, centered
│  round. Thank you!                             │     color: textSecondary
│                                                │
│  [Done]                                        │  ← PrimaryButton
│                                                │
└────────────────────────────────────────────────┘
```

**Copy:**
- Title: "How was your round at {courseName}?"
- Question: "Did everyone show up and behave respectfully?"
- Yes button: "✅ Yes, all good"
- No button: "⚠️ No, there was an issue"
- Helper: "Your feedback is private and helps build a trusted community"
- Loading: "Loading..."
- Error title: "⚠️ Unable to Load Feedback"
- Error message: "This round couldn't be loaded. Please try again."
- Already submitted title: "✅ Feedback Submitted"
- Already submitted message: "You already provided feedback for this round. Thank you!"

**Accessibility:**
- VoiceOver label for Yes: "Yes, everyone was respectful. Double tap to continue."
- VoiceOver label for No: "No, there was an issue. Double tap to report."
- Helper text read automatically after question
- Back button hint: "Returns to previous screen"
- Close button hint: "Dismisses feedback flow"

**Analytics:**
```swift
// On screen appear
Analytics.logEvent("feedback_screen_viewed", parameters: [
    "roundId": roundId,
    "courseName": courseName
])

// On Yes tap
Analytics.logEvent("feedback_yes_selected", parameters: [
    "roundId": roundId
])

// On No tap
Analytics.logEvent("feedback_no_selected", parameters: [
    "roundId": roundId
])
```

---

### 4.2 Screen 2A: Endorsement Screen ("Yes" Flow)

**File Name**: `EndorsementScreen.swift`

**Layout:**
```
┌────────────────────────────────────────────────┐
│  [← Back]                    [X Close]         │
│                                                │
│  Great! Would you play with                    │  ← Title (headlineLarge)
│  them again?                                   │
│                                                │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━     │
│                                                │
│  ┌──────────────────────────────────────────┐ │
│  │  [Photo] John Doe                        │ │  ← Player row
│  │  San Jose, CA • 🥇 Verified              │ │
│  │  [ 👍 Would play again ]                 │ │  ← Endorsement button (unchecked)
│  └──────────────────────────────────────────┘ │
│                                                │
│  ┌──────────────────────────────────────────┐ │
│  │  [Photo] Jane Smith                      │ │
│  │  Palo Alto, CA • 🥈 Trusted              │ │
│  │  [✓ Would play again ]                   │ │  ← Endorsed (checked, green)
│  └──────────────────────────────────────────┘ │
│                                                │
│  ┌──────────────────────────────────────────┐ │
│  │  [Photo] Bob Wilson                      │ │
│  │  Mountain View, CA • 🥉 Member           │ │
│  │  [ 👍 Would play again ]                 │ │
│  └──────────────────────────────────────────┘ │
│                                                │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━     │
│                                                │
│  Was everyone's skill level accurate?          │  ← Question (bodyMedium)
│  [✓ Yes]  [ No]                                │  ← Radio buttons (Yes checked)
│                                                │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━     │
│                                                │
│  [Skip for Now]          [Submit]              │  ← Buttons (sticky at bottom)
│                                                │
└────────────────────────────────────────────────┘
```

**Component Breakdown:**
```swift
struct EndorsementScreen: View {
    @ObservedObject var viewModel: PostRoundFeedbackViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.backgroundGrouped.ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Title
                    VStack(spacing: AppSpacing.xs) {
                        Text("Great! Would you play with")
                            .font(AppTypography.headlineLarge)
                            .foregroundColor(AppColors.textPrimary)
                        Text("them again?")
                            .font(AppTypography.headlineLarge)
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .padding(.top, AppSpacing.md)

                    Divider()

                    // Player list
                    ForEach(viewModel.participants) { participant in
                        PlayerEndorsementRow(
                            participant: participant,
                            isEndorsed: viewModel.isEndorsed(participant.id),
                            onTap: { viewModel.toggleEndorsement(participant.id) }
                        )
                    }

                    Divider()
                        .padding(.vertical, AppSpacing.md)

                    // Skill accuracy question
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Was everyone's skill level accurate?")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimary)

                        HStack(spacing: AppSpacing.lg) {
                            RadioButton(
                                title: "Yes",
                                isSelected: viewModel.skillAccurate == true,
                                action: { viewModel.skillAccurate = true }
                            )

                            RadioButton(
                                title: "No",
                                isSelected: viewModel.skillAccurate == false,
                                action: { viewModel.skillAccurate = false }
                            )
                        }
                    }
                    .padding(.horizontal, AppSpacing.contentPadding)

                    // Bottom padding for sticky buttons
                    Spacer()
                        .frame(height: 100)
                }
                .padding(.horizontal, AppSpacing.contentPadding)
            }

            // Sticky bottom buttons
            bottomButtons
                .background(AppColors.backgroundGrouped)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") { viewModel.goBack() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }

    private var bottomButtons: some View {
        HStack(spacing: AppSpacing.md) {
            SecondaryButton(
                title: "Skip for Now",
                action: { viewModel.skipEndorsements() }
            )

            PrimaryButton(
                title: "Submit",
                action: { Task { await viewModel.submitFeedback() } },
                isLoading: viewModel.isSubmitting
            )
        }
        .padding(.horizontal, AppSpacing.contentPadding)
        .padding(.bottom, AppSpacing.lg)
    }
}

// Player Row Component
struct PlayerEndorsementRow: View {
    let participant: PublicProfile
    let isEndorsed: Bool
    let onTap: () -> Void

    var body: some View {
        AppCard {
            HStack(spacing: AppSpacing.md) {
                // Profile photo
                CachedAsyncImage(url: participant.photoURL) { image in
                    image.resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(AppColors.primary.opacity(0.1))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(AppColors.primary.opacity(0.4))
                        )
                }
                .frame(width: 56, height: 56)
                .clipShape(Circle())

                // Name & location
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(participant.nickname)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)

                    HStack(spacing: AppSpacing.xs) {
                        Text(participant.primaryCityLabel)
                            .font(AppTypography.labelSmall)
                            .foregroundColor(AppColors.textSecondary)

                        Text("•")
                            .foregroundColor(AppColors.textTertiary)

                        Text(participant.trustTierBadge)
                            .font(AppTypography.labelSmall)
                    }
                }

                Spacer()

                // Endorsement button
                Button(action: onTap) {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: isEndorsed ? "checkmark.circle.fill" : "hand.thumbsup")
                            .foregroundColor(isEndorsed ? AppColors.success : AppColors.primary)

                        Text(isEndorsed ? "Endorsed" : "Would play again")
                            .font(AppTypography.labelSmall)
                            .foregroundColor(isEndorsed ? AppColors.success : AppColors.primary)
                    }
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xs)
                    .background(
                        isEndorsed ? AppColors.success.opacity(0.1) : AppColors.primary.opacity(0.1)
                    )
                    .cornerRadius(8)
                }
            }
            .padding(AppSpacing.md)
        }
    }
}
```

**States:**

**Submitting State**:
- "Submit" button shows loading spinner
- All interactions disabled
- Can't tap back or close

**Submitted Successfully**:
- Navigate to Success Screen (4.4)

**Submission Error**:
- Show InlineErrorBanner at top
- "Unable to submit feedback. Please try again."
- Re-enable all interactions

**Copy:**
- Title: "Great! Would you play with them again?"
- Skill question: "Was everyone's skill level accurate?"
- Skip button: "Skip for Now"
- Submit button: "Submit"
- Endorsement button (unchecked): "👍 Would play again"
- Endorsement button (checked): "✓ Endorsed"
- Error message: "Unable to submit feedback. Please try again."

**Interactions:**
- Tap player card → Toggle endorsement (haptic feedback)
- Endorsement is optional (can submit without any)
- Skill accuracy defaults to "Yes" (positive default)
- Skip → Submit feedback with safetyOK=true, no endorsements
- Submit → Validate, show loading, submit to backend

**Edge Cases:**

**Only 1 other participant:**
- Show single card, no scrolling needed

**10+ participants:**
- ScrollView works normally
- Consider "Endorse All" button at top?
- No, keep it opt-in (more meaningful signal)

**No participants (solo round):**
- Skip endorsement screen entirely
- Go directly to success screen

**Participant has no photo:**
- Show placeholder circle with initials

**Participant blocked mid-flow:**
- Don't show them in list
- Handle gracefully (remove from participants array)

**Accessibility:**
- VoiceOver: "John Doe, San Jose, California, Verified member. Would play again button. Double tap to endorse."
- Dynamic Type: Text scales properly
- VoiceOver hint for Skip: "Submits positive feedback without endorsements"
- VoiceOver hint for Submit: "Submits feedback with selected endorsements"

**Analytics:**
```swift
// On screen appear
Analytics.logEvent("endorsement_screen_viewed", parameters: [
    "roundId": roundId,
    "participantCount": participantCount
])

// On endorsement tap
Analytics.logEvent("endorsement_toggled", parameters: [
    "roundId": roundId,
    "endorsed": isEndorsed
])

// On skill accuracy selection
Analytics.logEvent("skill_accuracy_selected", parameters: [
    "roundId": roundId,
    "accurate": skillAccurate
])

// On skip
Analytics.logEvent("endorsements_skipped", parameters: [
    "roundId": roundId
])

// On submit
Analytics.logEvent("feedback_submitted", parameters: [
    "roundId": roundId,
    "safetyOK": true,
    "endorsementCount": endorsementCount,
    "skillAccurate": skillAccurate
])
```

---

### 4.3 Screen 2B: Incident Reporting ("No" Flow)

**Step 1: Select Who Had Issues**

**Layout:**
```
┌────────────────────────────────────────────────┐
│  [← Back]                    [X Close]         │
│                                                │
│  Who had an issue?                             │  ← Title (headlineLarge)
│  Select all that apply                         │  ← Subtitle (bodyMedium, textSecondary)
│                                                │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━     │
│                                                │
│  ┌──────────────────────────────────────────┐ │
│  │  [ ] [Photo] John Doe                    │ │  ← Checkbox row (unchecked)
│  │      San Jose, CA • 🥇 Verified          │ │
│  └──────────────────────────────────────────┘ │
│                                                │
│  ┌──────────────────────────────────────────┐ │
│  │  [✓] [Photo] Jane Smith                  │ │  ← Checkbox row (checked)
│  │      Palo Alto, CA • 🥈 Trusted          │ │
│  └──────────────────────────────────────────┘ │
│                                                │
│  ┌──────────────────────────────────────────┐ │
│  │  [ ] [Photo] Bob Wilson                  │ │
│  │      Mountain View, CA • 🥉 Member       │ │
│  └──────────────────────────────────────────┘ │
│                                                │
│  This is private and confidential              │  ← Helper (caption, centered)
│                                                │
│  [Back]                      [Next]            │  ← Buttons (Next only enabled if ≥1 selected)
│                                                │
└────────────────────────────────────────────────┘
```

**Component:**
```swift
struct SelectIssueUsersScreen: View {
    @ObservedObject var viewModel: PostRoundFeedbackViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.backgroundGrouped.ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Title
                    VStack(spacing: AppSpacing.xs) {
                        Text("Who had an issue?")
                            .font(AppTypography.headlineLarge)
                            .foregroundColor(AppColors.textPrimary)
                        Text("Select all that apply")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.top, AppSpacing.md)

                    Divider()

                    // Participant list with checkboxes
                    ForEach(viewModel.participants) { participant in
                        SelectableParticipantRow(
                            participant: participant,
                            isSelected: viewModel.selectedIssueUsers.contains(participant.id),
                            onTap: { viewModel.toggleIssueUser(participant.id) }
                        )
                    }

                    // Helper text
                    Text("This is private and confidential")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)

                    Spacer()
                        .frame(height: 100)
                }
                .padding(.horizontal, AppSpacing.contentPadding)
            }

            // Bottom buttons
            HStack(spacing: AppSpacing.md) {
                SecondaryButton(
                    title: "Back",
                    action: { viewModel.goBack() }
                )

                PrimaryButton(
                    title: "Next",
                    action: { viewModel.proceedToIssueDetails() },
                    isDisabled: viewModel.selectedIssueUsers.isEmpty
                )
            }
            .padding(.horizontal, AppSpacing.contentPadding)
            .padding(.bottom, AppSpacing.lg)
            .background(AppColors.backgroundGrouped)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }
}

struct SelectableParticipantRow: View {
    let participant: PublicProfile
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            AppCard {
                HStack(spacing: AppSpacing.md) {
                    // Checkbox
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? AppColors.primary : AppColors.border)

                    // Photo
                    CachedAsyncImage(url: participant.photoURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(AppColors.primary.opacity(0.1))
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())

                    // Name & location
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(participant.nickname)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimary)

                        HStack(spacing: AppSpacing.xs) {
                            Text(participant.primaryCityLabel)
                                .font(AppTypography.labelSmall)
                                .foregroundColor(AppColors.textSecondary)
                            Text("•")
                            Text(participant.trustTierBadge)
                                .font(AppTypography.labelSmall)
                        }
                    }

                    Spacer()
                }
                .padding(AppSpacing.md)
            }
        }
        .buttonStyle(.plain)
    }
}
```

**Copy:**
- Title: "Who had an issue?"
- Subtitle: "Select all that apply"
- Helper: "This is private and confidential"
- Back button: "Back"
- Next button: "Next" (disabled if none selected)

**Interactions:**
- Tap anywhere on row → Toggle selection (haptic feedback)
- Can select multiple
- Next button only enabled if ≥1 selected
- Back → Returns to primary question screen

**Step 2: Describe Issues (Per Selected User)**

**Layout:**
```
┌────────────────────────────────────────────────┐
│  [← Back]                    [X Close]         │
│                                                │
│  What happened with                            │  ← Title (headlineLarge)
│  John Doe?                                     │
│                                                │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━     │
│                                                │
│  Select all that apply                         │  ← Instruction (bodyMedium)
│                                                │
│  ┌──────────────────────────────────────────┐ │
│  │  [✓] No-show                             │ │  ← Checkbox (checked)
│  └──────────────────────────────────────────┘ │
│                                                │
│  ┌──────────────────────────────────────────┐ │
│  │  [ ] Late (15+ min)                      │ │  ← Checkbox (unchecked)
│  └──────────────────────────────────────────┘ │
│                                                │
│  ┌──────────────────────────────────────────┐ │
│  │  [ ] Poor communication                  │ │
│  └──────────────────────────────────────────┘ │
│                                                │
│  ┌──────────────────────────────────────────┐ │
│  │  [ ] Disrespectful behavior              │ │
│  └──────────────────────────────────────────┘ │
│                                                │
│  ┌──────────────────────────────────────────┐ │
│  │  [ ] Skill mismatch                      │ │
│  └──────────────────────────────────────────┘ │
│                                                │
│  ┌──────────────────────────────────────────┐ │
│  │  [ ] Other                               │ │
│  └──────────────────────────────────────────┘ │
│                                                │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━     │
│                                                │
│  More details (optional)                       │  ← Label (bodyMedium)
│  ┌────────────────────────────────────────┐   │
│  │                                        │   │  ← Text field (multiline)
│  │  (Tap to add private notes)            │   │     Placeholder (textTertiary)
│  │                                        │   │
│  └────────────────────────────────────────┘   │
│  0 / 200 characters                            │  ← Character count (caption)
│                                                │
│  [Back]              [Submit Report]           │  ← Buttons
│                                                │
└────────────────────────────────────────────────┘
```

**Component:**
```swift
struct IssueDetailsScreen: View {
    @ObservedObject var viewModel: PostRoundFeedbackViewModel
    @Environment(\.dismiss) var dismiss
    @FocusState private var isCommentFocused: Bool

    let participant: PublicProfile

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.backgroundGrouped.ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Title
                    VStack(spacing: AppSpacing.xs) {
                        Text("What happened with")
                            .font(AppTypography.headlineLarge)
                            .foregroundColor(AppColors.textPrimary)
                        Text(participant.nickname + "?")
                            .font(AppTypography.headlineLarge)
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .padding(.top, AppSpacing.md)

                    Divider()

                    Text("Select all that apply")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Issue type checkboxes
                    ForEach(IssueType.allCases, id: \.self) { issueType in
                        IssueTypeRow(
                            issueType: issueType,
                            isSelected: viewModel.selectedIssues(for: participant.id).contains(issueType),
                            onTap: { viewModel.toggleIssue(issueType, for: participant.id) }
                        )
                    }

                    Divider()
                        .padding(.vertical, AppSpacing.md)

                    // Optional comment field
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("More details (optional)")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimary)

                        TextEditor(text: $viewModel.issueComment)
                            .font(AppTypography.bodyMedium)
                            .frame(height: 100)
                            .padding(AppSpacing.sm)
                            .background(AppColors.cardBackground)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(AppColors.border, lineWidth: 1)
                            )
                            .focused($isCommentFocused)

                        Text("\(viewModel.issueComment.count) / 200 characters")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()
                        .frame(height: 100)
                }
                .padding(.horizontal, AppSpacing.contentPadding)
            }

            // Bottom buttons
            HStack(spacing: AppSpacing.md) {
                SecondaryButton(
                    title: "Back",
                    action: { viewModel.goBackToUserSelection() }
                )

                PrimaryButton(
                    title: "Submit Report",
                    action: { Task { await viewModel.submitIncidentReport() } },
                    isLoading: viewModel.isSubmitting,
                    isDisabled: viewModel.selectedIssues(for: participant.id).isEmpty
                )
            }
            .padding(.horizontal, AppSpacing.contentPadding)
            .padding(.bottom, AppSpacing.lg)
            .background(AppColors.backgroundGrouped)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .onChange(of: viewModel.issueComment) { _, newValue in
            if newValue.count > 200 {
                viewModel.issueComment = String(newValue.prefix(200))
            }
        }
    }
}

struct IssueTypeRow: View {
    let issueType: IssueType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            AppCard {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? AppColors.destructive : AppColors.border)

                    Text(issueType.displayName)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()
                }
                .padding(AppSpacing.md)
            }
        }
        .buttonStyle(.plain)
    }
}

enum IssueType: String, CaseIterable {
    case noShow = "no_show"
    case late = "late"
    case poorCommunication = "poor_communication"
    case disrespectful = "disrespectful"
    case skillMismatch = "skill_mismatch"
    case other = "other"

    var displayName: String {
        switch self {
        case .noShow: return "No-show"
        case .late: return "Late (15+ min)"
        case .poorCommunication: return "Poor communication"
        case .disrespectful: return "Disrespectful behavior"
        case .skillMismatch: return "Skill mismatch"
        case .other: return "Other"
        }
    }
}
```

**Multiple Users Flow:**
If user selected 2+ people with issues:
- After submitting for John Doe
- Automatically navigate to "What happened with Jane Smith?"
- Show progress indicator: "2 of 3" at top
- Submit Report → Next person or Final submit if last

**Copy:**
- Title: "What happened with {name}?"
- Instruction: "Select all that apply"
- Issue types:
  - "No-show"
  - "Late (15+ min)"
  - "Poor communication"
  - "Disrespectful behavior"
  - "Skill mismatch"
  - "Other"
- Comment label: "More details (optional)"
- Comment placeholder: "(Tap to add private notes)"
- Character count: "{count} / 200 characters"
- Back button: "Back"
- Submit button: "Submit Report" (destructive color)

**Interactions:**
- Tap issue → Toggle selection (haptic feedback)
- Can select multiple issues
- Comment is optional
- 200 character limit enforced
- Submit button disabled if no issues selected
- Submit button shows loading spinner while submitting

**Accessibility:**
- VoiceOver: "No-show, checkbox, not selected. Double tap to select."
- VoiceOver hint for Submit: "Submits confidential incident report"
- Comment field: "More details text field. Optional. 200 character limit."

**Analytics:**
```swift
// On screen appear
Analytics.logEvent("issue_details_screen_viewed", parameters: [
    "roundId": roundId,
    "targetUid": targetUid
])

// On issue type selected
Analytics.logEvent("issue_type_selected", parameters: [
    "roundId": roundId,
    "issueType": issueType.rawValue
])

// On submit
Analytics.logEvent("incident_reported", parameters: [
    "roundId": roundId,
    "issueTypes": issueTypeArray,
    "hasComment": !comment.isEmpty
])
```

---

### 4.4 Screen 3: Success Screen

**Layout:**
```
┌────────────────────────────────────────────────┐
│                                                │
│                                                │
│                                                │
│                   ✅                           │  ← Large checkmark (80pt)
│                                                │     Color: AppColors.success
│              Thank you!                         │  ← Title (headlineLarge)
│                                                │
│     Your feedback helps build a                │  ← Body (bodyMedium, centered)
│     trusted community                          │     Color: textSecondary
│                                                │
│                                                │
│              [Done]                            │  ← PrimaryButton
│                                                │
│                                                │
└────────────────────────────────────────────────┘
```

**Component:**
```swift
struct FeedbackSuccessScreen: View {
    @Environment(\.dismiss) var dismiss
    let onDone: () -> Void

    var body: some View {
        ZStack {
            AppColors.backgroundGrouped.ignoresSafeArea()

            VStack(spacing: AppSpacing.xxl) {
                Spacer()

                // Success icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(AppColors.success)

                // Title
                Text("Thank you!")
                    .font(AppTypography.headlineLarge)
                    .foregroundColor(AppColors.textPrimary)

                // Message
                Text("Your feedback helps build a trusted community")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)

                Spacer()

                // Done button
                PrimaryButton(
                    title: "Done",
                    action: onDone
                )
                .padding(.horizontal, AppSpacing.contentPadding)
                .padding(.bottom, AppSpacing.xxl)
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }
}
```

**Behavior:**
- Auto-dismiss after 2 seconds OR tap Done
- Navigate back to wherever user came from:
  - If from notification → Go to Home
  - If from Profile → Go back to Profile
  - If from Round Detail → Go back to Round Detail
- Remove pending feedback item from list
- Haptic success feedback on appear

**Copy:**
- Icon: Checkmark circle (system icon)
- Title: "Thank you!"
- Message: "Your feedback helps build a trusted community"
- Button: "Done"

**Analytics:**
```swift
// On screen appear
Analytics.logEvent("feedback_success_viewed", parameters: [
    "roundId": roundId
])

// On done tap
Analytics.logEvent("feedback_success_dismissed", parameters: [
    "roundId": roundId,
    "dismissMethod": "button" // vs "auto" if 2s timeout
])
```

---

## 5. Navigation Flow Diagram

```
Entry Points:
├─ Notification tap ──────────────┐
├─ Profile "Pending" tap ─────────┤
├─ Round Detail banner tap ───────┤
└─ Deep link ─────────────────────┘
                                   │
                                   ▼
                    ┌──────────────────────────┐
                    │  Primary Question        │
                    │  (Screen 1)              │
                    │  "Everyone respectful?"  │
                    └──────────────────────────┘
                           │            │
                     ✅ Yes            ⚠️ No
                           │            │
                           ▼            ▼
              ┌─────────────────┐  ┌──────────────────┐
              │  Endorsement    │  │  Select Users    │
              │  (Screen 2A)    │  │  (Screen 2B-1)   │
              │  "Play again?"  │  │  "Who had issue?"│
              └─────────────────┘  └──────────────────┘
                      │                     │
            [Skip] or [Submit]              │ [Next]
                      │                     ▼
                      │            ┌──────────────────┐
                      │            │  Issue Details   │
                      │            │  (Screen 2B-2)   │
                      │            │  "What happened?"│
                      │            └──────────────────┘
                      │                     │
                      │          [Submit Report for User 1]
                      │                     │
                      │        ┌────────────┴────────────┐
                      │        │                         │
                      │   More users?                   Last user?
                      │        │                         │
                      │        ▼                         │
                      │  ┌──────────────────┐           │
                      │  │  Next User       │           │
                      │  │  (Screen 2B-2)   │           │
                      │  └──────────────────┘           │
                      │        │                         │
                      └────────┴─────────────────────────┘
                                    │
                                    ▼
                         ┌──────────────────┐
                         │  Success Screen  │
                         │  (Screen 3)      │
                         │  "Thank you!"    │
                         └──────────────────┘
                                    │
                         [Done] or Auto-dismiss
                                    │
                                    ▼
                              [Exit Flow]
```

---

## 6. Edge Cases & Error Handling

### 6.1 Round Not Found

**Scenario:** User taps notification, round doesn't exist

**UI:**
```
┌────────────────────────────────────────────────┐
│  [← Back]                    [X Close]         │
│                                                │
│  ⚠️ Round Not Found                            │
│                                                │
│  [!] This round couldn't be loaded.            │
│      It may have been cancelled.               │
│                                                │
│  [Go to Profile]                               │
│                                                │
└────────────────────────────────────────────────┘
```

**Copy:**
- Title: "⚠️ Round Not Found"
- Message: "This round couldn't be loaded. It may have been cancelled."
- Button: "Go to Profile"

### 6.2 Already Submitted

**Scenario:** User taps notification twice

**UI:** Show "Already Submitted" state (see Screen 1 states)

### 6.3 User Removed from Round

**Scenario:** User was removed after round completed

**UI:**
```
┌────────────────────────────────────────────────┐
│  [← Back]                    [X Close]         │
│                                                │
│  ⚠️ Can't Submit Feedback                      │
│                                                │
│  [!] You're no longer a participant of         │
│      this round.                               │
│                                                │
│  [Go Back]                                     │
│                                                │
└────────────────────────────────────────────────┘
```

### 6.4 Network Error During Submit

**UI:** Show InlineErrorBanner at top of current screen

```
┌────────────────────────────────────────────────┐
│  [!] Unable to submit feedback. Check your     │
│      connection and try again. [Retry]         │
└────────────────────────────────────────────────┘
```

**Behavior:**
- Error banner appears at top (animated slide down)
- All form data preserved (don't lose user input)
- Retry button → Attempts submission again
- User can also edit and submit again

### 6.5 Round Cancelled During Feedback Flow

**Scenario:** Round cancelled while user filling out feedback

**UI:** Same as 6.1 (Round Not Found)

**Prevention:** Check round status before submit

### 6.6 User Blocked During Flow

**Scenario:** User blocks participant while on endorsement screen

**Behavior:**
- Remove blocked user from participant list immediately
- If on issue details for blocked user → Go back
- Continue with remaining participants

### 6.7 No Participants to Rate

**Scenario:** Solo round (user was only participant)

**Behavior:**
- Don't show feedback prompt at all
- No pending feedback item created

### 6.8 10+ Participants

**Scenario:** Large round with many participants

**UI:**
- Endorsement screen scrolls normally
- Issue selection screen scrolls normally
- Consider performance: Lazy loading? (Probably not needed for < 50)

### 6.9 User Force-Quits App Mid-Flow

**Behavior:**
- On next launch, show pending feedback in Profile
- Form state not preserved (start fresh)
- This is acceptable (simple restart)

### 6.10 Offline Mode

**Behavior:**
- Can't load round data → Show error (6.3)
- Can't submit → Show network error (6.4)
- Don't support offline queueing (too complex)

---

## 7. Pending Feedback List (Profile Tab)

**Location:** ProfileView → Between stats and posts

**States:**

**Has Pending Feedback:**
```
┌──────────────────────────────────────┐
│  Pending Feedback                    │
│  ───────────────────────────────     │
│  ⛳️ Pebble Beach                     │
│  Jan 15, 2026 • 6 days left          │
│  [Give Feedback →]                   │
│  ───────────────────────────────     │
│  ⛳️ Spyglass Hill                    │
│  Jan 10, 2026 • 1 day left           │
│  [Give Feedback →]                   │
│  ───────────────────────────────     │
│  ⛳️ Torrey Pines                     │
│  Jan 8, 2026 • Expiring soon         │
│  [Give Feedback →]                   │
└──────────────────────────────────────┘
```

**No Pending Feedback:**
```
┌──────────────────────────────────────┐
│  Pending Feedback                    │
│  ───────────────────────────────     │
│  No feedback needed at this time     │
└──────────────────────────────────────┘
```

**Component:**
```swift
struct PendingFeedbackSection: View {
    let pendingItems: [PendingFeedback]
    let onTap: (String) -> Void // roundId

    var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                // Section header
                Text("Pending Feedback")
                    .font(AppTypography.headlineMedium)
                    .foregroundColor(AppColors.textPrimary)

                Divider()

                if pendingItems.isEmpty {
                    // Empty state
                    Text("No feedback needed at this time")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.vertical, AppSpacing.sm)
                } else {
                    // List of pending items (max 3 shown)
                    ForEach(pendingItems.prefix(3)) { item in
                        PendingFeedbackRow(
                            item: item,
                            onTap: { onTap(item.roundId) }
                        )

                        if item.id != pendingItems.prefix(3).last?.id {
                            Divider()
                        }
                    }

                    // Show "View All" if more than 3
                    if pendingItems.count > 3 {
                        Button("View All (\(pendingItems.count - 3) more)") {
                            // Navigate to full list screen
                        }
                        .font(AppTypography.labelMedium)
                        .foregroundColor(AppColors.primary)
                        .padding(.top, AppSpacing.sm)
                    }
                }
            }
            .padding(AppSpacing.contentPadding)
        }
    }
}

struct PendingFeedbackRow: View {
    let item: PendingFeedback
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.md) {
                // Course icon
                Image(systemName: "figure.golf")
                    .font(.system(size: 24))
                    .foregroundColor(AppColors.primary)
                    .frame(width: 40, height: 40)
                    .background(AppColors.primary.opacity(0.1))
                    .clipShape(Circle())

                // Course & date info
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(item.courseName)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)

                    HStack(spacing: AppSpacing.xs) {
                        Text(item.completedAt.formatted(date: .abbreviated, time: .omitted))
                            .font(AppTypography.labelSmall)
                            .foregroundColor(AppColors.textSecondary)

                        Text("•")
                            .foregroundColor(AppColors.textTertiary)

                        Text(timeLeftText(item.expiresAt))
                            .font(AppTypography.labelSmall)
                            .foregroundColor(urgencyColor(item.expiresAt))
                    }
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(.vertical, AppSpacing.sm)
        }
        .buttonStyle(.plain)
    }

    private func timeLeftText(_ expiresAt: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expiresAt).day ?? 0
        if days <= 0 {
            return "Expiring soon"
        } else if days == 1 {
            return "1 day left"
        } else {
            return "\(days) days left"
        }
    }

    private func urgencyColor(_ expiresAt: Date) -> Color {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expiresAt).day ?? 0
        if days <= 1 {
            return AppColors.destructive
        } else if days <= 3 {
            return Color.orange
        } else {
            return AppColors.textSecondary
        }
    }
}
```

**Copy:**
- Section title: "Pending Feedback"
- Empty state: "No feedback needed at this time"
- Time left variants:
  - "Expiring soon" (< 1 day)
  - "1 day left"
  - "X days left"
- View all: "View All (X more)"

**Colors:**
- Expiring soon (< 1 day): Red (AppColors.destructive)
- 1-3 days: Orange
- 4+ days: Gray (AppColors.textSecondary)

---

## 8. Accessibility Checklist

### 8.1 VoiceOver Support

**Screen 1: Primary Question**
- Title: "How was your round at Pebble Beach?"
- Question: "Did everyone show up and behave respectfully?"
- Yes button: "Yes, all good. Button. Double tap to select."
- No button: "No, there was an issue. Button. Double tap to report."
- Helper text: Automatically read after question
- Back: "Back. Button. Returns to previous screen."
- Close: "Close. Button. Dismisses feedback flow."

**Screen 2A: Endorsement**
- Title: "Great! Would you play with them again?"
- Player row: "John Doe, San Jose, California, Verified member. Would play again button. Double tap to endorse."
- Endorsed state: "John Doe. Endorsed. Button. Double tap to remove endorsement."
- Skill question: "Was everyone's skill level accurate?"
- Yes radio: "Yes. Radio button. Selected."
- Skip: "Skip for now. Button. Submits positive feedback without endorsements."
- Submit: "Submit. Button. Submits feedback with selected endorsements."

**Screen 2B: Incident Reporting**
- Select users title: "Who had an issue? Select all that apply."
- Selectable row: "John Doe, San Jose, California, Verified member. Not selected. Checkbox. Double tap to select."
- Issue detail title: "What happened with John Doe?"
- Issue checkbox: "No-show. Checkbox. Not selected. Double tap to select."
- Comment field: "More details. Text field. Optional. 200 character limit."
- Submit: "Submit report. Button. Submits confidential incident report."

**Screen 3: Success**
- Icon: "Checkmark. Success."
- Title: "Thank you!"
- Message: "Your feedback helps build a trusted community"
- Done: "Done. Button. Dismisses success screen."

### 8.2 Dynamic Type

**Requirements:**
- All text scales with user's preferred text size
- Buttons remain tappable at largest size
- Minimum touch target: 44x44 pts
- Test at:
  - Default (16pt body)
  - Accessibility Medium (23pt)
  - Accessibility XXL (38pt)

**Layout adjustments:**
- At large sizes, buttons stack vertically
- Cards expand to accommodate text
- Maintain 16pt min padding at all sizes

### 8.3 Color Contrast

**WCAG AA Requirements:**
- Text: 4.5:1 contrast ratio
- Large text (18pt+): 3:1
- Interactive elements: 3:1

**Validation:**
- AppColors.textPrimary on backgroundGrouped: ✅ 13:1
- AppColors.textSecondary on backgroundGrouped: ✅ 7:1
- AppColors.primary on backgroundGrouped: ✅ 4.5:1
- Success green on white: ✅ 4.8:1
- Destructive red on white: ✅ 5.2:1

### 8.4 Reduce Motion

**Animations to disable:**
- Screen transitions (use instant push)
- Banner slide-down (use instant appear)
- Button scale effects (use opacity only)

**Preserve:**
- Loading spinners (essential feedback)
- Checkmark animations (can be instant)

### 8.5 Keyboard Navigation (iPad)

**Tab order:**
- Navigation bar buttons
- Primary question buttons
- All interactive elements (checkboxes, buttons)
- Text fields
- Bottom buttons

**Shortcuts:**
- Escape: Close/dismiss
- Return: Submit (when enabled)
- Tab/Shift-Tab: Navigate

---

## 9. Testing Scenarios

### 9.1 Happy Path Testing

**Scenario 1: Everyone was great**
1. Tap notification → Primary question screen loads
2. Tap "Yes, all good" → Endorsement screen appears
3. Tap "Would play again" for 2 players
4. Keep skill accurate as "Yes"
5. Tap "Submit" → Success screen shows
6. Tap "Done" → Return to app

**Expected:**
- Total taps: 5
- Time: < 15 seconds
- No errors

**Scenario 2: One person had issue**
1. Tap notification → Primary question screen
2. Tap "No, there was an issue" → Select users screen
3. Tap on John Doe → Checkbox selected
4. Tap "Next" → Issue details for John
5. Tap "Late (15+ min)" → Checkbox selected
6. Tap "Submit Report" → Success screen
7. Tap "Done" → Return to app

**Expected:**
- Total taps: 7
- Time: < 20 seconds
- Incident recorded

### 9.2 Edge Case Testing

**Test 1: Network fails during submit**
- Disable network
- Attempt to submit
- Error banner appears
- Re-enable network
- Tap "Retry"
- Submits successfully

**Test 2: App killed mid-flow**
- Start feedback flow
- Select options
- Kill app
- Reopen app
- Pending feedback still visible in Profile
- Can restart flow

**Test 3: Round cancelled during flow**
- Start feedback flow
- Host cancels round (have someone else do this)
- Attempt to submit
- Error: "Round not found"

**Test 4: 10 participants**
- Round with 10 people
- Endorsement screen scrolls smoothly
- Can endorse all 10
- Submit works

**Test 5: Solo round**
- Complete solo round
- No feedback prompt shown
- No pending feedback item

**Test 6: Already submitted**
- Submit feedback
- Tap notification again
- "Already Submitted" screen shows

### 9.3 Accessibility Testing

**VoiceOver:**
- Enable VoiceOver
- Navigate entire flow using only gestures
- All elements properly labeled
- Can complete submission

**Dynamic Type:**
- Settings → Display → Text Size → Accessibility XXL
- Open feedback flow
- All text readable
- Buttons still tappable
- Layout doesn't break

**Reduce Motion:**
- Settings → Accessibility → Motion → Reduce Motion ON
- Transitions are instant (no animations)
- Loading indicators still work

### 9.4 Performance Testing

**Metrics:**
- Screen load time: < 500ms
- Tap response: < 100ms
- Submit request: < 2 seconds
- Image loading: < 1 second per photo

**Test with:**
- Slow network (3G simulation)
- Low memory device (iPhone SE 2)
- Background activity (music playing)

---

## 10. Analytics Events Summary

```swift
// Screen views
feedback_screen_viewed(roundId, courseName)
endorsement_screen_viewed(roundId, participantCount)
select_users_screen_viewed(roundId)
issue_details_screen_viewed(roundId, targetUid)
feedback_success_viewed(roundId)

// Interactions
feedback_yes_selected(roundId)
feedback_no_selected(roundId)
endorsement_toggled(roundId, endorsed)
skill_accuracy_selected(roundId, accurate)
endorsements_skipped(roundId)
issue_user_selected(roundId, targetUid)
issue_type_selected(roundId, issueType)

// Submissions
feedback_submitted(roundId, safetyOK, endorsementCount, skillAccurate)
incident_reported(roundId, targetUid, issueTypes, hasComment)

// Errors
feedback_error(roundId, errorType, errorMessage)

// Success
feedback_success_dismissed(roundId, dismissMethod)
```

**Custom dimensions:**
- User tier (rookie/member/trusted/verified)
- Round participant count
- Days since round completed
- Entry point (notification/profile/round_detail)

---

## 11. Copy Deck (All Text)

### Primary Question Screen
- Title: "How was your round at {courseName}?"
- Question: "Did everyone show up and behave respectfully?"
- Yes button: "✅ Yes, all good"
- No button: "⚠️ No, there was an issue"
- Helper: "Your feedback is private and helps build a trusted community"
- Loading: "Loading..."
- Error title: "⚠️ Unable to Load Feedback"
- Error message: "This round couldn't be loaded. Please try again."
- Retry button: "Retry"
- Already submitted title: "✅ Feedback Submitted"
- Already submitted message: "You already provided feedback for this round. Thank you!"
- Done button: "Done"

### Endorsement Screen
- Title: "Great! Would you play with them again?"
- Skill question: "Was everyone's skill level accurate?"
- Yes radio: "Yes"
- No radio: "No"
- Endorsement button (unchecked): "👍 Would play again"
- Endorsement button (checked): "✓ Endorsed"
- Skip button: "Skip for Now"
- Submit button: "Submit"
- Error banner: "Unable to submit feedback. Please try again."

### Select Users Screen
- Title: "Who had an issue?"
- Subtitle: "Select all that apply"
- Helper: "This is private and confidential"
- Back button: "Back"
- Next button: "Next"

### Issue Details Screen
- Title: "What happened with {name}?"
- Instruction: "Select all that apply"
- Issue types:
  - "No-show"
  - "Late (15+ min)"
  - "Poor communication"
  - "Disrespectful behavior"
  - "Skill mismatch"
  - "Other"
- Comment label: "More details (optional)"
- Comment placeholder: "(Tap to add private notes)"
- Character count: "{count} / 200 characters"
- Back button: "Back"
- Submit button: "Submit Report"

### Success Screen
- Title: "Thank you!"
- Message: "Your feedback helps build a trusted community"
- Button: "Done"

### Pending Feedback Section
- Section title: "Pending Feedback"
- Empty state: "No feedback needed at this time"
- Time variants:
  - "Expiring soon"
  - "1 day left"
  - "{X} days left"
- View all: "View All ({X} more)"

### Error Messages
- Round not found: "This round couldn't be loaded. It may have been cancelled."
- Not a participant: "You're no longer a participant of this round."
- Network error: "Unable to submit feedback. Check your connection and try again."
- Generic error: "Something went wrong. Please try again."

### Notifications
- Initial: "Rate your round at {courseName}"
- Body: "Quick 5-second feedback helps the community"
- Reminder: "⛳️ Quick question about your round"
- Reminder body: "Tap to give 5-second feedback"

---

## 12. Implementation Checklist

### Phase 1: Foundation
- [ ] Create PostRoundFeedbackViewModel
- [ ] Create TrustRepository protocol
- [ ] Define all models (RoundFeedback, PlayerEndorsement, IncidentFlag)
- [ ] Set up navigation coordinator

### Phase 2: Primary Question Screen
- [ ] Build PostRoundFeedbackView layout
- [ ] Implement loading state
- [ ] Implement error state
- [ ] Implement already submitted state
- [ ] Wire up Yes/No buttons
- [ ] Add analytics events
- [ ] Test VoiceOver

### Phase 3: Endorsement Screen
- [ ] Build EndorsementScreen layout
- [ ] Implement PlayerEndorsementRow component
- [ ] Implement skill accuracy radio buttons
- [ ] Wire up Skip/Submit buttons
- [ ] Add submission loading state
- [ ] Handle submission errors
- [ ] Add analytics events
- [ ] Test VoiceOver

### Phase 4: Incident Reporting Screens
- [ ] Build SelectIssueUsersScreen
- [ ] Build IssueDetailsScreen
- [ ] Implement multi-user flow
- [ ] Wire up issue type checkboxes
- [ ] Implement comment text field
- [ ] Add 200 char limit validation
- [ ] Add submission logic
- [ ] Handle errors
- [ ] Add analytics events
- [ ] Test VoiceOver

### Phase 5: Success Screen
- [ ] Build FeedbackSuccessScreen
- [ ] Implement auto-dismiss (2s)
- [ ] Handle navigation back
- [ ] Add haptic feedback
- [ ] Add analytics events

### Phase 6: Pending Feedback Section
- [ ] Build PendingFeedbackSection
- [ ] Build PendingFeedbackRow
- [ ] Implement urgency colors
- [ ] Add to ProfileView
- [ ] Wire up navigation
- [ ] Test with 0, 1, 3, 5 items

### Phase 7: Entry Points
- [ ] Implement notification handling
- [ ] Implement deep link routing
- [ ] Add Profile section entry
- [ ] Add Round Detail banner entry
- [ ] Test all entry points

### Phase 8: Edge Cases
- [ ] Handle round not found
- [ ] Handle already submitted
- [ ] Handle user removed
- [ ] Handle network errors
- [ ] Handle round cancelled
- [ ] Handle blocked users
- [ ] Test offline behavior

### Phase 9: Polish
- [ ] Implement haptic feedback
- [ ] Add loading indicators
- [ ] Optimize image loading
- [ ] Test on slow network
- [ ] Test on low-end device
- [ ] Test with Dynamic Type
- [ ] Test with Reduce Motion
- [ ] Test with VoiceOver

### Phase 10: Testing
- [ ] Unit tests for ViewModel
- [ ] Unit tests for Repository
- [ ] UI tests for happy paths
- [ ] UI tests for edge cases
- [ ] Accessibility audit
- [ ] Performance testing
- [ ] Beta user testing

---

## 13. Open Questions for Engineering

1. **Should we pre-fetch participant profiles during loading state?**
   - Pro: Faster screen render
   - Con: More complex loading logic
   - Recommendation: Yes, fetch in parallel with round data

2. **Should we cache submissions locally for retry?**
   - Pro: Better offline support
   - Con: Complexity, data staleness
   - Recommendation: No, keep simple (network required)

3. **Should we implement progressive loading for 10+ participants?**
   - Pro: Better performance
   - Con: Unnecessary for < 50 people
   - Recommendation: No, not needed for MVP

4. **Should pending feedback items sync in real-time?**
   - Pro: Always up-to-date
   - Con: More Firestore listeners
   - Recommendation: Yes, use listener (1 per user, minimal cost)

5. **Should we track "time to complete" metric?**
   - Pro: Good UX insight
   - Con: Minor added complexity
   - Recommendation: Yes, easy to add (timestamp on appear/submit)

---

## Status: ✅ Ready for Implementation

This spec is complete and implementation-ready. All screens, states, interactions, copy, and edge cases are defined. Engineers can build directly from this document.

**Next Step:** Create technical implementation spec (ViewModels, Repositories, Models).
