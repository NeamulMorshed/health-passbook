# OMRA — WORKFLOW SETUP GUIDE
**Version 1.0 · 2026-05-24**  
**Purpose: How to install and verify every item in WORKFLOW_STRATEGY_REPORT.md**

> Read this before WORKFLOW_STRATEGY_REPORT.md if you want to actually implement the workflow.  
> This guide answers: "What happens automatically?" and "How exactly do I install each piece?"

---

## PART 1 — WHAT HAPPENS AUTOMATICALLY VS. MANUALLY

This is the most important thing to understand before installing anything.

### Layer 1: Fully Automatic — Once created, forever works, zero effort per session

| What | How it's automatic |
|------|--------------------|
| **`CLAUDE.md`** | Claude Code reads this file at the start of every session automatically. You never need to reference it — it's always loaded. |
| **`.claude/settings.json` hooks** | The moment any `Edit` or `Write` tool call fires on a `.dart` file, the flutter analyze hook runs by itself. No command, no trigger. |
| **Existing Caveman skills** | Already installed and registered. Claude Code scans `.claude/skills/` at startup — they're always available as `/caveman`, `/cavecrew`, etc. |

---

### Layer 2: Semi-Automatic — Automatic BECAUSE `CLAUDE.md` instructs it

The secret: `CLAUDE.md` is not just a knowledge file — it is an **instruction file**. By writing behavior rules inside it, you program Claude's startup behavior for every future session.

Example: if CLAUDE.md contains:
```
At the start of every session, read .claude/UPDATES.md (top 80 lines) and
.claude/BACKLOG.md (Phase 1 section only). Then tell me the current state.
```

Claude will do this automatically every session because it reads CLAUDE.md first. No manual prompting needed.

| What | Why it's semi-automatic |
|------|------------------------|
| Reading `.claude/UPDATES.md` at session start | CLAUDE.md instructs Claude to do it |
| Reading `.claude/BACKLOG.md` Phase 1 at session start | CLAUDE.md instructs Claude to do it |
| Reading the right persona before UI work | CLAUDE.md instructs Claude: "Before any screen edit, read the relevant persona from .claude/PERSONAS.md" |
| Checking DECISIONS.md before architecture changes | CLAUDE.md instructs Claude: "Before any Firestore/architecture change, read .claude/DECISIONS.md" |
| Suggesting Opus for planning tasks | CLAUDE.md instructs Claude: "When a task involves planning a new feature, remind the user to switch to /model opus" |
| Updating UPDATES.md at session end | CLAUDE.md instructs Claude: "At the end of every session, append a summary entry to .claude/UPDATES.md" |

**The rule: anything you write as an instruction in CLAUDE.md becomes automatic behavior.**

---

### Layer 3: One Command Per Session — Intentional, fast, your choice

| What | Command | When |
|------|---------|------|
| Activate token compression | `/caveman` | Start of any dev session |
| Switch to planning mode | `/model opus` | Before designing a feature |
| Switch back to standard | `/model sonnet` | After planning, before implementing |
| Quick questions mode | `/model haiku` | For fast lookups only |
| Dispatch parallel agents | `/cavecrew` | Large multi-task jobs |
| UX review a screen | `/omra-ux-review home_screen` | After editing a screen |
| Design system check | `/omra-design-check` | Before committing UI changes |
| Security pattern check | `/omra-security-check` | After any Firestore/rules change |

These are intentional because you decide WHEN to use them. They are instant (one slash command) and cost nothing to skip if not needed.

---

### Layer 4: Already Working — No setup needed

These work right now with zero installation:

| What | Status |
|------|--------|
| `/caveman` (token compression) | ✅ Already installed |
| `/cavecrew` (parallel agents) | ✅ Already installed |
| `/caveman-review` (code review) | ✅ Already installed |
| `/caveman-compress` (output compression) | ✅ Already installed |
| `/caveman-commit` (commit messages) | ✅ Already installed |
| `/caveman-stats` (token usage) | ✅ Already installed |
| Agent spawning (parallel work) | ✅ Built into Claude Code |
| Model switching (`/model`) | ✅ Built into Claude Code |
| Worktree isolation for agents | ✅ Already configured |

