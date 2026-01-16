# Implementation Plan: Share Round via Deep Link

## Overview
Add ability to share rounds via iOS share sheet using HTTPS Universal Links. Recipients can open the round in-app (if installed) or view a web landing page (if not).

**Core UX:** Round Details → "Share" button → iOS share sheet → User picks iMessage/WhatsApp/Instagram/etc → Recipient opens link

**Link Strategy:** Use canonical HTTPS URLs (`https://teepals.com/r/{roundId}`) that work as both Universal Links (iOS) and web fallback. No vendor lock-in, no deprecated APIs.

## Key Decisions

### 1. Generic Share Link (Not Contact Sync)
- **Decision:** Use iOS native share sheet with HTTPS Universal Links
- **Why:** Privacy-first, no permissions needed, works across all platforms
- **Alternative Rejected:** Contact sync (massive complexity, privacy concerns, GDPR issues)

### 2. Universal Links (HTTPS URLs)
- **Decision:** Use HTTPS Universal Links on our own domain (`https://teepals.com/r/{roundId}`)
- **Why:**
  - **Future-proof:** Not dependent on third-party services (Firebase Dynamic Links deprecated for new projects)
  - **Simple:** One canonical URL for web + iOS (no custom schemes needed)
  - **SEO-friendly:** Actual web pages that work in browsers
  - **Flexible:** Can add query params for attribution without vendor lock-in
- **Trade-offs:**
  - No automatic App Store fallback on iOS (landing page handles this with "Get App" button)
  - Deferred deep linking requires additional work (optional, can add Branch/AppsFlyer later if needed)

### 3. Share Button Placement
- **Decision:** Add "Share" button in Round Details action row (alongside "Edit", "Cancel")
- **Why:** Standard iOS pattern, discoverable, doesn't clutter UI
- **Not:** Separate "Invite" flow (keep existing "Invite TeePals" separate for now)

### 4. Link Format
```
Canonical URL: https://teepals.com/r/{roundId}
- iOS (app installed): Opens app via Universal Links
- iOS (app not installed): Shows web landing page
- Android/Desktop: Shows web landing page

Optional query params (future):
- ?inviter={uid}  - Track who shared
- ?source={iMessage|whatsapp|...}  - Track channel
```

**Why no custom schemes:** Custom URL schemes (`teepals://`) are not shared via iMessage. Universal Links work everywhere and degrade gracefully to web.

## Implementation Steps

### Phase 1: Universal Links Setup & Service Layer

#### 1.1 Universal Links Configuration (iOS)
**Manual Steps (Xcode):**
1. Add Associated Domain capability:
   - Target → Signing & Capabilities → + Capability
   - Add "Associated Domains"
   - Add: `applinks:teepals.com`

**Manual Steps (Web Server):**
1. Host AASA file at `https://teepals.com/.well-known/apple-app-site-association`
2. File contents (no extension, JSON format):
```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAM_ID.com.teepals.TeePals",
        "paths": ["/r/*"]
      }
    ]
  }
}
```
3. Serve with `Content-Type: application/json` (no redirect, HTTPS required)
4. Verify: https://branch.io/resources/aasa-validator/

**Why this works:**
- iOS checks AASA file when app installs
- When user taps `https://teepals.com/r/{roundId}`, iOS opens app (if installed)
- If app not installed, Safari loads the page normally

#### 1.2 Create ShareLinkService Protocol
**File:** `TeePals/Services/ShareLinkService.swift` (new)

