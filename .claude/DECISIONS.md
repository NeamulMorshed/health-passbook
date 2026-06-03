# Omra — Architecture Decision Records (ADRs)
<!-- Claude: Read this before any Firestore query, rules, or structural architecture change. -->
<!-- If you are about to do something that contradicts an ADR, STOP and flag it to the user. -->
<!-- When a new significant decision is made, append it here in the same format. -->

---

## ADR-001 — Client-Side Sorting Instead of Firestore orderBy
**Date:** 2026-05  
**Status:** Implemented (v2.11.0+34)  
**Decision:** Remove `.orderBy('createdAt', descending: true)` from all Firestore queries; sort the resulting list client-side.  
**Reason:** `.orderBy()` + `.where()` together require a composite Firestore index to be deployed. The missing index caused "Failed to load" errors on the doctor dashboard. Client-side sorting on `<100` items has negligible performance cost and eliminates the index dependency entirely.  
**Affected files:** `lib/services/firestore_service.dart` — `watchDoctorAppointments`, `watchPatientAppointments`  
**Pattern:**
```dart
.snapshots().map((s) {
  final items = s.docs.map(...).whereType<T>().toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return items;
})
```
**Do NOT reintroduce:** Any new `.orderBy()` + `.where()` combination without first deploying the matching index in `firestore.indexes.json`.

---

## ADR-002 — "Family Member" Terminology (Not "Caregiver") in UI
**Date:** 2026-05  
**Status:** Implemented (v2.11.0+33)  
**Decision:** All user-facing strings, labels, button text, and UI copy use "Family Member" (not "Caregiver").  
**Reason:** The app is designed for informal family monitoring, not professional caregiving. "Caregiver" implies a medical professional; it misleads users about the app's scope and purpose.  
**Scope:**
- UI strings, snackbars, headings, labels, tooltips → "Family Member"
- Internal code variables, class names, filenames, route names → may still use `caregiver` (refactor is tracked as a future task, not blocking)
- Firestore field names → may still use `caregiverId`, `caregiverUid` etc. (do not rename without full migration)
**Exceptions:** "Professional Carer" is acceptable for the specific relationship type in invite flows.

---

## ADR-003 — Defensive Stream Pattern (try-catch in fromMap)
**Date:** 2026-05  
**Status:** Implemented (v2.11.0+34)  
**Decision:** Wrap all `Model.fromMap()` calls inside a `try-catch` within `.map()` on Firestore streams. Use `.whereType<Model>()` to filter out nulls after the catch.  
**Reason:** One malformed or type-mismatched Firestore document (e.g., `patientRating` stored as `double` instead of `int`, causing `as int?` cast crash) would crash the entire stream for all documents, not just the bad one.  
**Pattern:**
```dart
.map((snapshot) => snapshot.docs
    .map((doc) {
      try { return Model.fromMap(doc.data(), doc.id); }
      catch (_) { return null; }
    })
    .whereType<Model>()
    .toList())
```
**Apply to:** Any new stream query that deserialises Firestore documents via a `fromMap` factory.  
**Also:** Use `(map['numericField'] as num?)?.toInt()` for all numeric fields (not `as int?`) to handle Firestore storing integers as doubles.

---

## ADR-004 — Firestore Security Rules (Critical Vulnerabilities — RESOLVED)
**Date:** 2026-05 (fixed 2026-05-24)  
**Status:** ✅ Implemented (v2.11.0+35, branch: chore/workflow-claude-setup)  
**Decision:** Fixed all four critical vulnerabilities in `firestore.rules`:
- S-01: `allow list` on appointments/prescriptions/vitals now requires `resource.data.patientId == request.auth.uid || resource.data.doctorId == request.auth.uid` (+ isCaregiverFor for prescriptions/vitals)
- S-02: `users/{uid}` split into `allow create` (unrestricted for owner) + `allow update` (blocks `userType` field via `!affectedKeys().hasAny(['userType'])`)
- S-03: `/patients/{patientId}/medicines` create now requires `doctorHasPatient(patientId)` for doctor writes
- S-04: `/prescriptions` create now requires `doctorHasPatient(request.resource.data.patientId)`
**Note:** `doctorHasPatient()` function was already present in rules — only the call sites needed adding.  
**Remaining:** S-05 (email case-insensitivity, Phase 3), S-07 (O(n) cloud function, Phase 3)

---

## ADR-005 — No dependency_overrides in pubspec.yaml
**Date:** 2026-05  
**Status:** Permanent policy  
**Decision:** Never add `dependency_overrides` to `pubspec.yaml`.  
**Reason:** Previous overrides (google_sign_in_android 6.1.36 pin, manual firebase_auth_platform_interface 7.3.0 patch) caused PigeonUserDetails / PigeonUserInfo type-cast crashes at runtime. The canonical Firebase v3/v5 golden stack resolves all bridge issues at the source. Overrides mask the root cause and create future upgrade debt.  
**Firebase stack pinned to:**
- `firebase_core: ^3.6.0`
- `firebase_auth: ^5.3.1`
- `cloud_firestore: ^5.4.1`
- `firebase_messaging: ^15.1.3`

---

## ADR-006 — Workflow Infrastructure (Claude Code Setup)
**Date:** 2026-05-24  
**Status:** Implemented (v2.11.0+35, branch: chore/workflow-claude-setup)  
**Decision:** Add Claude Code workflow infrastructure files to the project root and `.claude/` directory. These files have zero impact on the Flutter app.  
**Files added:**
- `CLAUDE.md` — auto-loaded project context
- `.claude/UPDATES.md` — session change log
- `.claude/BACKLOG.md` — prioritised task backlog
- `.claude/DESIGN_SYSTEM.md` — visual design reference
- `.claude/PERSONAS.md` — user persona reference
- `.claude/DECISIONS.md` — this file
- `.claude/settings.json` — PostToolUse hook for flutter analyze
- `.claude/skills/omra-ux-review/` — UX review skill
- `.claude/skills/omra-design-check/` — design system checker skill
- `.claude/skills/omra-security-check/` — security pattern checker skill
**Reason:** Eliminates 15,000–22,000 tokens per session on re-orientation; enables self-correcting code verification; provides persistent memory across sessions; enables model-appropriate task routing.

