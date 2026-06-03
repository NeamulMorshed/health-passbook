# P0 Emotion & Generic-UI Uplift — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a reusable daily status-hero card to all 3 portal home screens, a surface depth tier, an on-brand demoted AI card, and 4 reduced-motion-safe micro-interactions — lifting the app from flat/generic to calm and crafted, with no backend changes.

**Architecture:** Two new pure units (`StatusHeroCard` widget + `reduced_motion` helper) are TDD'd in isolation. Home screens compute a `StatusHeroData` value object from existing providers and pass it in (widget stays provider-free + testable). Screen integration verified via `flutter analyze` + manual smoke (stream-heavy screens, not unit-tested). Frequent commits per task.

**Tech Stack:** Flutter, flutter_riverpod, hugeicons, google_fonts, flutter_test. Spec: `docs/superpowers/specs/2026-06-01-p0-emotion-ui-design.md`.

**Branch:** `feature/ux-audit-improvements` (already created).

---

### Task 1: Reduced-motion helper

**Files:**
- Create: `lib/core/anim/reduced_motion.dart`
- Test: `test/core/anim/reduced_motion_test.dart`

- [ ] **Step 1: Write failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitalpath/core/anim/reduced_motion.dart';

void main() {
  testWidgets('prefersReducedMotion true when disableAnimations set', (t) async {
    late bool result;
    await t.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Builder(builder: (c) { result = prefersReducedMotion(c); return const SizedBox(); }),
    ));
    expect(result, isTrue);
  });

  testWidgets('prefersReducedMotion false by default', (t) async {
    late bool result;
    await t.pumpWidget(MediaQuery(
      data: const MediaQueryData(),
      child: Builder(builder: (c) { result = prefersReducedMotion(c); return const SizedBox(); }),
    ));
    expect(result, isFalse);
  });
}
```

- [ ] **Step 2: Run test, verify it fails**

Run: `flutter test test/core/anim/reduced_motion_test.dart`
Expected: FAIL — `reduced_motion.dart` does not exist / `prefersReducedMotion` undefined.

- [ ] **Step 3: Implement**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// True when the OS has "reduce motion" / "remove animations" enabled.
bool prefersReducedMotion(BuildContext context) {
  final mq = MediaQuery.maybeOf(context);
  return mq?.disableAnimations ?? false;
}

/// Fires a haptic only when reduced motion is OFF (haptics are part of the
/// motion feedback system we suppress for accessibility).
void safeHaptic(BuildContext context, {bool medium = false}) {
  if (prefersReducedMotion(context)) return;
  medium ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact();
}
```

- [ ] **Step 4: Run test, verify it passes**

Run: `flutter test test/core/anim/reduced_motion_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/anim/reduced_motion.dart test/core/anim/reduced_motion_test.dart
git commit -m "feat(anim): reduced-motion gate + safe haptic helper

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: AppShadows hero token

**Files:**
- Modify: `lib/core/theme/app_theme.dart` (add after `AppColors` class)

- [ ] **Step 1: Add `AppShadows` class**

```dart
class AppShadows {
  /// Soft ambient shadow for the single elevated hero card per screen (green states).
  static const List<BoxShadow> hero = [
    BoxShadow(color: Color(0x1A0F9D77), blurRadius: 16, offset: Offset(0, 4)),
  ];

  /// Amber-tinted variant for the "catch up" hero state.
  static const List<BoxShadow> heroWarning = [
    BoxShadow(color: Color(0x1AD97706), blurRadius: 16, offset: Offset(0, 4)),
  ];
}
```

- [ ] **Step 2: Verify analyze clean**

Run: `flutter analyze lib/core/theme/app_theme.dart`
Expected: No issues for this file.

- [ ] **Step 3: Commit**

```bash
git add lib/core/theme/app_theme.dart
git commit -m "feat(theme): AppShadows.hero depth tokens for hero cards

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: StatusHeroData model + StatusHeroCard widget (ring/action variant)

**Files:**
- Create: `lib/core/widgets/status_hero_card.dart`
- Test: `test/core/widgets/status_hero_card_test.dart`

- [ ] **Step 1: Write failing tests (states)**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitalpath/core/widgets/status_hero_card.dart';

Widget _wrap(Widget c) => MaterialApp(home: Scaffold(body: c));

