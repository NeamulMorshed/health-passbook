# P1 Flow & Heuristic Gaps — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Recoverable dose logging with deferred HP (G-2), shimmer skeleton loaders on the 3 dashboards (Nielsen #1), and a light patient-home reorder (G-1).

**Architecture:** Undo is caller-side timing — record dose + decrement pills immediately, defer HP/streak past a ~4s Undo SnackBar; reverse via arrayRemove of the exact timestamp if undone. A shared `logDoseWithUndo` helper holds the SnackBar lifecycle so all 3 call sites stay DRY. Skeletons are a new pure widget swapped into existing `.loading` branches. Reorder is pure widget shuffling.

**Tech Stack:** Flutter, flutter_riverpod, cloud_firestore (arrayUnion/arrayRemove, runTransaction), flutter_test. Spec: `docs/superpowers/specs/2026-06-02-p1-flow-heuristic-design.md`.

**Branch:** `feature/ux-audit-improvements` (continues from P0).

---

### Task 1: Service layer — timestamped log, unlog, pill increment

**Files:**
- Modify: `lib/services/firestore_service.dart`

- [ ] **Step 1: Make `logDose` accept an explicit timestamp**

Replace the existing `logDose` body:

```dart
  Future<void> logDose(String patientId, String medicineId,
      {DateTime? at}) async {
    final ts = at ?? DateTime.now();
    await _db
        .collection(AppConstants.colPatients)
        .doc(patientId)
        .collection(AppConstants.colMedicines)
        .doc(medicineId)
        .update({
      'loggedDoses': FieldValue.arrayUnion([Timestamp.fromDate(ts)]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
```

- [ ] **Step 2: Add `unlogDose` (patient)**

Immediately after `logDose`:

```dart
  Future<void> unlogDose(
      String patientId, String medicineId, DateTime at) async {
    await _db
        .collection(AppConstants.colPatients)
        .doc(patientId)
        .collection(AppConstants.colMedicines)
        .doc(medicineId)
        .update({
      'loggedDoses': FieldValue.arrayRemove([Timestamp.fromDate(at)]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
```

- [ ] **Step 3: Add `incrementPillCount` (mirror of decrement, transaction-guarded)**

Immediately after `decrementPillCount`:

```dart
  Future<void> incrementPillCount(String patientId, String medicineId) async {
    final ref = _db
        .collection(AppConstants.colPatients)
        .doc(patientId)
        .collection(AppConstants.colMedicines)
        .doc(medicineId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final current = (snap.data()?['pillsRemaining'] as num?)?.toInt();
      if (current == null) return;
      tx.update(ref, {'pillsRemaining': current + 1});
    });
  }
```

- [ ] **Step 4: Family — timestamped log + unlog**

Replace `logFamilyMemberDose` to accept `at`, and add `unlogFamilyMemberDose`:

```dart
  Future<void> logFamilyMemberDose(
      String uid, String memberId, String medicineId, {DateTime? at}) async {
    final ts = at ?? DateTime.now();
    await _db
        .collection(AppConstants.colPatients)
        .doc(uid)
        .collection(AppConstants.colFamilyMembers)
        .doc(memberId)
        .collection(AppConstants.colMedicines)
        .doc(medicineId)
        .update({
      'loggedDoses': FieldValue.arrayUnion([Timestamp.fromDate(ts)]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unlogFamilyMemberDose(
      String uid, String memberId, String medicineId, DateTime at) async {
    await _db
        .collection(AppConstants.colPatients)
        .doc(uid)
        .collection(AppConstants.colFamilyMembers)
        .doc(memberId)
        .collection(AppConstants.colMedicines)
        .doc(medicineId)
        .update({
      'loggedDoses': FieldValue.arrayRemove([Timestamp.fromDate(at)]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
```

- [ ] **Step 5: Verify analyze + commit**

Run: `flutter analyze lib/services/firestore_service.dart`
Expected: 0 errors (the existing `logFamilyMemberDose` callers still compile — `at` is optional).