**You can start using these today without any installation.**

---

## PART 2 — INSTALLATION STEPS (in order)

Install in this exact order. Each step takes the estimated time shown. Total: ~2.5 hours.

---

### STEP 1 — Create `CLAUDE.md` ⏱ 30 min

**What it does:** Claude Code automatically reads this file at every session start. This single file replaces 20,000+ tokens of re-orientation per session.

**Where:** Project root — same folder as `AUDIT_REPORT.md` and `WORKFLOW_STRATEGY_REPORT.md`

**Path:** `/Health Passbook/Health Passbook/CLAUDE.md`

**How to create:** Ask Claude to write it, or create it manually. The content below is the complete template — customize the values marked with `← UPDATE THIS`.

**Content to use:**
```markdown
# Omra — Project Context for Claude
<!-- Claude: Read this entire file at session start. It replaces reading source files for orientation. -->

## Session Start Protocol
1. Read .claude/UPDATES.md — limit: 80 lines from top (most recent sessions)
2. Read .claude/BACKLOG.md — limit: first 40 lines (Phase 1 critical items only)
3. Tell me: current app version, what was last changed, and top 3 open items
4. If this session involves UI/screen work: also read .claude/PERSONAS.md relevant persona
5. If this session involves Firestore/architecture: also read .claude/DECISIONS.md

## Session End Protocol
1. Append a new entry to .claude/UPDATES.md (at the TOP, reverse-chronological)
2. Update checkbox states in .claude/BACKLOG.md for any completed items
3. If a new architectural decision was made, append it to .claude/DECISIONS.md

## Model Selection Reminders
- Planning/designing a new feature → remind user to type `/model opus` first
- Standard implementation/debugging → Sonnet is correct (current default)
- Quick lookups only → Haiku is fine; never use Haiku for code edits

## App Identity
- Name: Omra (package name: vitalpath)
- Tagline: Health app for patients, doctors, and family members
- Flutter + Firebase (Firestore, Auth, Storage, Messaging, Cloud Functions)
- Current version: 2.11.0+35  ← UPDATE THIS each session end
- Active branch: feature/caregiver-ux-redesign
- Firebase App Distribution App ID: 1:768599207887:android:a365080e6a086985736cba

## Tech Stack
- State: flutter_riverpod ^2.5.1 (ConsumerWidget, StreamProvider.family, StateNotifier)
- Routing: go_router ^14.3.0 with role-based redirect guards
- UI: BentoCard/BentoStatCard/BentoRow/BentoSectionHeader (bento_card.dart)
- Icons: HugeIcons (strokeRounded variants) — never use Material icons without justification
- Colors: AppColors tokens — NEVER use raw hex values
- Firebase stack: firebase_core ^3.6.0, firebase_auth ^5.3.1, cloud_firestore ^5.4.1

## Three User Portals
- Patient → routes: /home — AppColors.primary (blue)
- Doctor → routes: /doc/* — AppColors.doctor (green)
- Family Member → routes: /caregiver/* — AppColors.caregiver #F59E0B (amber)

## Terminology Rules
- Always: "Family Member" (never "Caregiver" in UI text)
- Code variables/filenames may still say caregiver (refactor is separate task)
- Always: "Omra" (not "VitalPath" — old name, fully replaced)

## Critical File Map
- lib/screens/patient/home/home_screen.dart — Patient dashboard (~1150 lines)
- lib/screens/doctor/doc_dashboard_screen.dart — Doctor dashboard (266 lines)
- lib/screens/caregiver/home/caregiver_home_screen.dart — Family member home
- lib/screens/caregiver/caregiver_patient_profile_screen.dart — Caregiver patient view (~1500 lines, god-widget)
- lib/screens/doctor/doc_patient_view_screen.dart — Doctor patient view (1525 lines)
- lib/services/firestore_service.dart — All Firestore queries
- lib/models/ — Data models (Appointment, Medicine, Prescription, etc.)
- firestore.rules — Security rules ⚠ HAS CRITICAL VULNERABILITIES (see AUDIT_REPORT.md)
- functions/src/index.ts — Cloud Functions (TypeScript)

## Known Critical Issues (do not forget)
- S-01: allow list on appointments/prescriptions/vitals exposes ALL medical data to any signed-in user
- S-02: Users can self-escalate to doctor role by writing userType field
- S-03/S-04: Any doctor can write medicines/prescriptions to any patient (no connection check)
- S-06: checkMissedDoses Cloud Function uses conn.caregiverId (should be conn.caregiverUid) — FCM broken
- Full list: AUDIT_REPORT.md Section 3

## Architecture Rules (enforced — do not violate)
- Never add dependency_overrides to pubspec.yaml
- Never use orderBy() + where() together in Firestore (no composite index) — sort client-side
- Always wrap fromMap() in try-catch inside stream .map()
- Never use raw hex in UI — always AppColors.tokenName

## See Also
- AUDIT_REPORT.md — Full technical/security/UX audit
- .claude/UPDATES.md — Session change log (read top 80 lines)
- .claude/BACKLOG.md — Task backlog with checkboxes
- .claude/DESIGN_SYSTEM.md — AppColors, widget catalog, spacing
- .claude/PERSONAS.md — User personas (Aisha, Dr. Rahman, Karim)
- .claude/DECISIONS.md — Architecture Decision Records
- WORKFLOW_STRATEGY_REPORT.md — Full workflow strategy
```

