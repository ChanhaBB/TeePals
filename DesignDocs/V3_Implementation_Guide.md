# Home Dashboard V3 - Implementation Guide

**Created**: February 16, 2026
**Status**: Components ready, fonts and assets needed

---

## ✅ Completed

### Design System (UIFoundationNew)
1. ✅ **AppColorsV3.swift** - Premium color palette
2. ✅ **AppTypographyV3.swift** - Inter + Playfair Display fonts
3. ✅ **AppSpacingV3.swift** - Simplified spacing (8, 12, 16, 24)
4. ✅ **AppShadowsV3.swift** - Premium shadow system
5. ✅ **AppGradientsV3.swift** - Card gradient overlays

### Reusable Components
1. ✅ **HeroCardV3.swift** - Large card with course photo + gradient
2. ✅ **MetricCardV3.swift** - Invites/Pending metric cards
3. ✅ **CompactRoundCard.swift** - Horizontal round card (no photo)
4. ✅ **SectionHeaderV3.swift** - Section title with "View All" link

### Views
1. ✅ **HomeViewV3.swift** - Complete home dashboard implementation

---

## 📋 TODO: Required Setup

### 1. Add Fonts to Xcode

You need to add these font files to your Xcode project:

**Inter Font Family:**
- Inter-Regular.ttf
- Inter-Medium.ttf
- Inter-SemiBold.ttf
- Inter-Bold.ttf

**Playfair Display Font Family:**
- PlayfairDisplay-Bold.ttf
- PlayfairDisplay-BoldItalic.ttf

**Steps:**
1. Download fonts:
   - Inter: https://fonts.google.com/specimen/Inter
   - Playfair Display: https://fonts.google.com/specimen/Playfair+Display

2. Add to Xcode:
   - Drag font files into Xcode project
   - Check "Copy items if needed"
   - Add to target: TeePals

3. Update Info.plist:
   ```xml
   <key>UIAppFonts</key>
   <array>
       <string>Inter-Regular.ttf</string>
       <string>Inter-Medium.ttf</string>
       <string>Inter-SemiBold.ttf</string>
       <string>Inter-Bold.ttf</string>
       <string>PlayfairDisplay-Bold.ttf</string>
       <string>PlayfairDisplay-BoldItalic.ttf</string>
   </array>
   ```

4. Verify fonts loaded (call during app launch):
   ```swift
   verifyCustomFonts() // Function in AppTypographyV3.swift
   ```

---

### 2. Add course.png to Assets

**File**: `/Users/chanhak/TeePalsUI/course.png`

**Steps:**
1. Open `Assets.xcassets` in Xcode
2. Create new Image Set: "course-placeholder"
3. Drag `course.png` into 1x slot
4. Update HomeViewV3.swift:
   ```swift
   private var courseImageURL: URL? {
       // Use bundled image
       guard let image = UIImage(named: "course-placeholder") else { return nil }
       // Save to temp directory and return URL
       // OR use directly in AsyncImage fallback
       return nil
   }
   ```

**Alternative**: Convert to use `Image("course-placeholder")` directly instead of URL

---

### 3. Update MainTabView to Use V3

**File**: `TeePals/Views/Main/MainTabView.swift`

**Change:**
```swift
// OLD
HomeView(viewModel: container.makeHomeViewModel())

// NEW (to test V3)
HomeViewV3(viewModel: container.makeHomeViewModel())
```

---

## 🎨 Design System Reference

### Colors
```swift
AppColorsV3.forestGreen    // #0B3D2E - Primary
AppColorsV3.emeraldAccent  // #155E49 - Accent
AppColorsV3.bgNeutral      // #FDFDFD - Background
AppColorsV3.surfaceWhite   // #FFFFFF - Cards
AppColorsV3.textPrimary    // #121413 - Headings
AppColorsV3.textSecondary  // #6B7280 - Body
AppColorsV3.borderLight    // #F1F3F2 - Borders
```

### Typography
```swift
// Playfair Display (Serif)
AppTypographyV3.displayLargeSerif        // 30pt bold italic (Sunday Morning)
AppTypographyV3.displayMediumSerif       // 24pt bold (Torrey Pines)
AppTypographyV3.sectionHeaderSerif       // 20pt bold (My Schedule)
AppTypographyV3.numberLargeSerif         // 30pt bold (2, 1)
AppTypographyV3.numberMediumSerif        // 18pt bold (16, 23)

// Inter (Sans-Serif)
AppTypographyV3.bodyMedium               // 14pt medium
AppTypographyV3.roundCardTitle           // 15pt bold
AppTypographyV3.labelUppercaseBold       // 10pt bold
AppTypographyV3.buttonUppercase          // 11pt bold
```

