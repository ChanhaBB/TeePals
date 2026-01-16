# TeePals Web - Firebase Hosting

This directory contains the web infrastructure for TeePals Universal Links.

## Files

### AASA (Apple App Site Association)
- `apple-app-site-association` - Root location (primary)
- `.well-known/apple-app-site-association` - Fallback location

**Configuration:**
- Team ID: `Y6F9X8K3XF`
- Bundle ID: `com.teepals.app`
- Paths: `/r/*` (round invite links)

### Landing Pages
- `index.html` - Home page (teepals.com)
- `round.html` - Round invite page (teepals.com/r/{roundId})
- `404.html` - Not found page

## Firebase Hosting Configuration

Configured in `/firebase.json`:
- Rewrites `/r/**` → `round.html`
- Serves AASA file with correct Content-Type
- Auto-redirects iOS users to app

## Deployment

```bash
# From project root
firebase deploy --only hosting
```

## Testing AASA File

After deployment, verify:
```bash
curl https://teepals.com/apple-app-site-association
curl https://teepals.com/.well-known/apple-app-site-association
```

Both should return the same JSON with appID `Y6F9X8K3XF.com.teepals.app`.

## Universal Link Format

```
https://teepals.com/r/{roundId}?inviter={inviterUid}
```

Example:
```
https://teepals.com/r/abc123?inviter=user456
```