**How to verify it works:**  
Start a brand new Claude Code session. Claude's very first message should reference the app name, current version, last session activity, and open backlog items — without you saying anything about the project.

---

### STEP 2 — Create `.claude/UPDATES.md` ⏱ 15 min

**What it does:** Session-by-session change log. Claude reads the top 80 lines at session start to know what was last done. Claude appends to it at session end.

**Path:** `.claude/UPDATES.md`

**How to create:** Create the file manually (or ask Claude to create it). Start with the entries below as a bootstrap — these are the last ~6 sessions from memory.

**Content to use:**
```markdown
# Omra — Session Change Log
<!-- Claude: Read the TOP 80 lines only (most recent 2–3 sessions). Append NEW entries at the TOP. -->
<!-- Format: ## YYYY-MM-DD · vX.X.X+N then bullets -->

---
## 2026-05-24 · v2.11.0+35
**Focus:** Audit + workflow strategy planning
**Changed:**
- AUDIT_REPORT.md (new) — full technical/security/UX audit across all 3 portals
- WORKFLOW_STRATEGY_REPORT.md (new) — complete workflow strategy v2.0
- SETUP_GUIDE.md (new) — this installation guide

**Critical findings recorded (not yet fixed):**
- 4 Firestore security rule vulnerabilities (S-01 to S-04)
- Cloud Function FCM field name bug (S-06) — family member push notifications never delivered
- 20 UX recommendations across 4 phases

**Next session should:**
- Install this workflow infrastructure first (follow SETUP_GUIDE.md)
- Then tackle Phase 1 critical security fixes from BACKLOG.md

---
## 2026-05-24 · v2.11.0+35
**Focus:** Family member medicines card → full-width fix
**Changed:**
- lib/screens/caregiver/home/caregiver_home_screen.dart — replaced two narrow BentoStatCards with single full-width BentoCard showing taken/due stats
- pubspec.yaml — bumped to 2.11.0+35
- release_notes.txt — updated

---
## 2026-05-24 · v2.11.0+34
**Focus:** Doctor dashboard "Failed to load" fix
**Changed:**
- lib/services/firestore_service.dart — removed orderBy from watchDoctorAppointments + watchPatientAppointments, client-side sort, try-catch wrapper
- lib/models/appointment.dart — patientRating cast: as int? → (as num?)?.toInt()
- pubspec.yaml — bumped to 2.11.0+34

---
## 2026-05-24 · v2.11.0+33
**Focus:** Terminology fix (caregiver → family member) + ConnectedPatientCard
**Changed:**
- lib/screens/caregiver/patients/caregiver_patients_screen.dart — added _StatusDot + _ConnectedPatientCard
- caregiver_profile_screen.dart, profile_screen.dart, care_circle_screen.dart, manage_caregiver_screen.dart, invite_caregiver_screen.dart, caregiver_connection.dart — all "caregiver" UI text → "family member"
- caregiver_patient_profile_screen.dart — promoted _timeAgo to top-level function
- pubspec.yaml — bumped to 2.11.0+33

---
## [Earlier sessions — add manually if needed]
```