Define protocol and implementation:
```swift
protocol ShareLinkServiceProtocol {
    func createRoundInviteLink(
        roundId: String,
        round: Round,
        inviterUid: String?
    ) async throws -> URL
}

final class ShareLinkService: ShareLinkServiceProtocol {
    func createRoundInviteLink(
        roundId: String,
        round: Round,
        inviterUid: String? = nil
    ) async throws -> URL {
        // Simple URL construction - no network call needed
        var components = URLComponents()
        components.scheme = "https"
        components.host = "teepals.com"
        components.path = "/r/\(roundId)"

        // Optional: Add inviter for attribution (future analytics)
        if let inviterUid = inviterUid {
            components.queryItems = [
                URLQueryItem(name: "inviter", value: inviterUid)
            ]
        }

        guard let url = components.url else {
            throw ShareLinkError.invalidURL
        }

        return url
    }
}

enum ShareLinkError: Error {
    case invalidURL
}
```

**Why this is simple:**
- No network call required (URL is deterministic)
- No third-party SDK needed
- Can add query params for analytics later
- Easy to swap implementations (Branch, AppsFlyer) behind same protocol

#### 1.3 Add to AppContainer
**File:** `TeePals/App/AppContainer.swift`

Add singleton:
```swift
private(set) lazy var shareLinkService: ShareLinkServiceProtocol = {
    ShareLinkService()
}()
```

Update `makeRoundDetailViewModel()` to inject service.

### Phase 2: Round Detail View Integration

#### 2.1 Update RoundDetailViewModel
**File:** `TeePals/ViewModels/RoundDetailViewModel.swift`

Add properties:
```swift
@Published var showShareSheet = false
@Published var shareURL: URL?
@Published var isGeneratingLink = false  // Always fast, but good UX to show feedback
```

Add dependency:
```swift
private let shareLinkService: ShareLinkServiceProtocol
```

Add methods:
```swift
func generateShareLink() async {
    isGeneratingLink = true
    defer { isGeneratingLink = false }

    do {
        shareURL = try await shareLinkService.createRoundInviteLink(
            roundId: roundId,
            round: round,
            inviterUid: currentUid()
        )
        showShareSheet = true
    } catch {
        errorMessage = "Failed to create share link"
    }
}

func shareMessage() -> String {
    guard let url = shareURL else { return "" }
    return """
    Join my round at \(round.courseName)!
    \(round.courseCity) • \(round.formattedDate) at \(round.formattedTime)

    \(url.absoluteString)
    """
}
```

#### 2.2 Create ShareSheet UIKit Wrapper
**File:** `TeePals/UIComponents/ShareSheet.swift` (new)

SwiftUI wrapper for `UIActivityViewController`:
```swift
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController
    func updateUIViewController(...)
}
```

#### 2.3 Update RoundDetailView UI
**File:** `TeePals/Views/Rounds/RoundDetailView.swift`

Add share button to action row (line ~150, after Edit/Cancel buttons):
```swift
if viewModel.canShare {
    Button {
        Task { await viewModel.generateShareLink() }
    } label: {
        if viewModel.isGeneratingLink {
            ProgressView()
        } else {
            Label("Share", systemImage: "square.and.arrow.up")
        }
    }
}
```

Add sheet modifier:
```swift
.sheet(isPresented: $viewModel.showShareSheet) {
    if let url = viewModel.shareURL {
        ShareSheet(items: [viewModel.shareMessage()])
    }
}
```

**Permissions check:** `canShare` should check if user is host OR member with accepted status.

### Phase 3: Universal Link Handling (In-App)

#### 3.1 Update TeePalsApp.swift
**File:** `TeePals/TeePalsApp.swift`

Add URL handler:
```swift
.onOpenURL { url in
    handleUniversalLink(url)
}
```

Add method:
```swift
func handleUniversalLink(_ url: URL) {
    // Parse: https://teepals.com/r/{roundId}
    guard url.host == "teepals.com",
          url.pathComponents.count >= 3,
          url.pathComponents[1] == "r" else {
        return
    }

    let roundId = url.pathComponents[2]

    // Extract optional query params
    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    let inviterUid = components?.queryItems?.first(where: { $0.name == "inviter" })?.value

    // Route to round
    routeToRound(roundId: roundId, inviterUid: inviterUid)
}

func routeToRound(roundId: String, inviterUid: String?) {
    // Check authentication state
    guard Auth.auth().currentUser != nil else {
        // Not authenticated - store for post-login routing
        pendingDeepLink = PendingDeepLink(roundId: roundId, inviterUid: inviterUid)
        return
    }

    // Navigate to round details
    // Implementation depends on your navigation setup (check RootView.swift)
    navigationCoordinator.navigate(to: .roundDetail(roundId))
}
```

