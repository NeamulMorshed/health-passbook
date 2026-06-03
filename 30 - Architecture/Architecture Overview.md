# Architecture Overview

#architecture

## Stack at a Glance

```
Flutter (Dart)
  ├── Riverpod 2.5.1 — state management
  ├── GoRouter 14.3.0 — routing + guards
  └── Three portals: Patient / Doctor / Family Member

Firebase
  ├── Authentication — email/password
  ├── Firestore — primary database
  ├── Cloud Messaging (FCM) — push notifications
  ├── Crashlytics — crash reporting (active v2.12.0+38)
  └── App Distribution — internal testing

Cloud Functions (TypeScript)
  ├── sendPushOnNotification — trigger on notification doc create
  ├── checkMissedDoses — pub/sub, missed dose nudges to family members
  ├── sendAppointmentReminders — scheduled every 30 min (⚠ deploy pending)
  └── resetRemindersOnReschedule — trigger on appointment update
```

## Data Flow

```
User action in Flutter
  → Riverpod StateNotifier
  → FirestoreService method
  → Firestore write
  → Cloud Function trigger (if applicable)
  → FCM push → Flutter NotificationService
  → OS heads-up OR in-app NotifBell badge
```

## Firestore Collections

| Collection | Notes |
|-----------|-------|
| `users/{uid}` | userType field — blocked from self-write on update (S-02) |
| `appointments/{id}` | Bidirectional: patient queries by patientId, doctor by doctorId |
| `prescriptions/{id}` | doctorHasPatient() required on create |
| `patients/{id}/medicines/{id}` | doctorHasPatient() required on doctor create |
| `patients/{id}/caregivers/{caregiverUid}` | Mirror doc — holds permissions map (ADR-011) |
| `patients/{id}/vitals/{id}` | Guarded by patientId/doctorId/caregiverCanRead |
| `patients/{id}/notifications/{id}` | Written cross-user; triggers FCM push |
| `users/{uid}/notifications/{id}` | User's own notification inbox |
| `caregiver_connections/{id}` | Source of truth for active connections |
| `invites/{id}` | Invite telemetry (allow create if fromUid == auth.uid) |

## Notification Pipeline
```
Firestore write to {uid}/notifications
  → Cloud Function: sendPushOnNotification
  → FCM to device token
  → Flutter: onMessage handler
  → Local notification OR NotifBell count update
```

## Key Architecture Decisions
→ [[ADR Index]]

## Current Deploy Status
| Service | Status |
|---------|--------|
| Firestore rules | ✅ Latest deployed |
| Cloud Functions | ⚠ sendAppointmentReminders + resetRemindersOnReschedule NOT deployed |
| Flutter APK | v2.12.0+41 (Play Store submission pending) |
| Flutter AAB | v2.12.0+41 built (ready for Play Console) |