void main() {
  testWidgets('on-track shows pill, title, action', (t) async {
    await t.pumpWidget(_wrap(StatusHeroCard(
      data: const StatusHeroData(
        fraction: 0.66, ringLabel: '2/3', pillLabel: 'ON TRACK',
        tone: HeroTone.positive, title: 'One more to go today',
        subtitle: 'Evening dose due at 8:00 PM', actionLabel: 'Mark next dose taken'),
      onAction: () {},
    )));
    expect(find.text('ON TRACK'), findsOneWidget);
    expect(find.text('One more to go today'), findsOneWidget);
    expect(find.text('Mark next dose taken'), findsOneWidget);
  });

  testWidgets('all-done hides action button', (t) async {
    await t.pumpWidget(_wrap(StatusHeroCard(
      data: const StatusHeroData(
        fraction: 1.0, ringLabel: '✓', pillLabel: 'ALL DONE',
        tone: HeroTone.positive, title: 'Everything logged', subtitle: '3 of 3 doses',
        actionLabel: null),
      onAction: null,
    )));
    expect(find.text('ALL DONE'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets('catch-up uses warning tone label', (t) async {
    await t.pumpWidget(_wrap(StatusHeroCard(
      data: const StatusHeroData(
        fraction: 0.33, ringLabel: '1/3', pillLabel: 'LET\'S CATCH UP',
        tone: HeroTone.warning, title: '2 doses waiting',
        subtitle: 'Morning & noon still due', actionLabel: 'Mark morning dose taken'),
      onAction: () {},
    )));
    expect(find.text('LET\'S CATCH UP'), findsOneWidget);
    expect(find.text('Mark morning dose taken'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `flutter test test/core/widgets/status_hero_card_test.dart`
Expected: FAIL — `status_hero_card.dart` / `StatusHeroData` / `StatusHeroCard` undefined.

- [ ] **Step 3: Implement widget**

```dart
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_theme.dart';
import '../anim/reduced_motion.dart';

enum HeroTone { positive, warning }

class StatusHeroData {
  final double fraction;       // 0.0–1.0 ring fill
  final String ringLabel;      // e.g. '2/3' or '✓'
  final String pillLabel;      // e.g. 'ON TRACK'
  final HeroTone tone;
  final String title;
  final String subtitle;
  final String? actionLabel;   // null → no button
  const StatusHeroData({
    required this.fraction, required this.ringLabel, required this.pillLabel,
    required this.tone, required this.title, required this.subtitle, this.actionLabel,
  });
}

class StatusHeroCard extends StatelessWidget {
  final StatusHeroData data;
  final VoidCallback? onAction;
  const StatusHeroCard({super.key, required this.data, this.onAction});

  @override
  Widget build(BuildContext context) {
    final warn = data.tone == HeroTone.warning;
    final accent = warn ? AppColors.warning : AppColors.primary;
    final bg = warn ? AppColors.warningLight : AppColors.primaryXLight;
    final pillBg = warn ? AppColors.warningLight : AppColors.successLight;
    final pillFg = warn ? AppColors.warning : AppColors.success;
    final reduce = prefersReducedMotion(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: warn ? AppShadows.heroWarning : AppShadows.hero,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _Ring(fraction: data.fraction, label: data.ringLabel, accent: accent, animate: !reduce),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: pillBg, borderRadius: BorderRadius.circular(20)),
              child: Text(data.pillLabel, style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: pillFg)),
            ),
            const SizedBox(height: 5),
            Text(data.title, style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700,
              color: warn ? const Color(0xFF92400E) : AppColors.primaryDark)),
            const SizedBox(height: 2),
            Text(data.subtitle, style: const TextStyle(
              fontSize: 12, color: AppColors.textSecondary)),
          ])),
        ]),
        if (data.actionLabel != null) ...[
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent, minimumSize: const Size(double.infinity, 44)),
            child: Text(data.actionLabel!),
          )),
        ],
      ]),
    );
  }
}

class _Ring extends StatelessWidget {
  final double fraction;
  final String label;
  final Color accent;
  final bool animate;
  const _Ring({required this.fraction, required this.label, required this.accent, required this.animate});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: animate ? 0 : fraction, end: fraction),
      duration: Duration(milliseconds: animate ? 300 : 0),
      curve: Curves.easeOut,
      builder: (_, value, __) => SizedBox(
        width: 54, height: 54,
        child: CustomPaint(
          painter: _RingPainter(value, accent),
          child: Center(child: Text(label, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, color: accent))),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double fraction;
  final Color accent;
  _RingPainter(this.fraction, this.accent);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 3;
    final track = Paint()..style = PaintingStyle.stroke..strokeWidth = 6
      ..color = accent.withValues(alpha: 0.15);
    final fill = Paint()..style = PaintingStyle.stroke..strokeWidth = 6
      ..strokeCap = StrokeCap.round..color = accent;
    canvas.drawCircle(c, r, track);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r),
      -1.5708, 6.2832 * fraction.clamp(0.0, 1.0), false, fill);
  }
  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.accent != accent;
}
```

- [ ] **Step 4: Run tests, verify they pass**

Run: `flutter test test/core/widgets/status_hero_card_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/status_hero_card.dart test/core/widgets/status_hero_card_test.dart
git commit -m "feat(widgets): StatusHeroCard ring/action variant + StatusHeroData

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: StatusHeroCard schedule variant (doctor)

**Files:**
- Modify: `lib/core/widgets/status_hero_card.dart`
- Modify: `test/core/widgets/status_hero_card_test.dart`

- [ ] **Step 1: Add failing test**

```dart
  testWidgets('schedule variant lists rows + open action', (t) async {
    await t.pumpWidget(_wrap(StatusHeroCard.schedule(
      dateLabel: 'Mon, Jun 1',
      rows: const [
        ScheduleRow(time: '09:30', name: 'Aisha Hassan', status: 'Confirmed', confirmed: true),
        ScheduleRow(time: '11:00', name: 'Rafiq Ahmed', status: 'Pending', confirmed: false),
      ],
      onOpen: () {},
    )));
    expect(find.text('Today · 2 appointments'), findsOneWidget);
    expect(find.text('Aisha Hassan'), findsOneWidget);
    expect(find.text('Open appointments'), findsOneWidget);
  });

  testWidgets('schedule empty shows caught-up', (t) async {
    await t.pumpWidget(_wrap(StatusHeroCard.schedule(
      dateLabel: 'Mon, Jun 1', rows: const [], onOpen: () {})));
    expect(find.text('No appointments today'), findsOneWidget);
  });
```

- [ ] **Step 2: Run, verify fail**

Run: `flutter test test/core/widgets/status_hero_card_test.dart`
Expected: FAIL — `StatusHeroCard.schedule` / `ScheduleRow` undefined.

- [ ] **Step 3: Implement schedule constructor**

Add to `status_hero_card.dart`:

```dart
class ScheduleRow {
  final String time, name, status;
  final bool confirmed;
  const ScheduleRow({required this.time, required this.name, required this.status, required this.confirmed});
}
```

Convert `StatusHeroCard` to expose a named constructor. Add these fields + constructor to the class (keep the default constructor):

```dart
  // schedule-variant fields
  final List<ScheduleRow>? _rows;
  final String? _dateLabel;
  final VoidCallback? _onOpen;

  const StatusHeroCard({super.key, required this.data, this.onAction})
      : _rows = null, _dateLabel = null, _onOpen = null;

  const StatusHeroCard.schedule({
    super.key, required List<ScheduleRow> rows, required String dateLabel, required VoidCallback onOpen,
  })  : data = const StatusHeroData(fraction: 0, ringLabel: '', pillLabel: '',
            tone: HeroTone.positive, title: '', subtitle: ''),
        onAction = null, _rows = rows, _dateLabel = dateLabel, _onOpen = onOpen;
```

In `build`, branch at the top:

```dart
    if (_rows != null) return _buildSchedule(context);
```

Add the schedule builder method:

```dart
  Widget _buildSchedule(BuildContext context) {
    final rows = _rows!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.hero,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(rows.isEmpty ? 'Today' : 'Today · ${rows.length} appointment${rows.length == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(color: AppColors.infoLight, borderRadius: BorderRadius.circular(20)),
            child: Text(_dateLabel!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.info)),
          ),
        ]),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No appointments today', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)))
        else
          ...rows.take(4).map((r) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text('${r.time}   ${r.name}',
                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis)),
              Text(r.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: r.confirmed ? AppColors.success : AppColors.warning)),
            ]),
          )),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _onOpen,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size(double.infinity, 44)),
          child: const Text('Open appointments'),
        )),
      ]),
    );
  }