**Note:** Navigation implementation depends on current navigation architecture (check RootView.swift for existing patterns).

#### 3.2 Handle Cold Start (App Not Running)
**File:** `TeePals/TeePalsApp.swift`

Handle links when app launches from closed state:
```swift
@main
struct TeePalsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var deepLinkCoordinator = DeepLinkCoordinator()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(deepLinkCoordinator)
                .onOpenURL { url in
                    handleUniversalLink(url)
                }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        // iOS calls this when app opens via Universal Link (cold start)
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return false
        }

        // Store URL for SwiftUI to handle after launch
        NotificationCenter.default.post(
            name: .universalLinkReceived,
            object: nil,
            userInfo: ["url": url]
        )

        return true
    }
}

// Pending deep link storage
struct PendingDeepLink {
    let roundId: String
    let inviterUid: String?
}

extension Notification.Name {
    static let universalLinkReceived = Notification.Name("universalLinkReceived")
}
```

#### 3.3 Post-Login Routing
**File:** `TeePals/Views/RootView.swift` (or auth flow)

After successful login, check for pending deep link:
```swift
func handleAuthenticationSuccess() {
    // Check if there's a pending deep link
    if let pending = deepLinkCoordinator.pendingDeepLink {
        deepLinkCoordinator.pendingDeepLink = nil
        routeToRound(roundId: pending.roundId, inviterUid: pending.inviterUid)
    } else {
        // Normal post-login flow
        routeToMainTab()
    }
}
```

**This provides "resume after login" for already-installed app.** Post-install deep linking (user installs app from App Store, then opens) requires additional work and can be deferred.

### Phase 4: Web Landing Page (MVP)

#### 4.1 Create Landing Page Route
**File:** Backend web server (Next.js, Express, or static hosting)

Create route handler for `/r/{roundId}`:
```javascript
// Next.js example: pages/r/[roundId].js
export async function getServerSideProps({ params }) {
  const { roundId } = params;

  // Fetch round data from Firestore (server-side)
  const round = await fetchPublicRound(roundId);

  if (!round || round.visibility !== 'public') {
    return { notFound: true };
  }

  return {
    props: {
      round,
      roundId,
    },
  };
}

export default function RoundLandingPage({ round, roundId }) {
  const appStoreUrl = "https://apps.apple.com/app/teepals/APPID";
  const universalLink = `https://teepals.com/r/${roundId}`;

  return (
    <div>
      <h1>Join this round</h1>
      <div>
        <h2>{round.courseName}</h2>
        <p>{round.courseCity}</p>
        <p>{formatDate(round.startTime)} at {formatTime(round.startTime)}</p>
        <p>{round.spotsAvailable} spots available</p>
      </div>

      {/* Smart CTA buttons */}
      <button onClick={() => window.location.href = universalLink}>
        Open in TeePals
      </button>
      <a href={appStoreUrl}>
        Get the App
      </a>
    </div>
  );
}
```

#### 4.2 Add OG Meta Tags (iMessage Preview)
**File:** Same landing page

Add meta tags for rich previews:
```html
<meta property="og:title" content="Join my round at {courseName}" />
<meta property="og:description" content="{courseCity} • {date} at {time}" />
<meta property="og:image" content="https://teepals.com/og-image.jpg" />
<meta property="og:url" content="https://teepals.com/r/{roundId}" />
```

**Why this matters:**
- iMessage shows preview card when link is shared
- Increases click-through rate
- Looks professional

#### 4.3 Handle Private/Deleted Rounds
```javascript
if (!round) {
  return (
    <div>
      <h1>Round Not Found</h1>
      <p>This round may have been deleted or is no longer available.</p>
      <a href="https://teepals.com">Explore TeePals</a>
    </div>
  );
}