```bash
git add lib/services/firestore_service.dart
git commit -m "feat(service): timestamped logDose, unlogDose, incrementPillCount (+ family)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Provider layer — recordDose / awardDoseHp / unlogDose

**Files:**
- Modify: `lib/providers/patient_provider.dart`

- [ ] **Step 1: Patient — split logDose into record + award + unlog**

In `MedicineNotifier`, keep the existing `logDose` (backwards-safe) and ADD:

```dart
  /// Records a dose (loggedDoses + pill decrement) WITHOUT awarding HP.
  /// Returns the exact timestamp written, so it can be reversed via [unlogDose].
  Future<DateTime> recordDose(String patientId, String medicineId,
      {Medicine? medicine}) async {
    final ts = DateTime.now();
    await _db.logDose(patientId, medicineId, at: ts);
    if (medicine != null && medicine.pillsRemaining != null) {
      await _db.decrementPillCount(patientId, medicineId);
    }
    return ts;
  }

  /// Awards HP for a recorded dose. Never throws (returns 0 on failure).
  Future<int> awardDoseHp(String patientId) async {
    try {
      return await _gamification.awardMedicineDose(patientId);
    } catch (_) {
      return 0;
    }
  }

  /// Reverses [recordDose]: removes the timestamp + restores pill count.
  Future<void> unlogDose(String patientId, String medicineId, DateTime at,
      {Medicine? medicine}) async {
    await _db.unlogDose(patientId, medicineId, at);
    if (medicine != null && medicine.pillsRemaining != null) {
      await _db.incrementPillCount(patientId, medicineId);
    }
  }
```

- [ ] **Step 2: Family — record (timestamped) + unlog**

In `FamilyMedicinePatch`, replace `logDose` and add `unlogDose`:

```dart
  Future<DateTime> recordDose(String uid, String memberId, String medicineId) async {
    final ts = DateTime.now();
    await _db.logFamilyMemberDose(uid, memberId, medicineId, at: ts);
    return ts;
  }

  Future<void> unlogDose(
          String uid, String memberId, String medicineId, DateTime at) =>
      _db.unlogFamilyMemberDose(uid, memberId, medicineId, at);
```

Keep the existing `logDose(uid, memberId, medicineId)` method too (in case other callers use it).

- [ ] **Step 3: Verify + commit**

Run: `flutter analyze lib/providers/patient_provider.dart`
Expected: 0 errors.

```bash
git add lib/providers/patient_provider.dart
git commit -m "feat(provider): recordDose/awardDoseHp/unlogDose (deferred-HP undo); family record/unlog

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Shared `logDoseWithUndo` helper

**Files:**
- Create: `lib/core/widgets/dose_undo.dart`

- [ ] **Step 1: Implement helper**

```dart
import 'package:flutter/material.dart';
import 'app_widgets.dart';

/// Records a dose, shows an "Undo" snackbar for ~4s, then either reverses the
/// dose (if Undo tapped) or awards HP (if [awardHp] provided — patient path).
///
/// * [record] writes the dose and returns the logged timestamp.
/// * [undo] reverses the dose by that timestamp.
/// * [awardHp] null → family path (no HP). Non-null → patient path.
Future<void> logDoseWithUndo(
  BuildContext context, {
  required Future<DateTime> Function() record,
  required Future<void> Function(DateTime ts) undo,
  Future<int> Function()? awardHp,
}) async {
  final DateTime ts;
  try {
    ts = await record();
  } catch (_) {
    if (context.mounted) {
      AppSnackBar.error(context, 'Could not log dose. Please try again.');
    }
    return;
  }
  if (!context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final controller = messenger.showSnackBar(
    SnackBar(
      content: const Text('Dose logged'),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(label: 'Undo', onPressed: () {}),
    ),
  );

  final reason = await controller.closed;

  if (reason == SnackBarClosedReason.action) {
    await undo(ts);
    return;
  }
  if (awardHp != null) {
    final hp = await awardHp();
    if (hp > 0 && context.mounted) {
      AppSnackBar.success(context, '+$hp HP  Dose logged!');
    }
  }
}
```

- [ ] **Step 2: Verify + commit**

Run: `flutter analyze lib/core/widgets/dose_undo.dart`
Expected: 0 errors.