```

- [ ] **Step 4: Run, verify pass**

Run: `flutter test test/core/widgets/status_hero_card_test.dart`
Expected: PASS (5 tests total).

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/status_hero_card.dart test/core/widgets/status_hero_card_test.dart
git commit -m "feat(widgets): StatusHeroCard.schedule variant for doctor dashboard

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Wire hero into patient home + remove snapshot row + restyle/demote AI card

**Files:**
- Modify: `lib/screens/patient/home/home_screen.dart`

- [ ] **Step 1: Add a helper that derives `StatusHeroData` from meds**

Near the top of `_HomeContent` (after providers are read in `build`), compute taken/total from `medsAsync.asData?.value`. Add a private function in the file:

```dart
StatusHeroData? _patientHero(List<Medicine> meds) {
  final active = meds.where((m) => m.isActive).toList();
  final totalSlots = active.fold<int>(0, (s, m) => s + m.todaySlotCount);
  if (totalSlots == 0) return null; // no meds → hero hidden, get-started shows
  final taken = active.fold<int>(0, (s, m) => s + m.todayTakenCount);
  final overdue = active.any((m) => m.hasDueSlot);
  final frac = taken / totalSlots;
  if (taken >= totalSlots) {
    return const StatusHeroData(fraction: 1, ringLabel: '✓', pillLabel: 'ALL DONE',
      tone: HeroTone.positive, title: 'Everything\'s logged today',
      subtitle: 'All doses taken. Rest easy tonight.');
  }
  if (overdue) {
    final left = totalSlots - taken;
    return StatusHeroData(fraction: frac, ringLabel: '$taken/$totalSlots', pillLabel: 'LET\'S CATCH UP',
      tone: HeroTone.warning, title: '$left dose${left == 1 ? '' : 's'} waiting',
      subtitle: 'Tap below to log your next dose.', actionLabel: 'Mark next dose taken');
  }
  final left = totalSlots - taken;
  return StatusHeroData(fraction: frac, ringLabel: '$taken/$totalSlots', pillLabel: 'ON TRACK',
    tone: HeroTone.positive, title: '$left more to go today',
    subtitle: 'You\'re on track with your medicines.', actionLabel: 'Mark next dose taken');
}
```

> NOTE: confirm `Medicine` exposes `todaySlotCount`, `todayTakenCount`, `hasDueSlot`. If the first two don't exist, derive from existing fields used by `_DailySnapshotRow`/`_UpcomingTasksCard` (read those widgets first and reuse their exact slot logic — do NOT invent new fields).

- [ ] **Step 2: Insert hero at top of sliver list; remove snapshot row**

In the `SliverChildListDelegate([...])` list (currently starts with `FreshnessTimestamp`), insert immediately after the GET STARTED block and BEFORE `_DailyAwarenessCard`:

```dart
                  // ── STATUS HERO ───────────────────────────────────────────
                  Builder(builder: (_) {
                    final hero = _patientHero(medsAsync.asData?.value ?? []);
                    if (hero == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: StatusHeroCard(
                        data: hero,
                        onAction: hero.actionLabel == null ? null : () => context.go('/care'),
                      ),
                    );
                  }),
