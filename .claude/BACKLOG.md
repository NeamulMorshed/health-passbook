# Omra — Development Backlog
<!-- Source: AUDIT_REPORT.md Section 9 · Last reviewed: 2026-05-24 -->
<!-- Claude: Update checkboxes as tasks complete. Add new items at appropriate phase. -->
<!-- Session start reading: Phase 1 only (lines 1–45). Read Phase 2 when Phase 1 is fully done. -->

## Phase 1 — CRITICAL (Security — must fix before any public launch)
- [ ] **S-01** Fix `allow list: if isSignedIn()` on appointments, prescriptions, vitals — add patientId/doctorId/caregiverHasPatient guards
- [ ] **S-02** Block `userType` self-write in Firestore rules — add field exclusion on update rule for users collection
- [ ] **S-03** Add `doctorHasPatient()` function + check on medicine subcollection writes
- [ ] **S-04** Add `doctorHasPatient()` check on prescription collection writes
- [ ] **S-06** Fix `conn.caregiverId` → `conn.caregiverUid` in `functions/src/index.ts` `checkMissedDoses` function
- [ ] **S-08** Wrap caregiver invite acceptance in Firestore `WriteBatch` (atomic — prevents orphaned connections)

## Phase 2 — HIGH (Core UX Workflow Fixes)
- [ ] **UX-1** Patient health profile onboarding screen (age, weight, height, conditions, allergies, emergency contact)
- [ ] **UX-2** Doctor sends push notification + in-app badge when appointment is confirmed
- [ ] **UX-3** Prescription confirmation dialog — preview before save (prevents dosage errors)
- [ ] **UX-4** Permission lock sections: show tooltip + "Request access" button (not silent hidden/grayed)
- [ ] **UX-5** Family member home: at-a-glance health status banner (✅ All good / ⚠ Heads up / 🔴 Urgent)
- [ ] **UX-6** Patient home dashboard reorder: Upcoming Tasks → position #2, Awareness Card → #1
- [ ] **UX-7** Care Circle: show "invite pending" badge (not "0 people monitoring you" after invite sent)
- [ ] **T-02** Enforce caregiver permissions at Firestore layer (currently UI-only, bypass possible)

## Phase 3 — HIGH (Collaboration Features)
- [ ] **UX-8** Vitals trending charts: 30-day history on patient home + doctor patient view (use fl_chart)
- [ ] **UX-9** Nudge follow-up: show "Aisha took her medicine 20 min after your nudge" indicator
- [ ] **UX-10** Doctor dashboard "Needs Attention" section: list patients with <50% adherence or abnormal vitals
- [ ] **UX-11** Appointment reminders: automated push notification 1 day before + day-of
- [ ] **UX-12** Caregiver profile view: read-only "Recent prescriptions from doctor" section
- [ ] **S-05** Case-insensitive email comparison in Firestore invite rules (`.lower()` on both sides)
- [ ] **S-07** Refactor `checkMissedDoses` to pub/sub model (current O(n) queries ALL patients every 30 min)

## Phase 4 — MEDIUM (Polish & Accessibility)
- [ ] **UX-13** New user empty state on patient home ("Get started" guide, appears when 0 medicines added)
- [ ] **UX-14** Standardise all SnackBar format: icon + message + retry button on errors
- [ ] **UX-15** Status dot legend on medicines (add icon + text label alongside color — accessibility fix)
- [ ] **UX-16** Custom caregiver nudge messages (beyond 4 presets — allow free text + save as preset)
- [ ] **UX-17** Data freshness timestamp on all 3 dashboards ("Last updated 3 minutes ago")
- [ ] **UX-18** Gamification explanation: "What is HP?" tooltip or modal
- [ ] **T-01** Refactor `CaregiverPatientProfileScreen` into sub-widgets (god-widget — ~1500 lines)
- [ ] **T-03** Cursor-based pagination for appointments + prescriptions (current `.limit(100)` silently truncates)
- [ ] **T-04** Fix midnight date boundary in `watchTodayMeals` stream (recalculates only on widget rebuild, not on midnight)

## Completed ✓
- [x] Family member medicines card → full-width BentoCard (v2.11.0+35)
- [x] Doctor dashboard "Failed to load" → defensive stream + client-side sort (v2.11.0+34)
- [x] `patientRating` type cast fix → `(as num?)?.toInt()` (v2.11.0+34)
- [x] All "caregiver" UI text → "family member" terminology (v2.11.0+33)
- [x] `_ConnectedPatientCard` + `_StatusDot` compile fix (v2.11.0+33)
- [x] `_timeAgo` promoted to top-level function (scope fix) (v2.11.0+33)
- [x] Removed `.orderBy()` composite index dependency from appointment streams (v2.11.0+34)
- [x] Workflow infrastructure setup — CLAUDE.md, memory files, hooks, skills (v2.11.0+35)
