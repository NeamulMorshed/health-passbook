# Omra — User Personas
<!-- Source: AUDIT_REPORT.md Section 4 (full journey simulation) -->
<!-- Claude: Before editing any user-facing screen, read the relevant persona section. -->
<!-- Ask: "Does this change serve this persona's primary need? Does it reduce taps to their goal?" -->

---

## Persona 1 — Aisha Hassan (Patient)

| Attribute | Detail |
|-----------|--------|
| Age | 42 |
| Condition | Type 2 Diabetes + mild hypertension |
| Daily routine | Takes 3 medicines (morning / noon / evening), logs meals, tracks BP + glucose |
| Device usage | Checks app 3–4× daily, often on the go |
| Tech comfort | Moderate — comfortable with smartphones, not power user |

### Needs (ranked)
1. **Primary:** Know what to DO right now — "What medicine do I need to take? Have I logged lunch?" Actionable, not informational.
2. **Secondary:** Feel in control and on top of her health without being overwhelmed
3. **Tertiary:** See long-term trends (adherence, vitals over time) when she has a moment

### Biggest Frustrations
- Dashboard shows metrics ("Adherence 75%") without telling her what to do about it
- Vitals trending is missing — she can't see her BP history for doctor visits
- No drug interaction warnings when doctor prescribes something new
- Care Circle shows "0 people monitoring" after she sent an invite (no pending badge)

### Key Screens
- `home_screen.dart` — primary daily screen
- `lib/screens/patient/care/care_screen.dart` — medicines + meals management
- `lib/screens/patient/invite_caregiver_screen.dart` — inviting Karim
- `lib/screens/patient/appointments/appointments_screen.dart` — booking with Dr. Rahman

### Dashboard Priority Order (most → least important for Aisha)
1. **Urgent alerts** (missed medicines, missed meals, abnormal vitals)
2. **Today's actionable tasks** (what medicines are due, what meals to log, vitals to record)
3. **Next appointment** (when is my doctor visit?)
4. **Medicine refill alert** (any supply running low?)
5. **Notification banners** (permission, family member active)
6. **Time-contextual guidance** (context card for this hour)
7. **Weekly adherence ring** (motivational trend — below fold is fine)
8. **Family status bar** (who's monitoring her)
9. **AI insights** (low priority)

### UX Validation Questions (ask before any Aisha-facing change)
- Does Aisha see her most urgent task **without scrolling**?
- Is there an action button next to any alert ("Log now", "Mark taken")?
- Does the change add taps between Aisha and her primary task?
- Would Aisha understand this at 7am before coffee?

---

## Persona 2 — Dr. Rahman (Doctor)

| Attribute | Detail |
|-----------|--------|
| Specialty | Cardiology |
| Practice | Multi-patient clinical practice |
| Daily routine | Reviews pending appointment requests, confirms appointments, writes prescriptions, monitors adherence |
| Device usage | Checks during breaks, between patients — needs fast in/out |
| Tech comfort | High — comfortable with medical software |

### Needs (ranked)
1. **Primary:** Know which patients need attention TODAY — who is non-compliant, who has abnormal readings
2. **Secondary:** Fast prescription writing from a patient's profile
3. **Tertiary:** Clean appointment management — confirm/cancel with notes

### Biggest Frustrations
- Dashboard shows counts ("3 patients", "2 appointments") but not WHO needs action
- Confirms appointment — patient gets no notification (silent loop break)
- Prescription form has no confirmation step (one tap saves — typos are not recoverable intuitively)
- No vitals history/trends in patient view — only latest reading shown
- No way to message patients or ask questions in-app

### Key Screens
- `lib/screens/doctor/doc_dashboard_screen.dart` — primary daily screen (266 lines)
- `lib/screens/doctor/doc_patient_view_screen.dart` — patient detail, 5 tabs (1525 lines)
- `lib/screens/doctor/doc_appointments_screen.dart` — appointment management (476 lines)

### Dashboard Priority Order (most → least important for Dr. Rahman)
1. **Needs attention** — patients with <50% adherence this week or abnormal vitals (MISSING)
2. **Today's schedule** — appointment list with times and patient names (MISSING — only count shown)
3. **Pending requests** — new appointment requests to confirm (exists — good placement)
4. **Quick actions** — Patients / Appointments / Prescribe
5. **Recent activity** — latest new patients or prescription requests

### UX Validation Questions (ask before any Doctor-facing change)
- Does Dr. Rahman see WHO needs action (not just a count)?
- Is the prescription workflow defensible against typos (confirmation step)?
- Does any change require more than 2 taps to reach a patient's medicines?
- Will the patient be notified when Dr. Rahman acts on something?

---

## Persona 3 — Karim Hassan (Family Member / Husband)

| Attribute | Detail |
|-----------|--------|
| Relationship | Aisha's husband |
| Context | Loves Aisha, worries but does not want to be intrusive |
| Daily routine | Checks app 1–2× a day to see if Aisha is on track |
| Device usage | Quick glance — opens app for 30 seconds to confirm Aisha is OK |
| Tech comfort | Moderate — comfortable with basic apps |

### Needs (ranked)
1. **Primary:** At-a-glance "Is she OK?" — green/red status answer in 2 seconds (MISSING)
2. **Secondary:** Send a gentle nudge when she misses something — without feeling intrusive
3. **Tertiary:** See what doctor has prescribed, so he understands her treatment

### Biggest Frustrations
- Must navigate 3 screens to find out if Aisha took her meds today
- Nudge is fire-and-forget — no feedback on whether it worked
- Locked sections are silently hidden with no explanation (no "Aisha hasn't shared this")
- Nudges are preset only (4 options) — can't write "How was your glucose check today?"
- After accepting Aisha's invite, was shown a blank screen (no "you're connected" confirmation)

### Key Screens
- `lib/screens/caregiver/home/caregiver_home_screen.dart` — primary daily screen
- `lib/screens/caregiver/caregiver_patient_profile_screen.dart` — Aisha's detail view (~1500 lines)
- `lib/screens/caregiver/accept_invite_screen.dart` — invite acceptance (150 lines)

### Dashboard Priority Order (most → least important for Karim)
1. **Status banner** — "✅ Aisha is on track" or "⚠ Aisha missed morning medicine" (MISSING)
2. **Quick actions** — "Send nudge" directly from home (currently buried in profile)
3. **Today's detail** — medicines taken, vitals logged, next appointment, meals
4. **Pending** — any new invites, new prescriptions from Dr. Rahman

### UX Validation Questions (ask before any Karim-facing change)
- Can Karim answer "Is Aisha OK?" in under 3 seconds without any navigation?
- Is the nudge button reachable from the home screen (not buried in profile)?
- If a section is locked, does it tell Karim WHY and offer to request access?
- Does Karim get feedback after sending a nudge (did it work)?

---

## Cross-Persona Validation (ask for any feature touching 2+ portals)
- When Doctor Rahman acts (confirms appointment, writes prescription) → does Aisha get notified?
- When Aisha invites Karim → does Aisha see the pending state in her Care Circle?
- When Aisha takes a medicine → does Karim's status update in near real-time?
- Are permission boundaries respected and clearly communicated (not silently hidden)?
- Does the change create any new direct Doctor ↔ Karim interaction? (currently none — by design)