```

Then DELETE the `_DailySnapshotRow(...)` widget + its trailing `SizedBox(height: 12)` from the list (the "── SNAPSHOT ──" block). Leave the `_DailySnapshotRow` class definition in place if unused-warnings are acceptable, OR delete the class too if `flutter analyze` flags it.

- [ ] **Step 3: Restyle + demote AI insights card**

Replace the gradient `Container` (the "── AI INSIGHTS ──" block, ~lines 313–351) with:

```dart
                  GestureDetector(
                    onTap: () => context.push('/insights'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryXLight,
                        border: Border.all(color: AppColors.border, width: 0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(children: [
                        HugeIcon(icon: HugeIcons.strokeRoundedSparkles, color: AppColors.primary, size: 22),
                        const SizedBox(width: 14),
                        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('AI Health Insights', style: TextStyle(
                            color: AppColors.primaryDark, fontSize: 14, fontWeight: FontWeight.w600)),
                          Text('Personalised suggestions from Claude AI', style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                        ])),
                        HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: AppColors.textTertiary, size: 14),
                      ]),
                    ),
                  ),
```

The AI block is already last in the list (good — below the fold). No move needed beyond confirming it sits after `_FamilyStatusBar`.

- [ ] **Step 4: Verify analyze + tests**

Run: `flutter analyze lib/screens/patient/home/home_screen.dart`
Expected: 0 errors (pre-existing info warnings OK).
Run: `flutter test`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/patient/home/home_screen.dart
git commit -m "feat(patient-home): status hero card; remove redundant snapshot; on-brand demoted AI card

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Wire hero into caregiver home (status + nudge)

**Files:**
- Modify: `lib/screens/caregiver/home/caregiver_home_screen.dart`

- [ ] **Step 1: Read existing medicine-status + nudge logic**

Read `caregiver_home_screen.dart` fully + `_cg_profile_nudge.dart`. Identify: how the selected member's medicines are watched (`familyMemberMedicinesProvider`), the taken/total computation already used in the member detail, and the existing nudge entry point. Reuse that exact slot logic — do not invent fields.

- [ ] **Step 2: Build a caregiver hero from selected member meds**

Add a private helper mirroring `_patientHero` but with caregiver copy: title `'<FirstName> is on track today'` / `'<FirstName> missed a dose'`, subtitle `'<taken> of <total> meds taken'`, actionLabel `'Send a nudge'`. Insert the hero `StatusHeroCard` immediately after `FreshnessTimestamp` and before the member detail sections, only when a member is selected and has meds. `onAction` opens the existing nudge sheet/flow.

```dart
                  if (selectedMember != null) Builder(builder: (_) {
                    final hero = _caregiverHero(/* selected member meds + name */);
                    if (hero == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: StatusHeroCard(data: hero, onAction: () => _openNudge(selectedMember)),
                    );
                  }),