if (round.visibility === 'private') {
  return (
    <div>
      <h1>Private Round</h1>
      <p>This round is private and can only be accessed by invited members.</p>
      <a href="https://teepals.com">Explore TeePals</a>
    </div>
  );
}
```

**MVP Landing Page Spec:**
- Show round details (course, date, time, spots)
- "Open in TeePals" button (attempts Universal Link)
- "Get the App" button (App Store)
- Handle private/deleted rounds gracefully
- Mobile-optimized (most traffic will be mobile)
- No authentication required (public page)

**No deferred deep linking needed:** Landing page just shows context. If user downloads app and signs in, they can search for the round or host can re-share the link.

### Phase 5: Round Access Logic (In-App)

#### 5.1 Update Firestore Security Rules
**File:** `firestore.rules`

Verify rule allows reading public rounds by authenticated users:
```javascript
match /rounds/{roundId} {
  allow read: if request.auth != null
              && (resource.data.visibility == 'public' || isRoundMember(roundId));
}
```

**No changes needed** if this rule already exists.

#### 5.2 Handle Non-Member Access
**File:** `TeePals/ViewModels/RoundDetailViewModel.swift`

Update `loadRound()` to handle scenarios:
- User is member → Show full details with actions
- User is not member → Show details, hide chat, show "Request to Join" if open
- Round is private → Show error "Round not found or private"

Add computed property:
```swift
var canAccessRound: Bool {
    round.visibility == .public || isMember
}
```

## Critical Files

### New Files (iOS):
1. `TeePals/Services/ShareLinkService.swift` - Link generation service
2. `TeePals/UIComponents/ShareSheet.swift` - UIKit wrapper for share sheet
3. `TeePals/Coordinators/DeepLinkCoordinator.swift` - (optional) Manage pending deep links

### New Files (Web):
1. `pages/r/[roundId].js` - Landing page for shared rounds (Next.js example)
2. `.well-known/apple-app-site-association` - AASA file for Universal Links

### Modified Files (iOS):
1. `TeePals/ViewModels/RoundDetailViewModel.swift` - Add share functionality
2. `TeePals/Views/Rounds/RoundDetailView.swift` - Add share button UI
3. `TeePals/App/AppContainer.swift` - Inject ShareLinkService
4. `TeePals/TeePalsApp.swift` - Handle Universal Links
5. `TeePals/Views/RootView.swift` - Post-login routing for pending deep links
6. `firestore.rules` - (verify) Public rounds readable by auth users

### Configuration Files:
1. Xcode Project - Associated Domains capability (`applinks:teepals.com`)
2. Web Server - Host AASA file at `/.well-known/apple-app-site-association`
3. DNS - Ensure `teepals.com` points to web server with valid SSL

## Setup Checklist

### iOS Configuration:
- [ ] Add Associated Domains entitlement in Xcode
- [ ] Add `applinks:teepals.com` to Associated Domains
- [ ] Test on device (Universal Links don't work in Simulator)

### Web Server Configuration:
- [ ] Create AASA file with correct Team ID and Bundle ID
- [ ] Host AASA at `https://teepals.com/.well-known/apple-app-site-association`
- [ ] Verify AASA serves with `Content-Type: application/json`
- [ ] Test AASA: https://branch.io/resources/aasa-validator/
- [ ] Create landing page route at `/r/{roundId}`
- [ ] Add OG meta tags for iMessage preview

### Firestore:
- [ ] Verify public rounds are readable by authenticated users
- [ ] Test accessing round by ID with non-member account

## Architecture Compliance

### Repository Pattern:
- ✅ ShareLinkService is a service (not repository) - pure URL construction
- ✅ No third-party SDK dependencies in core flow
- ✅ Protocol-based dependency injection (easy to swap Branch/AppsFlyer later)

