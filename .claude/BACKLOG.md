# Omra — Development Backlog
<!-- Source: AUDIT_REPORT.md Section 9 · Last reviewed: 2026-05-24 -->
<!-- Claude: Update checkboxes as tasks complete. Add new items at appropriate phase. -->
<!-- Session start reading: Phase 1 only (lines 1–45). Read Phase 2 when Phase 1 is fully done. -->

## Phase 1 — CRITICAL (Security — must fix before any public launch)
- [x] **S-01** Fix `allow list: if isSignedIn()` on appointments, prescriptions, vitals — add patientId/doctorId/caregiverHasPatient guards
- [x] **S-02** Block `userType` self-write in Firestore rules — add field exclusion on update rule for users collection
- [x] **S-03** Add `doctorHasPatient()` function + check on medicine subcollection writes
- [x] **S-04** Add `doctorHasPatient()` check on prescription collection writes
- [x] **S-06** Fix `conn.caregiverId` → `conn.caregiverUid` in `functions/src/index.ts` `checkMissedDoses` function
- [x] **S-08** Wrap caregiver invite acceptance in Firestore `WriteBatch` (confirmed already implemented)

## Phase 2 — HIGH (Core UX Workflow Fixes)
- [x] **UX-1** Patient health profile onboarding — close 3 gaps per ADR-007: (G1) defensive router safety net for incomplete patients, (G2) allergies String? → List<String> with legacy adapter + chip UI, (G3) emergency contact relationship field [implemented 2026-05-24]
- [x] **UX-2** Doctor sends push notification + in-app badge when appointment is confirmed
- [x] **UX-3** Prescription confirmation dialog — preview before save (prevents dosage errors) [implemented 2026-05-24]
- [x] **UX-4** Permission lock sections: show tooltip + "Request access" button (not silent hidden/grayed) [implemented 2026-05-24]
- [x] **UX-5** Family member home: at-a-glance health status banner — confirmed already implemented (`_DailySummaryBanner`)
- [x] **UX-6** Patient home dashboard reorder: Upcoming Tasks → position #2, Awareness Card → #1
- [x] **UX-7** Care Circle: show "invite pending" badge — AppBar + intro banner + section header now reflect pending count
- [x] **T-02** Enforce caregiver permissions at Firestore layer (currently UI-only, bypass possible) [implemented 2026-05-24]

## Phase 3 — HIGH (Collaboration Features)
- [x] **UX-8** Vitals trending charts: 30-day history on patient home + doctor patient view (use fl_chart) [implemented 2026-05-24]
- [x] **UX-9** Nudge follow-up: show "Aisha took her medicine 20 min after your nudge" indicator [implemented 2026-05-26]
- [x] **UX-10** Doctor dashboard "Needs Attention" section: list patients with <50% adherence or abnormal vitals [implemented 2026-05-26]
- [x] **UX-11** Appointment reminders: automated push notification 1 day before + ~15 min before (both patient + doctor) [implemented 2026-05-26]
- [x] **UX-12** Caregiver profile view: read-only "Recent prescriptions from doctor" section [implemented 2026-05-24]
- [x] **S-05** Case-insensitive email comparison in Firestore invite rules (`.lower()` on both sides) [implemented 2026-05-24]
- [x] **S-07** Refactor `checkMissedDoses` to pub/sub model (current O(n) queries ALL patients every 30 min) [implemented 2026-05-26]

## Phase 4 — MEDIUM (Polish & Accessibility)
- [x] **UX-13** New user empty state on patient home ("Get started" guide, appears when 0 medicines added) [implemented 2026-05-26]
- [x] **UX-14** Standardise all SnackBar format: icon + message + retry button on errors [implemented 2026-05-26]
- [x] **UX-15** Status dot legend on medicines (add icon + text label alongside color — accessibility fix) [implemented 2026-05-26]
- [x] **UX-16** Custom caregiver nudge messages (beyond 4 presets — allow free text + save as preset) [implemented 2026-05-26]
- [x] **UX-17** Data freshness timestamp on all 3 dashboards ("Last updated 3 minutes ago") [implemented 2026-05-26]
- [x] **UX-18** Gamification explanation: "What is HP?" tooltip or modal [implemented 2026-05-26]
- [x] **T-01** Refactor `CaregiverPatientProfileScreen` into sub-widgets (god-widget — ~1500 lines) [implemented 2026-05-26]
- [x] **T-03** Cursor-based pagination for appointments + prescriptions (current `.limit(100)` silently truncates) [implemented 2026-05-26]
- [x] **T-04** Fix midnight date boundary in `watchTodayMeals` stream (recalculates only on widget rebuild, not on midnight) [implemented 2026-05-26]

