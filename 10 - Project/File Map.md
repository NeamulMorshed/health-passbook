# Critical File Map

#reference

## Flutter App Root
`vitalpath_flutter/`

## Core

| File | Purpose |
|------|---------|
| `lib/core/theme/app_theme.dart` | AppColors + AppTheme — ALL color tokens live here |
| `lib/core/widgets/bento_card.dart` | BentoCard, BentoStatCard, BentoRow, BentoFeaturedCard, BentoSettingsTile, BentoSectionHeader (6 widgets) |
| `lib/core/constants/app_constants.dart` | Firestore collection names, shared constants |
| `lib/core/widgets/vital_trend_chart.dart` | VitalTrendChart — fl_chart wrapper for vitals history |
| `lib/core/widgets/notif_bell.dart` | NotifBell — numeric unread count badge, 8 AppBars |

## Services & Providers

| File | Purpose |
|------|---------|
| `lib/services/firestore_service.dart` | ALL Firestore queries — read before any query change |
| `lib/providers/auth_provider.dart` | Auth + Crashlytics user sync |
| `lib/providers/caregiver_provider.dart` | Caregiver streams + caregiverMirrorProvider |
| `lib/providers/doctor_attention_provider.dart` | patientsNeedingAttentionProvider (UX-10) |
| `lib/app/router.dart` | GoRouter config + role-based guards |

## Models

| File | Key Types |
|------|-----------|
| `lib/models/patient.dart` | PatientProfile — allergies now List<String> with legacy adapter |
| `lib/models/appointment.dart` | Appointment |
| `lib/models/medicine.dart` | Medicine, PrescribedMed |
| `lib/models/prescription.dart` | Prescription |
| `lib/models/caregiver_connection.dart` | CaregiverConnection, CaregiverPermissions |
| `lib/models/app_notification.dart` | AppNotification, NotificationType |
| `lib/models/patient_attention.dart` | PatientAttention (UX-10) |

## Patient Portal Screens

| File | Lines | Notes |
|------|-------|-------|
| `lib/screens/patient/home/home_screen.dart` | ~1150 | Primary patient dashboard |
| `lib/screens/patient/care/care_screen.dart` | — | Medicines + meals |
| `lib/screens/patient/vitals/vitals_screen.dart` | — | Vitals + trending charts |
| `lib/screens/patient/appointments/appointments_screen.dart` | — | Appointment booking |
| `lib/screens/patient/profile/patient_health_profile_screen.dart` | — | Health profile read + edit |
| `lib/screens/patient/notifications/notifications_screen.dart` | — | Notification list |
| `lib/screens/onboarding/health_profile_screen.dart` | — | 3-step onboarding wizard |
| `lib/screens/onboarding/disclaimer_screen.dart` | — | First-launch disclaimer (Play Store) |
| `lib/screens/legal/privacy_policy_screen.dart` | — | In-app privacy policy |

## Doctor Portal Screens

| File | Lines | Notes |
|------|-------|-------|
| `lib/screens/doctor/doc_dashboard_screen.dart` | 266 | Doctor dashboard |
| `lib/screens/doctor/doc_patient_view_screen.dart` | 1525 | 6-tab patient detail |
| `lib/screens/doctor/appointments/doc_appointments_screen.dart` | 476 | Appointment management |

## Family Member Portal Screens

| File | Lines | Notes |
|------|-------|-------|
| `lib/screens/caregiver/home/caregiver_home_screen.dart` | — | Family member home |
| `lib/screens/caregiver/caregiver_patient_profile_screen.dart` | ~1500 | Patient detail (god-widget, refactored) |
| `lib/screens/caregiver/accept_invite_screen.dart` | 150 | Invite acceptance |

## Infrastructure

| File | Purpose |
|------|---------|
| `vitalpath_flutter/firestore.rules` | ⚠ All 4 critical vulnerabilities fixed (ADR-004) |
| `vitalpath_flutter/functions/src/index.ts` | Cloud Functions — ⚠ deploy pending for ADR-008, ADR-015 |
| `docs/privacy-policy.html` | Hosted privacy policy for Play Console |
| `android/app/build.gradle` | Release signing config |
| `android/app/omra-release.jks` | Release keystore (not in git) |