---

## ADR-009 — UX-3 Prescription Confirmation Dialog
**Date:** 2026-05-24
**Status:** ✅ Planned (Opus), ready for Sonnet implementation
**Author:** Opus 4.7 planning session

### Context

Per AUDIT_REPORT.md line 820: "UX-3 Prescription confirmation dialog (review before save) — Prevents dosage errors."

Investigation of [`_PrescribeSheet`](vitalpath_flutter/lib/screens/doctor/patient_view/doc_patient_view_screen.dart#L1334) — the doctor's "Write Prescription" bottom sheet (DraggableScrollableSheet at 85% height):

**Current flow:** Diagnosis → Medicines (name + dosage + frequency dropdown + optional instructions) → Notes → **tap "Save Prescription"** → `_save()` runs immediately:
1. Builds `PrescribedMed` list from controllers (no validation beyond "≥1 named medicine")
2. Calls [`prescriptionNotifierProvider.add()`](vitalpath_flutter/lib/providers/doctor_provider.dart#L156) → writes to `prescriptions/` collection
3. **Mirrors each medicine into `patients/{patientId}/medicines/`** with `reminderTimes: const []` — appears in patient's Care screen as a tracked medicine
4. Pops sheet, shows success snackbar

**The risk:**
- Dr. Rahman types fast on a phone. "5000mg" instead of "500mg" is a 1-keystroke typo with 10× the dose.
- Frequency dropdown defaults to "Once daily" → easy to forget to change.
- No intermediate review. Mistakes commit to Firestore AND to Aisha's Care screen instantly.
- Aisha trusts the system — a wrong dosage propagates silently to her medicine list (reminders included).

**No drug-interaction check on doctor side.** The patient OCR flow ([`scan_prescription_screen.dart`](vitalpath_flutter/lib/screens/patient/care/scan_prescription_screen.dart#L275)) uses `DrugInteractionService` + [`InteractionWarningCard`](vitalpath_flutter/lib/widgets/interaction_warning_card.dart), but `_PrescribeSheet` does not. That's a related concern, tracked as deferred D1 below.

### Decision — single gap: G1 confirmation dialog

**G1 — Preview dialog between "Save" tap and commit**

Insert a confirmation `Dialog` (not `AlertDialog` — needs scroll for 5+ meds) that shows the full prescription as the doctor will have written it. Two actions: **Edit** (back to sheet, no changes) and **Confirm & Save** (commit).

**Dialog content:**
- Header: "Confirm Prescription" + patient name as subtitle
- Diagnosis row (or italic "No diagnosis recorded" if blank)
- Medicines section: each as a card row
  - Bold name (top)
  - Dosage badge (`AppColors.primary` tint) · Frequency badge (`AppColors.info` tint)
  - Instructions (small grey text) if present
- Notes row (if present)
- Consequence callout: "These will be added to **[Patient name]**'s Care screen. Patient can set reminder times."
- Bottom actions: `TextButton('Edit')` left, `GradientButton('Confirm & Save')` right

**Implementation pattern:**
- Refactor current `_save()` → `_commit()` (the actual write path, unchanged behavior)
- Add `_showConfirmation()` — builds the `Prescription`+`PrescribedMed` previews, opens the dialog, awaits user choice
- Wire the existing "Save Prescription" `GradientButton` to `_showConfirmation`
- The dialog is a private widget `_PrescriptionConfirmDialog` (StatefulWidget) in the same file — owns its own loading state during commit, so Confirm button shows a spinner and prevents double-tap
- On commit success: pop dialog first, then sheet (so the parent snackbar still appears in scaffold context)
- On commit error: stay in dialog, show error SnackBar, re-enable Confirm

### Deferred (separate backlog items)

- **D1 — Drug interaction check on doctor side.** Wire `DrugInteractionService` into the confirmation dialog (run when dialog opens, show `InteractionWarningCard` above the actions). Patient side already does this — strong precedent. Track as Phase 3 item "UX-3b". Not in this ADR because: (1) it triples the work, (2) adds async loading state to a critical-path dialog, (3) UX-3 is scoped specifically to confirmation, not interaction prevention.
- **D2 — Per-medicine reminder times at prescribe time.** Currently mirrored with `reminderTimes: const []` — patient must manually set times in Care screen. Could be added but is a workflow-redesign question, not a confirmation-step question.
- **D3 — Edit-specific-field flow.** Just close-and-return-to-sheet — the controllers retain state. Targeted edit (jump to a specific medicine row) is over-scope.
- **D4 — Validation polish.** Empty dosage or empty medicine name beyond the first should be flagged. Current code silently drops empty-name entries. Out of scope for UX-3.

### Acceptance criteria

1. Doctor opens "Write Prescription" sheet, fills 2 medicines, taps "Save Prescription" → confirmation dialog appears with both medicines listed correctly (name + dosage + frequency + instructions if set)
2. Tap "Edit" → dialog closes, sheet remains with all entered values intact, no Firestore write occurred
3. Tap "Confirm & Save" → spinner shows in Confirm button, existing `_commit()` runs, both dialog + sheet pop on success, success snackbar appears, prescription + medicines visible in patient Care screen
4. Save error → dialog stays open, error snackbar appears, Confirm button re-enabled
5. Zero medicines (all rows empty) → still blocks before reaching dialog (existing check at `_save` line 1381)
6. `flutter analyze --no-fatal-infos` clean

### Risks

- **Double-tap on Confirm during slow network:** Owned by the dialog's own `_committing` state flag — Confirm button disabled + spinner shown while `_commit` in flight.
- **Scroll overflow with 5+ meds:** Use `Dialog` + `ConstrainedBox(maxHeight: MediaQuery.sizeOf(context).height * 0.75)` + `SingleChildScrollView` for the medicines list. AlertDialog is too rigid.
- **Context loss after pop:** Snackbar in `_commit` currently uses the sheet's `ScaffoldMessenger.of(context)`. After dialog → sheet pops, that context is gone. Solution: capture `ScaffoldMessenger.of(parentContext)` before popping, use the cached messenger. Pass through dialog's commit callback.
- **Riverpod state during async:** The existing `_saving` flag in `_PrescribeSheetState` is no longer the source of truth — the dialog owns its own `_committing` flag. Remove `_saving` from the sheet's progress UI; the GradientButton just opens the dialog now (instant operation).

### Implementation order (for Sonnet)

1. Read [`doc_patient_view_screen.dart`](vitalpath_flutter/lib/screens/doctor/patient_view/doc_patient_view_screen.dart) lines 1334-1567 to ground the existing widget shape
2. In `_PrescribeSheetState`:
   - Rename current `_save()` → `_commit({required ScaffoldMessengerState messenger})`; keep all the existing write logic (prescription write + medicine mirror)
   - Add `_showConfirmation()` — builds the medicines preview list, captures `ScaffoldMessenger.of(context)` for later, opens the `_PrescriptionConfirmDialog`
   - Wire the `GradientButton` `onPressed` to `_showConfirmation`
   - Remove the `_saving` ternary above the GradientButton (no longer needed since the button just opens a dialog — commit lives in the dialog)
3. Add a new private class `_PrescriptionConfirmDialog extends StatefulWidget` in the same file (placed after `_MedEntry`):
   - Inputs: patientName, diagnosis, List<PrescribedMed>, notes, onConfirm callback (returns Future<void>)
   - State: `bool _committing = false`
   - Layout: `Dialog` → `ConstrainedBox(maxHeight: 0.75 * screenHeight)` → `Padding(24)` → `Column` with header, scrollable content, action row
   - Confirm button: while committing → spinner; on success → `Navigator.pop(true)`; on error → stay open
4. Modify `_showConfirmation` to await dialog result; if `true`, pop the sheet (the dialog already popped itself); the success snackbar fires here via captured messenger
5. Run `flutter analyze` on the touched file
6. Update `.claude/BACKLOG.md` → mark UX-3 [x]
7. Append `.claude/UPDATES.md` entry

---

## ADR-008 — UX-2 Appointment-Confirmation Notification Loop
**Date:** 2026-05-24
**Status:** ✅ Planned (Opus), ready for Sonnet implementation
**Author:** Opus 4.7 planning session

### Context

The audit ([AUDIT_REPORT.md](AUDIT_REPORT.md) line 373) flagged UX-2 as **broken**: "Patient receives NO notification when appointment is confirmed. Only a SnackBar shown to the doctor. This is a broken feedback loop." The backlog item asks for "push notification + in-app badge when appointment is confirmed."

Code audit shows the chain is **already fully wired end-to-end**:

1. **Doctor confirms** → [`DoctorAppointmentNotifier.confirm`](vitalpath_flutter/lib/providers/doctor_provider.dart#L92) → [`firestore_service.confirmAppointment`](vitalpath_flutter/lib/services/firestore_service.dart#L589)
2. **`confirmAppointment` writes 3 things atomically in a WriteBatch** (lines 589-643):
   - Updates appointment status to `confirmed`
   - Creates bidirectional `connections` mirrors
   - **Writes notification doc** to `patients/{patientId}/notifications/{uuid}` with title "Appointment Confirmed", body "Dr. X confirmed your appointment for ...", type `appointment`, `isRead: false`
3. **Cloud Function [`sendPushOnNotification`](vitalpath_flutter/functions/src/index.ts#L28)** triggers on create of that doc, reads patient's FCM token from `users/{patientId}.fcmToken`, sends FCM push with channel `appointment_reminders`, marks `pushSent: true`
4. **Flutter receives**:
   - Foreground: [`onMessage`](vitalpath_flutter/lib/services/notification_service.dart#L72) → shows OS heads-up via `showLocalNotification`
   - Tap: [`_navigateForFcmMessage`](vitalpath_flutter/lib/services/notification_service.dart#L379) → routes via [`_routeForChannel`](vitalpath_flutter/lib/services/notification_service.dart#L371) → `/appointments`
5. **In-app badge**: [`NotifBell`](vitalpath_flutter/lib/core/widgets/notif_bell.dart) shows a red unread dot — present in 8 AppBars (patient home/care/appointments/profile/activity + caregiver home/patients/profile)
6. **Security rules** (firestore.rules:71-77): notification subcollection allows doctor `create` + patient `read/update/delete`

The audit was outdated — the push loop works. The remaining gaps are smaller than the audit suggests.

### Decision — close 3 small gaps

**G1 — NotifBell numeric count (replaces silent dot)**
- **Problem:** Current bell shows only a red dot when `unread > 0`. Aisha can't tell if it's 1 new item or 5. No information density.
- **Fix in [`lib/core/widgets/notif_bell.dart`](vitalpath_flutter/lib/core/widgets/notif_bell.dart):**
  - Replace the 8×8 colored dot (current lines 37-49) with a small red pill showing the count
  - Format: `1`–`9` shown as the number; `≥10` shown as `9+`
  - Pill: `AppColors.destructive` background, white 11px bold text, ~16×16 min size, BorderRadius.circular(8), centered text
  - Hide entirely when count == 0 (same as today)
- **Affects:** All 8 AppBars that already include `NotifBell()` — no per-screen changes needed.

**G2 — Doctor SnackBar acknowledges patient notification**
- **Problem:** [doc_appointments_screen.dart:459](vitalpath_flutter/lib/screens/doctor/appointments/doc_appointments_screen.dart#L459) shows "Appointment confirmed for X" — gives Dr. Rahman no signal that the patient was actually notified. The audit's "feedback loop" complaint partly rests on this.
- **Fix:** Change snackbar text + add icon:
  ```dart
  messenger.showSnackBar(SnackBar(
    content: Row(children: [
      const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text('Confirmed. ${widget.appt.patientName} has been notified.')),
    ]),
  ));
  ```
  Single-location change at line 458-459.

**G3 — Deployment verification (ops, no code)**
- **Problem:** The chain only works in production if the Cloud Function is actually deployed. Phase 1 modified `functions/src/index.ts` (S-06 fix) — that change must be deployed for `sendPushOnNotification` to run with current rules + token paths. We cannot test G1/G2 e2e without deploy.
- **Action:** Run `firebase deploy --only functions:sendPushOnNotification,functions:checkMissedDoses` (deploys both — the S-06 fix and the unchanged-but-needed push function). Idempotent.
- **Not a code task.** Sonnet should flag this to the user as a manual step at end of implementation.

### Deferred (separate backlog items)

- **D1 — Foreground in-app SnackBar** when patient is on /home and an appointment-confirmed FCM arrives. The OS heads-up + bell-count update already covers this; an extra in-app banner would be redundant. Defer until a user reports missing it.
- **D2 — "NEW" tag on the confirmed appointment row.** The status chip already updates from "Pending" (warning) to "Confirmed" (success) via the Firestore stream. Adding a separate "NEW" tag is double-marking.
- **D3 — Reschedule flow.** Audit line 374 — separate Phase 3 backlog item.
- **D4 — Include doctor's notes in push body.** Current body says "for [date]". Including notes is a polish enhancement, not core to UX-2.
- **D5 — Cancel/Complete push.** `updateAppointmentStatus` already writes a cancellation notification doc (lines 663-679). Push delivery for cancellation works via the same `sendPushOnNotification` trigger — no code change needed.

### Acceptance criteria

1. NotifBell shows "1" when patient has 1 unread; "9+" when ≥10; nothing when 0
2. Doctor confirms appointment → SnackBar reads "Confirmed. [Patient name] has been notified." with check-icon prefix
3. `flutter analyze --no-fatal-infos` clean
4. **End-to-end live test** (post-deploy): Sign in as doctor on device A, confirm pending appt; sign in as patient on device B with same patientId → push notification arrives within ~5 sec; tap → app opens to `/appointments`; bell shows "1"

### Risks

- **FCM token null:** Users who haven't opened the app since FCM was added (Bug 2 fix era) have no token in Firestore — they will get no push. Unfixable except by them reopening the app. Bell count still updates via Firestore stream when they next open.
- **Per-channel toggle:** [`NotificationSettings`](vitalpath_flutter/lib/screens/patient/notifications/notification_settings_screen.dart) lets the patient disable `appointment_reminders` channel. The current `onMessage` handler does **not** check `_isChannelEnabled` before calling `showLocalNotification` — meaning an FCM-triggered local notification still fires even if the toggle is off. That's a pre-existing minor bug, not introduced by this work. Flag it but don't fix in scope.
- **Pill width with `9+`:** Need to ensure the 16x16 minimum doesn't truncate. Use `EdgeInsets.symmetric(horizontal: 5)` with `BoxConstraints(minWidth: 16, minHeight: 16)` and text centered.

### Implementation order (for Sonnet)

1. G1 — modify `notif_bell.dart` Stack to render numeric pill
2. G2 — modify SnackBar at `doc_appointments_screen.dart:458-459`
3. `flutter analyze` on both files
4. Update `.claude/BACKLOG.md` — mark UX-2 [x]
5. Append `.claude/UPDATES.md` entry
6. **Tell user**: "Code complete. Run `firebase deploy --only functions` from `vitalpath_flutter/` to activate the push trigger and the S-06 caregiver fix in production. Then do the e2e test in acceptance criterion #4."

---

## ADR-007 — UX-1 Health Profile Onboarding Gap Closure
**Date:** 2026-05-24  
**Status:** ✅ Planned (Opus), ready for Sonnet implementation  
**Author:** Opus 4.7 planning session

### Context

The audit listed UX-1 as "Patient health profile onboarding screen — needs to be built." Investigation found the screens already exist:
- `lib/screens/onboarding/health_profile_screen.dart` — 3-step wizard (Basic Info, Body Metrics, Medical Details)
- `lib/screens/patient/profile/patient_health_profile_screen.dart` — read-only view with Edit button reusing the wizard
- `lib/models/patient.dart` — `PatientProfile` with DOB, weight, height, bloodType, conditions, allergies, emergencyContact, computed `age` + `bmi`

Signup chain is wired and works:
`/user-select` → role pick → `/onboarding/permissions` ([permissions_screen.dart:68](vitalpath_flutter/lib/screens/onboarding/permissions_screen.dart#L68)) → `/onboarding/health-profile` → `markOnboardingComplete()` ([health_profile_screen.dart:165](vitalpath_flutter/lib/screens/onboarding/health_profile_screen.dart#L165)) → `/home`.

Three independent code paths confirm `onboardingComplete` is enforced: splash, login, user_select.

### Decision — close 3 gaps

**G1 — Defensive router safety net (small)**
- **Problem:** Router only redirects AWAY from onboarding routes when complete; doesn't redirect TOWARD onboarding for an incomplete patient who somehow lands on a patient-only route (deeplink, future routing bug).
- **Fix:** In [`lib/app/router.dart`](vitalpath_flutter/lib/app/router.dart) `redirect` callback, after the existing role-based guards, add:
  ```dart
  // Safety net: incomplete patients on patient-only routes → resume onboarding.
  if (isPatient && !user.onboardingComplete &&
      _patientOnlyRoutes.any((r) => loc == r || loc.startsWith('$r/'))) {
    return '/onboarding/health-profile';
  }
  ```
- Place before existing onboarding-route guards (~line 184).

**G2 — Allergies: `String?` → `List<String>` (model change with legacy adapter)**
- **Problem:** Allergies stored as freetext blob; drug-interaction service cannot cross-reference. Aisha types "Penicillin, Peanuts" → system can't warn when doctor prescribes Amoxicillin.
- **Fix in [`lib/models/patient.dart`](vitalpath_flutter/lib/models/patient.dart):**
  - Change field: `final List<String> allergies;` (default `const []`)
  - `fromMap` legacy adapter:
    ```dart
    allergies: _parseAllergies(map['allergies']),
    // ...
    static List<String> _parseAllergies(dynamic raw) {
      if (raw == null) return const [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      if (raw is String && raw.trim().isNotEmpty) {
        return raw.split(RegExp(r'[,;]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      }
      return const [];
    }
    ```
  - `toMap`: write as List directly.
- **Fix in [`lib/screens/onboarding/health_profile_screen.dart`](vitalpath_flutter/lib/screens/onboarding/health_profile_screen.dart):**
  - Replace `_allergiesCtrl` with `final List<String> _selectedAllergies = []` + an `_otherAllergiesCtrl` for free-text.
  - In `_Step3`, render a chip group of common drug allergies above the free-text "Other" field:
    ```dart
    static const _commonAllergies = ['Penicillin', 'Aspirin', 'NSAIDs', 'Sulfa', 'Latex', 'Peanuts', 'Shellfish', 'None'];
    ```
  - Same "None" interlock pattern as conditions (clears others when selected).
  - On `_save`, merge: `_selectedAllergies + (otherAllergies parsed by comma)`.
- **Fix in [`lib/screens/patient/profile/patient_health_profile_screen.dart`](vitalpath_flutter/lib/screens/patient/profile/patient_health_profile_screen.dart):**
  - Change allergies BentoCard from single Text to Wrap of `_Chip`s (mirror the conditions section pattern at lines 161-171).
  - Empty fallback: `_EmptyInfo('No allergies recorded.')`.
- **Verify** no other consumer breaks: grep for `.allergies` after change; update any reads (likely only patient_health_profile_screen, and possibly any insights/drug-interaction code).

**G3 — Emergency contact: add relationship field (polish)**
- **Problem:** `EmergencyContact` model has `relationship` field, form doesn't capture it. Karim shows up unlabelled in Aisha's profile.
- **Fix in [`lib/screens/onboarding/health_profile_screen.dart`](vitalpath_flutter/lib/screens/onboarding/health_profile_screen.dart):**
  - Add `final _ecRelationshipCtrl = TextEditingController();` (or use DropdownButton with `AppConstants.relationships`).
  - In `_Step3`, add field after phone:
    ```dart
    DropdownButtonFormField<String>(
      decoration: InputDecoration(labelText: 'Relationship'),
      items: AppConstants.relationships.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
      onChanged: (v) => /* state update */,
    )
    ```
  - In `_save`, include `relationship: _selectedRelationship ?? ''` when building `EmergencyContact`.
- **Fix in [`lib/screens/patient/profile/patient_health_profile_screen.dart`](vitalpath_flutter/lib/screens/patient/profile/patient_health_profile_screen.dart):**
  - Emergency contact card already calls `emergencyContact!.displayLine` capability is there but not used; the current code displays just name + phone. Update lines 233-241 to also show relationship (e.g., subtitle: "Spouse · +880 1XXX XXXXXX").

### Deferred (separate backlog items, not Phase 2 scope)

- G4 — "Profile incomplete" persistent banner on home (defer; G1 safety net is sufficient defensive coverage)
- G5 — "Other" free-text on conditions chip list (defer; low impact, same pattern as G2 if needed later)

### Acceptance criteria

1. Fresh signup → role pick "Patient" → onboarding chain runs (already works, verify untouched)
2. `flutter analyze` clean after all 3 edits
3. Old patient docs with `allergies: "Penicillin, Peanuts"` render correctly as chip list in profile view (legacy adapter)
4. Emergency contact in profile view shows relationship label when set
5. No Firestore migration required (legacy adapter handles read; new writes use new shape)

### Risks

- **Riverpod cache:** `patientProfileProvider(uid)` might cache an old `PatientProfile` instance. Forcing a `ref.invalidate` on save (already done at line 67-74 of profile screen) handles this.
- **Drug interaction service:** Not changed in this ADR. Will need separate work to actually USE the new allergies list — tracked as a follow-up.
- **Doctor view:** Not changed. Doctor's patient view may render `patient.allergies` somewhere; check before merging.

### Implementation order (for Sonnet)

1. G3 first (smallest, no model change) → verify
2. G2 model + adapter → verify all consumers compile
3. G2 wizard chip UI → verify save works
4. G2 profile view chip rendering → verify display
5. G1 router redirect → verify deeplink behaviour
6. Run `flutter analyze` and `/omra-design-check` on all touched files
7. Update BACKLOG.md to mark UX-1 complete
8. Append UPDATES.md entry

---

## ADR-010 — Permission Lock UX: Actionable "Request Access" (UX-4)
**Date:** 2026-05-24
**Status:** Implemented (v2.11.0+35)

### Problem

`_LockedSection` in `caregiver_patient_profile_screen.dart` showed a lock icon + "{name} hasn't shared this with you yet." text, but no way for Karim (family member) to ask Aisha to grant access. Karim's frustration: "Locked sections are silently hidden with no explanation." The copy was present but not actionable.

### Decision

Extend `_LockedSection` with a "Request access" `OutlinedButton`. On tap, write an `AppNotification` doc to `users/{patientUid}/notifications` so Aisha's existing notif bell badge increments and she can navigate to `ManageCaregiverScreen` to toggle the permission.

### What we chose NOT to do, and why

- **`permission_requests` collection** — adds new Firestore rules, new screen state, new providers. The existing `AppNotification` + `ManageCaregiverScreen` path covers the same need with zero new infra.
- **FCM push** — permission requests are not time-critical. In-app badge is sufficient.
- **Inline "Grant" button on Aisha's notification card** — requires deep-link payload parsing + new UI. Out of scope for v1.
- **24-hour rate-limit** — session-only disable (`_requested` bool) is fine for Karim's persona (1-2× daily usage).
- **Prescriptions locked section** — UX-4 is about lock UX, not adding new caregiver data sections.

### New `NotificationType.permissionRequest` enum entry

Added to `lib/models/app_notification.dart`. `notifications_screen.dart` switch expressions updated to include the new case (lock-open icon, amber color).

### Firestore rule for cross-user notification writes

`allow create: if isSignedIn()` on `users/{userId}/notifications/{notifId}` — already in place, confirmed by grep before implementing. No rules change needed.

### Implementation changes

- `lib/models/app_notification.dart` — added `permissionRequest('permission_request')` enum case + `fromString` arm
- `lib/screens/caregiver/caregiver_patient_profile_screen.dart` — added `app_notification.dart` import; added `_sectionLabel(String)` helper; converted `_LockedSection` from `StatelessWidget` → `StatefulWidget` with `section`, `connectionId`, `patientUid`, `caregiverName` params + `_requested`/`_sending` state + `_requestAccess()` method; updated 4 call sites
- `lib/screens/patient/notifications/notifications_screen.dart` — added `permissionRequest` arms to `_iconWidget` and `_color` switch expressions

### Acceptance criteria

1. Locked section shows lock + message + "Request access" button (amber border)
2. Tap writes `AppNotification` doc to patient's notifications subcollection
3. Button → disabled "Requested ✓" state for the session; snackbar confirms
4. Aisha's notif bell badge increments (existing UX-2 wiring)
5. Notification card in Aisha's notifications screen shows lock-open icon + amber color
6. `flutter analyze --no-fatal-infos` clean (30 pre-existing infos, 0 errors, 0 warnings)

---

## ADR-011 — Caregiver Firestore Permission Enforcement (T-02)
**Date:** 2026-05-24
**Status:** Implemented (v2.11.0+35) — ⚠ rules not active until `firebase deploy --only firestore:rules`

### Problem

UI gates correctly (`if (p.medicines)...else _LockedSection`) but `firestore.rules` only checked `isCaregiverFor(patientId)` — once Karim has ANY active connection, he can bypass the UI and query subcollections directly via the Firestore SDK even when `permissions.medicines = false`.

Side-bug found: `appointments` list rule was missing a caregiver arm entirely (prescriptions and vitals had it), so caregiver appointment queries silently returned 0 results.

### Decision

Add a `caregiverCanRead(patientId, section)` helper to rules that reads the per-section permission from the existing caregiver mirror doc (`patients/{patientId}/caregivers/{caregiverUid}`). Mirror doc extended to carry `permissions` map, synced at two client-side write points.

### New helper

```
function caregiverCanRead(patientId, section) {
  return isCaregiverFor(patientId) &&
    get(/databases/$(database)/documents/patients/$(patientId)/caregivers/$(request.auth.uid))
      .data.get('permissions', {}).get(section, true) == true;
}
```

Defensive default: `.get(section, true)` — missing field returns `true`, preserving access for pre-existing caregiver connections (backward-compat).

### Sync points

1. **`InviteResponseNotifier.accept()`** — mirror doc `set()` now includes `'permissions': permissions.toMap()`; `CaregiverPermissions permissions` added as required param; caller (accept_invite_screen) passes `connection.permissions`.
2. **`ManageCaregiverScreen._save()`** — switched to `WriteBatch`; updates both `caregiver_connections/{id}` AND `patients/{patientId}/caregivers/{caregiverUid}` atomically; guarded with `caregiverUid != null` (pending invite → skip mirror update).

### What was NOT done and why

- ❌ Source-of-truth refactor (permissions only in mirror): would break manage-screen UI that reads from `caregiver_connections`
- ❌ Cloud Function trigger for sync: client-side batch is sufficient and avoids new function deploy
- ❌ One-time backfill of existing mirror docs: defensive default covers it; lazily migrated on next patient save
- ❌ Removing the defensive default: future follow-up once telemetry confirms >99% of mirror docs carry the field

### Affected files

- `vitalpath_flutter/firestore.rules` — `caregiverCanRead()` helper + 7 rule changes (6 swaps + 1 add)
- `lib/providers/caregiver_provider.dart` — `accept()` new param + mirror doc write
- `lib/screens/caregiver/accept_invite_screen.dart` — updated call site
- `lib/screens/patient/care/manage_caregiver_screen.dart` — WriteBatch `_save()`

### Deploy required

`firebase deploy --only firestore:rules` from `vitalpath_flutter/`. Combine with `firebase deploy --only functions` (ADR-008 pending). Rules are dormant until deployed.

---

## ADR-012 — Vitals Trending Charts (UX-8)
**Date:** 2026-05-24  
**Status:** Implemented (v2.11.0+35)  
**Decision:** Shared `VitalTrendChart` widget using `fl_chart` `LineChart`; surfaced on patient vitals screen (trends section + history sheet header) and doctor patient view (new 6th Vitals tab).

### Architecture

- **New file:** `lib/core/widgets/vital_trend_chart.dart` — `VitalTrendChart(patientId, types, height, showAxis)` ConsumerWidget
  - Reads `vitalsProvider(patientId)` (no second provider — reuses existing stream)
  - Filters last 30 days, sorts ascending
  - `<2 points` → "Not enough data" text fallback (no crash)
  - Normal-range band via `ExtraLinesData.horizontalLines` (dashed green lines at `VitalType.normalRange()` bounds)
  - Multi-line legend row rendered when `types.length > 1`
  - Line colours: systolic=`AppColors.destructive`, diastolic=`AppColors.info`, glucose=`AppColors.warning`, pulse=`AppColors.primary`, spo2=`AppColors.success`, temp=`AppColors.caregiver`

- **`watchVitals` limit:** 50 → 200 (fetches enough history for 30-day view)

- **Patient vitals screen (`vitals_screen.dart`):**
  - `_TrendsSection` widget added at top of `_VitalsContent` scroll body (above `_VitalStatusCard`)
  - 3 mini-charts: BP compound (systolic + diastolic, full-width BentoCard), Glucose + Pulse (side-by-side BentoRow)
  - `_VitalHistorySheet` — chart injected after title/unit divider, before reading list; BP history sheet shows compound [systolic, diastolic] lines

- **Doctor patient view (`doc_patient_view_screen.dart`):**
  - `TabController(length: 5)` → `TabController(length: 6)`
  - New 6th Tab: "Vitals" with `HugeIcons.strokeRoundedActivity01` icon
  - New `_VitalsTab` ConsumerWidget: 30-day trend charts (BP full-width with `showAxis: true`, Glucose + Pulse side-by-side) + Latest Readings summary card with status dots
  - New `_VitalRow` StatelessWidget: dot + icon + label + value row

### What was NOT done and why

- ❌ Separate provider for chart data: `vitalsProvider` already fetches 200 readings — filtering in-widget is sufficient
- ❌ SpO₂ and Temperature trend charts: low-frequency readings make trends less useful; can add in Phase 4
- ❌ Tap-to-expand on mini-charts: existing `_showHistorySheet` already provides drilldown; chart in sheet is the expanded view

### Affected files

- `lib/core/widgets/vital_trend_chart.dart` — NEW
- `lib/services/firestore_service.dart` — `watchVitals` limit 50→200
- `lib/screens/patient/vitals/vitals_screen.dart` — import, `_TrendsSection`, chart in `_VitalHistorySheet`
- `lib/screens/doctor/patient_view/doc_patient_view_screen.dart` — imports, TabController length, 6th tab entry, `_VitalsTab`, `_VitalRow`

---

## ADR-013 — Nudge Follow-up Indicator (UX-9)
**Date:** 2026-05-26  
**Status:** Implemented (v2.11.0+35)  
**Decision:** On nudge send, mirror `lastNudgeSentAt` (+ `lastNudgeMessage`) to the caregiver mirror doc. On the caregiver patient profile, compare that timestamp against `loggedDoses` to render a green success callout: "Aisha took her medicine N min after your nudge."

### Why mirror doc, not patient notifications?

Firestore rules only allow the patient to read their own notifications. Caregivers cannot query what they sent. The mirror doc at `patients/{patientId}/caregivers/{caregiverUid}` is already readable by the caregiver (existing rule: `allow read: if isOwner(patientId) || isOwner(caregiverUid)`) and writable by the caregiver (`allow create, update: if isOwner(caregiverUid)`). No rule change required.

### Architecture

1. **`_sendNudge` (WriteBatch):** Two writes in one commit:
   - `users/{patientId}/notifications.set(...)` — existing nudge notification
   - `patients/{patientId}/caregivers/{caregiverUid}.update({'lastNudgeSentAt': serverTimestamp(), 'lastNudgeMessage': message})` — NEW; guarded by `caregiverUid != null` (pending invites have no UID yet)

2. **`caregiverMirrorProvider`** — NEW `StreamProvider.family<Map<String, dynamic>?, _MirrorKey>` in `caregiver_provider.dart`; streams the mirror doc snapshot; returns nullable map.

3. **`_NudgeFollowUp` widget:**
   - Watches `caregiverMirrorProvider` → extracts `lastNudgeSentAt`
   - Watches `medicinesProvider(patientId)` → flattens active medicines' `loggedDoses`
   - Match window: `[nudgeAt, nudgeAt + 2h]`; display expires after 4 hours
   - Renders nothing if no dose matched (positive-only; avoids false-negative shaming)
   - Mounted **above** `_MissedDoseNudge` — positive feedback wins prime real estate

### Window decisions

- **Match window:** 2 h — causal without overreaching
- **Display expiry:** 4 h — stays celebratory while fresh; silently disappears
- **Single field (not subcollection):** Only "latest nudge" matters for the UX-9 question ("did my last nudge work?"); history is Phase 4 scope

### What was NOT done and why

- ❌ Push notification to caregiver when patient takes dose — Cloud Function work, independent ADR
- ❌ Display on family-member home — adds fan-out query; profile is natural surface
- ❌ Filter by nudge message content — permissive: any nudge can prompt medicine adherence
- ❌ Manual dismiss button — callout auto-expires; adding state would persist past context

### Affected files

- `lib/providers/caregiver_provider.dart` — NEW `caregiverMirrorProvider` + `_MirrorKey` typedef
- `lib/screens/caregiver/caregiver_patient_profile_screen.dart` — import `caregiver_provider.dart`; `_sendNudge` → WriteBatch; new `_NudgeFollowUp` widget; mount above `_MissedDoseNudge`
- `firestore.rules` — **No change**

---

## ADR-014 — Doctor "Needs Attention" Dashboard Section (UX-10)
**Date:** 2026-05-26  
**Status:** Implemented (v2.11.0+35)  
**Decision:** One-shot aggregator provider loads medicines + last-7-day vitals for all connected patients in parallel, computes adherence + abnormal vitals, returns a sorted list for the new dashboard section at position #3 (after stats, before quick actions).

### Architecture

- **`PatientAttention` model** (`lib/models/patient_attention.dart`): holds `adherencePct` (nullable — null when no active meds with reminders), `abnormalVitalsCount`, `mostRecentAbnormalLabel`. Single severity tier (amber — no critical/watch split). `needsAttention` = adherence < 50% OR any abnormal vital.

- **`patientsNeedingAttentionProvider`** (`lib/providers/doctor_attention_provider.dart`):  
  `FutureProvider.autoDispose.family<List<PatientAttention>, String>`. Reads `doctorPatientsStreamProvider(...).future`, then `Future.wait` over `_computeAttention` for each patient. Errors per patient are caught and skipped (defensive). `autoDispose` clears on unmount.

- **Two new service methods** (`firestore_service.dart`): `getMedicinesOnce(patientId)` and `getVitalsLastNDays(patientId, {days})`. Use `get()` not `snapshots()` to avoid N concurrent subscriptions. No `.orderBy()` to avoid composite index (ADR-001). Defensive `try/catch` per doc in `.map()`.

- **Dashboard** (`doc_dashboard_screen.dart`):
  - `_NeedsAttentionSection` inserted at position #3, guarded by `patientCount > 0`
  - `RefreshIndicator` wrapping the `ListView`; `onRefresh` calls `ref.invalidate(patientsNeedingAttentionProvider)` + `ref.invalidate(doctorAppointmentsProvider)` for consistency
  - Empty state: green "All patients on track" card (always shown when section is visible — builds doctor habit)
  - `_PatientAttentionTile`: avatar + name + amber pill badges (adherence%, abnormal vital label) + chevron
  - `_Pill` widget: amber border + amber tinted background
  - Max 5 shown; "See all" → `/doc/patients`

### Why one-shot, not streams

Riverpod `StreamProvider.family` would open 2N simultaneous Firestore subscriptions for a doctor with N patients — expensive at >20 patients. One-shot `FutureProvider` fetches at mount and on explicit pull-to-refresh, which matches the "morning check-in" usage pattern for this feature.

### What was NOT done and why

- ❌ Two severity tiers (critical/watch) — user chose amber-only for simplicity
- ❌ Server-side precomputed summaries — Cloud Function approach is better long-term but premature for MVP
- ❌ Real-time updates — one-shot + pull-to-refresh suits usage pattern
- ❌ Push notification when patient flips to "needs attention" — future ADR

### Affected files

- `lib/models/patient_attention.dart` — NEW
- `lib/providers/doctor_attention_provider.dart` — NEW
- `lib/services/firestore_service.dart` — `getMedicinesOnce`, `getVitalsLastNDays`
- `lib/screens/doctor/dashboard/doc_dashboard_screen.dart` — imports, `_NeedsAttentionSection`, `_PatientAttentionTile`, `_Pill`, `RefreshIndicator`
- `firestore.rules` — no change

---

## ADR-015 — Appointment Reminders (UX-11)
**Date:** 2026-05-26  
**Status:** Implemented (v2.11.0+35) — ⚠ not active until `firebase deploy --only functions`  
**Decision:** Two Cloud Functions handle appointment reminders: a scheduled pub/sub that fires every 30 minutes, and a Firestore update trigger that resets idempotency markers when an appointment is rescheduled.

### Architecture

- **`sendAppointmentReminders`** — `functions.pubsub.schedule("every 30 minutes")`
  - Queries `appointments` where `status == "confirmed"` AND `scheduledAt` in next 25h (covers both windows)
  - **Day-before window:** `hoursUntil ∈ [23.5, 24.5)` — body uses "tomorrow" phrasing
  - **Soon window:** `minutesUntil ∈ [0, 30)` — 30-min poll cadence reliably catches the 15-min mark; body uses "in about 15 minutes" phrasing
  - Calls `_writeApptReminder` for qualifying appointments
  - Idempotency: sets `appointments/{id}.reminders.dayBeforeSentAt` / `reminders.soonSentAt` after sending; checks presence before sending
  - **Customization hook (future):** Comment notes where to read `appointmentReminderLeadMinutes` from user doc; hardcoded 30-min window for now

- **`_writeApptReminder`** — shared helper
  - **Patient path:** writes `patients/{patientId}/notifications` doc (type: `"appointment"`) → triggers existing `sendPushOnNotification` pipeline
  - **Doctor path:** direct FCM to `users/{doctorId}.fcmToken` — doctor has no notifications subcollection; uses `appointment_reminders` channel

- **`resetRemindersOnReschedule`** — `functions.firestore.document("appointments/{apptId}").onUpdate`
  - Compares `before.scheduledAt.toMillis()` vs `after.scheduledAt.toMillis()`; if changed, deletes `reminders` field entirely via `FieldValue.delete()`
  - Ensures rescheduled appointments get fresh reminders at the new time

### Window design rationale

30-min polling means a "15-minute before" reminder fires when the appointment is 0–30 min away. The user chose 15 min as the target; the window `[0, 30)` ensures every appointment in that range is caught exactly once (idempotency prevents double-send if two poll cycles overlap the window).

### Required Firestore composite index

`appointments` collection: `(status ASC, scheduledAt ASC)` — needed for the two-field compound query in `sendAppointmentReminders`. Add to `firestore.indexes.json` before deploy.

### What was NOT done and why

- ❌ Per-user configurable lead time — user requested "if possible, make customisable"; deferred: add `appointmentReminderLeadMinutes` to user doc in a future ADR
- ❌ Patient path direct FCM — existing `sendPushOnNotification` trigger handles it; duplicating that logic would risk double-sends
- ❌ `patients/{patientId}/notifications` for doctors — doctors have no such subcollection; direct FCM is cleaner
- ❌ Day-of reminder (1h before) — user approved just two windows (day-before + 15 min); add as Phase 4 item

### Affected files

- `vitalpath_flutter/functions/src/index.ts` — `sendAppointmentReminders`, `resetRemindersOnReschedule`, `_writeApptReminder`, `_ApptReminderPayload`
- `firestore.indexes.json` — composite index `(status, scheduledAt)` required (not created in this ADR — manual step before deploy)
