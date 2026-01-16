# Geo Search Plan (Firestore + GeoHash) — Clean, Future‑Proof, Bug‑Resistant

This doc is written for Cursor to implement a correct and scalable geo-radius search on top of Firestore.

## Goals

1. **Correctness:** If `X` rounds are within radius `R` of a center point, results must include **all X** (subject to server limits you define explicitly).
2. **Deterministic behavior:** Same inputs ⇒ same outputs (modulo new data).
3. **Performance + cost control:** Bounded reads via **date windows**, precision selection, and per-bound limits.
4. **Future-proof:** Clean abstraction so we can swap Firestore geo implementation later (Algolia/PostGIS/etc.) without rewriting UI.
5. **Bug-resistant:** Centralized geo utilities, consistent indexing strategy, robust dedupe + pagination.

---

## Non-Goals (for now)

- Real-time moving targets (Uber-style). Rounds are static and can tolerate multi-query aggregation.
- Perfect global search with no read bounds. We will intentionally bound candidate sets.

---

## Definitions

- **Center**: `(centerLat, centerLng)` — default derived from user profile city location; user can override via filters.
- **Radius**: `radiusMiles` — user-configurable.
- **Date Window**: `[startTimeMin, startTimeMax)` — required to bound results (e.g., Next 7 days / Next 30 days).
- **Candidate Set**: Documents returned by geohash range queries before exact distance filtering.
- **Exact Match**: Candidate that satisfies `distance(center, round.location) <= radiusMiles`.

---

## Architecture (Must Follow)

### 1) Public Interface

Create an interface (protocol) so UI never knows implementation details:

- `RoundsSearchService`
  - `searchRounds(filter: RoundsSearchFilter, page: PageCursor?) async throws -> RoundsSearchPage`

Where:
- `RoundsSearchFilter` contains:
  - `centerLat`, `centerLng`
  - `radiusMiles`
  - `startTimeMin`, `startTimeMax`
  - optional: `visibility`, `status`, `skillLevel`, etc. (add later)
- `RoundsSearchPage` contains:
  - `items: [Round]`
  - `nextPageCursor: PageCursor?`
  - `debug: SearchDebugInfo` (optional, dev builds)

### 2) Implementation v1

- `FirestoreGeoHashRoundsSearchService : RoundsSearchService`

### 3) Shared Utilities

- `GeoHashUtil` (encode, neighbors, bounds for radius)
- `DistanceUtil` (haversine distance)
- `GeoPrecisionPolicy` (choose geohash length based on radius + density assumptions)

---

## Firestore Data Model

### Rounds collection
`rounds/{roundId}`

Required fields:
- `startTime: Timestamp` (round scheduled time)
- `createdAt: Timestamp`
- `geo.lat: Double`
- `geo.lng: Double`
- `geo.geohash: String`  **(required for geo search)**
- `cityKey: String` (optional but still useful for UX filtering/analytics)

Recommended fields:
- `status: String` (e.g., open/canceled/closed)
- `visibility: String` (public/friendsOnly)
- `hostUid: String`

**Important:** `geo.geohash` must always correspond to `geo.lat/lng`.

---

## Write Path Rules (Prevent Bugs)

Whenever a Round is created or its location changes:

1. Validate `lat in [-90, 90]`, `lng in [-180, 180]`
2. Compute `geohash = GeoHashUtil.encode(lat, lng, precision)`
3. Persist all 3 fields atomically (`lat`, `lng`, `geohash`)

### Precision at write time
Choose a **fixed write precision** that supports your smallest radius well (recommended: 9).
- Store `geo.geohash` at precision **9**
- Query can use prefix slicing (start/end bounds) at shorter precision if needed.

---

## Query Plan (How Radius Search Works)

Firestore cannot do native “distance <= R”. We do:

1) Compute geohash ranges that cover the circle (approx)  
2) Query Firestore for each range  
3) Merge + dedupe  
4) Filter exact distance client-side  
5) Apply date window (server-side where possible, otherwise client-side)  
6) Sort and paginate deterministically  

### 1) Choose precision for the query
Select a geohash prefix length `p` based on radius:

| Radius (miles) | Query Prefix Length (p) |
|---:|---:|
| 0–2 | 9 |
| 2–5 | 8 |
| 5–15 | 7 |
| 15–50 | 6 |
| 50–120 | 5 |
| 120+ | 4 |

(Adjust after measuring density.)

### 2) Compute bounds
Use a GeoFire-style algorithm that returns a set of `[start, end]` bounds for prefix length `p`.

- `bounds = GeoHashUtil.queryBounds(center, radiusMeters, precision=p)`