### Security:
- ✅ Only public rounds can be accessed via shared links
- ✅ Authentication still required in-app (must have TeePals account)
- ✅ Firestore rules enforce visibility checks
- ✅ Web landing page has no authentication (public pages for SEO)

### Error Handling:
- Link generation failure (invalid roundId) → Show error alert (rare, URL construction is simple)
- Invalid deep link → Silently ignore or show "Round not found"
- Private round access → Show "This round is private" (both web and in-app)
- Deleted round → Show "Round no longer exists"

## Testing & Verification

### Manual Testing Checklist:

#### Link Generation (iOS App):
- [ ] Tap "Share" → Link generates instantly
- [ ] Link format is `https://teepals.com/r/{roundId}`
- [ ] Share sheet appears with recent contacts
- [ ] Can send via iMessage (message includes text + link)
- [ ] Can send via WhatsApp
- [ ] "Copy Link" copies to pasteboard

#### Universal Links (App Installed):
- [ ] Tap link in iMessage → App opens to Round Details (test on device, not simulator)
- [ ] Cold start (app closed) → Opens correctly after launch
- [ ] Background (app open) → Navigates to round
- [ ] Already authenticated → Direct to round
- [ ] Not authenticated → Login → Routing to round (pending deep link)

#### Web Landing Page (App Not Installed):
- [ ] Tap link in iMessage → Web page loads
- [ ] Shows round details (course, date, time)
- [ ] Shows "Open in TeePals" button
- [ ] Shows "Get the App" button (links to App Store)
- [ ] OG meta tags render in iMessage preview
- [ ] Mobile-optimized layout
- [ ] Private round → Shows "Private Round" message
- [ ] Deleted round → Shows "Round Not Found" message

#### AASA Validation:
- [ ] AASA file accessible at `https://teepals.com/.well-known/apple-app-site-association`
- [ ] AASA serves with `Content-Type: application/json`
- [ ] AASA validates: https://branch.io/resources/aasa-validator/
- [ ] iOS downloads AASA on app install (check console logs)

#### Permissions & Access (In-App):
- [ ] Public round → Anyone can view via link
- [ ] Private round → Shows "Round not found or private"
- [ ] Open round → Non-members see "Request to Join"
- [ ] Full round → Non-members see "Round is full"

#### Edge Cases:
- [ ] Round deleted → Shows "Round no longer exists" (web and app)
- [ ] Round past date → Still accessible (for history)
- [ ] User blocked by host → (TODO: handle gracefully)
- [ ] Malformed roundId → Shows error message

### Error Scenarios:
- [ ] No internet during link generation → Rare (URL construction offline), but handle gracefully
- [ ] Malformed deep link → Ignored, no crash
- [ ] AASA file missing → Universal Links fail, web page still works

## Future Enhancements (Post-MVP)

### Phase 6: Server-Side Analytics
- Track link opens (add simple counter in Firestore)
- Track link opens → round joins (conversion metric)
- Track link opens by source (iMessage, WhatsApp, etc.) via query params

### Phase 7: Rate Limiting
- Limit to 10 share links per user per hour
- Prevent spam/abuse
- Show friendly error: "You've shared many rounds recently. Try again in an hour."
- Implementation: Add Firestore counter doc per user with TTL

### Phase 8: Rich Previews
- Add course photo to OG image meta tags (once photos are in Round model)
- Custom OG image generation (dynamic images showing round details)
- Better click-through rates on shared links

### Phase 9: Deferred Deep Linking (Optional)
**Only if attribution is critical for growth:**
- Integrate Branch or AppsFlyer behind ShareLinkServiceProtocol
- Track app installs from shared links
- Resume to round after App Store install
- **Trade-off:** Adds third-party dependency, but provides true attribution

**Simple implementation without vendor:**
- Web landing page sets cookie/localStorage with roundId
- After app install + login, check for stored roundId via JS bridge
- Limited to same-device attribution only

