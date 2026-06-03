---
name: omra-ux-review
description: >
  UX review for Omra app screens. Checks any screen against the 3 user personas in
  .claude/PERSONAS.md and the 10 app-wide UX pattern issues documented in AUDIT_REPORT.md
  Section 8. Produces a one-line-per-finding checklist with PASS/FAIL and file:line references.
  Use before and after editing any user-facing screen.
  Invoke: /omra-ux-review [screen-name]  e.g. /omra-ux-review home_screen
---

Perform a structured UX review of the named Omra screen.

## Step 1 — Identify Persona
Determine the primary persona for this screen from `.claude/PERSONAS.md`:
- `home_screen`, `care_screen`, `appointments_screen`, `invite_caregiver_screen`, `care_circle_screen` → **Aisha (Patient)**
- `doc_dashboard_screen`, `doc_patient_view_screen`, `doc_appointments_screen` → **Dr. Rahman (Doctor)**
- `caregiver_home_screen`, `caregiver_patient_profile_screen`, `accept_invite_screen` → **Karim (Family Member)**

Read the persona's **primary need**, **biggest frustrations**, **dashboard priority order**, and **UX validation questions**.

## Step 2 — Run the 10 Pattern Checks

For each check output: `P-XX [label]: PASS` or `P-XX [label]: FAIL — [specific issue at file:line]`

- **P-01 Terminology** — Any instance of "Caregiver" (UI text), "VitalPath", or "caregiver" in user-visible strings?
- **P-02 Navigation depth** — Does the screen use the correct bottom nav structure for its portal? (Patient: 4 tabs; Doctor: 4 tabs; Family Member: 3 tabs)
- **P-03 Empty state** — Is there an empty state widget for the zero-data scenario (0 medicines, 0 appointments, 0 patients)?
- **P-04 Error state** — Does the error path show a retry button, not just a message?
- **P-05 Confirmation dialogs** — Destructive action (delete/cancel) → AlertDialog with red confirm? New record (prescription/appointment) → bottom sheet preview before save?
- **P-06 Permission locks** — If a section is conditionally hidden, does it show a tooltip explaining why + a "Request access" action?
- **P-07 SnackBar format** — Does every SnackBar follow: icon + message (≤1 line) + optional [Retry] on errors?
- **P-08 Data freshness** — Is there a "Last updated X ago" indicator on dashboard screens?
- **P-09 Status indicators** — Are colour-only indicators (red/green/yellow dots) accompanied by an icon or text label?
- **P-10 Action hierarchy** — Are today's actionable tasks above trend/metric widgets on dashboard screens?

## Step 3 — Dashboard Order Check (dashboards only)

If reviewing a dashboard screen, verify the widget order matches the persona's **dashboard priority order** from `.claude/PERSONAS.md`.

For each widget that is out of order: `ORDER FAIL — [widget] at position #N, should be #M`

## Step 4 — Summary Output

```
Screen: [filename] | Persona: [name] ([role])
─────────────────────────────────────────────
P-01 Terminology:        [PASS/FAIL]
P-02 Navigation depth:   [PASS/FAIL]
P-03 Empty state:        [PASS/FAIL]
P-04 Error state:        [PASS/FAIL]
P-05 Confirm dialogs:    [PASS/FAIL]
P-06 Permission locks:   [PASS/FAIL]
P-07 SnackBar format:    [PASS/FAIL]
P-08 Data freshness:     [PASS/FAIL]
P-09 Status indicators:  [PASS/FAIL]
P-10 Action hierarchy:   [PASS/FAIL]
─────────────────────────────────────────────
[N] issues found.
Priority fix: [highest impact issue for this persona]
```