```

> Use amber `AppColors.caregiver` for the action by passing `HeroTone` accordingly is not supported (tone drives green/amber). For the nudge button specifically, acceptable to keep the tone-driven accent. If amber nudge button is required, that is a P1 refinement — keep P0 to tone-driven color.

- [ ] **Step 3: Verify**

Run: `flutter analyze lib/screens/caregiver/home/caregiver_home_screen.dart`
Expected: 0 errors.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/caregiver/home/caregiver_home_screen.dart
git commit -m "feat(caregiver-home): status hero answering 'is she OK' + nudge action

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 7: Wire schedule hero into doctor dashboard + refresh toast

**Files:**
- Modify: `lib/screens/doctor/dashboard/doc_dashboard_screen.dart`

- [ ] **Step 1: Build ScheduleRow list from today's confirmed+pending**

In the `data: (appts)` builder, after `todayCount` is computed, build:

```dart
                    final todayAppts = [...confirmed, ...pending].where((a) =>
                        a.scheduledAt != null &&
                        !a.scheduledAt!.isBefore(todayStart) &&
                        a.scheduledAt!.isBefore(todayEnd)).toList()
                      ..sort((x, y) => x.scheduledAt!.compareTo(y.scheduledAt!));
                    final scheduleRows = todayAppts.map((a) => ScheduleRow(
                      time: DateFormat('HH:mm').format(a.scheduledAt!),
                      name: a.patientName,
                      status: a.isConfirmed ? 'Confirmed' : 'Pending',
                      confirmed: a.isConfirmed,
                    )).toList();
```

- [ ] **Step 2: Insert schedule hero after the stat row**

After the `Row` of 3 `BentoStatCard`s + its `SizedBox(height: 24)`, insert:

```dart
                    StatusHeroCard.schedule(
                      dateLabel: DateFormat('EEE, MMM d').format(DateTime.now()),
                      rows: scheduleRows,
                      onOpen: () => context.go('/doc/appointments'),
                    ),
                    const SizedBox(height: 24),
```

Add `import '../../../core/widgets/status_hero_card.dart';` at top.

- [ ] **Step 3: Add refresh toast**

In the `RefreshIndicator.onRefresh` (after invalidations + setting `_docLastRefreshedProvider`), add:

```dart
                  if (context.mounted) AppSnackBar.info(context, 'Updated just now');
```

(Confirm `AppSnackBar.info` exists in `app_widgets.dart`; if the method is named differently, use the existing info-toast helper.)

- [ ] **Step 4: Verify**

Run: `flutter analyze lib/screens/doctor/dashboard/doc_dashboard_screen.dart`
Expected: 0 errors.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/doctor/dashboard/doc_dashboard_screen.dart
git commit -m "feat(doctor-dash): today-schedule hero (closes G-4) + refresh toast

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 8: Dose check-off micro-interaction + all-done pulse + refresh toasts on remaining dashboards

**Files:**
- Modify: `lib/screens/patient/care/care_screen.dart` (already has `HapticFeedback.mediumImpact()` at `_logDose`)
- Modify: `lib/screens/patient/home/home_screen.dart` (refresh toast)
- Modify: `lib/screens/caregiver/home/caregiver_home_screen.dart` (refresh toast)

- [ ] **Step 1: Gate the existing care-screen haptic via reduced motion + add check animation**

In `care_screen.dart` `_logDose` (line ~654): replace bare `HapticFeedback.mediumImpact();` with `safeHaptic(context, medium: true);` (import `reduced_motion.dart`). Wrap the success checkmark that appears post-log in an `AnimatedScale`/`TweenAnimationBuilder` (0.8→1.0, 200ms, easeOut) gated by `prefersReducedMotion`.

> Read the widget around line 654–800 first to find where the "taken" check is rendered, and apply the scale/fade there. Keep it minimal — one `AnimatedScale` around the existing check icon.

- [ ] **Step 2: Add refresh toast to patient + caregiver home**

In each `RefreshIndicator.onRefresh`, after the existing invalidations + `_*LastRefreshedProvider` set, add:

```dart
            if (context.mounted) AppSnackBar.info(context, 'Updated just now');
