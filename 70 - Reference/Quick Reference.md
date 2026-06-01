# Quick Reference

#reference

## Most-Used Commands

```bash
# Build
flutter build apk --release
flutter build appbundle --release

# Test / analyze
flutter analyze --no-fatal-infos

# Deploy rules
firebase deploy --only firestore:rules          # from vitalpath_flutter/

# Deploy functions (⚠ pending for ADR-008, ADR-015)
firebase deploy --only functions                # from vitalpath_flutter/

# Deploy specific functions
firebase deploy --only functions:sendAppointmentReminders,functions:sendPushOnNotification

# Distribute APK
firebase appdistribution:distribute <path>.apk \
  --app 1:768599207887:android:a365080e6a086985736cba \
  --groups testers
```

## Firestore Collection Names
> Defined in `lib/core/constants/app_constants.dart`

| Key | Collection |
|-----|-----------|
| users | `users` |
| appointments | `appointments` |
| prescriptions | `prescriptions` |
| medicines | `patients/{id}/medicines` |
| vitals | `patients/{id}/vitals` |
| notifications | `patients/{id}/notifications` (for push trigger) |
| userNotifications | `users/{id}/notifications` |
| caregiver connections | `caregiver_connections` |
| caregiver mirror | `patients/{id}/caregivers/{caregiverUid}` |
| invites | `invites` |

## Firebase Console Links
- Dashboard: `https://console.firebase.google.com/project/health-passbook-9a0df`
- Crashlytics: `https://console.firebase.google.com/project/health-passbook-9a0df/crashlytics`
- App Distribution: `https://console.firebase.google.com/project/health-passbook-9a0df/appdistribution`
- Firestore: `https://console.firebase.google.com/project/health-passbook-9a0df/firestore`

## Model Selection Reminder
- **Planning / architecture** → `/model opus`
- **Quick lookup / single question** → Haiku
- **Coding / debugging / analysis** → Sonnet (default)

## Claude Code Skills
| Skill | Trigger |
|-------|---------|
| `/omra-security-check` | After any Firestore rules / Cloud Function change |
| `/omra-ux-review [screen]` | Before and after any user-facing screen edit |
| `/omra-design-check` | After any UI widget/color/icon edit |
