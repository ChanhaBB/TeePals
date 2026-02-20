# Flow 09: Create Round

**Purpose**: Let users create new golf rounds and invite participants

---

## Overview

Creating a round is the primary action for organizing golf outings. The flow must be:
- Simple enough for quick creation
- Flexible enough for detailed planning
- Clear about what's required vs. optional

---

## User Goals

**Primary**: Quickly set up a golf round and find participants
**Secondary**: Provide enough detail to attract the right golfers

---

## Entry Points

1. **Tap "Host Round"** from Home empty state
2. **Tap "Create"** from Rounds tab (floating action button or header)
3. **Tap "Host Again"** from past round (future feature)

---

## Gating

**Tier 2 Required**: Must have profile photo + skill level
- If incomplete, show ProfileGateView modal
- After completion, return to create flow

---

## Create Round Screen

**Layout**: Full screen, scrollable form

**Navigation**:
- "Cancel" (top left) → Confirm discard if fields filled
- "Create Round" (top right) → Validate and publish

### Section 1: Course Selection

**Field**: "Course"

**Required**: Yes

**UI**: Tappable card that opens course search sheet

**Display**:
- If not selected: "Choose a course" placeholder
- If selected: Course name + city, thumbnail photo

**Course Search Sheet**:
- Search bar (autocomplete via Google Places API)
- Recent courses (user's history)
- Popular courses (if available)
- Results list: Course name, city, distance
- Tap result → Preview course with "Select" button

**Validation**: Must select a valid course

---

### Section 2: Date & Time

**Fields**:
- "Date" (required)
- "Time" (required)

**UI Options**:
1. **Single date/time picker**:
   - Combined wheel picker
   - Default: Tomorrow at 10:00 AM

2. **Flexible scheduling** (future):
   - Allow multiple date/time candidates
   - Participants vote on preferred time

**Current**: Single date/time, wheel picker

**Validation**:
- Must be future date/time
- Cannot be in the past

---

### Section 3: Format

**Field**: "Format" (optional)

**UI**: Segmented control or dropdown

**Options**:
- 9 holes
- 18 holes (default)
- Other (text input)

---

### Section 4: Participants

**Fields**:
- "Max Participants" (required)
- Default: 4
- Range: 2-8 players (including host)

**UI**: Number picker or slider

**Display**: "X of Y spots filled" (starts at 1 of X, host is first)

---

### Section 5: Cost

**Field**: "Cost per Person" (optional)

**UI**: Text input with "$" prefix

**Options**:
- Leave blank = Free
- Enter amount = "$45"

**Note**: "Informational only – payments handled outside app"

---

### Section 6: Additional Details

**Field**: "Notes" (optional)

**UI**: Multi-line text area

**Placeholder**: "Add any details (dress code, equipment, skill level preference...)"

**Max**: 500 characters

**Character counter**: Shows remaining

---

### Preview Section (Optional)

Show a preview of how the round will appear to others

---

## Validation Rules

**Required**:
- Course selected
- Date/time set (future)
- Max participants (2-8)

**Optional**:
- Format (defaults to 18 holes)
- Cost (defaults to Free)
- Notes

**Create Button State**:
- Disabled if required fields missing
- Shows loading during creation

---

## Create Flow

1. User fills required fields
2. Taps "Create Round"
3. Validate all fields
4. If invalid: Show inline errors, stay on screen
5. If valid:
   - Show loading on button
   - Create round document in Firestore
   - Create member document (host = accepted)
   - Navigate to Round Detail screen
   - Show success toast: "Round created!"

---

## Key Components Used

- `AppTextField` – Text inputs
- `AppCard` – Section groupings
- Date/time pickers (native)
- Number picker
- Course search (autocomplete)
- `PrimaryButton` – Create button
- Character counter

---

## States

### Empty (New Round)
- All fields blank with placeholders
- Create button disabled

### Partially Filled
- Some fields completed
- Create button still disabled if required fields missing

### Validation Errors
- Inline errors below fields
- Red border on invalid fields

### Creating
- Loading spinner on Create button
- Prevent multiple submissions

### Success
- Navigate to new Round Detail
- Show success toast

### Error
- Show error banner
- Keep form data
- Allow retry

---

## Edge Cases

### Course Not Found in Search
- Allow user to enter custom course name
- Store as text (no Google Places data)

### Duplicate Round (Same Course, Time)
- No restriction currently
- Future: Warn user

### Max Participants = 2
- Just host + 1 guest
- Valid use case

### Date/Time in Past
- Show validation error
- Cannot create

### User Cancels Mid-Creation
- Show confirmation if fields filled: "Discard round?"
- If no data entered, just go back

### Network Error During Creation
- Show error message
- Keep form data
- Retry button

### Course Search API Quota Exceeded
- Show error
- Allow manual text entry fallback

---

## Interactions

### Select Course
1. Tap "Choose a course"
2. Open course search sheet
3. Type course name
4. See autocomplete results (debounced)
5. Tap result → Preview course
6. Tap "Select" → Close sheet, populate course field

### Set Date/Time
1. Tap date/time field
2. Wheel picker appears
3. Scroll to select
4. Tap outside or "Done" to confirm

### Set Max Participants
1. Tap field
2. Number picker or stepper appears
3. Adjust value (2-8)
4. Confirm

### Add Cost
1. Tap cost field
2. Keyboard appears (numeric)
3. Enter amount
4. Tap outside to dismiss

### Write Notes
1. Tap notes field
2. Keyboard appears
3. Type notes (max 500 chars)
4. See character counter update

### Create Round
1. Tap "Create Round"
2. Validate all fields
3. Show loading
4. Create in Firestore
5. Navigate to Round Detail
6. Show success toast

---

## Current Implementation

### What's Working Well
✅ Round creation functional
✅ Course search via Google Places
✅ Date/time validation
✅ Firestore integration

### What Needs Improvement
- [ ] UI design needs polish
- [ ] No form preview
- [ ] Course search UX could be better
- [ ] No course photos shown during selection
- [ ] No "Save as Draft" option
- [ ] No round templates
- [ ] Cost field could have presets
- [ ] No duplicate round detection
- [ ] Form validation could be clearer
- [ ] No haptic feedback on creation

---

## Open Questions for Designer

1. **Form layout**:
   - Should we use a multi-step wizard (vs. single form)?
   - Should we show progress indicator?
   - Should there be section headers or cards?

2. **Course selection**:
   - Should we show course photos during search?
   - Should we show course ratings/reviews?
   - Should we show a map with course location?
   - Should we allow saving favorite courses?

3. **Date/time**:
   - Should we add "flexible scheduling" (multiple options)?
   - Should we show popular tee times?
   - Should we validate against course tee time availability?

4. **Participants**:
   - Should we allow immediate friend invitations during creation?
   - Should we show skill level filter for auto-matching?
   - Should there be group size suggestions?

5. **Preview**:
   - Should there be a preview screen before publishing?
   - Should we show estimated responses?

6. **Templates**:
   - Should we allow saving round templates?
   - Should there be quick-create options ("Regular Saturday Game")?

---

## Design Assets Needed

1. **Empty states** – No course selected
2. **Course search** – Search results, course cards
3. **Date/time picker** – Custom design vs. native
4. **Form validation** – Error states
5. **Success confirmation** – Round created animation
6. **Loading states** – Creation in progress

---

**Related Flows**:
- Flow 02: Home Dashboard ("Host Round" entry point)
- Flow 03: Rounds Discovery (new round appears in browse)
- Flow 04: Round Detail (navigate here after creation)
- Flow 07: Profile (Tier 2 gating)