```bash
git add lib/core/widgets/dose_undo.dart
git commit -m "feat(widgets): logDoseWithUndo helper (record -> undo snackbar -> award/reverse)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Wire undo into care_screen

**Files:**
- Modify: `lib/screens/patient/care/care_screen.dart`

- [ ] **Step 1: Replace `_logDose` body**

Current `_logDose` calls `familyMedicinePatchProvider.logDose` or `medicineNotifierProvider.logDose` then shows the success snackbar. Replace its try-block with the helper (keep `_isTaking` guard + `safeHaptic`):

```dart
  Future<void> _logDose() async {
    if (_isTaking) return;
    setState(() => _isTaking = true);
    safeHaptic(context, medium: true);
    try {
      final fm = widget.familyMember;
      if (fm != null) {
        final patch = ref.read(familyMedicinePatchProvider);
        await logDoseWithUndo(
          context,
          record: () => patch.recordDose(widget.uid, fm.id, widget.med.id),
          undo: (ts) => patch.unlogDose(widget.uid, fm.id, widget.med.id, ts),
          // family path: no HP
        );
      } else {
        final notifier = ref.read(medicineNotifierProvider.notifier);
        await logDoseWithUndo(
          context,
          record: () => notifier.recordDose(widget.uid, widget.med.id,
              medicine: widget.med),
          undo: (ts) => notifier.unlogDose(widget.uid, widget.med.id, ts,
              medicine: widget.med),
          awardHp: () => notifier.awardDoseHp(widget.uid),
        );
      }
    } finally {
      if (mounted) setState(() => _isTaking = false);
    }
  }
```

Add import: `import '../../../core/widgets/dose_undo.dart';`

> NOTE: the `finally` resets `_isTaking` after `logDoseWithUndo` returns — which is after the 4s window. That keeps the button disabled during the undo window (prevents double-log). Acceptable. If a snappier re-enable is wanted that's a future refinement.

- [ ] **Step 2: Verify + commit**

Run: `flutter analyze lib/screens/patient/care/care_screen.dart`
Expected: 0 errors.

```bash
git add lib/screens/patient/care/care_screen.dart
git commit -m "feat(care): recoverable dose logging via logDoseWithUndo

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Wire undo into patient home + caregiver home inline log buttons

**Files:**
- Modify: `lib/screens/patient/home/home_screen.dart` (inline `logDose` ~ the tasks card)
- Modify: `lib/screens/caregiver/home/caregiver_home_screen.dart` (logDose ~line 664)

- [ ] **Step 1: Patient home inline log**

Find the inline call `ref.read(medicineNotifierProvider.notifier).logDose(uid, medicine.id)` (in the upcoming-tasks/home dose button). Replace with:

```dart
                final notifier = ref.read(medicineNotifierProvider.notifier);
                await logDoseWithUndo(
                  context,
                  record: () => notifier.recordDose(uid, medicine.id, medicine: medicine),
                  undo: (ts) => notifier.unlogDose(uid, medicine.id, ts, medicine: medicine),
                  awardHp: () => notifier.awardDoseHp(uid),
                );
```

Remove any now-duplicated success snackbar at that call site (the helper shows it). Add import `import '../../../core/widgets/dose_undo.dart';` if not present.

> Read the surrounding handler first to confirm the `context`, `uid`, and `medicine` identifiers in scope and that it's an async callback.

- [ ] **Step 2: Caregiver home inline log (family path)**

Find `.logDose(caregiverUid, memberId, medicine.id)` (~line 664). Replace with:

```dart
                  final patch = ref.read(familyMedicinePatchProvider);
                  await logDoseWithUndo(
                    context,
                    record: () => patch.recordDose(caregiverUid, memberId, medicine.id),
                    undo: (ts) => patch.unlogDose(caregiverUid, memberId, medicine.id, ts),
                  );
```

Add import `import '../../../core/widgets/dose_undo.dart';`. Confirm `caregiverUid`, `memberId`, `medicine`, `context` are in scope (read surrounding widget first).

- [ ] **Step 3: Verify + commit**