### Spacing
```swift
AppSpacingV3.xs              // 8pt
AppSpacingV3.sm              // 12pt
AppSpacingV3.md              // 16pt
AppSpacingV3.lg              // 24pt
AppSpacingV3.contentPadding  // 24pt (px-6)
AppSpacingV3.sectionSpacing  // 32pt (space-y-8)
AppSpacingV3.radiusLarge     // 24pt (rounded-3xl)
AppSpacingV3.radiusMedium    // 16pt (rounded-2xl)
```

### Shadows
```swift
.premiumShadow()      // Premium card shadow
.buttonShadowV3()     // Button shadow
.textDropShadow()     // Text over images
```

### Gradients
```swift
AppGradientsV3.heroCardForestGreen  // For rounds with photos
AppGradientsV3.heroCardEmpty        // For empty state
```

---

## 🔧 Current Limitations

### In HomeViewV3:

1. **Course Photos**: Not loading yet
   - Need to integrate with `CoursePhotoService`
   - Should load from Google Places API
   - Use `course.png` as fallback

2. **My Schedule**: Only shows empty state
   - Need to fetch user's upcoming rounds
   - Should use `ActivityRoundsService`
   - Show CompactRoundCard for each

3. **Host Names**: Showing "Host" placeholder
   - Need to fetch host profile for each round
   - Should use `ProfileRepository`

4. **Distance**: Showing "0.0mi"
   - Need to calculate from user's location
   - Use `DistanceUtil` from existing codebase

5. **Slot Counts**: Hardcoded to 2
   - Need to fetch actual member count
   - Query `rounds/{roundId}/members` collection

6. **Navigation**: All TODOs
   - Wire up to Round Detail
   - Wire up to Rounds tab
   - Wire up to Activity sections

---

## 🚀 Next Steps

### Phase 1: Fonts & Assets (Required)
1. Add Inter and Playfair Display fonts
2. Add course.png to Assets
3. Test font loading with `verifyCustomFonts()`

### Phase 2: Integration (Complete Features)
1. Load course photos for hero card
2. Fetch user's schedule rounds
3. Fetch host profiles for round cards
4. Calculate distances
5. Get accurate slot counts

### Phase 3: Navigation (Wire Up Actions)
1. Hero card → Round Detail
2. "Find a Round" → Rounds tab
3. Metric cards → Activity sections
4. Round cards → Round Detail
5. "View All" links → appropriate tabs

### Phase 4: Polish
1. Add loading states (skeleton loaders)
2. Add error handling
3. Add pull-to-refresh
4. Add haptic feedback
5. Performance optimization

---

## 📱 Testing Checklist

Once fonts are added:

- [ ] Fonts load correctly (check console)
- [ ] "Sunday Morning" displays in italic serif
- [ ] Section headers use serif font
- [ ] Numbers use serif font (bold, not italic)
- [ ] Body text uses Inter
- [ ] Colors match HTML design
- [ ] Shadows are subtle (forest green tint)
- [ ] Cards have rounded corners (24pt hero, 16pt cards)
- [ ] Spacing matches HTML (24pt padding, 32pt sections)
- [ ] Empty state shows course.png
- [ ] Metrics show 0 correctly (grayed out)
- [ ] Date badges work (outline vs filled)

---

## 📖 Component Usage Examples

### Hero Card
```swift
HeroCardV3(
    backgroundImage: coursePhotoURL,
    badgeText: "Upcoming Round",
    title: "Torrey Pines South",
    subtitle: "Sun, Feb 16 • 07:30 AM",
    buttonTitle: "View Details",
    action: { /* navigate */ }
)
```

### Metric Card
```swift
MetricCardV3(
    icon: "envelope.fill",
    count: 2,
    label: "Invites",
    hasNotification: true,
    action: { /* navigate */ }
)
```

### Compact Round Card
```swift
CompactRoundCard(
    dateMonth: "Feb",
    dateDay: "16",
    courseName: "Torrey Pines South",
    hostName: "Alex P.",
    distance: "18.6mi",
    totalSlots: 4,
    filledSlots: 3,
    statusBadge: "You're In",
    isUserRound: true,
    action: { /* navigate */ }
)
```

### Section Header
```swift
SectionHeaderV3(
    title: "My Schedule",
    actionTitle: "View All",
    action: { /* navigate */ }
)
```

---

## 🎯 Success Criteria

V3 is complete when:
1. ✅ All fonts load and display correctly
2. ✅ Design matches HTML pixel-perfectly
3. ✅ All data loads from ViewModels (no hardcoded values)
4. ✅ All navigation works
5. ✅ Empty states handle gracefully
6. ✅ Performance is smooth (60fps scroll)

---

**Questions?** See component preview code in each file for usage examples.