**How to verify:** Ask Claude "What was done in the last session?" — it should answer from UPDATES.md without reading any source files.

---

### STEP 3 — Create `.claude/BACKLOG.md` ⏱ 20 min

**What it does:** The single source of truth for "what to do next." Checkbox list derived from AUDIT_REPORT.md. Claude updates checkboxes as items complete.

**Path:** `.claude/BACKLOG.md`

**Content to use:**
```markdown
# Omra — Development Backlog
<!-- Source: AUDIT_REPORT.md Section 9 · Last reviewed: 2026-05-24 -->
<!-- Claude: Update checkboxes as items complete. Add new items at the appropriate phase. -->
<!-- Reading strategy: Read Phase 1 only at session start (lines 1–40). Read Phase 2 when Phase 1 is done. -->

## Phase 1 — CRITICAL (Security — Must fix before public launch)
- [ ] S-01: Fix `allow list: if isSignedIn()` on appointments, prescriptions, vitals collections
- [ ] S-02: Block userType self-write in Firestore rules (add field exclusion on update)
- [ ] S-03: Add doctorHasPatient() check on medicine writes (any doctor → specific connected doctor)
- [ ] S-04: Add doctorHasPatient() check on prescription writes
- [ ] S-06: Fix conn.caregiverId → conn.caregiverUid in Cloud Function checkMissedDoses
- [ ] S-08: Wrap caregiver invite acceptance in Firestore batch write (atomicity fix)

## Phase 2 — HIGH (Core UX Workflow Fixes)
- [ ] UX-1: Patient health profile onboarding screen (age, weight, conditions, allergies, emergency contact)
- [ ] UX-2: Doctor sends push notification + in-app badge when appointment is confirmed
- [ ] UX-3: Prescription confirmation dialog (preview before save — prevent dosage errors)
- [ ] UX-4: Permission lock tooltip + "Request access" button for family member locked sections
- [ ] UX-5: Family member home: health status banner (✅ All good / ⚠ Heads up / 🔴 Urgent)
- [ ] UX-6: Patient home dashboard reorder (Upcoming Tasks to #2, Awareness Card to #1)
- [ ] UX-7: Care Circle shows pending invite badge (not "0 people" while invite is pending)
- [ ] T-02: Enforce caregiver permissions at Firestore layer (not just UI)

## Phase 3 — HIGH (Collaboration Features)
- [ ] UX-8: Vitals trending charts on patient home + doctor patient view (30-day)
- [ ] UX-9: Nudge follow-up: show "Aisha took medicine 20 min after nudge" indicator
- [ ] UX-10: Doctor dashboard: "Needs Attention" section (non-compliant patients, abnormal vitals)
- [ ] UX-11: Appointment reminders (automated 1-day + day-of push notifications)
- [ ] UX-12: Caregiver view: show recent prescriptions from doctor (read-only)
- [ ] S-05: Case-insensitive email comparison in Firestore rules (caregiver invite lockout fix)
- [ ] S-07: Refactor checkMissedDoses to pub/sub (O(n) cost scaling fix)

## Phase 4 — MEDIUM (Polish & Accessibility)
- [ ] UX-13: New user empty state on patient home ("Get Started" guide, 0 medicines)
- [ ] UX-14: Standard SnackBar format with retry buttons on all error states
- [ ] UX-15: Status dot legend on medicines (✓ Taken, ! Due, ✗ Missed — add icons not just color)
- [ ] UX-16: Custom caregiver nudge messages (beyond 4 presets)
- [ ] UX-17: Data freshness timestamp on all three dashboards
- [ ] UX-18: Gamification explanation ("What is HP?" tooltip/screen)
- [ ] T-01: Refactor CaregiverPatientProfileScreen into sub-widgets (god-widget fix)
- [ ] T-03: Cursor-based pagination for appointments + prescriptions (beyond limit(100))
- [ ] T-04: Fix midnight date recalculation in watchTodayMeals stream

## Completed ✓
- [x] Family member medicines card → full-width BentoCard (v2.11.0+35)
- [x] Doctor dashboard "Failed to load" → defensive stream + client-side sort (v2.11.0+34)
- [x] patientRating type cast fix → (as num?)?.toInt() (v2.11.0+34)
- [x] All "caregiver" UI text → "family member" terminology (v2.11.0+33)
- [x] _ConnectedPatientCard + _StatusDot compile fix (v2.11.0+33)
- [x] _timeAgo promoted to top-level function (v2.11.0+33)
- [x] Firestore composite index removed from watchDoctorAppointments (v2.11.0+34)
```