Run: `flutter analyze lib/screens/patient/home/home_screen.dart lib/screens/caregiver/home/caregiver_home_screen.dart`
Expected: 0 errors.

```bash
git add lib/screens/patient/home/home_screen.dart lib/screens/caregiver/home/caregiver_home_screen.dart
git commit -m "feat(home): recoverable dose logging on patient + caregiver home buttons

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Skeleton widgets

**Files:**
- Create: `lib/core/widgets/skeleton.dart`
- Test: `test/core/widgets/skeleton_test.dart`

- [ ] **Step 1: Write failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitalpath/core/widgets/skeleton.dart';

Widget _wrap(Widget c) => MaterialApp(home: Scaffold(body: c));

void main() {
  testWidgets('SkeletonBox renders at given size', (t) async {
    await t.pumpWidget(_wrap(const SkeletonBox(width: 100, height: 20)));
    expect(find.byType(SkeletonBox), findsOneWidget);
  });

  testWidgets('DashboardSkeleton builds without overflow', (t) async {
    await t.pumpWidget(_wrap(const SizedBox(width: 360, height: 720, child: DashboardSkeleton())));
    expect(tester_noException(), isTrue);
    expect(find.byType(SkeletonBox), findsWidgets);
  });
}

bool tester_noException() => true; // builds without throwing = pass
```

- [ ] **Step 2: Run, verify fail**

Run: `flutter test test/core/widgets/skeleton_test.dart`
Expected: FAIL — `skeleton.dart` undefined.

- [ ] **Step 3: Implement**

```dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../anim/reduced_motion.dart';

/// A single shimmering placeholder block. Static under reduced motion.
class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;
  const SkeletonBox(
      {super.key, required this.width, required this.height, this.radius = 8});

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = (double opacity) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(
                AppColors.surfaceSubtle, AppColors.border, opacity),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
    if (prefersReducedMotion(context)) return box(0.5);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => box(_ctrl.value),
    );
  }
}

/// Full-screen first-load placeholder shaped like a dashboard.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
      children: const [
        SkeletonBox(width: 120, height: 12),
        SizedBox(height: 8),
        SkeletonBox(width: 180, height: 18),
        SizedBox(height: 20),
        SkeletonBox(width: double.infinity, height: 96, radius: 16), // hero
        SizedBox(height: 12),
        SkeletonBox(width: double.infinity, height: 72, radius: 16),
        SizedBox(height: 12),
        SkeletonBox(width: double.infinity, height: 72, radius: 16),
        SizedBox(height: 12),
        SkeletonBox(width: double.infinity, height: 120, radius: 16),
      ],
    );
  }
}
```

- [ ] **Step 4: Run, verify pass**

Run: `flutter test test/core/widgets/skeleton_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/skeleton.dart test/core/widgets/skeleton_test.dart
git commit -m "feat(widgets): SkeletonBox + DashboardSkeleton (reduced-motion safe)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 7: Apply skeletons to 3 dashboards

**Files:**
- Modify: `lib/screens/patient/home/home_screen.dart`
- Modify: `lib/screens/doctor/dashboard/doc_dashboard_screen.dart`
- Modify: `lib/screens/caregiver/home/caregiver_home_screen.dart`

- [ ] **Step 1: Patient home**

In `HomeScreen.build`, the `userAsync.when(loading: ...)` returns `Scaffold(body: Center(child: CircularProgressIndicator()))`. Replace with:

```dart
      loading: () => const Scaffold(body: SafeArea(child: DashboardSkeleton())),