## Phase 8 — Clinical Features
- [x] **8a** Prescription safety checks — doctor's confirm dialog now runs drug-interaction (against new + active meds) and allergy cross-checks (with class expansion for common allergies) before allowing save; major warnings require explicit acknowledgment [2026-05-26]
- [ ] **8b** Lab results (deferred — not in v1 scope)
- [ ] **8c** Doctor med-adjustment workflow with audit trail (deferred)
- [ ] **8d** Chronic-condition trend tracking (deferred)

## Phase 9 — Accessibility quick wins
- [x] **9b** Color contrast — `textTertiary` #9CA3AF (~2.85:1 on white, failed WCAG AA) → #6B7280 (gray-500, 4.84:1); `textSecondary`/`mutedForeground` bumped from #6B7280 → #4B5563 (gray-600, 7.34:1) to preserve hierarchy [2026-05-26]
- [x] **9a** Semantics labels added to dismissible info/close icons on patient home (HP info icon, awareness card dismiss, banner dismiss) [2026-05-26]
- [x] **9c** 44dp tap targets enforced on the icon-only buttons that were 16dp (HP info, dismiss-close on awareness cards) [2026-05-26]

## Phase 7 — Cross-User Communication
- [x] **7c** Permission renegotiation loop — family member's "Request access" notification is tappable on patient side and opens a quick-grant bottom sheet [2026-05-26]
- [x] **7b** Doctor visibility into patient's family members — section in doctor patient view + patient privacy toggle (opt-in, default off) [2026-05-26]
- [x] **7a** Patient ↔ Doctor async messaging (appointment-scoped) — text-only v1 with read receipts; available once appointment is confirmed [2026-05-26]

## Phase 6 — Quick UX Wins (from AUDIT_REPORT.md Sections 4–8)
- [x] **6g** `caregiver_setup_screen.dart` — "Their Doctor" step → "Care Notes"; copy rewritten to be actionable and less prescriptive [2026-05-26]
- [x] **6a** `accept_invite_screen.dart` — extract `_accept()`/`_decline()` methods; `AppSnackBar.error` now passes `onRetry` callbacks; inline spinner on Accept button during processing [2026-05-26]
- [x] **6b** `_cg_profile_sections.dart` — `_DoseChip` shows overdue elapsed time ("8:00 AM (14m ago)") on missed slots [2026-05-26]
- [x] **6c** `_cg_profile_sections.dart` — `_MedRow` shows "Dr. [name]" subscript when `medicine.prescribedBy` is set [2026-05-26]
- [x] **6d** `_cg_profile_sections.dart` — `_MedicinesSection` shows green "All N medicines taken today" banner when all doses done [2026-05-26]
- [x] **6e** `care_circle_screen.dart` — `_CaregiverCard` detects expired invites (>7 days since `invitedAt`); shows "Expired" badge in red + "Re-invite" OutlinedButton [2026-05-26]
- [x] **6f** `_cg_profile_nudge.dart` — nudge count persisted to `users/{uid}.nudgesTodayCount`+`nudgesTodayDate`; sheet subtitle switches to "You've sent N nudges today." after first send [2026-05-26]

## Completed ✓
- [x] Family member medicines card → full-width BentoCard (v2.11.0+35)
- [x] Doctor dashboard "Failed to load" → defensive stream + client-side sort (v2.11.0+34)
- [x] `patientRating` type cast fix → `(as num?)?.toInt()` (v2.11.0+34)
- [x] All "caregiver" UI text → "family member" terminology (v2.11.0+33)
- [x] `_ConnectedPatientCard` + `_StatusDot` compile fix (v2.11.0+33)
- [x] `_timeAgo` promoted to top-level function (scope fix) (v2.11.0+33)
- [x] Removed `.orderBy()` composite index dependency from appointment streams (v2.11.0+34)
- [x] Workflow infrastructure setup — CLAUDE.md, memory files, hooks, skills (v2.11.0+35)
