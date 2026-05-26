# Omra — Project Context for Claude
<!-- Claude Code auto-loads this file every session. It replaces reading source files for orientation. -->
<!-- Keep this file under 250 lines. Update version and branch after each session. -->

## Session Start Protocol (run every session, in order)
1. Read `.claude/UPDATES.md` — limit: 80 lines from top (most recent sessions)
2. Read `.claude/BACKLOG.md` — limit: first 45 lines (Phase 1 critical items)
3. Report: current version, what was last changed, top 3 open Phase 1 items
4. **If session involves any UI/screen work:** also read `.claude/PERSONAS.md` relevant persona section
5. **If session involves Firestore, rules, or architecture:** also read `.claude/DECISIONS.md`
6. **If session involves any UI widget/color/icon edit:** also read `.claude/DESIGN_SYSTEM.md` relevant section

## Session End Protocol (run every session, before closing)
1. Append a new entry to `.claude/UPDATES.md` at the TOP (reverse-chronological)
2. Update checkbox states in `.claude/BACKLOG.md` for any completed items
3. If a new architectural decision was made, append it to `.claude/DECISIONS.md`
4. Update the version number in this file if pubspec.yaml was bumped

## Model Selection Reminders
- If the request involves **planning, designing, or architecture** → remind user: "This looks like a planning task — type `/model opus` first for deeper reasoning"
- If the request is a **quick lookup or single factual question** → Haiku is appropriate (`/model haiku`)
- Default for all coding/implementation/debugging/analysis → Sonnet (current, no switch needed)

## App Identity
- **Name:** Omra (package: vitalpath, old name VitalPath — fully replaced)
- **Platform:** Flutter/Dart + Firebase backend
- **Current version:** 2.12.0+38  ← update this after each pubspec bump
- **Active branch:** feature/caregiver-ux-redesign
- **Firebase Distribution App ID:** `1:768599207887:android:a365080e6a086985736cba`
- **Deploy command:** `firebase appdistribution:distribute <path>.apk --app 1:768599207887:android:a365080e6a086985736cba --groups testers`

## Tech Stack (exact versions)
- **State:** flutter_riverpod ^2.5.1 — ConsumerWidget, StreamProvider.family, StateNotifier, AsyncValue
- **Routing:** go_router ^14.3.0 — role-based redirect guards, shell routes per portal
- **Firebase:** firebase_core ^3.6.0, firebase_auth ^5.3.1, cloud_firestore ^5.4.1, firebase_messaging ^15.1.3
- **UI:** HugeIcons ^1.1.4 (strokeRounded*), google_fonts ^6.2.1 (Open Sans), fl_chart ^0.69.0
- **Build:** `flutter build apk --release` then distribute via firebase CLI

## Three User Portals
| Portal | Routes | Color | Entry File |
|--------|--------|-------|-----------|
| Patient | `/home` | `AppColors.primary` (#0F9D77 green) | `lib/screens/patient/home/home_screen.dart` |
| Doctor | `/doc/*` | `AppColors.primary` (shared) | `lib/screens/doctor/doc_dashboard_screen.dart` |
| Family Member | `/caregiver/*` | `AppColors.caregiver` (#F59E0B amber) | `lib/screens/caregiver/home/caregiver_home_screen.dart` |

## Strict Terminology Rules
- **Always "Family Member"** — never "Caregiver" in any UI-facing text, strings, or labels
- **Always "Omra"** — never "VitalPath" (old name, fully replaced in UI)
- Code variables/filenames may still use `caregiver` (refactor is a separate backlog item, do not change without explicit instruction)

## Critical File Map
```
lib/
├── core/
│   ├── theme/app_theme.dart          — AppColors + AppTheme (ALL color tokens live here)
│   ├── widgets/bento_card.dart       — BentoCard, BentoStatCard, BentoRow, BentoFeaturedCard,
│   │                                   BentoSettingsTile, BentoSectionHeader (6 widgets)
│   └── constants/app_constants.dart  — Firestore collection names, shared constants
├── models/                           — Appointment, Medicine, Prescription, CaregiverConnection, etc.
├── services/firestore_service.dart   — ALL Firestore queries (read this before any query change)
├── screens/
│   ├── patient/home/home_screen.dart              — Patient dashboard (~1150 lines)
│   ├── doctor/doc_dashboard_screen.dart           — Doctor dashboard (266 lines)
│   ├── doctor/doc_patient_view_screen.dart        — Doctor patient view (1525 lines, 5 tabs)
│   ├── caregiver/home/caregiver_home_screen.dart  — Family member home
│   └── caregiver/caregiver_patient_profile_screen.dart — Family member patient view (~1500 lines, god-widget)
├── app/router.dart                   — GoRouter config + role-based guards
firestore.rules                       — ⚠ HAS 4 CRITICAL VULNERABILITIES (see AUDIT_REPORT.md S-01–S-04)
functions/src/index.ts                — Cloud Functions (TypeScript) — ⚠ FCM bug S-06
```

## Architecture Rules (enforced — do not violate without creating an ADR)
1. **Never** add `dependency_overrides` to `pubspec.yaml`
2. **Never** use `.orderBy()` + `.where()` together on Firestore queries — composite index will fail; sort client-side instead
3. **Always** wrap `fromMap()` calls in `try-catch` inside `.map()` inside streams — defensive stream pattern
4. **Never** use raw hex values in UI — always `AppColors.tokenName`
5. **Never** use `Material Icons` where a `HugeIcons.strokeRounded*` equivalent exists

## Known Critical Issues (must not be forgotten)
- **S-01** `allow list: if isSignedIn()` on appointments/prescriptions/vitals → any signed-in user reads ALL medical data
- **S-02** User can write `userType` field → self-escalation to doctor role
- **S-03** Any doctor can add medicines to any patient (missing `doctorHasPatient()` check)
- **S-04** Any doctor can prescribe to any patient (missing `doctorHasPatient()` check)
- **S-06** `checkMissedDoses` Cloud Function: `conn.caregiverId` → should be `conn.caregiverUid` — all FCM push to family members silently fails
- Full details: `AUDIT_REPORT.md` Section 3

## Reference Files
| File | Purpose | When to Read |
|------|---------|-------------|
| `.claude/UPDATES.md` | Session change log | Session start (top 80 lines) |
| `.claude/BACKLOG.md` | Prioritised task queue | Session start (Phase 1 only) |
| `.claude/DESIGN_SYSTEM.md` | AppColors, widgets, spacing, icons | Before any UI edit |
| `.claude/PERSONAS.md` | Aisha / Dr. Rahman / Karim user needs | Before any screen-level UX decision |
| `.claude/DECISIONS.md` | Architecture Decision Records | Before any Firestore/architecture change |
| `AUDIT_REPORT.md` | Full technical + security + UX audit | Reference by section, not full read |
| `WORKFLOW_STRATEGY_REPORT.md` | Full workflow strategy | Reference only |
| `SETUP_GUIDE.md` | How to install/verify workflow tooling | Reference only |
