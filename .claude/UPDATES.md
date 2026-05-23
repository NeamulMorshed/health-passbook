# Omra — Session Change Log
<!-- Claude: Read TOP 80 lines only (most recent 2–3 sessions). Append NEW entries at the TOP. -->
<!-- Format per entry: ## YYYY-MM-DD · vX.X.X+N then bullets for changed/next -->

---
## 2026-05-24 · v2.11.0+35
**Focus:** Workflow infrastructure setup (all 10 files created)
**Changed:**
- `CLAUDE.md` (new) — auto-loaded project context, session protocols, model selection reminders
- `.claude/UPDATES.md` (new) — this session log
- `.claude/BACKLOG.md` (new) — 20 prioritised items from AUDIT_REPORT.md
- `.claude/DESIGN_SYSTEM.md` (new) — AppColors from app_theme.dart, BentoCard catalog from bento_card.dart
- `.claude/PERSONAS.md` (new) — Aisha, Dr. Rahman, Karim personas with needs + priority orders
- `.claude/DECISIONS.md` (new) — ADR-001 through ADR-005
- `.claude/settings.json` (new) — PostToolUse hook: flutter analyze on every .dart edit
- `.claude/skills/omra-ux-review/SKILL.md` (new) — UX checklist skill
- `.claude/skills/omra-design-check/SKILL.md` (new) — design system enforcement skill
- `.claude/skills/omra-security-check/SKILL.md` (new) — Firestore security pattern checker
- `skills-lock.json` (updated) — 3 new local skills registered
- `AUDIT_REPORT.md` (new) — full technical/security/UX audit report
- `WORKFLOW_STRATEGY_REPORT.md` (new) — complete workflow strategy v2.0
- `SETUP_GUIDE.md` (new) — step-by-step installation guide
- Git: branch `chore/workflow-claude-setup` created and pushed to GitHub

**Workflow is now active. All session protocols in CLAUDE.md are live.**

**Next session should:**
- Run 5 verification tests from SETUP_GUIDE.md Part 3 to confirm everything works
- Then begin Phase 1 security fixes from BACKLOG.md (S-01 through S-06)
- Use `/model opus` before planning the Firestore rules fix (S-01 is complex)

---
## 2026-05-24 · v2.11.0+35
**Focus:** Full app audit + workflow strategy planning
**Changed:**
- `AUDIT_REPORT.md` (new) — 3-agent parallel audit: technical + security/DB + UX/journey simulation
- `WORKFLOW_STRATEGY_REPORT.md` (new) — workflow strategy v2.0 with model selection strategy
- `SETUP_GUIDE.md` (new) — implementation guide

**Critical findings (not yet fixed):**
- S-01: `allow list: if isSignedIn()` exposes all medical data to any authenticated user
- S-06: `checkMissedDoses` Cloud Function field name bug — FCM family member notifications never delivered
- Full list: AUDIT_REPORT.md Section 3

---
## 2026-05-24 · v2.11.0+35
**Focus:** Family member medicines card → full-width
**Changed:**
- `lib/screens/caregiver/home/caregiver_home_screen.dart` — replaced two narrow BentoStatCards (BentoRow) with one full-width BentoCard showing taken count left + due count right
- `pubspec.yaml` — bumped to 2.11.0+35
- `release_notes.txt` — updated

---
## 2026-05-24 · v2.11.0+34
**Focus:** Doctor dashboard "Failed to load" fix
**Changed:**
- `lib/services/firestore_service.dart` — removed `.orderBy()` from `watchDoctorAppointments` + `watchPatientAppointments`; added client-side sort + try-catch wrapper inside stream .map()
- `lib/models/appointment.dart` — `patientRating` cast: `as int?` → `(as num?)?.toInt()`
- `pubspec.yaml` — bumped to 2.11.0+34

**Why:** Composite Firestore index was missing/failed; one bad document type (patientRating as double) crashed entire stream.

---
## 2026-05-24 · v2.11.0+33
**Focus:** Terminology fix + ConnectedPatientCard compile fix
**Changed:**
- `lib/screens/caregiver/patients/caregiver_patients_screen.dart` — added `_StatusDot` enum + `_ConnectedPatientCard` ConsumerWidget (was referenced but missing)
- `lib/screens/caregiver/caregiver_patient_profile_screen.dart` — promoted `_timeAgo` from static state method to top-level function (scope fix)
- 8 files: all "caregiver" UI text → "family member" (see AUDIT_REPORT.md for full list)
- `pubspec.yaml` — bumped to 2.11.0+33