---

### STEP 4 — Create `.claude/DESIGN_SYSTEM.md` ⏱ 20 min

**What it does:** Visual design memory. Claude reads the relevant section before any UI change so it never uses raw hex, wrong widget, or incorrect icon.

**Path:** `.claude/DESIGN_SYSTEM.md`

**How to create:** Ask Claude: *"Read lib/core/app_colors.dart and bento_card.dart, then write .claude/DESIGN_SYSTEM.md from the actual code"* — Claude will generate it from the source files, which is more accurate than a template.

**Alternatively, create manually using this template:**
```markdown
# Omra — Design System Reference
<!-- Claude: Read the relevant section before any UI edit. Do not write raw hex or use wrong widgets. -->

## AppColors Tokens
<!-- Extract from lib/core/app_colors.dart — paste actual values here -->
| Token | Usage |
|-------|-------|
| AppColors.primary | Patient portal — CTAs, highlights |
| AppColors.caregiver | Family Member portal — amber accent (#F59E0B) |
| AppColors.caregiverLight | Family Member background fills (#FEF3C7) |
| AppColors.inviteAccent | Invite flows, purple accent (#7C3AED) |
| AppColors.mutedForeground | Secondary text, captions |
| AppColors.destructive | Errors, delete actions |
RULE: Never raw hex. Always AppColors.tokenName.

## Widget Catalog
| Widget | Use For | Do NOT Use For |
|--------|---------|----------------|
| BentoCard | Standard content container | Never nest BentoCards |
| BentoStatCard | Single metric (number + label) | Multi-line content |
| BentoRow | Two cards side by side | More than 2 children |
| BentoSectionHeader | Section title with optional link | Page titles |

## Icon Rules
- Always HugeIcons.strokeRounded* variants
- Size 20px inline, 24px standalone, 18px in stat cards
- Use Material Icons ONLY if HugeIcons has no equivalent (must comment why)

## Typography
- Body text: 14px regular
- Caption: 12px, AppColors.mutedForeground
- Stat number: 22px, FontWeight.w700
- Section header: 16px, FontWeight.w600

## Spacing
- Card internal padding: 16px all sides
- Card-to-card gap: 12px
- Section gap: 24px
- Icon-to-text (horizontal): 12–14px

## Portal Color Identity
- Patient screens: primary blue tones
- Doctor screens: doctor green tones
- Family Member screens: caregiver amber + caregiverLight
```

---

### STEP 5 — Create `.claude/PERSONAS.md` ⏱ 15 min

**What it does:** User persona memory. Claude reads the relevant persona before editing any user-facing screen, so every decision is grounded in real user needs.

**Path:** `.claude/PERSONAS.md`

**How to create:** The content is already fully written in WORKFLOW_STRATEGY_REPORT.md Section 5.7. Copy the code block from that section into this file. It includes Aisha, Dr. Rahman, Karim, and the 5 UX validation questions.

---

### STEP 6 — Create `.claude/DECISIONS.md` ⏱ 15 min

