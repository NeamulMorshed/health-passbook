# OMRA — DEVELOPMENT WORKFLOW STRATEGY REPORT
**Prepared: 2026-05-24 · Version 2.0**  
**Updated: 2026-05-24 — Added: UX/Design skills, extended memory files, model selection strategy (Opus/Sonnet/Haiku)**

> This is a planning report only. No code, no configuration, no app files are created or modified here.  
> The purpose is to document how to implement a professional, token-efficient, parallel-capable  
> development workflow for this project — one that has **zero impact on the Flutter app itself.**

---

## TABLE OF CONTENTS

1. [Executive Summary](#1-executive-summary)
2. [What We Already Have](#2-what-we-already-have)
   - 2.1 Installed Skill Suite (Caveman)
   - 2.2 Existing MD Documents
   - 2.3 Directory Structure
   - 2.4 What's Missing
   - **2.5 Skills Worth Adding (UX / Design / Product)**
3. [Parallel Agent Architecture](#3-parallel-agent-architecture)
4. [Code Verification System](#4-code-verification-system)
5. [MD File Infrastructure](#5-md-file-infrastructure)
   - 5.1 Overview
   - 5.2 CLAUDE.md — The Project Brain
   - 5.3 `.claude/UPDATES.md` — The Change Log
   - 5.4 `.claude/BACKLOG.md` — The Work Queue
   - 5.5 Reading Strategy (Token Optimization)
   - **5.6 `.claude/DESIGN_SYSTEM.md` — Visual Memory**
   - **5.7 `.claude/PERSONAS.md` — User Persona Memory**
   - **5.8 `.claude/DECISIONS.md` — Architecture Decision Records**
6. [Token Usage Optimization](#6-token-usage-optimization)
7. [Proposed File Structure](#7-proposed-file-structure)
8. [App Impact Assessment](#8-app-impact-assessment)
9. [Implementation Plan](#9-implementation-plan)
10. [Session Workflow Protocol](#10-session-workflow-protocol)
11. **[Model Selection Strategy — Opus / Sonnet / Haiku](#11-model-selection-strategy--opus--sonnet--haiku)**

---

## 1. EXECUTIVE SUMMARY

This report proposes a three-layer workflow infrastructure for the Omra project:

| Layer | Purpose | Key Files/Tools |
|-------|---------|-----------------|
| **Context Layer** | Claude remembers the project without re-reading code | `CLAUDE.md`, `.claude/UPDATES.md`, `.claude/PERSONAS.md` |
| **Verification Layer** | Code changes are automatically checked after every edit | Claude Code hooks → `flutter analyze` |
| **Parallelism Layer** | Multiple Claude agents work simultaneously on independent tasks | cavecrew skill, background Agent tool |
| **Design Layer** | Claude validates UI/UX decisions against the design system and user personas | `.claude/DESIGN_SYSTEM.md`, `.claude/PERSONAS.md`, custom skills |
| **Intelligence Layer** | The right model is used for the right job — cost and quality optimized | Opus (plan), Sonnet (build), Haiku (chat) |

**The critical constraint:** Every file, hook, and configuration lives **outside** `vitalpath_flutter/`. The Flutter app directory is never touched by workflow tooling.

---

## 2. WHAT WE ALREADY HAVE

The project has more tooling infrastructure than most projects. Before adding anything, it's worth cataloguing what's already here.

### 2.1 Installed Skill Suite (Caveman)

Located in `.claude/skills/` and registered in `skills-lock.json`:

| Skill | Purpose | How to Invoke |
|-------|---------|---------------|
| `caveman` | Ultra-compressed prose (~75% fewer tokens) | `/caveman` |
| `cavecrew` | Dispatches multiple parallel agents | `/cavecrew` |
| `caveman-commit` | Compressed commit message generation | `/caveman-commit` |
| `caveman-compress` | Compresses long outputs before storing | `/caveman-compress` |
| `caveman-help` | Help for caveman skills | `/caveman-help` |
| `caveman-review` | Compressed code review comments | `/caveman-review` |
| `caveman-stats` | Token usage statistics | `/caveman-stats` |

**Observation:** `cavecrew` is the parallel agent dispatch skill we need for large tasks. `caveman` is the token compression mode. `caveman-compress` is for compressing large agent outputs before they enter the main context. These are already available — we just need to use them consistently.

### 2.2 Existing MD Documents

| File | Content |
|------|---------|
| `AUDIT_REPORT.md` | Full technical, security, and UX audit (just created) |
| `WORKFLOW_STRATEGY_REPORT.md` | This document |

### 2.3 Directory Structure

```
.claude/
├── skills/          ← Caveman skill suite (7 skills)
└── worktrees/       ← Git worktrees for isolated agent work

.agents/
└── skills/          ← Mirror of .claude/skills
```

### 2.4 What's Missing

**Workflow infrastructure files:**
- `CLAUDE.md` — Auto-loaded project context file (most impactful missing piece)
- `.claude/UPDATES.md` — Session-by-session change log
- `.claude/BACKLOG.md` — Prioritized work backlog
- `.claude/settings.json` — Hooks configuration for code verification

**Design & product memory files:**
- `.claude/DESIGN_SYSTEM.md` — Visual design tokens, widget catalog, color conventions
- `.claude/PERSONAS.md` — The 3 user personas with needs, flows, and pain points
- `.claude/DECISIONS.md` — Architecture Decision Records (why we chose certain approaches)

**Skills not yet installed:**
- UX review skill for Omra-specific design validation
- Flutter design system checker skill
- Security pattern checker skill

**Protocol gaps:**
- No model selection strategy (Opus / Sonnet / Haiku)
- Inconsistent caveman/cavecrew usage across sessions

---

### 2.5 Skills Worth Adding (UX / Design / Product)

The Caveman suite covers developer productivity. Three additional skill categories are missing for a full design+development workflow.

#### Skill Category A: UX / Product Review

**Proposed skill: `omra-ux-review`**  
A custom skill stored in `.claude/skills/omra-ux-review/SKILL.md` that gives Claude a structured UX review checklist for any screen in this project.

When invoked with `/omra-ux-review [screen-name]`, it would:
1. Load the relevant user persona from `.claude/PERSONAS.md` (who uses this screen?)
2. Check the screen against the 10 UX pattern issues in `AUDIT_REPORT.md` Section 8
3. Verify the dashboard follows the recommended layout from `AUDIT_REPORT.md` Section 7
4. Output a structured review: what works, what's broken, priority fixes

**Example invocation:**
```
/omra-ux-review home_screen
→ Checking against Aisha persona...
→ Dashboard order: Tasks is #6 (should be #2) — FAIL
→ Status dot legend: missing — FAIL  
→ Empty state for 0 medicines: missing — FAIL
→ Refill countdown position: #9 (should be #3) — FAIL
→ Time-contextual card: present — PASS
→ Priority: [list of specific line fixes]
```

**Why this matters:** Without this, UX decisions in code are made intuitively. With it, Claude cross-references every UI change against the documented standards from the audit.

---

**Proposed skill: `omra-design-check`**  
Checks that any new or edited screen follows the Omra design system from `.claude/DESIGN_SYSTEM.md`.

When invoked, it checks:
- Are `AppColors` tokens used (never raw hex)?
- Are `BentoCard` / `BentoStatCard` / `BentoRow` widgets used correctly?
- Are `HugeIcons` used (not Material icons, unless justified)?
- Are `Google Fonts` applied via the app's font convention?
- Are spacing/padding values consistent with the design system?

---

#### Skill Category B: Security / Backend Review

**Proposed skill: `omra-security-check`**  
When Claude writes or edits a Firestore query or security rule, this skill runs a quick checklist:

- Does the query access a collection without proper auth guard?
- Is `isSignedIn()` used alone (without role/relationship check)?
- Is `doctorHasPatient()` missing on medicine/prescription writes?
- Is a new collection being introduced without rules?
- Is the query creating a new cross-patient access path?

**Why this matters:** Given the 4 critical security vulnerabilities found in the audit, Claude should always sanity-check any Firestore-related change against these patterns.

---

#### Skill Category C: External UX/Design Skills (GitHub)

Beyond custom skills, the following skill types are available on GitHub for the Claude Code skill ecosystem. These are worth exploring:

| Skill Type | What It Does | Relevance to Omra |
|------------|-------------|-------------------|
| **Figma-to-code reviewer** | Compares implemented UI to Figma spec | High — project started from Figma exports |
| **Accessibility auditor** | Checks color contrast, touch targets, screen reader labels | High — AUDIT found 4/10 accessibility score |
| **Component design system enforcer** | Validates widget usage against a defined component catalog | High — BentoCard system needs enforcement |
| **User story validator** | Checks features against acceptance criteria from user stories | Medium — useful for persona-aligned development |

These cannot be installed until the exact skill repo URLs are known. The pattern for installation is the same as the Caveman suite: find the GitHub repo, add to `skills-lock.json`, and the SKILL.md files are placed in `.claude/skills/`.

---

## 3. PARALLEL AGENT ARCHITECTURE

### 3.1 How Claude's Agent System Works

Claude Code's `Agent` tool spawns a sub-agent — a fresh Claude instance with:
- Its own context window (does not share main conversation context)
- Access to a defined set of tools (Read, Bash, Write, Edit, etc.)
- The ability to run in the **background** (main conversation continues while it works)

This is not a plugin or external service — it is built into Claude Code. No installation needed.

### 3.2 Available Agent Types in This Project

| Agent Type | Best Used For |
|------------|--------------|
| `Explore` | Finding files, grepping for symbols, mapping the codebase |
| `Plan` | Designing implementation strategy before coding |
| `general-purpose` | Multi-step research, analysis, complex investigations |
| `claude` (default) | Any task that doesn't fit a specialized type |
| `claude-code-guide` | Questions about Claude Code itself, API usage, MCP |

### 3.3 The cavecrew Skill (Already Installed)

`/cavecrew` is a meta-skill that dispatches a fleet of parallel agents for large tasks. In the previous session, we used this pattern manually (spawning 3 agents in parallel: Technical Audit, Security Audit, UX Audit). The `cavecrew` skill formalizes this into a structured dispatch command.

**When to use cavecrew vs manual Agent spawning:**
- `cavecrew` → Pre-defined fleet patterns (audit all screens, review all services, etc.)
- Manual `Agent` tool → Custom one-off parallel tasks

### 3.4 Parallel Agent Patterns for This Project

**Pattern A: Parallel Feature Implementation**
```
Task: "Add vitals trending to patient home + doctor patient view"

Agents dispatched in parallel:
├── Agent 1 (Explore): Map all vitals-related files, data models, providers
├── Agent 2 (Plan): Design the chart implementation architecture
└── Agent 3 (general-purpose): Research fl_chart API for line charts

Main agent: waits for all 3, then implements using their findings
```

**Pattern B: Parallel Audit (already used)**
```
Task: "Audit the entire codebase"

Agents dispatched in parallel:
├── Agent 1: Technical architecture audit
├── Agent 2: Security & database audit
└── Agent 3: UX & user journey simulation

Main agent: synthesizes all three into AUDIT_REPORT.md
```

**Pattern C: Parallel Screen Implementation**
```
Task: "Implement 3 new screens"

Agents dispatched in parallel (background):
├── Agent 1: Implement Patient Vitals Chart screen
├── Agent 2: Implement Doctor "Needs Attention" dashboard section
└── Agent 3: Implement Caregiver status banner

Main agent: verifies and integrates each agent's output
```

**Pattern D: Background + Foreground**
```
Task: "Fix security rules while building new feature"

Agent 1 (background): Update Firestore security rules, test them
Main agent (foreground): Implement UI feature while Agent 1 runs
When Agent 1 finishes: Review and confirm rules, continue
```

### 3.5 Agent Communication Strategy

Agents cannot directly share state, but can communicate through:

1. **Shared files** — One agent writes `.claude/UPDATES.md`, another reads it
2. **Output files** — Agent writes findings to a temp file; main agent reads it
3. **Structured prompts** — Main agent tells each sub-agent exactly what to produce and in what format, then stitches the outputs together

### 3.6 Isolation Mode (Worktrees)

For risky changes, agents can work in isolated git worktrees (`isolation: "worktree"`). The agent works on a branch copy; if it makes no changes, the worktree is auto-cleaned. This prevents any unreviewed code from reaching `main` or `feature/*` branches.

---

## 4. CODE VERIFICATION SYSTEM

### 4.1 The Problem

Currently, when Claude edits a Dart file, there is no automatic check that the code is valid. Claude must manually run `flutter analyze` to verify. If Claude makes a mistake that doesn't surface until the next `flutter build`, it's caught late — or not at all.

### 4.2 The Solution: Claude Code Hooks

Claude Code supports **hooks** — shell commands that run automatically in response to tool events. These are configured in `.claude/settings.json` (project-level) or `~/.claude/settings.json` (global).

**Hook types:**
| Hook | Trigger | When Useful |
|------|---------|-------------|
| `PreToolUse` | Before Claude calls a tool | Block risky operations, require confirmation |
| `PostToolUse` | After Claude calls a tool | Verify changes, run analysis, update logs |
| `Stop` | When Claude finishes a turn | Run build verification, update UPDATES.md |
| `Notification` | When user notification is sent | Custom alerts |

### 4.3 Proposed Hooks for This Project

#### Hook 1: Flutter Analyzer (PostToolUse after Edit/Write)
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "if echo '$CLAUDE_TOOL_INPUT' | grep -q 'vitalpath_flutter'; then cd 'vitalpath_flutter' && flutter analyze --no-fatal-infos 2>&1 | tail -30; fi"
          }
        ]
      }
    ]
  }
}
```

**What it does:** After every `Edit` or `Write` tool call on a file inside `vitalpath_flutter/`, runs `flutter analyze` and feeds the output back to Claude. If there are errors, Claude sees them immediately and can fix them before proceeding to the next task.

**Impact on app:** None. `flutter analyze` is read-only static analysis.

#### Hook 2: Dart Format Check (PostToolUse after Edit/Write on .dart files)
```json
{
  "type": "command",
  "command": "if echo '$CLAUDE_TOOL_INPUT' | grep -q '\\.dart'; then dart format --output=none --set-exit-if-changed '$CLAUDE_TOOL_INPUT_PATH' 2>&1; fi"
}
```

**What it does:** After editing a `.dart` file, checks if formatting is correct. Outputs any formatting issues. Claude can then run `dart format` to fix them.

#### Hook 3: Build Verification (on Stop)
```json
{
  "hooks": {
    "Stop": [
      {
        "type": "command",
        "command": "cd vitalpath_flutter && flutter build apk --debug --no-pub 2>&1 | tail -10"
      }
    ]
  }
}
```

**What it does:** When Claude finishes a major task (conversation turn ends), runs a debug APK build to confirm the code compiles. Output is shown in the terminal.

**Note:** This is relatively slow (~60–90s). Configure only for sessions where significant code changes are expected. Can be commented out for analysis-only sessions.

### 4.4 How Hooks Feed Back Into Claude

When a hook runs, its `stdout` is injected into Claude's context as a system message. Claude sees the analyzer output without being explicitly asked. This creates a **self-correcting loop:**

```
Claude edits file
  → PostToolUse hook fires
  → flutter analyze runs
  → Output injected into Claude's context
  → If errors found: Claude reads them, fixes them, re-edits
  → If clean: Claude continues to next task
```

### 4.5 Scope Restriction

Hooks should only run on `vitalpath_flutter/` files. This ensures that editing `CLAUDE.md`, `AUDIT_REPORT.md`, or `.claude/UPDATES.md` does not trigger a Flutter analysis run.

---

## 5. MD FILE INFRASTRUCTURE

### 5.1 Overview

Four markdown files form the "memory" layer of Claude's workflow:

```
CLAUDE.md                ← Session context (auto-loaded)
.claude/UPDATES.md       ← Change history (Claude reads + appends)
.claude/BACKLOG.md       ← Work queue (Claude updates as tasks complete)
AUDIT_REPORT.md          ← Full audit (reference only, not updated frequently)
```

### 5.2 CLAUDE.md — The Project Brain

**Location:** `/project-root/CLAUDE.md`

**Behaviour:** Claude Code automatically reads `CLAUDE.md` at the start of every session (it is loaded as part of the system context). This eliminates the need to re-explain the project, its conventions, and its current state every time a new session starts.

**What to put in CLAUDE.md:**

```markdown
# Omra — Project Context (Claude reads this every session)

## App Identity
- Name: Omra (package: vitalpath)
- Platform: Flutter/Dart, Firebase backend
- Version: 2.11.0+35
- Branch convention: feature/*, fix/*, bump/* against main

## Tech Stack
- Flutter + Riverpod (ConsumerWidget, StreamProvider.family, StateNotifier)
- GoRouter with role-based route guards
- Firebase: Firestore, Auth, Storage, Messaging, Cloud Functions (TypeScript)
- Google Fonts, HugeIcons, fl_chart, flutter_svg

## Three User Roles
- Patient → portal at /home, AppColors.primary
- Doctor → portal at /doc/*, AppColors.doctor
- Family Member → portal at /caregiver/*, AppColors.caregiver (#F59E0B amber)

## Key File Map
- lib/screens/patient/home/home_screen.dart — Patient dashboard (~1150 lines)
- lib/screens/doctor/doc_dashboard_screen.dart — Doctor dashboard
- lib/screens/caregiver/home/caregiver_home_screen.dart — Family member home
- lib/services/firestore_service.dart — All Firestore queries
- lib/models/ — Data models (Appointment, Medicine, Prescription, etc.)
- firestore.rules — Security rules (has CRITICAL vulnerabilities — see AUDIT_REPORT.md)
- functions/src/index.ts — Cloud Functions

## Conventions
- Terminology: "Family Member" (not "caregiver") in all UI text
- Widgets: BentoCard, BentoStatCard, BentoRow, BentoSectionHeader
- Colors: Always use AppColors tokens, never raw hex
- No dependency_overrides in pubspec.yaml

## Current Known Issues (from AUDIT_REPORT.md)
- S-01: allow list on appointments/prescriptions/vitals leaks all medical data
- S-06: checkMissedDoses uses conn.caregiverId (should be conn.caregiverUid) — FCM broken
- See AUDIT_REPORT.md Section 3 for full security findings

## Firebase App Distribution
- App ID: 1:768599207887:android:a365080e6a086985736cba
- Deploy: firebase appdistribution:distribute path/to/app.apk --app [APP_ID] --groups testers

## See Also
- AUDIT_REPORT.md — Full technical, security, and UX audit
- .claude/UPDATES.md — Recent changes log
- .claude/BACKLOG.md — Prioritized work queue
```

**Key benefit:** When a new Claude session starts, it reads `CLAUDE.md` first. Claude immediately knows the app architecture, the Firebase app ID, the terminology convention, the widget system, and the current security issues — without reading a single source file.

### 5.3 `.claude/UPDATES.md` — The Change Log

**Location:** `/project-root/.claude/UPDATES.md`

**Purpose:** A reverse-chronological log of every meaningful change made to the project, written and maintained by Claude. At the start of any session, Claude reads this file to understand what has already been done, what version the app is at, and what the last known state was.

**Format:**
```markdown
# Omra — Update Log
<!-- Claude: Append new entries at the TOP of this file. Most recent first. -->

---
## 2026-05-24 · v2.11.0+35
**Session:** Audit + workflow strategy
**Changed files:**
- AUDIT_REPORT.md (new) — Full technical/security/UX audit
- WORKFLOW_STRATEGY_REPORT.md (new) — This workflow plan

**Key findings recorded:**
- 4 critical Firestore security rule vulnerabilities (see AUDIT_REPORT.md S-01–S-04)
- Cloud Function FCM field name bug (S-06) — family member notifications broken
- 20 prioritized UX recommendations across 4 phases

**Next session should:**
- Start with Phase 1 critical security fixes (S-01 through S-06)
- No version bump needed for rules-only changes

---
## 2026-05-24 · v2.11.0+35
**Session:** Family member medicines card fix
**Changed files:**
- lib/screens/caregiver/home/caregiver_home_screen.dart — Full-width medicines card
- pubspec.yaml — Bumped from +34 to +35
- release_notes.txt — Updated

---
## [Earlier entries...]
```

**How Claude uses it:**
- Session start → Read first 100 lines of `UPDATES.md` → know current state
- Session end → Append new entry at the top → next Claude session picks up immediately

### 5.4 `.claude/BACKLOG.md` — The Work Queue

**Location:** `/project-root/.claude/BACKLOG.md`

**Purpose:** A living, prioritized list of tasks derived from `AUDIT_REPORT.md`. As Claude completes tasks, it updates the checkboxes in this file. This prevents duplicate work across sessions and makes it clear what's next.

**Format:**
```markdown
# Omra — Development Backlog
<!-- Source: AUDIT_REPORT.md · Last reviewed: 2026-05-24 -->
<!-- Claude: Update checkboxes as tasks complete. Add new tasks at appropriate priority. -->

## Phase 1 — CRITICAL (Security Fixes)
- [ ] S-01: Fix `allow list: if isSignedIn()` on appointments/prescriptions/vitals
- [ ] S-02: Block userType self-write in Firestore rules  
- [ ] S-03: Add doctorHasPatient() check on medicine writes
- [ ] S-04: Add doctorHasPatient() check on prescription writes
- [ ] S-06: Fix conn.caregiverId → conn.caregiverUid in Cloud Function
- [ ] S-08: Wrap invite acceptance in Firestore batch write

## Phase 2 — HIGH (Core Workflow)
- [ ] UX-1: Patient health profile onboarding screen
- [ ] UX-2: Doctor sends push notification on appointment confirmation
- [ ] UX-3: Prescription confirmation dialog (review before save)
...

## Phase 3 — HIGH (Collaboration Features)
- [ ] UX-8: Vitals trending charts
- [ ] UX-9: Nudge follow-up feedback
...

## Completed ✓
- [x] Fix caregiver medicines card → full-width (v2.11.0+35)
- [x] Fix doctor dashboard "Failed to load" (v2.11.0+34)
- [x] Replace all "caregiver" UI text → "family member" (v2.11.0+33)
- [x] Fix _ConnectedPatientCard compile error (v2.11.0+33)
```

### 5.5 Reading Strategy (Token Optimization)

These files should be read selectively, not in full every session:
- `CLAUDE.md` → Auto-loaded (entire file; keep it under 200 lines)
- `.claude/UPDATES.md` → Read only the top 80–100 lines (most recent entries)
- `.claude/BACKLOG.md` → Read Phase 1 and Phase 2 sections only; skip Completed
- `.claude/DESIGN_SYSTEM.md` → Read only the section relevant to the current screen being worked on
- `.claude/PERSONAS.md` → Read only the persona relevant to the current screen being worked on
- `.claude/DECISIONS.md` → Read only when making a new architectural decision (check for prior decisions first)
- `AUDIT_REPORT.md` → Read specific sections by jumping to line offsets; never read fully unless doing a new audit cycle

---

### 5.6 `.claude/DESIGN_SYSTEM.md` — Visual Memory

**Location:** `/project-root/.claude/DESIGN_SYSTEM.md`

**Purpose:** Captures the Omra visual design language so Claude never makes design decisions without referencing it. Without this file, Claude might use a raw hex color, pick the wrong widget, or use a Material icon when a HugeIcon exists. With it, every UI change is grounded in the established system.

**What to put in it:**

```markdown
# Omra — Design System Reference

## Color Tokens (AppColors)
| Token | Hex | Usage |
|-------|-----|-------|
| primary | #3B82F6 | Patient portal — CTAs, highlights |
| caregiver | #F59E0B | Family Member portal — amber accents |
| caregiverLight | #FEF3C7 | Family Member background fills |
| inviteAccent | #7C3AED | Invite flows, purple accents |
| mutedForeground | #6B7280 | Secondary text |
| destructive | #EF4444 | Errors, delete actions |
RULE: Never use raw hex. Always use AppColors.tokenName.

## Typography
- All fonts via Google Fonts (Nunito for body, Poppins for headings)
- Heading sizes: 22px (h1), 18px (h2), 15px (h3)
- Body: 14px regular, 12px caption

## Icon System
- Primary: HugeIcons package (strokeRounded variants)
- Fallback: Material Icons only if HugeIcons has no equivalent
- Size: 20px inline, 24px standalone, 18px in stat cards

## Widget Catalog
| Widget | Purpose | Example Usage |
|--------|---------|---------------|
| BentoCard | Standard content card | Medicine list, vital readings |
| BentoStatCard | Single metric display | Step count, streak |
| BentoRow | Side-by-side bento layout | Two stat cards together |
| BentoSectionHeader | Section title with optional action | "Your Medicines" + "See all" |

## Spacing Convention
- Card padding: 16px all sides
- Card-to-card gap: 12px
- Section gap: 24px
- Icon-to-text gap: 12px (horizontal), 8px (vertical)

## Role Color Mapping
- Patient UI: primary blue
- Doctor UI: AppColors.doctor (green tones)
- Family Member UI: AppColors.caregiver (amber)

## Portal Navigation Structure
- Patient: Bottom nav (Home / Care / Appointments / Profile)
- Doctor: Bottom nav (Dashboard / Patients / Appointments / Profile)  
- Family Member: Bottom nav (Home / My Family / Profile)
```

**How Claude uses it:**  
Before implementing any UI widget or choosing a color, Claude reads the relevant section of this file. If Claude writes `Color(0xFFF59E0B)` instead of `AppColors.caregiver`, this file catches it.

---

### 5.7 `.claude/PERSONAS.md` — User Persona Memory

**Location:** `/project-root/.claude/PERSONAS.md`

**Purpose:** Captures the three user personas so every feature decision, dashboard design, and UX flow can be validated against real user needs. Without this, Claude makes features that technically work but don't fit the actual user's mental model or daily context.

**What to put in it:**

```markdown
# Omra — User Personas

## Persona 1: Aisha Hassan (Patient)
- Age: 42 | Condition: Type 2 Diabetes + mild hypertension
- Daily routine: Takes 3 medicines (morning, noon, evening), logs meals, tracks BP/glucose
- Primary need: Know what to do RIGHT NOW (not trends, not stats — today's action)
- Secondary need: Feel in control of her health, not overwhelmed
- Biggest frustration: Generic dashboards that don't tell her what's urgent
- Key screens: home_screen, medicines, care_circle, appointments
- Dashboard priority order: Urgent alerts → Today's tasks → Next appointment → Trends

## Persona 2: Dr. Rahman (Doctor)
- Specialty: Cardiology | Practice: Multi-patient
- Daily routine: Reviews pending requests, confirms appointments, writes prescriptions
- Primary need: Know which patients need attention TODAY (non-compliant, abnormal readings)
- Secondary need: Fast prescription writing, clean appointment management
- Biggest frustration: Dashboard shows counts but not WHO needs action
- Key screens: doc_dashboard, doc_patient_view, doc_appointments
- Dashboard priority order: Needs attention → Today's schedule → Pending requests → Quick actions

## Persona 3: Karim Hassan (Family Member / Husband)
- Relationship: Aisha's husband | Context: Worries but doesn't want to hover
- Daily routine: Checks app once or twice a day to see if Aisha is on track
- Primary need: At-a-glance "Is she OK?" — green/red status in 2 seconds
- Secondary need: Gentle nudge capability when she misses something
- Biggest frustration: Having to navigate 3 screens to find out if meds are taken
- Key screens: caregiver_home, caregiver_patient_profile
- Dashboard priority order: Status banner → Quick actions (nudge) → Detail (medicines/vitals)

## Validation Questions (for any new feature)
1. Which persona does this feature primarily serve?
2. Does it reduce or increase the number of taps to their primary need?
3. Does the information hierarchy match their priority order?
4. Would Karim understand this at 11pm on a tired day?
5. Would Aisha see the actionable item without scrolling?
```

**How Claude uses it:**  
When implementing a new screen or modifying a dashboard, Claude reads the relevant persona section. If a change adds a new card above "Upcoming Tasks" on the patient home, Claude checks: does this serve Aisha's primary need better than what it's displacing?

---

### 5.8 `.claude/DECISIONS.md` — Architecture Decision Records

**Location:** `/project-root/.claude/DECISIONS.md`

**Purpose:** A log of significant architectural and product decisions — what was decided, why, and what alternatives were considered. This prevents re-debating the same questions across sessions and ensures Claude doesn't "undo" a deliberate decision without knowing it was deliberate.

**What to put in it:**

```markdown
# Omra — Architecture Decision Records (ADRs)

## ADR-001: Client-Side Sorting Instead of Firestore orderBy
- Date: 2026-05
- Decision: Remove orderBy('createdAt') from Firestore queries; sort client-side
- Reason: Composite indexes were failing; orderBy + where requires a deployed index;
  client-side sort on <100 items has negligible performance cost
- Impact: watchDoctorAppointments, watchPatientAppointments
- Status: Implemented (v2.11.0+34)

## ADR-002: Family Member Terminology (Not "Caregiver")
- Date: 2026-05
- Decision: All UI text uses "Family Member" instead of "Caregiver"
- Reason: App is designed for family monitoring, not professional care;
  "caregiver" implies medical professional; misleads users on the app's purpose
- Exceptions: Internal code variables/filenames may still say "caregiver" (refactor later)
- Status: Implemented (v2.11.0+33)

## ADR-003: Defensive Stream Pattern (try-catch in fromMap)
- Date: 2026-05
- Decision: Wrap Appointment.fromMap() in try-catch inside stream .map()
- Reason: One bad Firestore document should not crash the entire stream;
  type mismatches (e.g., patientRating stored as double) cause cast failures
- Pattern: whereType<Appointment>() to filter nulls after catch
- Status: Implemented (v2.11.0+34)

## ADR-004: Firestore Security Rules — UNRESOLVED
- Date: 2026-05
- Decision: [PENDING] Must fix allow list:if isSignedIn() before production
- See: AUDIT_REPORT.md S-01 through S-04
- Status: Not yet implemented — Phase 1 critical

## ADR-005: No dependency_overrides in pubspec.yaml
- Date: 2026-05
- Decision: Never add dependency_overrides; use canonical Firebase v3/v5 stack
- Reason: Previous overrides caused pigeon bridge crashes; golden stack resolves at source
- Status: Permanent policy
```

**How Claude uses it:**  
At the start of any session involving architecture changes, Claude reads `DECISIONS.md`. If Claude is about to add `orderBy` back to a Firestore query, it sees ADR-001 and understands this was a deliberate choice, not an omission.

---

## 6. TOKEN USAGE OPTIMIZATION

### 6.1 Current State

The Caveman skills are already installed. This is the biggest token optimization available — `/caveman` reduces Claude's prose output by ~75% without losing technical accuracy. The key is using it consistently for development sessions (not needed for user-facing reports like this one).

### 6.2 Token Optimization Strategies

#### Strategy 1: CLAUDE.md Amortization
Without `CLAUDE.md`, every new session requires Claude to re-read 3–5 source files to understand the project (pubspec.yaml, app structure, firestore rules, etc.) — consuming ~15,000–25,000 tokens per session just for orientation.

With `CLAUDE.md` (200 lines ≈ 3,000 tokens), Claude gets full context in one read. The remaining 22,000 tokens are available for actual work.

**Estimated savings: 15,000–22,000 tokens per session.**

#### Strategy 2: Subagents Protect Main Context
When a task requires exploring 10+ files (e.g., "find all screens that use HugeIcons"), spawning an `Explore` agent keeps those file contents out of the main context window. The agent returns only a summary (e.g., 200 lines) instead of the raw file contents (could be 5,000+ lines).

**Estimated savings: 3,000–8,000 tokens per exploration task.**

#### Strategy 3: Selective File Reading
Using `Read` with `offset` and `limit` parameters instead of reading entire large files:
- `firestore_service.dart` (~800 lines) → Read only the relevant 50-line function instead
- `home_screen.dart` (~1150 lines) → Read only the section being modified

**Estimated savings: 2,000–5,000 tokens per file access.**

#### Strategy 4: caveman-compress for Agent Outputs
When a background agent returns a large output (like the 3 audit agents in the previous session), use `/caveman-compress` to compress the output before incorporating it into the main context.

**Estimated savings: 50–70% reduction in agent output tokens.**

#### Strategy 5: Caveman Mode for Dev Sessions
For any session involving code changes (vs. user-facing reports), activate `/caveman` at the start. Claude's explanations become 75% shorter; code blocks are unchanged. Over a 2-hour dev session, this can save 30,000–50,000 tokens.

**How to activate:** Start session with `/caveman` — it persists for the entire session.

#### Strategy 6: TodoWrite for Session State
Using `TodoWrite` to maintain task state across turns within a session means Claude doesn't need to re-summarize what it's done. The todo list serves as the working memory, freeing context for actual code.

### 6.3 Token Budget Reference

| Operation | Approximate Token Cost |
|-----------|----------------------|
| Reading `CLAUDE.md` (200 lines) | ~3,000 |
| Reading `home_screen.dart` in full | ~18,000 |
| Reading `.claude/UPDATES.md` (top 80 lines) | ~1,200 |
| One parallel agent output (full) | ~20,000–40,000 |
| One parallel agent output (caveman-compressed) | ~6,000–12,000 |
| `flutter analyze` output (clean) | ~200 |
| `flutter analyze` output (with errors) | ~500–2,000 |
| caveman mode prose for 1 hour dev session | ~15,000 |
| normal mode prose for 1 hour dev session | ~60,000 |

---

## 7. PROPOSED FILE STRUCTURE

All new files are outside `vitalpath_flutter/`. The Flutter app is completely isolated.

```
/Health Passbook/                          ← Project root
│
├── CLAUDE.md                              ← [NEW] Auto-loaded by Claude Code every session
│                                            Project context, conventions, file map, known issues
│
├── AUDIT_REPORT.md                        ← [EXISTS] Full technical/security/UX audit
│
├── WORKFLOW_STRATEGY_REPORT.md            ← [EXISTS] This document
│
├── .claude/
│   ├── settings.json                      ← [NEW] Hook configuration (code verification)
│   │                                        Contains flutter analyze PostToolUse hook
│   │
│   ├── UPDATES.md                         ← [NEW] Session change log
│   │                                        Reverse-chronological, Claude appends each session
│   │
│   ├── BACKLOG.md                         ← [NEW] Prioritized task backlog
│   │                                        Derived from AUDIT_REPORT.md, checkboxes
│   │
│   ├── DESIGN_SYSTEM.md                   ← [NEW] Visual design memory
│   │                                        AppColors, widgets, icons, spacing, typography
│   │
│   ├── PERSONAS.md                        ← [NEW] User persona memory
│   │                                        Aisha / Dr. Rahman / Karim — needs, flows, priorities
│   │
│   ├── DECISIONS.md                       ← [NEW] Architecture Decision Records
│   │                                        Why we chose each pattern (prevents re-debating)
│   │
│   ├── skills/                            ← [EXISTS] Caveman skill suite (7 skills)
│   │   ├── caveman/
│   │   ├── cavecrew/
│   │   ├── caveman-commit/
│   │   ├── caveman-compress/
│   │   ├── caveman-help/
│   │   ├── caveman-review/
│   │   ├── caveman-stats/
│   │   ├── omra-ux-review/                ← [NEW] Custom UX review skill for this project
│   │   ├── omra-design-check/             ← [NEW] Design system enforcement skill
│   │   └── omra-security-check/           ← [NEW] Firestore security pattern checker
│   │
│   └── worktrees/                         ← [EXISTS] Git worktrees for agent isolation
│
├── .agents/                               ← [EXISTS] Agent skill mirror
│   └── skills/
│
├── skills-lock.json                       ← [EXISTS] Skill version lock file
│
└── vitalpath_flutter/                     ← [UNTOUCHED] Flutter application
    ├── lib/
    ├── android/
    ├── firestore.rules
    ├── firestore.indexes.json
    ├── pubspec.yaml
    └── ...
```

**Total new files proposed: 10**
- `CLAUDE.md` (project root) — project brain, auto-loaded
- `.claude/settings.json` — code verification hooks
- `.claude/UPDATES.md` — session change log
- `.claude/BACKLOG.md` — prioritized task backlog
- `.claude/DESIGN_SYSTEM.md` — visual design memory
- `.claude/PERSONAS.md` — user persona memory
- `.claude/DECISIONS.md` — architecture decision records
- `.claude/skills/omra-ux-review/SKILL.md` — UX review skill
- `.claude/skills/omra-design-check/SKILL.md` — design system checker skill
- `.claude/skills/omra-security-check/SKILL.md` — security pattern checker skill

---

## 8. APP IMPACT ASSESSMENT

### 8.1 Files That Touch the Flutter App: NONE

| Proposed Addition | Location | Touches `vitalpath_flutter/`? |
|------------------|----------|-------------------------------|
| `CLAUDE.md` | Project root | No |
| `.claude/settings.json` | `.claude/` | No |
| `.claude/UPDATES.md` | `.claude/` | No |
| `.claude/BACKLOG.md` | `.claude/` | No |
| `.claude/DESIGN_SYSTEM.md` | `.claude/` | No |
| `.claude/PERSONAS.md` | `.claude/` | No |
| `.claude/DECISIONS.md` | `.claude/` | No |
| `.claude/skills/omra-ux-review/` | `.claude/skills/` | No |
| `.claude/skills/omra-design-check/` | `.claude/skills/` | No |
| `.claude/skills/omra-security-check/` | `.claude/skills/` | No |
| Caveman mode (`/caveman`) | Runtime only | No |
| Parallel agents | Runtime only | No |
| Model selection strategy | Protocol only | No |
| Flutter analyze hook | Runs `flutter analyze` (read-only) | Read-only, no writes |

### 8.2 `flutter analyze` is Read-Only

The code verification hook runs `flutter analyze`, which:
- Reads Dart source files
- Outputs analysis results
- Does **not** modify any files
- Does **not** affect build artifacts
- Does **not** affect the running app

### 8.3 Git Impact

None of the proposed files need to be committed to the git repository. They can be added to `.gitignore`:

```gitignore
# Claude workflow files (local only)
CLAUDE.md
WORKFLOW_STRATEGY_REPORT.md
.claude/settings.json
.claude/UPDATES.md
.claude/BACKLOG.md
```

Or they can be committed — `CLAUDE.md` in particular is valuable to commit so any team member using Claude Code gets the same context automatically.

### 8.4 CI/CD Impact

None. The proposed hooks run only inside Claude Code sessions. They do not modify CI configuration, Fastlane, Firebase App Distribution pipelines, or any build scripts.

---

## 9. IMPLEMENTATION PLAN

When you are ready to implement, the order of operations is:

### Step 1: Create `CLAUDE.md` (30 min)
The highest-value single action. Once this file exists, every future session starts with full project context automatically. Content sourced from `AUDIT_REPORT.md` + knowledge from this session.

**What's in it:** Tech stack, file map, role descriptions, widget system, known issues summary, Firebase app ID, terminology conventions, pointers to other MD files.

### Step 2: Create `.claude/UPDATES.md` (15 min)
Bootstrap the change log with the last 5–6 significant sessions from memory. Then commit to appending every session forward.

**What's in it:** Reverse-chronological list of sessions, what was changed, what version was bumped to, what the next session should focus on.

### Step 3: Create `.claude/BACKLOG.md` (20 min)
Convert `AUDIT_REPORT.md` Section 9 (priority recommendations) into a checkbox list. All 20 recommendations mapped to Phase 1–4 with checkboxes. This becomes the single source of truth for "what to do next."

### Step 4: Configure `.claude/settings.json` (15 min)
Add the PostToolUse hook for `flutter analyze`. Test it by making a deliberate syntax error, confirming the hook catches it, then reverting.

**Validation:** Edit a Dart file → see `flutter analyze` output appear in terminal automatically.

### Step 5: Create `.claude/DESIGN_SYSTEM.md` (20 min)
Extract the design token list, widget catalog, and spacing conventions from the current codebase. Content sourced from `app_colors.dart`, `bento_card.dart`, and existing screen patterns.

**What's in it:** AppColors token table, widget catalog, icon rules, typography scale, spacing conventions, role-to-color mapping.

### Step 6: Create `.claude/PERSONAS.md` (15 min)
Transcribe the three user personas from `AUDIT_REPORT.md` Sections 4.1, 4.2, and 4.3 into the persona template format.

**What's in it:** Aisha, Dr. Rahman, Karim — age/context, primary need, secondary need, biggest frustration, key screens, dashboard priority order.

### Step 7: Create `.claude/DECISIONS.md` (20 min)
Document the 5 known architectural decisions already made (client-side sort, terminology, defensive streams, security rules TODO, no dependency_overrides). This is the baseline; Claude adds to it as new decisions are made.

### Step 8: Create the 3 Custom Skills (45 min)
Write three `SKILL.md` files in `.claude/skills/`:
- `omra-ux-review/SKILL.md` — UX checklist referencing AUDIT_REPORT + PERSONAS
- `omra-design-check/SKILL.md` — Design system enforcement referencing DESIGN_SYSTEM
- `omra-security-check/SKILL.md` — Firestore security checklist

Each is a simple markdown file with a name, description, and structured checklist. No code required.

### Step 9: Establish Caveman Protocol (5 min)
Agree on when to use `/caveman`:
- **Use:** Any development session (code changes, debugging, refactoring)
- **Don't use:** User-facing reports, planning documents, audit reports

### Step 10: Establish Model Selection Protocol (5 min — ongoing)
Agree on the Opus / Sonnet / Haiku routing rules from Section 11. Start using `/model opus` for planning sessions, default Sonnet for development, Haiku for quick questions.

See Section 11 for full decision framework.

### Step 11: Establish Session Start Protocol (ongoing)
At the start of each session:
1. Claude reads `CLAUDE.md` (auto-loaded)
2. Claude reads top 80 lines of `.claude/UPDATES.md` (most recent 2–3 sessions)
3. Claude reads `.claude/BACKLOG.md` Phase 1 section
4. If UI work: Claude reads the relevant persona from `.claude/PERSONAS.md`
5. If architecture work: Claude reads `.claude/DECISIONS.md`
6. Claude is immediately oriented: project state, design standards, user needs, what's next

---

## 10. SESSION WORKFLOW PROTOCOL

Once everything is set up, the recommended working pattern for each session:

### Session Start
```
Claude reads:
  → CLAUDE.md (auto-loaded, ~3,000 tokens)
  → .claude/UPDATES.md (top 80 lines, ~1,200 tokens)
  → .claude/BACKLOG.md Phase 1 (50 lines, ~750 tokens)

Total orientation cost: ~5,000 tokens (vs. 20,000+ without this infrastructure)
```

### During Development
```
For large research tasks   → spawn Explore agent (protect main context)
For large implementations  → spawn background agents via /cavecrew
For code edits             → PostToolUse hook runs flutter analyze automatically
For token savings          → activate /caveman at session start for dev sessions
For task tracking          → use TodoWrite to maintain in-session state
For UI/UX decisions        → invoke /omra-ux-review [screen] before and after changes
For design decisions       → read .claude/DESIGN_SYSTEM.md relevant section
For architecture decisions → read .claude/DECISIONS.md, then add new ADR if needed
For planning new features  → switch to Opus model (/model opus) before planning
For quick questions        → switch to Haiku model (/model haiku)
```

### Session End
```
Claude appends to .claude/UPDATES.md:
  - Date + version
  - Files changed (list)
  - Summary of what was done
  - What next session should focus on

Claude updates .claude/BACKLOG.md:
  - Check off completed items
  - Add any new items discovered
```

### For Large Multi-Day Features (e.g., "Add vitals trending")
```
Session 1: Plan agent designs architecture → .claude/UPDATES.md captures plan
Session 2: Claude reads UPDATES.md → continues from plan, no re-explanation needed
Session 3: Claude reads UPDATES.md → continues from previous progress
```

---

## 11. MODEL SELECTION STRATEGY — OPUS / SONNET / HAIKU

This is the most strategically important section for cost efficiency and output quality. Claude Code's three available models have fundamentally different capabilities, speeds, and costs. Using the wrong model for a task either wastes money (Opus for trivial tasks) or produces shallow output (Haiku for deep architectural work).

### 11.1 The Three Models

| Model | ID | Strength | Speed | Cost | Best For |
|-------|-----|---------|-------|------|---------|
| **Claude Opus 4.7** | `claude-opus-4-7` | Maximum reasoning depth, architectural thinking, multi-variable trade-off analysis | Slowest | Highest | Planning, security analysis, complex UX strategy |
| **Claude Sonnet 4.6** | `claude-sonnet-4-6` | Balanced capability + speed, strong coding | Fast | Medium | All development work, debugging, implementation |
| **Claude Haiku 4.5** | `claude-haiku-4-5-20251001` | Conversational, fast lookups, simple edits | Fastest | Lowest | Quick questions, file lookups, clarifications |

---

### 11.2 Decision Framework — Which Model to Use

#### Use OPUS when the task requires:

**Deep architectural planning**
- Designing a new feature from scratch (e.g., "Design the vitals trending architecture")
- Planning a migration (e.g., "Design the fix for the 4 Firestore security vulnerabilities")
- Evaluating trade-offs with multiple variables (e.g., "Should we use FCM topics or individual tokens for family member notifications?")

**Security-critical analysis**
- Writing new Firestore security rules (getting them wrong has production consequences)
- Designing the `doctorHasPatient()` function and all its edge cases
- Auditing new features against known vulnerability patterns

**Cross-system UX strategy**
- Designing a new flow that affects all three portals (e.g., "Design the doctor→patient notification system")
- Planning dashboard reorganizations (understanding all ripple effects)
- Designing the messaging system that must work across patient, doctor, and caregiver roles

**Product decisions with long-term consequences**
- Feature prioritization from the backlog (which Phase 2 item to do first, and why)
- Deciding whether to add a new Firebase collection vs. subcollection
- Any decision that will create an ADR in `.claude/DECISIONS.md`

**Trigger phrases that should route to Opus:**
- "Plan the...", "Design the architecture for...", "What's the best approach to..."
- "How should we...", "Think through...", "Strategy for..."
- Anything in Phase 1 security fixes (consequences of getting it wrong are high)
- Any question with "trade-offs" or "implications" or "impact on all three portals"

---

#### Use SONNET when the task requires:

**Standard implementation**
- Writing Dart code for a feature that has already been planned
- Fixing a specific bug from the backlog
- Updating a screen's widget layout
- Writing Firestore queries (from a known design)
- Implementing a new route in the router
- Any task where the approach is clear and it's execution work

**Code review and analysis**
- Running `flutter analyze` and interpreting results
- Reading a screen file and identifying issues
- Comparing current implementation to a design spec

**Documentation and reporting**
- Writing `AUDIT_REPORT.md` style analysis (structured, detailed)
- Updating `.claude/UPDATES.md` and `.claude/BACKLOG.md`
- Writing SKILL.md files for custom skills

**Multi-step development sessions**
- Any full development session where code will be edited
- Bug fix sessions with moderate complexity
- Feature implementation from a pre-existing plan

**Trigger phrases that route to Sonnet (default):**
- "Implement...", "Fix...", "Build...", "Add...", "Update..."
- "Read this file and...", "Find the issue in...", "Write the code for..."
- Most requests during active development

---

#### Use HAIKU when the task requires:

**Quick factual lookups**
- "What's the AppColors.caregiver hex value?"
- "Where is the `watchDoctorAppointments` function?"
- "What version is the app at?"
- "Which file contains the BentoCard widget?"

**Simple confirmations**
- "Does this file exist?" (use Bash/Read directly instead of a long conversation)
- "What branch am I on?"
- "Show me the last 5 git commits"

**Light conversational back-and-forth**
- Asking for clarifications on a task before starting
- Checking if a plan sounds right before executing
- Quick questions during a development session that don't need deep reasoning

**Simple formatting/renaming tasks**
- "Rename this variable in this file"
- "Change this string from X to Y"
- "Format this JSON"

**Trigger phrases that route to Haiku:**
- "What is...", "Where is...", "Which file...", "Show me...", "List..."
- "Quick question:", "Just checking:", "Can you confirm..."
- Any question that has a definitive, factual answer

---

### 11.3 Model Routing by Task Type (Omra-Specific)

| Task | Model | Reason |
|------|-------|--------|
| Fix Firestore security rules (S-01–S-04) | **Opus** | Security consequences; complex rule logic |
| Fix `checkMissedDoses` field name bug | **Haiku** | Simple rename in Cloud Function |
| Design vitals trending architecture | **Opus** | Cross-system design; data model implications |
| Implement vitals chart widget | **Sonnet** | Execution from plan; standard Flutter code |
| Quick: "What's the Firebase App ID?" | **Haiku** | Single factual lookup |
| Design doctor monitoring dashboard section | **Opus** | UX strategy; affects doctor workflow |
| Implement the "Needs Attention" widget | **Sonnet** | Code from design |
| Review a PR / code diff | **Sonnet** | `/caveman-review` + Sonnet |
| Plan Phase 2 implementation order | **Opus** | Prioritization requires deep trade-off analysis |
| Fix a null pointer bug | **Sonnet** | Debugging; code analysis |
| "Is my understanding of the BentoCard system correct?" | **Haiku** | Quick confirmation |
| Design the nudge follow-up system | **Opus** | Cross-user interaction; new data model |
| Implement nudge read receipt UI | **Sonnet** | UI code from design |
| Audit a new screen for UX issues | **Sonnet** | `/omra-ux-review` + Sonnet |
| Write a new Firestore query | **Sonnet** | Standard query pattern |
| Design permissions model for new caregiver feature | **Opus** | Security + UX + data model all together |

---

### 11.4 How to Switch Models in Claude Code

**Method 1: In-conversation command**  
Type `/model opus` to switch the current session to Opus.  
Type `/model sonnet` to switch back to Sonnet.  
Type `/model haiku` to switch to Haiku.

**Method 2: Per-Agent model specification**  
When spawning a sub-agent for planning, specify the model:
```
Agent(
  subagent_type: "Plan",
  model: "opus",        ← explicit Opus for planning agents
  prompt: "..."
)
```

When spawning an Explore agent for quick lookups:
```
Agent(
  subagent_type: "Explore",
  model: "haiku",       ← Haiku for simple search tasks
  prompt: "Find where X is defined..."
)
```

**Method 3: Session intent as a natural trigger**  
At the start of a session, stating the intent routes automatically:
- "I want to plan the vitals trending feature" → Claude should suggest switching to Opus
- "Let's implement the security fixes from the backlog" → Sonnet is appropriate
- "Quick question about the design system" → Haiku is appropriate

---

### 11.5 Model Cost Optimization Pattern for This Project

**The Opus-plans, Sonnet-builds, Haiku-checks pattern:**

```
Phase 1 — Planning (Opus, short session)
  → Opus designs the architecture/approach
  → Opus writes the plan into .claude/DECISIONS.md or a feature spec
  → Session ends (Opus cost is bounded by session length)

Phase 2 — Building (Sonnet, main session)
  → Sonnet reads the Opus plan from DECISIONS.md
  → Sonnet implements without needing to re-plan
  → PostToolUse hook verifies code automatically
  → Session produces working code

Phase 3 — Verification (Haiku, very short)
  → Haiku confirms specific lookups ("Is the correct field name caregiverUid?")
  → Haiku summarizes what was done for UPDATES.md
  → No expensive model time wasted on confirmations
```

**Estimated cost profile per feature cycle:**
- Opus planning session: 15–30 min, focused, short context = bounded cost
- Sonnet implementation: 1–3 hours, full context, main cost center
- Haiku verification: 5–10 min, very short = near-zero cost
- Net result: ~30–40% lower total cost vs. using Sonnet for everything, with higher quality plans

---

### 11.6 When NOT to Switch to Haiku

Haiku should not be used when:
- The task involves editing production code (even a "simple" rename can break things if context is missed)
- The task requires reading and understanding a large file before acting
- Security rules or Firestore queries are involved
- The user's intent is unclear and needs interpretation

**The rule:** If getting it wrong has any meaningful consequence, use Sonnet minimum. Haiku is for read-only, lookup-only, and confirmatory tasks.

---

## APPENDIX: QUICK REFERENCE

### Model Selection Quick Reference
| Trigger | Model | Examples |
|---------|-------|---------|
| Plan / Design / Architecture / Strategy | **Opus** | "Plan the vitals feature", "Design security rules", "What's the best approach?" |
| Implement / Fix / Build / Update / Debug | **Sonnet** | "Fix this bug", "Implement the widget", "Write the Firestore query" |
| What / Where / Which / Show me / Quick | **Haiku** | "What's the app version?", "Where is BentoCard?", "Show last 5 commits" |

### Switch Model Commands
| Command | Switches to |
|---------|------------|
| `/model opus` | Claude Opus 4.7 — planning mode |
| `/model sonnet` | Claude Sonnet 4.6 — development mode (default) |
| `/model haiku` | Claude Haiku 4.5 — conversational mode |

---

### Skill Commands
| Command | Effect |
|---------|--------|
| `/caveman` | Activate compressed communication (75% token reduction) |
| `/caveman lite` | Lighter compression, full sentences |
| `/caveman ultra` | Maximum compression, abbreviations |
| `/cavecrew` | Dispatch parallel agent fleet |
| `/caveman-review` | Compressed code review comments |
| `/caveman-compress` | Compress large text before storing |
| `/caveman-stats` | Show token usage statistics |
| `/omra-ux-review [screen]` | Run UX checklist against persona + audit standards |
| `/omra-design-check` | Verify AppColors, BentoCard, HugeIcons usage |
| `/omra-security-check` | Verify Firestore queries against security patterns |

---

### Files to Read at Session Start
| File | When to Read | Lines | Cost |
|------|-------------|-------|------|
| `CLAUDE.md` | Every session (auto-loaded) | All | ~3,000 tokens |
| `.claude/UPDATES.md` | Every session | Top 80 | ~1,200 tokens |
| `.claude/BACKLOG.md` | Every session | Phase 1–2 only | ~500 tokens |
| `.claude/DESIGN_SYSTEM.md` | UI/UX sessions | Relevant section | ~500 tokens |
| `.claude/PERSONAS.md` | UI/UX sessions | Relevant persona | ~400 tokens |
| `.claude/DECISIONS.md` | Architecture sessions | All (keep short) | ~800 tokens |
| `AUDIT_REPORT.md` | Reference only | Targeted sections | ~2,000 tokens |

### Code Verification Commands (Manual)
```bash
# Static analysis (run from vitalpath_flutter/)
flutter analyze --no-fatal-infos

# Format check
dart format --output=none --set-exit-if-changed lib/

# Debug build verify
flutter build apk --debug --no-pub

# Run tests
flutter test
```

---

*Report prepared by: Claude Code (claude-sonnet-4-6)*  
*Version: 2.0 — Updated 2026-05-24*  
*Status: Planning only — no files created, no code modified*  
*Next step: Confirm this plan, then implement in the order described in Section 9*
