# Tech Stack

#reference

## Core
- **Flutter/Dart** — cross-platform mobile
- **Firebase** — backend (Auth, Firestore, Messaging, Crashlytics)
- **TypeScript** — Cloud Functions (`functions/src/index.ts`)

## Exact Package Versions (pinned — do not override)

| Package | Version | Notes |
|---------|---------|-------|
| flutter_riverpod | ^2.5.1 | ConsumerWidget, StreamProvider.family, StateNotifier, AsyncValue |
| go_router | ^14.3.0 | Role-based redirect guards, shell routes per portal |
| firebase_core | ^3.6.0 | Golden stack — see ADR-005 |
| firebase_auth | ^5.3.1 | Golden stack |
| cloud_firestore | ^5.4.1 | Golden stack |
| firebase_messaging | ^15.1.3 | Golden stack |
| firebase_crashlytics | ^4.1.3 | Activated v2.12.0+38 |
| HugeIcons | ^1.1.4 | `strokeRounded*` variant only — no Material Icons where HugeIcon exists |
| google_fonts | ^6.2.1 | Open Sans throughout |
| fl_chart | ^0.69.0 | Vitals trending charts |

## Architecture Patterns

| Pattern | Rule |
|---------|------|
| State | ConsumerWidget + StreamProvider.family + StateNotifier |
| Routing | GoRouter with role-based redirect guards |
| Firestore queries | Never `.orderBy()` + `.where()` together — sort client-side (ADR-001) |
| Defensive streams | Wrap `fromMap()` in `try-catch` + `.whereType<T>()` (ADR-003) |
| Colors | Always `AppColors.tokenName` — never raw hex (CLAUDE.md rule) |
| Numeric Firestore fields | Use `(map['field'] as num?)?.toInt()` — Firestore stores int as double |
| No dependency_overrides | Ever (ADR-005) |

## Build Commands
```bash
flutter build apk --release
flutter build appbundle --release
firebase deploy --only firestore:rules
firebase deploy --only functions           # from vitalpath_flutter/
firebase appdistribution:distribute <apk> --app 1:768599207887:android:a365080e6a086985736cba --groups testers
```

## Three Portals
→ See [[Three Portals]]

## Known Firebase Firestore Rules Location
`vitalpath_flutter/firestore.rules`

## Cloud Functions Location
`vitalpath_flutter/functions/src/index.ts`
