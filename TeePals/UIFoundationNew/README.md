# UIFoundationNew - TeePals V2 Design System

This folder contains the polished, modern design system for TeePals. Use these components and tokens for all new UI work.

## 📐 Design Tokens

### Typography (`AppTypographyV2.swift`)

**Display Text:**
- `.displayHeavy` - 24pt heavy (greetings, emphasis)
- `.displayLarge` - 26pt bold
- `.displayMedium` - 22pt bold

**Section Headers:**
- `.sectionHeader` - 20pt bold (main sections)
- `.subsectionHeader` - 18pt semibold (subsections)

**Body Text:**
- `.bodyLarge` - 16pt regular
- `.bodyMedium` - 15pt medium
- `.bodyRegular` - 15pt regular
- `.bodySmall` - 14pt medium

**Labels:**
- `.labelBoldUppercase` - 11pt bold (use with uppercase + tracking)
- `.labelMedium` - 13pt medium
- `.labelSmall` - 11pt medium

**Links & Actions:**
- `.linkSemibold` - 14pt semibold (View All, etc.)
- `.linkMedium` - 14pt medium

**Buttons:**
- `.buttonSemibold` - 16pt semibold (primary CTAs)
- `.buttonMedium` - 15pt semibold (secondary)

**Helpers:**
- `.placeholder` - 14pt medium (empty states)
- `.helper` - 13pt regular
- `.caption` - 12pt regular

**View Modifiers:**
```swift
Text("Action Center").sectionHeaderStyle()
Text("NEW INVITES").labelBoldUppercaseStyle(tracking: 0.5)
```

---

### Shadows (`AppShadows.swift`)

**Card Shadows:**
- `.card` - Standard card elevation
- `.hero` - Prominent depth for hero elements
- `.elevated` - Highest elevation for modals

**Button Shadows:**
- `.button(color:opacity:)` - Colored shadow for CTAs
- `.buttonSubtle` - Subtle shadow for secondary buttons

**Element Shadows:**
- `.small` - Avatars, chips, badges
- `.medium` - Input fields, selectors

**View Modifiers:**
```swift
VStack { ... }
    .cardShadow()

Button { ... }
    .buttonShadow(color: AppColors.primary)

Image(systemName: "person.fill")
    .smallShadow()
```

---

### Spacing (`AppSpacingV2.swift`)

**Compact Spacing:**
- `.sectionCompact` - 20pt (dashboard sections)
- `.itemCompact` - 12pt (list items)
- `.inlineCompact` - 6pt (within components)
- `.xxs` - 2pt (very tight)

**Dashboard Specific:**
- `.dashboardHeaderTop` - 40pt
- `.dashboardBottom` - 32pt
- `.dashboardCardSpacing` - 20pt

**Button Padding:**
- `.buttonHorizontalLarge` - 24pt
- `.buttonVerticalLarge` - 14pt
- `.buttonHorizontalMedium` - 20pt
- `.buttonVerticalMedium` - 12pt

**Corner Radius:**
- `.buttonRadiusCompact` - 10pt
- `.buttonRadiusMedium` - 12pt
- `.cardRadius` - 14pt

**Text Tracking:**
- `.uppercaseTracking` - 1.5pt
- `.labelTracking` - 0.5pt

**View Modifiers:**
```swift
VStack { ... }
    .dashboardHeaderPadding()
```

---

## 🧩 Reusable Components

### DashboardSectionHeader

Section header with optional action link.

```swift
DashboardSectionHeader(
    title: "Action Center",
    actionTitle: "View All",
    action: { /* navigate */ }
)
```

**Props:**
- `title: String` - Section title
- `actionTitle: String?` - Optional action text
- `action: (() -> Void)?` - Optional action callback

---

### DashboardMetricCard

Metric/action card showing icon, count/metric, and label.

```swift
// With count
DashboardMetricCard(
    icon: "envelope.fill",
    count: 3,
    label: "New Invites",
    hasNotification: true,
    action: { /* navigate */ }
)

// With custom text
DashboardMetricCard(
    icon: "figure.golf",
    metricText: "12",
    label: "Rounds Played",
    action: { /* navigate */ }
)
```

**Props:**
- `icon: String` - SF Symbol name
- `count: Int` - Number metric (shows "Will appear here" if 0)
- `metricText: String` - Custom text metric
- `label: String` - Label below metric
- `hasNotification: Bool` - Show notification dot
- `action: () -> Void` - Tap action

