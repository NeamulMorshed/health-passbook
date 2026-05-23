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

## ADR-004 — Firestore Security Rules (Critical Vulnerabilities — UNRESOLVED)
**Date:** 2026-05  
**Status:** ⚠ NOT YET IMPLEMENTED — Phase 1 Backlog (S-01 through S-04)  
**Decision:** [PENDING] Must fix the following before any public production launch:
- S-01: Replace `allow list: if isSignedIn()` on appointments/prescriptions/vitals with scoped guards
- S-02: Block `userType` field write on user document update
- S-03: Add `doctorHasPatient()` function + enforce on medicine subcollection writes
- S-04: Add `doctorHasPatient()` enforce on prescription collection writes
**See:** `AUDIT_REPORT.md` Section 3.1 for exact rule code to write  
**Note:** A future ADR should be created when the fix is implemented, documenting the exact rule structure chosen.

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
