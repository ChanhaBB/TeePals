# TeePals UI Rules (Cursor Enforced)

This document defines **non-negotiable UI rules** for TeePals.
Cursor must follow these rules when generating or modifying any UI code.

---

## 0) Non‑Negotiables
- No Firebase imports in Views
- No business logic inside `View.body`
- No view files larger than 250 lines
- Every screen must support: loading, empty, error, success states
- UIFoundation components must be used instead of inline styling

---

## 1) UIFoundation (Design System Lite)

### Tokens
- AppColors: background, surface, surface2, textPrimary, textSecondary, primary, danger, separator
- AppTypography: screenTitle, sectionTitle, body, caption
- AppSpacing: xs=8, sm=12, md=16, lg=24, xl=32
- AppRadii: card=16–20, button=14–16, chip=999

### Components (must exist and be reused)
- AppCard
- PrimaryButton (disabled + loading + pressed state)
- SecondaryButton
- AppTextField (label, hint, error)
- ChipGroup / SelectableChip
- InlineErrorBanner
- EmptyStateView
- SkeletonRow / SkeletonCard
- ProfileAvatarView

No repeated ad‑hoc modifiers where a component exists.

---

## 2) Layout & Spacing
- Screen padding: minimum 16pt
- Section spacing: 24pt
- Element spacing: 12–16pt
- Prefer card‑based layouts for grouped content

---

## 3) Typography & Hierarchy
- Clear hierarchy per screen:
  - Screen title (large, semibold)
  - Helper text (caption / secondary)
  - Single primary CTA
- Avoid uniform font weights everywhere

---

## 4) Buttons & Interactions
- Primary CTA is sticky at bottom when applicable
- Buttons must include:
  - Disabled state
  - Loading state
  - Pressed feedback
- Add haptics for:
  - Primary success actions
  - Selection confirmations

---

## 5) Navigation & Modals
- Use NavigationStack
- Prefer bottom sheets for selections
- Use push navigation for detail screens
- Avoid deep navigation logic in Views

---

## 6) UI States (Required Everywhere)

### Loading
- Show skeletons or progress indicator
- Do not show empty placeholders during loading

### Empty
- Use EmptyStateView with clear CTA

### Error
- Use InlineErrorBanner with retry option when possible

### Success
- Provide confirmation feedback (toast/banner)

---

## 7) Forms & Validation
- Inline validation with clear messaging
- Disable continue until valid
- Never block submission without explanation

---

## 8) Tier 1 Onboarding Wizard
Steps (locked order):
1. Nickname
2. Birthdate
3. Location
4. Gender

Rules:
- One question per screen
- Progress indicator (e.g., 2/4)
- Sticky bottom CTA
- Smooth animated transitions
- Resume from first missing step

---

## 9) Tier 2 Profile Completion
Required:
- Profile photo
- Skill level

Rules:
- Gate social/participation actions with a modal
- Show missing checklist
- Return user to intended action after completion

---

## 10) Tabs (Locked)
- Home
- Rounds
- Notifications
- Profile

Each tab root must handle loading/empty/error states.

---

## 11) Rounds UI
- Round cards must show:
  - Course + city
  - Tee time
  - Distance
  - Slots remaining
  - Price (if present)
  - Host mini‑profile
- Filters use a bottom sheet
- Clear join/request/accepted states

---

## 12) Accessibility & Dark Mode
- Support dark mode
- Reasonable Dynamic Type support
- Maintain contrast

---

## 13) UI Performance
- Avoid real‑time listeners for large lists
- Avoid heavy logic in body
- Use @StateObject for ViewModels
- Avoid duplicate async tasks

---

## 14) Premium Quality Checklist
- Consistent spacing
- Consistent corners
- Pressed/loading states everywhere
- Skeletons or empty states present
- Smooth transitions

---

Cursor must follow this document exactly.