```

(home_screen `onRefresh` is async with `ref.invalidate(...)`; caregiver same.)

- [ ] **Step 3: All-done pulse (hero ring)**

The hero ring already animates via `TweenAnimationBuilder` (Task 3). For the all-done celebration, add a one-shot scale pulse: in `StatusHeroCard`, when `data.fraction >= 1.0 && data.tone == positive && !reduce`, wrap the `_Ring` in a brief `TweenAnimationBuilder<double>` scale 1.0→1.06→1.0 (250ms) and fire `safeHaptic(context, medium: true)` once via a post-frame callback guarded by a `StatefulWidget` flag.

> This requires converting the all-done ring path to a small stateful sub-widget so the pulse fires once, not every rebuild. Add `_CelebrateRing extends StatefulWidget` used only when all-done; reuse `_RingPainter`.

- [ ] **Step 4: Verify**

Run: `flutter analyze`
Expected: 0 errors.
Run: `flutter test`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/patient/care/care_screen.dart lib/screens/patient/home/home_screen.dart lib/screens/caregiver/home/caregiver_home_screen.dart lib/core/widgets/status_hero_card.dart
git commit -m "feat(motion): reduced-motion-safe check-off haptic, all-done pulse, refresh toasts

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 9: Document design-system additions

**Files:**
- Modify: `.claude/DESIGN_SYSTEM.md`

- [ ] **Step 1: Add Hero Card + Depth Tier section**

Append a "Status Hero Card" entry to the Widget Catalog (props: `StatusHeroData` / `.schedule`), an "AppShadows" row to a new Elevation section, and the rule: *exactly one elevated+tinted hero card per screen; all other cards flat.*

- [ ] **Step 2: Commit**

```bash
git add .claude/DESIGN_SYSTEM.md
git commit -m "docs(design-system): hero card, AppShadows elevation, one-hero-per-screen rule

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 10: Final verification

- [ ] **Step 1: Full analyze**

Run: `flutter analyze`
Expected: 0 errors (pre-existing info-level warnings acceptable; no NEW warnings on touched files).

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: all pass (reduced_motion 2 + status_hero_card 5 + existing).

- [ ] **Step 3: Update UPDATES.md (session end protocol)**

Prepend a session entry to `.claude/UPDATES.md` summarizing P0 changes + files touched.

- [ ] **Step 4: Commit**

```bash
git add .claude/UPDATES.md
git commit -m "docs: UPDATES.md P0 emotion/UI session entry

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:** (1) Hero card → Tasks 3,4,5,6,7. (2) Surface depth tier → Task 2 + used in 3. (3) AI card → Task 5 step 3. (4) Micro-interactions: check-off → Task 8.1; ring fill → Task 3 (_Ring); all-done pulse → Task 8.3; refresh toast → Tasks 7.3, 8.2. (5) Home de-clutter → Task 5 step 2. Docs → Task 9. All spec sections covered.

**Placeholder scan:** Code provided inline for the two new pure units. Screen-integration tasks include explicit "read existing logic first / reuse exact slot fields, do not invent" guards because the precise `Medicine` slot accessors must be confirmed against the live model — this is a deliberate safety instruction, not a placeholder.

**Type consistency:** `StatusHeroData`, `HeroTone`, `ScheduleRow`, `StatusHeroCard` / `.schedule`, `prefersReducedMotion`, `safeHaptic`, `AppShadows.hero`/`.heroWarning` used consistently across tasks.

**Open dependency to confirm during execution:** exact `Medicine` per-day slot accessors (`todaySlotCount`/`todayTakenCount`/`hasDueSlot`) and `AppSnackBar.info` name — Tasks 5/8 instruct reading the source first and reusing existing logic rather than guessing.