**What it does:** Architecture Decision Records. Claude reads this before any architecture change to avoid undoing deliberate decisions without knowing it.

**Path:** `.claude/DECISIONS.md`

**How to create:** The content is already fully written in WORKFLOW_STRATEGY_REPORT.md Section 5.8. Copy the code block from that section into this file. It contains ADR-001 through ADR-005.

---

### STEP 7 — Create `.claude/settings.json` (Code Verification Hook) ⏱ 20 min

**What it does:** Automatically runs `flutter analyze` after every Dart file edit. Output appears in your terminal and is fed back to Claude. If there are errors, Claude sees them and fixes them before moving on.

**Path:** `.claude/settings.json`

**Important:** This file does NOT exist yet. You are creating it.

**Content to use:**
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "FILE=$(echo '$CLAUDE_TOOL_INPUT' | python3 -c \"import sys,json; d=json.load(sys.stdin); print(d.get('file_path',''))\" 2>/dev/null); if echo \"$FILE\" | grep -q 'vitalpath_flutter.*\\.dart'; then cd \"/Users/nahid/Figma Exports/Exploration Work in Claude/Health Passbook/Health Passbook/vitalpath_flutter\" && flutter analyze --no-fatal-infos 2>&1 | tail -25; fi"
          }
        ]
      }
    ]
  }
}
```

**What this does, precisely:**
1. After every `Edit` or `Write` tool call, it checks if the edited file is a `.dart` file inside `vitalpath_flutter/`
2. If yes: runs `flutter analyze` and outputs the last 25 lines (errors and warnings)
3. If no (e.g., editing CLAUDE.md): skips silently
4. Output is shown in your terminal AND injected into Claude's context

**How to verify it works:**
1. Ask Claude to add a deliberate syntax error to any `.dart` file (e.g., add a stray `{`)
2. After the edit, you should see `flutter analyze` output appear automatically in the terminal
3. If you see analyzer output → hook is working ✅
4. Ask Claude to fix the error; verify clean output → self-correcting loop confirmed ✅

**If the hook doesn't trigger:**  
Check that `.claude/settings.json` is in the project root's `.claude/` directory, not in `vitalpath_flutter/.claude/`. The file location must be `/project-root/.claude/settings.json`.

---

### STEP 8 — Create the 3 Custom Skills ⏱ 45 min

Custom skills live in `.claude/skills/` alongside the existing Caveman skills. Each is a folder containing a `SKILL.md` file with YAML frontmatter.

#### 8a. `/omra-ux-review` skill

**Create file:** `.claude/skills/omra-ux-review/SKILL.md`

**Content:**
```markdown
---
name: omra-ux-review
description: >
  UX review for Omra app screens. Checks implementation against the 3 user personas
  in .claude/PERSONAS.md and the 10 UX pattern issues in AUDIT_REPORT.md Section 8.
  Use when editing or reviewing any user-facing screen. Invoke: /omra-ux-review [screen-name]
---

Perform a structured UX review of the named screen.

## Steps

1. Identify the primary persona for this screen (Aisha / Dr. Rahman / Karim) from `.claude/PERSONAS.md`
2. Read the persona's "primary need", "biggest frustration", and "dashboard priority order"
3. Check the screen against these 10 issues from AUDIT_REPORT.md Section 8:
   - P-01: Terminology consistent? ("Family Member" not "Caregiver", "Omra" not "VitalPath")
   - P-02: Navigation depth matches the role's nav structure?
   - P-03: Empty state exists for zero-data scenario?
   - P-04: Error state has retry button?
   - P-05: Destructive actions have AlertDialog; major records have bottom-sheet confirm?
   - P-06: Permission locks show tooltip + "Request access" (not silent hidden section)?
   - P-07: SnackBar format: icon + message + optional retry, 3s or persistent for errors?
   - P-08: Data freshness timestamp shown?
   - P-09: Status indicators have icon/text label (not color-only)?
   - P-10: Upcoming tasks / actionable items appear above trend metrics?
4. For patient home specifically: verify dashboard order matches recommended order in AUDIT_REPORT.md Section 7.1
5. Output format: one line per finding. `PASS` or `FAIL: [specific issue] at [file:line]`

## Output Example
```
Screen: home_screen.dart | Persona: Aisha (Patient)
P-01 Terminology: PASS
P-03 Empty state (0 medicines): FAIL — no empty state widget found
P-09 Status dot legend: FAIL — _FamilyStatusChip uses color only, no icon/label
P-10 Tasks above metrics: FAIL — Upcoming Tasks at position #6 (should be #2)
P-05 Destructive confirm: PASS
---
3 issues found. Priority: P-10 (highest impact for Aisha's primary need)
```
```

#### 8b. `/omra-design-check` skill

**Create file:** `.claude/skills/omra-design-check/SKILL.md`

**Content:**
```markdown
---
name: omra-design-check
description: >
  Design system compliance checker for Omra. Verifies that any edited Dart file
  follows the design rules in .claude/DESIGN_SYSTEM.md — AppColors tokens, correct
  widgets, HugeIcons, spacing. Invoke: /omra-design-check [file-path]
---

Check the given file or recent edits for design system violations.

## Checks

1. **Color check**: Search for `Color(0x` or `Color.fromRGBO` or `Colors.` — these are raw colors. Flag each. Correct: `AppColors.tokenName`
2. **Widget check**: Look for `Card(` without `BentoCard` — flag as potential inconsistency
3. **Icon check**: Look for `Icons.` (Material) — flag each. Verify HugeIcons has no equivalent before accepting
4. **Font check**: Look for `TextStyle(fontFamily:` with raw string — should use GoogleFonts or app theme
5. **Padding check**: Look for `EdgeInsets.all(` with values not in [8, 12, 16, 24] — flag if unusual

## Output Format
One line per violation: `[file:line] [check-type]: [what was found] → [correct form]`

## Example
```
lib/screens/patient/home/home_screen.dart:342 [color]: Color(0xFFF59E0B) → AppColors.caregiver
lib/screens/patient/home/home_screen.dart:567 [icon]: Icons.check_circle → HugeIcons.strokeRoundedCheckmarkCircle01
```
```

#### 8c. `/omra-security-check` skill

**Create file:** `.claude/skills/omra-security-check/SKILL.md`

**Content:**
```markdown
---
name: omra-security-check
description: >
  Firestore security pattern checker for Omra. After any Firestore query, security rule,
  or Cloud Function edit, checks for the known vulnerability patterns from AUDIT_REPORT.md.
  Invoke: /omra-security-check
---

After any Firestore-related change, run these checks:

## Firestore Rules Checks
1. Is `allow list: if isSignedIn()` used without additional guard? → FLAG (S-01 pattern)
2. Is a `users` document write rule missing protection for `userType` field? → FLAG (S-02)
3. Is a medicine/prescription write rule missing `doctorHasPatient()` check? → FLAG (S-03/S-04)
4. Is email comparison done without `.lower()`? → FLAG (S-05)
5. Is a new collection introduced without a security rule? → FLAG

## Firestore Query Checks (Dart code)
1. Does the query use `.where()` + `.orderBy()` together? → FLAG (requires composite index, use client-side sort)
2. Is the result of `.fromMap()` used without a try-catch? → FLAG (defensive stream pattern required)
3. Does the query access another user's subcollection without a permission check? → FLAG

## Cloud Functions Checks
1. Does the function reference `conn.caregiverId`? → FLAG (should be `conn.caregiverUid`)
2. Does the function query ALL documents in a collection on a schedule? → FLAG (O(n) scaling risk)
3. Does the function do two separate writes that should be atomic? → FLAG (use batch/transaction)

## Output
One line per finding: `[CRITICAL/HIGH/MEDIUM] [file:line]: [description]. Fix: [remedy]`
```

#### 8d. Register the skills in `skills-lock.json`

Add these entries to the existing `skills-lock.json`. Open the file and add inside the `"skills"` object:

```json
"omra-ux-review": {
  "source": "local",
  "sourceType": "local",
  "skillPath": "skills/omra-ux-review/SKILL.md"
},
"omra-design-check": {
  "source": "local",
  "sourceType": "local",
  "skillPath": "skills/omra-design-check/SKILL.md"
},
"omra-security-check": {
  "source": "local",
  "sourceType": "local",
  "skillPath": "skills/omra-security-check/SKILL.md"
}
```

**Note:** Local skills don't need a `computedHash` since they're not version-pinned from a remote source. After adding, restart Claude Code to pick up the new skills.

**How to verify:** Type `/omra-ux-review` in Claude Code. If it activates and runs the checklist, it's installed. If nothing happens, check that the SKILL.md files exist in the correct paths relative to `.claude/skills/`.

---

### STEP 9 — Model Selection Protocol ⏱ 5 min (no files)

**There is nothing to install.** Model switching is built into Claude Code.

The only action: **agree with yourself on the habit:**

| You say (or think) | You type first |
|--------------------|---------------|
| "I want to plan the vitals feature" | `/model opus` then describe the task |
| "Let's implement the security fixes" | Nothing — Sonnet is default |
| "Quick question: where is X?" | `/model haiku` then ask |

The CLAUDE.md you created in Step 1 already instructs Claude to remind you when Opus would be appropriate. So in practice, Claude will say "This looks like a planning task — consider switching to `/model opus`" before you forget.

---

## PART 3 — VERIFICATION CHECKLIST

Once all steps are complete, verify the full workflow with these tests:

### Test 1: Auto-Context (confirms Step 1)
Start a brand new Claude Code session. **Do not say anything about the project.**  
Expected: Claude's first message mentions "Omra", the current version, what was last changed, and what Phase 1 items are open.  
Pass: Claude knows all this without being told ✅  
Fail: Claude asks you to explain the project → CLAUDE.md is not loading

### Test 2: Code Verification Hook (confirms Step 7)
Ask Claude to add a deliberate error to any `.dart` file inside `vitalpath_flutter/` (e.g., add an extra `{`).  
Expected: `flutter analyze` output appears in the terminal within seconds of the edit, showing the error.  
Pass: Analyzer output appears automatically ✅  
Fail: Nothing happens → check `.claude/settings.json` path and format

### Test 3: Session Continuity (confirms Steps 2 & 3)
End a session by asking Claude: "Append a summary of this session to UPDATES.md."  
Start a new session.  
Expected: Claude's opening message includes what you did in the previous session.  
Pass: Continuity confirmed ✅

### Test 4: Skill Availability (confirms Step 8)
Type `/omra-ux-review` in Claude Code.  
Expected: Claude runs the UX checklist against the last edited screen.  
Pass: Checklist runs ✅  
Fail: No response → restart Claude Code; check SKILL.md path

### Test 5: Persona-Aware UI Editing
Tell Claude: "I want to edit the patient home dashboard."  
Expected: Claude reads or references Aisha's persona without being asked, and validates any changes against her priority order.  
Pass: Persona reference is automatic ✅ (driven by CLAUDE.md instruction)

---

## SUMMARY — What You Built

```
Before setup:                    After setup:
─────────────────────────────────────────────────────────
Each session: re-explain         Each session: Claude reads
project, tech stack, issues      CLAUDE.md → knows everything

After code edit: nothing         After code edit: flutter analyze
checks correctness               runs automatically, Claude self-corrects

UX decisions: intuitive          UX decisions: validated against
(may contradict audit findings)  AUDIT_REPORT + personas

Architecture decisions:          Architecture decisions: checked
may undo past choices            against DECISIONS.md first

Planning with Sonnet:            Planning with Opus:
shallower trade-off analysis     deep reasoning, considers
                                 all cross-system implications

Session end: context lost        Session end: UPDATES.md has
                                 full record for next session
```

**Total time to set up: ~2.5 hours**  
**Benefit: saves 20,000+ tokens per session, self-correcting code, persistent memory**

---

*Guide prepared by: Claude Code (claude-sonnet-4-6)*  
*Status: Instructions only — nothing has been created yet*  
*When ready: follow Steps 1–9 in order, then run the 5 verification tests*
