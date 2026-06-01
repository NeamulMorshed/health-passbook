# P0 — Emotion & Generic-UI Uplift — Design Spec

**Date:** 2026-06-01 · **Branch:** `feature/ux-audit-improvements` · **Tier:** P0 (first of P0→P3)
**Source:** `50 - UX + Design/UX_Audit_2026-06-01.md` · **Design intelligence:** ui-ux-pro-max v2.5.0
**App:** Omra (`vitalpath_flutter`), Flutter + Riverpod + GoRouter

## Goal

Lift the app from "functionally complete but emotionally flat / visually generic" toward "calm, reassuring, crafted." Highest perceived-quality ROI. **No new features, no backend, no Firestore changes** — purely presentational + a new shared widget. All existing data providers reused.

## Scope (5 work items)

1. **Status hero card** — new top card on all 3 portal home screens
2. **Surface depth tier** — one elevated+tinted hero per screen; rest stay flat
3. **AI insights card** — replace off-brand gradient, demote below fold (patient home)
4. **Micro-interactions** — 4 motions, all reduced-motion-safe
5. **Patient home de-clutter** — merge the redundant snapshot row into the hero (drops 1 card)

Out of scope (later tiers): icon/hex consistency debt (P2), multi-role (P3), doctor needs-attention explainability (P3), skeleton loaders (P1).

---

## 1. Status Hero Card (decision: Option A — ring + next action)

A new reusable widget, **`StatusHeroCard`**, lives in `lib/core/widgets/status_hero_card.dart`. It is the single elevated card per home screen. Layout: progress ring (left) + status pill + title + subtitle (center) + one full-width primary action button (bottom, optional).

**Shared structure (one widget, three configurations):**

| Slot | Patient | Caregiver | Doctor |
|------|---------|-----------|--------|
| Ring value | doses taken / total today | monitored person's doses taken/total | n/a — replaced by count badge ("3 appts") |
| Status pill | ON TRACK / ALL DONE / LET'S CATCH UP | ON TRACK / ATTENTION | date chip |
| Title | "One more to go today" (neutral, A-style) | "Aisha is on track today" | "Today · 3 appointments" |
| Subtitle | "Evening dose due at 8:00 PM" | "2 of 3 meds taken · BP normal · meals logged" | — (list rows instead) |
| Action | "Mark next dose taken" | "Send a nudge" | "Open appointments" |

**State logic (patient & caregiver):**
- `taken == total && total > 0` → **ALL DONE** (full ring, success tint `primaryXLight`/`successLight`, no action button)
- `0 < taken < total` → **ON TRACK** (partial green ring, `primaryXLight` tint, action = next dose)
- `taken < total` and overdue slots exist → **LET'S CATCH UP** (amber ring, `warningLight` tint, encouraging copy, action = mark overdue). **Never red, never alarming.**
- `total == 0` (no meds) → hero hidden; existing `_GetStartedGuide` shows instead.

**Doctor variant** (`StatusHeroCard.schedule`): renders today's confirmed+pending appointments as up to ~4 time/name/status rows + "Open appointments" button. Empty → "No appointments today" caught-up state. Data: existing `doctorAppointmentsProvider`, filtered to today (logic already computed in `doc_dashboard_screen.dart` as `todayCount`).

**Tone:** Option A — neutral/clear copy (not the warmer "Doing great, Aisha"). Status conveyed by pill + ring color, not effusive text.

### Component contract
- **What it does:** renders a single glanceable daily-status summary + one primary action.
- **Inputs:** a `StatusHeroData` value object (ring fraction, pill label+color, title, subtitle, optional action label+callback) OR named constructor `.schedule({rows, onOpen})`.
- **Depends on:** `AppColors`, `AppTheme` text styles, `hugeicons`. No providers inside — parent screens compute `StatusHeroData` from existing providers and pass it in (keeps the widget pure + testable).

---

## 2. Surface Depth Tier (decision: one hero elevated, rest flat)

Add two surface treatments to the design system (in `app_theme.dart` as helpers/constants; document in `DESIGN_SYSTEM.md`):