### Phase 10: Link Expiry (Optional)
- Links expire after round date passes
- Show "This round has already happened" message
- Reduces stale link confusion

## Dependencies

### External (MVP):
- iOS 14+ (Associated Domains / Universal Links)
- Web server with HTTPS (for AASA file + landing page)
- Firestore (for round data fetching)

### External (Optional - Post-MVP):
- Branch or AppsFlyer (only if deferred deep linking needed)

### Internal:
- RoundDetailViewModel (existing)
- RoundsRepository (existing, for fetching round by ID)
- AppContainer (existing, for DI)
- Web backend (for landing page - can be static hosting + Firestore)

## Rollout Strategy

### MVP (Week 1):
- Phase 1-3: Universal Links setup + link generation + basic deep linking
- Phase 4: Web landing page (minimal, shows round details)
- Phase 5: In-app round access for non-members
- Works for members sharing with anyone
- No rate limiting (monitor for abuse)

### V1.1 (Week 2-3):
- Polished landing page design
- Better error messages (private rounds, deleted rounds)
- OG meta tag optimization for previews
- Server-side analytics (basic counters)

### V2 (Month 2+):
- Rate limiting
- Rich preview images (dynamic OG images)
- Optional: Branch/AppsFlyer for attribution
- Optional: Link expiry logic

## Security Considerations

### What's Safe:
- ✅ Only public rounds can be shared (enforced by Firestore rules)
- ✅ Authentication required to view any round
- ✅ Host can change round to private (stops new link opens)

### Potential Abuse Vectors:
- ⚠️ Link spam (mitigated by: rate limiting in Phase 6)
- ⚠️ SEO spam (mitigated by: noindex on web landing page)
- ⚠️ Unwanted invites (mitigated by: recipient controls whether to join)

### Privacy:
- ✅ No contact uploading
- ✅ User controls who they share with
- ✅ Links don't expose user data (just roundId)

## Success Metrics

### Track (MVP):
1. **Adoption:** % of rounds that get shared
2. **Distribution:** Where links are shared (add `?source=` query param)
3. **Web traffic:** Unique visitors to `/r/{roundId}` pages
4. **App opens:** Universal Links opened (iOS will track in console)

### Track (Post-MVP with Analytics):
1. **Conversion:** Link opens → round joins
2. **Attribution:** Link opens → app installs (requires Branch/AppsFlyer)

### Goals:
- 20% of rounds get shared within first week
- Web landing page loads successfully (no errors)
- Universal Links work reliably on iOS 14+
- No abuse reports in first month

---

## Questions for PM/Design

1. **Share button placement:** Action row vs. toolbar vs. ... menu?
2. **Share message copy:** Exact wording for "Join my round at {course}!" - can iterate
3. **Non-member UX:** Should they see full details or limited preview?
4. **Landing page priority:** MVP or defer? (Recommended: MVP for professional UX)
5. **Post-install attribution:** Critical for launch, or defer to Phase 9?

## Open Technical Questions

1. **Navigation architecture:** How does RootView handle deep link navigation? (Check existing implementation)
2. **Web hosting:** Next.js, static hosting, or Firebase Hosting for landing pages?
3. **App Store ID:** Use placeholder or wait until app is live?
4. **AASA file:** Who manages web server deployment? (DevOps/backend team)

---

**Estimated Effort:**

### iOS (App):
- Phase 1-3: Universal Links setup + link generation + in-app handling: **2 days**
- Phase 5: Polish non-member access flow: **0.5 days**

### Web (Landing Page):
- Phase 4: Minimal landing page (Next.js or static): **1-2 days**
- AASA file setup + testing: **0.5 days**

### Testing & Refinement:
- Device testing (Universal Links only work on device): **1 day**

**Total: ~5-6 days for production-ready MVP** (iOS + web + testing)

**Note:** No third-party SDK dependencies means faster shipping and less technical debt.
