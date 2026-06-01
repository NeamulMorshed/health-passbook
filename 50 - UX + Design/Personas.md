# User Personas

#ux #reference

> Read the relevant persona section before editing any user-facing screen.
> Ask: "Does this serve their primary need? Does it reduce taps to their goal?"

---

## Persona 1 — Aisha Hassan (Patient)

| Attribute | Detail |
|-----------|--------|
| Age | 42 |
| Condition | Type 2 Diabetes + mild hypertension |
| Daily routine | 3 medicines (morning/noon/evening), logs meals, tracks BP + glucose |
| Device usage | 3–4× daily, often on the go |
| Tech comfort | Moderate |

### Needs (ranked)
1. **Primary:** Know what to DO right now — actionable, not informational
2. **Secondary:** Feel in control without being overwhelmed
3. **Tertiary:** See long-term trends when she has a moment

### UX Validation Questions
- Does Aisha see her most urgent task **without scrolling**?
- Is there an action button next to any alert ("Log now", "Mark taken")?
- Does the change add taps between Aisha and her primary task?
- Would Aisha understand this at 7am before coffee?

### Dashboard Priority Order
1. Urgent alerts (missed medicines, abnormal vitals)
2. Today's actionable tasks (medicines due, meals to log)
3. Next appointment
4. Medicine refill alert
5. Notification banners
6. Time-contextual guidance
7. Weekly adherence ring
8. Family status bar
9. AI insights

### Key Screens
- `lib/screens/patient/home/home_screen.dart`
- `lib/screens/patient/care/care_screen.dart`
- `lib/screens/patient/invite_caregiver_screen.dart`
- `lib/screens/patient/appointments/appointments_screen.dart`

---

## Persona 2 — Dr. Rahman (Doctor)

| Attribute | Detail |
|-----------|--------|
| Specialty | Cardiology |
| Daily routine | Reviews requests, confirms appointments, writes prescriptions, monitors adherence |
| Device usage | Quick check during breaks — needs fast in/out |
| Tech comfort | High |

### Needs (ranked)
1. **Primary:** Know which patients need attention TODAY
2. **Secondary:** Fast prescription writing from patient profile
3. **Tertiary:** Clean appointment management

### UX Validation Questions
- Does Dr. Rahman see WHO needs action (not just a count)?
- Is the prescription workflow defensible against typos (confirmation step)?
- Does any change require >2 taps to reach a patient's medicines?
- Will the patient be notified when Dr. Rahman acts?

### Dashboard Priority Order
1. Needs Attention — patients with <50% adherence or abnormal vitals
2. Today's schedule — appointment list with times + patient names
3. Pending requests — new appointment requests to confirm
4. Quick actions — Patients / Appointments / Prescribe
5. Recent activity

### Key Screens
- `lib/screens/doctor/doc_dashboard_screen.dart`
- `lib/screens/doctor/doc_patient_view_screen.dart`
- `lib/screens/doctor/appointments/doc_appointments_screen.dart`

---

## Persona 3 — Karim Hassan (Family Member / Husband)

| Attribute | Detail |
|-----------|--------|
| Relationship | Aisha's husband |
| Daily routine | Checks 1–2× a day — quick glance to confirm Aisha is OK |
| Device usage | 30-second opens |
| Tech comfort | Moderate |

### Needs (ranked)
1. **Primary:** At-a-glance "Is she OK?" in 2 seconds
2. **Secondary:** Send gentle nudge when she misses something
3. **Tertiary:** See what doctor prescribed

### UX Validation Questions
- Can Karim answer "Is Aisha OK?" in under 3 seconds without any navigation?
- Is the nudge button reachable from home (not buried in profile)?
- If a section is locked, does it tell Karim WHY and offer to request access?
- Does Karim get feedback after sending a nudge (did it work)?

### Dashboard Priority Order
1. Status banner — "✅ Aisha is on track" or "⚠ Aisha missed morning medicine"
2. Quick actions — "Send nudge" directly from home
3. Today's detail — medicines taken, vitals, appointment, meals
4. Pending — new invites, new prescriptions

### Key Screens
- `lib/screens/caregiver/home/caregiver_home_screen.dart`
- `lib/screens/caregiver/caregiver_patient_profile_screen.dart`
- `lib/screens/caregiver/accept_invite_screen.dart`

---

## Cross-Persona Validation
> Ask for any feature touching 2+ portals:

- When Doctor acts → does Aisha get notified?
- When Aisha invites Karim → does Aisha see pending state in Care Circle?
- When Aisha takes medicine → does Karim's status update near real-time?
- Are permission boundaries respected AND clearly communicated?
- Does the change create any Doctor ↔ Karim interaction? (currently none — by design)