- **`AppShadows.hero`** — soft ambient shadow: `BoxShadow(color: primary @ 0.10, blur 16, offset (0,4))` for green heroes; amber-tinted variant for catch-up state.
- **Tinted hero surface** — `primaryXLight` (#F2FAF7) for green states, `warningLight` for catch-up, reusing existing tokens.

Rule (added to `DESIGN_SYSTEM.md`): **exactly one elevated+tinted hero card per screen; all other cards remain flat white + 0.5px border.** Prevents hierarchy flattening.

`StatusHeroCard` is the only consumer of `AppShadows.hero` in P0.

---

## 3. AI Insights Card (decision: on-brand + demoted)

In `home_screen.dart` (~line 313–352):
- Remove the `LinearGradient([#0EA5E9, #6366F1])`.
- Replace with flat `BentoCard`-style surface: `primaryXLight` background, `primaryDark` title text, green sparkle icon (`HugeIcons.strokeRoundedSparkles` in `AppColors.primary`).
- **Reposition:** move below the adherence ring / family status (true below-fold), since AI insights is ranked #12 for Aisha.

---

## 4. Micro-interactions (decision: all 4, reduced-motion-safe)

All durations 150–300ms. All gated behind a reduced-motion check (`MediaQuery.of(context).disableAnimations` / `accessibleNavigation`); when reduced motion is on, changes apply instantly and haptics are skipped.

1. **Dose check-off** — on mark-taken: checkmark scales 0.8→1.0 + fades in (200ms, `Curves.easeOut`) + `HapticFeedback.lightImpact()`. Applied where doses are toggled (care screen + hero action + home tasks).
2. **Hero ring fill** — ring `TweenAnimationBuilder<double>` animates old fraction → new fraction (300ms) when taken-count changes.
3. **All-done / streak celebration** — when day reaches 100% or streak extends: ring does one gentle scale pulse (1.0→1.06→1.0, 250ms) + `HapticFeedback.mediumImpact()`. No confetti (would read childish for the persona). Fires once per transition, not on every rebuild.
4. **Pull-to-refresh toast** — after a dashboard `RefreshIndicator` completes: brief "Updated just now" SnackBar/toast (reuse `AppSnackBar`). Applied to all 3 dashboards.

A small shared helper `lib/core/anim/reduced_motion.dart` exposes `bool prefersReducedMotion(context)` + `Future<void> safeHaptic(...)` so the gate is consistent and DRY.

---

## 5. Patient Home De-clutter

The existing `_DailySnapshotRow` (meds/streak/appts mini-stats) is now redundant with the hero's ring + subtitle. **Remove `_DailySnapshotRow` from the home sliver list** (its data folds into the hero). Net: patient home drops from ~11 cards to ~10 and the most-urgent action rises above the fold. No other reordering in P0 (deeper reorder is P1 G-1).

---

## Architecture & Files

| File | Change |
|------|--------|
| `lib/core/widgets/status_hero_card.dart` | **NEW** — `StatusHeroCard` widget + `StatusHeroData` + `.schedule` constructor |
| `lib/core/anim/reduced_motion.dart` | **NEW** — reduced-motion gate + safe haptic helper |
| `lib/core/theme/app_theme.dart` | add `AppShadows.hero` (+ amber variant) |
| `lib/screens/patient/home/home_screen.dart` | insert hero at top; remove `_DailySnapshotRow`; restyle + reposition AI card; wire ring-fill + check-off |
| `lib/screens/caregiver/home/caregiver_home_screen.dart` | insert hero (status + nudge) above member detail |
| `lib/screens/doctor/dashboard/doc_dashboard_screen.dart` | insert `.schedule` hero after stats; pull-to-refresh toast |
| `lib/screens/patient/care/care_screen.dart` | dose check-off micro-interaction on mark-taken |
| `.claude/DESIGN_SYSTEM.md` | document hero card, depth-tier rule, AppShadows |

## Data Flow
No new providers. Each home screen already watches meds/meals/appts/gamification. Screens compute a `StatusHeroData` from those `AsyncValue`s and pass it to `StatusHeroCard`. Hero hidden while underlying data is loading (or shows a slim skeleton placeholder — deferred to P1).

## Error / Edge Handling
- No meds/appointments → hero hidden, existing get-started/empty states unchanged.
- Loading → hero not shown (no spinner inside hero).
- Reduced motion on → all animations instant, no haptics.
- Overdue detection reuses existing `medicine.hasDueSlot` / slot logic — no new time math.

## Testing
- Widget tests for `StatusHeroCard`: each state (on-track / all-done / catch-up / doctor-schedule / empty) renders correct pill, ring fraction, action presence.
- `prefersReducedMotion` helper unit-tested true/false.
- Manual: `flutter analyze` clean; visual smoke on all 3 home screens.

## Non-Goals (explicit)
No copy warmth beyond Option A neutral tone. No confetti. No backend/Firestore/rules. No nav-structure change. No icon/hex migration (P2). No skeletons (P1).