**Features:**
- Automatically shows "Will appear here" when count is 0
- Uppercase label with proper tracking
- Standard card shadow and styling

---

### DashboardHeroCard

Full-width hero card with background image, gradient, and custom content.

```swift
DashboardHeroCard(
    backgroundImage: imageURL,
    height: 280,
    action: { /* navigate */ }
) {
    VStack(alignment: .leading) {
        // Custom content here
        Spacer()

        Text("Hero Title")
            .font(.system(size: 28, weight: .bold))
            .foregroundColor(.white)

        // CTA button, etc.
    }
}
```

**Props:**
- `backgroundImage: URL?` - Optional background image
- `placeholderGradient: LinearGradient` - Gradient when no image
- `height: CGFloat` - Card height (default 280)
- `action: (() -> Void)?` - Optional tap action
- `content: () -> Content` - Custom content view

**Features:**
- Automatic gradient overlay for readability
- Hero shadow depth
- AsyncImage with graceful fallback
- Tappable when action provided

---

## 🎨 Usage Examples

### Dashboard Section

```swift
VStack(spacing: AppSpacingV2.sectionCompact) {
    // Header
    DashboardSectionHeader(
        title: "Action Center",
        actionTitle: "View All",
        action: { selectedTab = 3 }
    )
    .padding(.horizontal, 20)

    // Metric cards
    HStack(spacing: 12) {
        DashboardMetricCard(
            icon: "envelope.fill",
            count: viewModel.newInvites,
            label: "New Invites",
            hasNotification: viewModel.newInvites > 0,
            action: { /* navigate */ }
        )

        DashboardMetricCard(
            icon: "clock.fill",
            count: viewModel.pendingRequests,
            label: "Pending Requests",
            action: { /* navigate */ }
        )
    }
    .padding(.horizontal, 20)
}
```

### Hero Card with Content

```swift
DashboardHeroCard(
    backgroundImage: viewModel.coursePhotoURL,
    action: { /* navigate to detail */ }
) {
    VStack(alignment: .leading, spacing: 12) {
        Spacer()

        // Badge
        HStack(spacing: 4) {
            Image(systemName: "star.fill").font(.system(size: 12))
            Text("HOSTING").font(.system(size: 11, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.white.opacity(0.2))
        .cornerRadius(99)

        // Title
        Text(viewModel.courseName)
            .font(.system(size: 28, weight: .bold))
            .foregroundColor(.white)

        // CTA
        HStack {
            Spacer()
            Text("View Details")
                .font(AppTypographyV2.buttonSemibold)
                .foregroundColor(.white)
                .padding(.horizontal, AppSpacingV2.buttonHorizontalLarge)
                .padding(.vertical, AppSpacingV2.buttonVerticalLarge)
                .background(AppColors.primary)
                .cornerRadius(AppSpacingV2.buttonRadiusMedium)
                .buttonShadow()
            Spacer()
        }
    }
}
```

---

## 🚀 Migration Guide

When building new views or refactoring existing ones:

1. **Replace hardcoded fonts** with `AppTypographyV2` tokens
2. **Replace inline shadows** with `.cardShadow()`, `.heroShadow()`, etc.
3. **Use spacing constants** from `AppSpacingV2` instead of magic numbers
4. **Use reusable components** instead of rebuilding patterns

### Before:
```swift
Text("Action Center")
    .font(.system(size: 20, weight: .bold))
    .foregroundColor(AppColors.textPrimary)

VStack { ... }
    .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
```

### After:
```swift
Text("Action Center")
    .font(AppTypographyV2.sectionHeader)
    .foregroundColor(AppColors.textPrimary)

VStack { ... }
    .cardShadow()
```

---

## ✅ Checklist for New Views

- [ ] Use `AppTypographyV2` for all text styling
- [ ] Apply shadow modifiers (`.cardShadow()`, etc.)
- [ ] Use `AppSpacingV2` constants for padding/spacing
- [ ] Reuse `DashboardSectionHeader` for section headers
- [ ] Reuse `DashboardMetricCard` for metrics/actions
- [ ] Reuse `DashboardHeroCard` for hero sections
- [ ] No hardcoded font sizes, shadows, or spacing values
- [ ] All views under 250 lines (per UI_RULES.md)

---

## 📚 References

- See `UI_RULES.md` for design principles
- See `HomeView.swift` for reference implementation
- Old design system in `/UIFoundation` (legacy, don't use for new views)
