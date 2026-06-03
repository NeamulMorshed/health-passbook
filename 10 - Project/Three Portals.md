# Three User Portals

#reference

| Portal | Routes | Color | Entry File |
|--------|--------|-------|-----------|
| Patient | `/home` | `AppColors.primary` (#0F9D77 green) | `lib/screens/patient/home/home_screen.dart` |
| Doctor | `/doc/*` | `AppColors.primary` (shared) | `lib/screens/doctor/doc_dashboard_screen.dart` |
| Family Member | `/caregiver/*` | `AppColors.caregiver` (#F59E0B amber) | `lib/screens/caregiver/home/caregiver_home_screen.dart` |

## Terminology Rules
- UI text: **"Family Member"** always — never "Caregiver"
- Code variables/filenames: `caregiver` is OK (refactor is backlog, not blocking)
- App name: **"Omra"** always — never "VitalPath"

## Personas
→ [[50 - UX + Design/Personas]]
- Patient = [[50 - UX + Design/Personas#Persona 1 — Aisha Hassan (Patient)|Aisha Hassan]]
- Doctor = [[50 - UX + Design/Personas#Persona 2 — Dr. Rahman (Doctor)|Dr. Rahman]]
- Family Member = [[50 - UX + Design/Personas#Persona 3 — Karim Hassan (Family Member / Husband)|Karim Hassan]]

## Portal Routing Rules
- Role determined at login → stored in `users/{uid}.userType`
- Router redirect: unauthenticated → `/login`; authenticated + incomplete onboarding → `/onboarding/health-profile`; authenticated + no disclaimer → `/disclaimer`
- File: `lib/app/router.dart`