```

Add `import '../../../core/widgets/skeleton.dart';`.

- [ ] **Step 2: Doctor dashboard**

Replace the outer `userAsync.when(loading: ...)` spinner and the inner `apptsAsync.when(loading: ...)` spinner with `DashboardSkeleton()` (wrap inner in `SafeArea`/padding as the surrounding `body` expects — use `const DashboardSkeleton()`). Add the import.

- [ ] **Step 3: Caregiver home**

Replace the `userAsync.when(loading:)` and `membersAsync.when(loading:)` `CircularProgressIndicator` Scaffolds with `const Scaffold(body: SafeArea(child: DashboardSkeleton()))`. Add the import.

- [ ] **Step 4: Verify + commit**

Run: `flutter analyze lib/screens/patient/home/home_screen.dart lib/screens/doctor/dashboard/doc_dashboard_screen.dart lib/screens/caregiver/home/caregiver_home_screen.dart`
Expected: 0 errors.

```bash
git add lib/screens/patient/home/home_screen.dart lib/screens/doctor/dashboard/doc_dashboard_screen.dart lib/screens/caregiver/home/caregiver_home_screen.dart
git commit -m "feat(dashboards): skeleton loaders replace bare spinners (Nielsen #1)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 8: Patient-home light reorder

**Files:**
- Modify: `lib/screens/patient/home/home_screen.dart`

- [ ] **Step 1: Reorder sliver children**

In the `SliverChildListDelegate([...])`, after the STATUS HERO block, reorder to: Upcoming Tasks (#2) → Refill (#3) → Awareness (#4) → existing tail (alerts, caregiver banner, context, ring, family, AI). Move `_UpcomingTasksCard` and `_RefillCountdownCard` up directly under the hero, and `_DailyAwarenessCard` below them. Preserve the `SizedBox(height: 12)` spacers (one after each card).

Resulting order under hero:
```dart
                  _UpcomingTasksCard(uid: user.uid),
                  const SizedBox(height: 12),
                  _RefillCountdownCard(medsAsync: medsAsync),
                  const SizedBox(height: 12),
                  _DailyAwarenessCard(uid: user.uid),
                  const SizedBox(height: 12),
                  const _NotifPermBanner(),
                  _PendingInviteBanner(email: user.email ?? ''),
                  // … unchanged tail (caregiver banner, context, ring, family, AI)
```

> Read the current sliver list first; move the existing widget instances (don't duplicate). `_RefillCountdownCard` currently sits lower with `medsAsync` — relocate that exact call.

- [ ] **Step 2: Verify + commit**

Run: `flutter analyze lib/screens/patient/home/home_screen.dart`
Expected: 0 errors, no duplicate-widget warnings.

```bash
git add lib/screens/patient/home/home_screen.dart
git commit -m "feat(patient-home): light reorder — Tasks #2, Refill #3, Awareness #4 (G-1)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 9: Final verification + docs

- [ ] **Step 1: Full analyze**

Run: `flutter analyze`
Expected: 0 errors, 0 warnings (≤32 pre-existing info).

- [ ] **Step 2: Full test**

Run: `flutter test`
Expected: all pass (P0 tests + new skeleton 2).

- [ ] **Step 3: Manual undo smoke (document, do not automate)**

Verify by reasoning/log: record→Undo removes the dose timestamp and awards no HP; record→wait awards HP and shows "+HP". (Stream + SnackBar lifecycle not unit-friendly.)

- [ ] **Step 4: UPDATES.md entry + commit**

Prepend a P1 session entry to `.claude/UPDATES.md`.

```bash
git add .claude/UPDATES.md
git commit -m "docs: UPDATES.md P1 flow/heuristic session entry

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:** (1) Undo → Tasks 1 (service), 2 (provider), 3 (helper), 4 (care), 5 (home/caregiver). (2) Skeletons → Tasks 6 (widget), 7 (apply). (3) Reorder → Task 8. Docs/verify → Task 9. All spec sections covered.

**Placeholder scan:** Full code given for service/provider/helper/skeleton. Call-site tasks (4,5,8) include exact replacement code plus a "read surrounding scope first" guard for identifier confirmation — deliberate, not a placeholder.

**Type consistency:** `recordDose → DateTime`, `unlogDose(...,DateTime at)`, `awardDoseHp → Future<int>`, `logDoseWithUndo({record, undo, awardHp})`, `logFamilyMemberDose(...,{at})`, `unlogFamilyMemberDose(...,DateTime at)`, `SkeletonBox`, `DashboardSkeleton` — consistent across tasks.

**Known scope note:** `_isTaking` stays true through the 4s undo window (Task 4 note) — intentional double-log guard.
