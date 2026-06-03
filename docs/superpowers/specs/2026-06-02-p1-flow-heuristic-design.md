# P1 — Flow & Heuristic Gaps — Design Spec

**Date:** 2026-06-02 · **Branch:** `feature/ux-audit-improvements` · **Tier:** P1 (second of P0→P3)
**Source:** `50 - UX + Design/UX_Audit_2026-06-01.md` · builds on P0 (`2026-06-01-p0-emotion-ui-design.md`)
**App:** Omra (`vitalpath_flutter`), Flutter + Riverpod + GoRouter

## Goal

Close the P1 flow/heuristic gaps: recoverable dose logging (G-2), system-status skeletons on dashboards (Nielsen #1), and above-fold task priority on patient home (G-1). No backend schema changes — reuses existing `loggedDoses` array + pill fields.

> Note: two P1 candidates already shipped in P0 — doctor Today's Schedule (G-4) and patient-home snapshot de-clutter. They are NOT repeated here.

## Scope (3 work items)

1. **Mark-taken undo** (G-2) — deferred-HP undo-after-toast
2. **Skeleton loaders** — replace bare spinners on 3 dashboards (Nielsen #1)
3. **Patient-home light reorder** (G-1) — Tasks #2, Refill #3, Awareness #4

Out of scope: P2 consistency debt (icons/hex), P3 multi-role + needs-attention explainability.

---

## 1. Mark-taken Undo (decision: defer HP until undo window closes)

**Problem:** `MedicineNotifier.logDose` currently does three things atomically — arrayUnion a `DateTime.now()` timestamp into `loggedDoses`, decrement pill count, and award HP/streak/badges (stored, non-reversible). A mis-tap is unrecoverable, and gamification has no reverse method.

**Approach:** Split the action so HP is deferred past a ~4s undo window. The dose log + pill decrement happen immediately (so status updates instantly); HP is awarded only if the user does not undo.

**New flow (per dose tap):**
1. `recordDose(uid, medId, timestamp, {medicine})` — `loggedDoses` arrayUnion(timestamp) + pill decrement. **No HP.**
2. Show `SnackBar('Dose logged · Undo')`, ~4s.
3. `await controller.closed` →
   - `SnackBarClosedReason.action` → `unlogDose(uid, medId, timestamp)` — arrayRemove(timestamp) + pill re-increment. No HP ever awarded.
   - otherwise (timeout/swipe/next) → `awardDoseHp(uid)` → if HP > 0, show existing "+N HP Dose logged!" success toast.

**Family-member path** (caregiver logging for a local member, and the `familyMember != null` branch in `care_screen._logDose`): record/unlog only — **no HP** (HP belongs to the patient's own gamification). Toast: `'Dose logged · Undo'` → undo reverses; no HP step.

### Service layer (`lib/services/firestore_service.dart`)
- `logDose(patientId, medicineId, {DateTime? at})` — use `at ?? DateTime.now()` for the arrayUnion timestamp (so the exact value is known to the caller).
- **NEW** `unlogDose(patientId, medicineId, DateTime at)` — `'loggedDoses': FieldValue.arrayRemove([Timestamp.fromDate(at)])` + `updatedAt`.
- **NEW** `incrementPillCount(patientId, medicineId)` — mirror of existing `decrementPillCount` (FieldValue.increment(1), capped if the existing decrement is capped — match its guard).
- Family equivalents: confirm the family medicine path (`familyMedicinePatchProvider` → its `logDose`) and add matching `unlogDose` there.

### Provider layer (`lib/providers/patient_provider.dart`)
- `MedicineNotifier.recordDose(uid, medId, {Medicine? medicine}) → DateTime` — generates a timestamp, calls `_db.logDose(uid, medId, at: ts)`, decrements pills if `medicine?.pillsRemaining != null`, returns `ts`. No gamification.
- `MedicineNotifier.awardDoseHp(uid) → Future<int>` — wraps `_gamification.awardMedicineDose(uid)` in the existing try/catch (returns 0 on failure).
- `MedicineNotifier.unlogDose(uid, medId, DateTime ts, {Medicine? medicine})` — `_db.unlogDose` + pill re-increment if applicable.
- Keep the existing `logDose(...)` method intact for any caller not adopting undo (backwards-safe), OR migrate all 3 call sites. Migrate all 3 (care_screen, patient home inline, caregiver home) to the record→toast→award/unlog pattern.
- `familyMedicinePatchProvider`: add `unlogDose(uid, memberId, medId, ts)`; its record stays HP-free.

### Call sites
- `lib/screens/patient/care/care_screen.dart` `_MedCardState._logDose` — implement the full record→SnackBar→closed→award/unlog flow. Patient branch awards HP; family branch does not. Keep the existing `_isTaking` guard + `safeHaptic` (from P0).
- `lib/screens/patient/home/home_screen.dart` (inline logDose ~`context`-bearing widget) — same patient flow.
- `lib/screens/caregiver/home/caregiver_home_screen.dart` (logDose ~line 664) — family flow (record + undo, no HP).

A shared helper avoids duplicating the SnackBar/closed dance:
**NEW** `lib/core/widgets/dose_undo.dart` →
```dart
/// Records a dose, shows an Undo snackbar, and either reverses it or awards HP.
/// awardHp == null  → family path (no HP).
Future<void> logDoseWithUndo(
  BuildContext context, {
  required Future<DateTime> Function() record,        // returns logged timestamp
  required Future<void> Function(DateTime ts) undo,   // reverses by timestamp
  Future<int> Function()? awardHp,                    // null = no HP
});
```
The three call sites pass closures wrapping their existing provider calls.

---

## 2. Skeleton Loaders (decision: subtle shimmer matching card layout)

**NEW** `lib/core/widgets/skeleton.dart`:
- `SkeletonBox({width, height, radius})` — a rounded container that pulses opacity between `surfaceSubtle` and `border` via a repeating 1200ms `AnimatedOpacity`/controller. Pulse disabled (static) under `prefersReducedMotion`.
- `DashboardSkeleton()` — composes: a short greeting bar (two `SkeletonBox` lines), a 54-tall hero placeholder, then 2–3 full-width card placeholders. Matches the real dashboard rhythm so the swap is calm.

**Apply to:**
- Patient `home_screen` — `currentUserProvider.loading` Scaffold body → `DashboardSkeleton()` instead of `CircularProgressIndicator`.
- Doctor `doc_dashboard_screen` — outer `userAsync.loading` + inner `apptsAsync.loading` → `DashboardSkeleton()`.
- Caregiver `caregiver_home_screen` — `userAsync.loading` + `membersAsync.loading` → `DashboardSkeleton()`.

Keep small inline spinners (e.g. needs-attention section, dose buttons) as-is — skeletons are for full-screen first loads only.

---

## 3. Patient-Home Light Reorder (decision: light)

In `home_screen.dart` sliver list, reorder existing widgets to (under the P0 hero):
1. Status hero (P0, unchanged — #1)
2. **Upcoming Tasks** (`_UpcomingTasksCard`) — move to #2
3. **Refill countdown** (`_RefillCountdownCard`) — move to #3
4. **Awareness card** (`_DailyAwarenessCard`) — drop to #4
5. Alerts (notif perm / pending invite) → context → adherence ring → family → AI (unchanged tail)

Pure widget reordering in `SliverChildListDelegate` — no logic change. Verify spacing (`SizedBox(height: 12)`) stays consistent.

---

## Architecture & Files

| File | Change |
|------|--------|
| `lib/services/firestore_service.dart` | `logDose` optional `at`; NEW `unlogDose`, `incrementPillCount` (+ family equivalents) |
| `lib/providers/patient_provider.dart` | NEW `recordDose`, `awardDoseHp`, `unlogDose`; family `unlogDose` |
| `lib/core/widgets/dose_undo.dart` | **NEW** — `logDoseWithUndo` helper |
| `lib/core/widgets/skeleton.dart` | **NEW** — `SkeletonBox`, `DashboardSkeleton` |
| `lib/screens/patient/care/care_screen.dart` | `_logDose` → undo flow (patient + family branches) |
| `lib/screens/patient/home/home_screen.dart` | inline logDose → undo flow; reorder sliver list |
| `lib/screens/doctor/dashboard/doc_dashboard_screen.dart` | skeleton on loading states |
| `lib/screens/caregiver/home/caregiver_home_screen.dart` | logDose → undo flow (family); skeleton on loading |
| `test/core/widgets/skeleton_test.dart` | **NEW** — renders both states |

## Data Flow
No schema change. Undo operates on the existing `loggedDoses` timestamp array via arrayUnion/arrayRemove of an exact `Timestamp`. Pill count uses existing increment/decrement fields. HP deferral is purely caller-side timing — gamification service is untouched.

## Error / Edge Handling
- Record fails → show error toast, no SnackBar/undo offered.
- Undo's arrayRemove must match the exact `Timestamp` recorded — caller holds the `DateTime`; pass it through unchanged (no re-`now()`).
- If the user logs a second dose before the first undo window closes, each gets its own timestamp + its own SnackBar/closed lifecycle (independent).
- `context.mounted` guarded before every post-`await` SnackBar/award.
- Reduced motion → skeleton static, undo unaffected.

## Testing
- `skeleton_test.dart`: `SkeletonBox` renders at given size; `DashboardSkeleton` builds without overflow in a constrained box; static under reduced motion.
- Undo: manual smoke (stream + SnackBar lifecycle not unit-friendly) — verify log→undo removes the dose and no HP toast; log→wait awards HP. `flutter analyze` 0 errors/0 warnings.

## Non-Goals
No gamification reverse method. No confirm-before dialog. No full home re-rank. No icon/hex migration (P2). No multi-role (P3).