Each bound is lexicographic inclusive start/end for the chosen prefix length.

### 3) Firestore query per bound
For each bound:
- `orderBy("geo.geohash")`
- `startAt(bound.start)`
- `endAt(bound.end)`
- `limit(perBoundLimit)`

#### Date window filtering (recommended MVP approach)
Firestore doesn’t combine multiple inequality filters gracefully across fields. For robustness:

- **Server filter:** geohash bounds
- **Client filter:** `startTime in [min, max)` AND `distance <= radius`

To keep reads bounded, enforce:
- date window required (e.g., <= 30 days)
- perBoundLimit + overall max candidates

### 4) Merge + dedupe
Bounds overlap. Deduplicate by document id:
- `Map<roundId, Round>`

### 5) Exact filters
Apply:
- `distance(center, round.geo) <= radiusMiles`
- `startTimeMin <= round.startTime < startTimeMax`
- optional status/visibility filters

### 6) Sorting
Sort deterministically:
1. `startTime` ascending
2. tiebreaker: `roundId` lexicographically

### 7) Pagination
For MVP (bounded windows), keep it simple:

- Page by `{lastStartTime, lastRoundId}`
- Re-run the same search and skip until cursor (in-memory skip)
- Return next `pageSize`

Later optimization: per-bound cursors + k-way merge.

---

## Bounding Reads (Cost Safety)

To prevent runaway reads in dense metros:

- Enforce date range max (e.g., <= 30 days)
- Enforce max radius (e.g., <= 100 miles) unless “Anywhere”
- Add hard caps:
  - `perBoundLimit` (e.g., 200)
  - `maxCandidatesTotal` (e.g., 2000)
If cap is hit:
- set `isTruncated = true`
- UI can suggest narrowing filters

---

## Indexing

Minimum:
- Firestore single-field index on `geo.geohash` exists by default.

If you add server-side equality filters later (status/visibility), Firestore may request composite indexes.

---

## Migration / Backfill Plan

If rounds already exist without geohash:

1. One-time job/script:
   - scan rounds missing `geo.geohash`
   - compute from existing lat/lng
   - write back

2. Validate:
   - No docs missing geohash
   - Spot-check a random sample

---

## Filter UX Rules

Default:
- center = user profile city location
- radius = 25 or 50 miles
- date window = Next 30 days (or Next 7 days)

Overrides:
- city selection changes center
- radius changes query precision + bounds
- date window bounds candidates

“Anywhere” mode:
- Optionally skip geohash and query by date globally (explicit product mode).

---

## Testing Plan (Must Have)

### Unit tests (pure Swift)
- `GeoHashUtil.encode` deterministic for known points
- `queryBounds` returns bounds and is stable
- `DistanceUtil.haversine` validated with known distances

### Correctness test (core requirement)
Seed rounds:
- inside radius
- outside radius
- across “city boundaries” but within radius
Assert:
- returns all inside, none outside (within date window)

### Regression edge cases
- near geohash cell borders
- high latitude
- lng near ±180 (at least handle safely)

### Pagination test
- stable ordering
- no duplicates across pages

---

## Common Footguns (Avoid)

1. **No dedupe across bounds** ⇒ duplicates.
2. **No read bounds** ⇒ high cost.
3. **Varying geohash precision in storage** ⇒ inconsistent range queries.
4. **Not recomputing geohash on location updates** ⇒ silent incorrect search.
5. **Combining multiple inequality filters across different fields** ⇒ query failures.

---

## Cursor Implementation Checklist

- [ ] Add `geo.geohash` to Round model + Firestore mapping
- [ ] Add `GeoHashUtil`, `DistanceUtil`, `GeoPrecisionPolicy`
- [ ] Add `RoundsSearchService` protocol
- [ ] Implement `FirestoreGeoHashRoundsSearchService`
- [ ] Implement merge + dedupe + exact distance + date window filtering
- [ ] Add safety caps (`perBoundLimit`, `maxCandidatesTotal`)
- [ ] Implement backfill job/script
- [ ] Add unit tests + seeded correctness tests
- [ ] Wire Rounds tab to use search service with default filter
- [ ] Filter UI updates filter and triggers new search

---

## Recommended Defaults

- `defaultRadiusMiles = 25` (or 50)
- `defaultDateWindowDays = 30`
- `pageSize = 30`
- `perBoundLimit = 200`
- `maxCandidatesTotal = 2000`

---

## Final Product Contract

Given `{center, radius, dateWindow}`, the service must:
- Return **all rounds** within distance and date window **unless** `maxCandidatesTotal` truncation occurs.
- If truncated, set a flag so UI can encourage narrowing filters.
