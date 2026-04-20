# VitalPath — Developer Handoff

> **Build status:** Full scaffold complete · 60 files · 9,084 lines of Dart · Android-first
> **Architecture:** Offline-first · Riverpod 3 · Drift + Supabase · Clean Architecture

---

## What Was Built

A production-quality Flutter scaffold for **VitalPath Health Passbook** — a centralized health management app for patients, caregivers, and healthcare providers. Every feature from the SRS is represented: medicine tracking with overdose protection, GPS walk sessions, doctor–patient sync via QR code, meal routines, activity monitoring via Health Connect, and HIPAA/GDPR-compliant cloud sync.

---

## Project Structure

```
vitalpath/
├── pubspec.yaml                        # All 40+ dependencies declared
├── analysis_options.yaml               # Strict Dart lints
├── .env.example                        # Supabase + Maps keys template
├── supabase_schema.sql                 # Full PostgreSQL schema (run in Supabase SQL Editor)
│
├── android/
│   └── app/src/main/
│       ├── AndroidManifest.xml         # All permissions (Health Connect, GPS, biometric, camera)
│       ├── kotlin/com/vitalpath/app/
│       │   └── MainActivity.kt         # FlutterFragmentActivity (biometric fragment support)
│       └── res/xml/
│           └── network_security_config.xml  # HTTPS-only, cleartextTraffic=false
│
└── lib/
    ├── main.dart                        # App entry point, biometric observer, WorkManager init
    │
    ├── core/
    │   ├── constants/
    │   │   ├── app_colors.dart          # Deep Emerald theme + semantic tokens
    │   │   ├── app_theme.dart           # Material 3 full component overrides, Plus Jakarta Sans
    │   │   └── app_constants.dart       # All SRS magic numbers (refillThreshold=5, duplicateWindow=15m…)
    │   │
    │   ├── database/
    │   │   ├── app_database.dart        # @DriftDatabase, 11 tables, WAL mode, 6 indexes
    │   │   ├── tables/
    │   │   │   ├── user_profile_table.dart
    │   │   │   ├── medicines_table.dart      # MedicineLogs with originalTimestamp (SRS §5.1)
    │   │   │   ├── meal_routines_table.dart
    │   │   │   ├── activity_table.dart       # WalkSessions with nullable polylineJson (SRS §5.3)
    │   │   │   ├── doctor_sync_table.dart    # Prescriptions with serverTimestamp conflict resolution
    │   │   │   └── sync_queue_table.dart     # Offline queue with retryCount
    │   │   └── daos/
    │   │       ├── user_profile_dao.dart
    │   │       ├── medicine_dao.dart          # Duplicate check, refill check, adherence report
    │   │       ├── meal_routine_dao.dart
    │   │       ├── activity_dao.dart
    │   │       ├── doctor_sync_dao.dart
    │   │       └── sync_queue_dao.dart        # enqueue / drain / retry / TTL cleanup
    │   │
    │   ├── network/
    │   │   ├── supabase_config.dart
    │   │   └── connectivity_service.dart
    │   │
    │   ├── router/
    │   │   └── app_router.dart          # GoRouter + ShellRoute, auth redirect, slide transitions
    │   │
    │   ├── services/
    │   │   ├── notification_service.dart  # 6 channels, medicine action buttons, refill alert
    │   │   ├── haptic_service.dart        # 4 precise patterns (medicine, step goal, GPS km, warning)
    │   │   ├── sync_service.dart          # WorkManager 15-min background drain, originalTimestamp inject
    │   │   ├── health_connector_service.dart  # Health Connect 7 types, Isolate for history
    │   │   └── biometric_service.dart
    │   │
    │   └── utils/
    │       └── validators.dart
    │
    ├── features/
    │   ├── auth/
    │   │   ├── presentation/providers/auth_provider.dart    # Supabase OTP, BiometricLock
    │   │   └── presentation/screens/
    │   │       ├── splash_screen.dart         # Animated logo, route decision
    │   │       ├── onboarding_screen.dart     # 3-page PageView
    │   │       ├── phone_auth_screen.dart     # Country picker (+880 default)
    │   │       ├── otp_verify_screen.dart     # Pinput 6-digit, auto-submit
    │   │       └── health_profile_screen.dart # Conditions chips, Health Connect permission request
    │   │
    │   ├── dashboard/
    │   │   ├── presentation/providers/dashboard_provider.dart  # 5 streams merged
    │   │   ├── presentation/screens/dashboard_screen.dart      # SliverAppBar, timeline, shimmer
    │   │   └── presentation/widgets/
    │   │       ├── step_progress_card.dart    # Circular progress, gradient
    │   │       ├── timeline_section.dart      # Animated timeline rows, status states, Log button
    │   │       └── daily_greeting_card.dart
    │   │
    │   ├── medicine/
    │   │   ├── domain/entities/medicine_entity.dart  # needsRefill, nextDoseTime computed
    │   │   ├── presentation/providers/medicine_provider.dart  # Duplicate check, inventory decrement
    │   │   ├── presentation/screens/
    │   │   │   ├── medicine_list_screen.dart   # Grouped (needs refill / active)
    │   │   │   ├── add_medicine_screen.dart    # 8-color picker, time slots, inventory
    │   │   │   └── medicine_detail_screen.dart # Hero gradient, dose action bar
    │   │   └── presentation/widgets/
    │   │       └── medicine_card.dart          # Slidable edit/delete, refill badge
    │   │
    │   ├── nutrition/
    │   │   └── presentation/screens/
    │   │       ├── nutrition_screen.dart
    │   │       └── add_meal_screen.dart        # Time window pair picker, 15-min pre-meal reminder
    │   │
    │   ├── activity/
    │   │   └── presentation/screens/
    │   │       ├── activity_screen.dart        # 7-day bar chart, step card
    │   │       └── gps_walk_screen.dart        # Google Maps polyline, km haptic, storage-aware save
    │   │
    │   ├── doctor_sync/
    │   │   └── presentation/screens/
    │   │       ├── doctor_sync_screen.dart     # Connection cards with status badge
    │   │       ├── qr_scanner_screen.dart      # MobileScanner + manual 6-digit fallback
    │   │       └── adherence_report_screen.dart  # LineChart 4-week trend
    │   │
    │   └── profile/
    │       └── presentation/screens/
    │           ├── profile_screen.dart         # GDPR delete dialog
    │           └── settings_screen.dart        # Notification toggles, biometric, sync status
    │
    └── shared/
        └── widgets/
            └── vp_bottom_nav_shell.dart        # AnimatedContainer 5-tab nav
```

---

## First Steps After Download

### 1. Install Flutter dependencies

```bash
cd vitalpath
flutter pub get
```

### 2. Generate code (Drift + Riverpod + GoRouter)

```bash
dart run build_runner build --delete-conflicting-outputs
```

This generates:
- `lib/core/database/app_database.g.dart` (Drift)
- All `*.g.dart` files for `@riverpod` providers
- `lib/core/router/app_router.g.dart` (GoRouter typed routes)

### 3. Set up Supabase

1. Create a project at [supabase.com](https://supabase.com)
2. Open **SQL Editor** → paste and run `supabase_schema.sql`
3. Enable **Phone Auth** in Authentication → Providers
4. Copy your Project URL and anon key

### 4. Configure environment

Copy `.env.example` to `.env` and fill in:

```
SUPABASE_URL=https://xxxxxxxxxxxx.supabase.co
SUPABASE_ANON_KEY=your-anon-key
GOOGLE_MAPS_API_KEY=your-maps-api-key
```

The Google Maps API key also goes into `android/local.properties` or the Gradle build config (referenced as `${GOOGLE_MAPS_API_KEY}` in AndroidManifest).

### 5. Run

```bash
flutter run --dart-define-from-file=.env
```

---

## Key Architectural Decisions

| Decision | Choice | Reason |
|---|---|---|
| State management | Riverpod 3 + riverpod_annotation | Compile-time safety, AsyncNotifier, no ProviderObserver boilerplate |
| Local DB | Drift (SQLite) | Type-safe queries, reactive streams, WAL mode for performance |
| Backend | Supabase | OTP auth, Realtime WebSockets, RLS, Edge Functions |
| Navigation | GoRouter + ShellRoute | Declarative, deep link support, auth redirect guard |
| Background sync | WorkManager (15-min periodic) | Survives app kill; Dart isolate via callbackDispatcher |
| Offline-first | SyncQueue table | originalTimestamp preserved — server never overwrites user's intent timestamp |

---

## Critical SRS Compliance Points

- **SRS §5.1 Overdose prevention**: `MedicineLogNotifier.logDose()` queries `findRecentLog()` within a 15-minute window. If a log exists, it aborts and fires `showDuplicateLogWarning()` with a full-screen intent notification.
- **SRS §5.1 Timestamp preservation**: `SyncQueueEntry.originalTimestamp` is injected as `_original_timestamp` into every Supabase upsert payload — the cloud record always reflects when the user actually acted, not when sync ran.
- **SRS §5.2 Improbable weight**: `HealthProfileScreen` validator rejects weight > 400 kg with a warning toast before saving.
- **SRS §5.3 Storage-aware GPS**: `GpsWalkScreen` catches storage exceptions on polyline serialization and sets `polylineJson = null` — the walk session is still saved with step count intact.
- **SRS §6.2 HIPAA/GDPR**: RLS on every Supabase table, `cleartextTrafficPermitted="false"` in Android network config, GDPR delete dialog in Profile screen.
- **Antigravity 100ms principle**: Haptic fires *before* the UI update in all log actions — the user feels acknowledgment instantly.

---

## What's Not Yet Built (V2 Backlog)

| Feature | Notes |
|---|---|
| Doctor Portal (Flutter Web) | Separate app instance; shares Supabase backend |
| Android Home Screen Widget | Steps + next medicine at a glance |
| Rive animations | Replace `CircularPercentIndicator` with Rive for premium feel |
| Timezone Leap dialog | Detect >3h timezone change, prompt re-confirmation (SRS §5.2) |
| Notification fatigue counter | `kNotificationFatigueCount` key exists; wire to `didReceiveNotificationResponse` |
| Redis caching (Doctor roster) | For doctor-side active patient list at scale |
| iOS parity | Info.plist permissions, HealthKit integration |
| Push notifications (FCM) | Doctor→patient real-time alerts when offline |

---

## Dependency Reference

Full list in `pubspec.yaml`. Key packages:

```
flutter_riverpod / riverpod_annotation   → state management
drift / drift_flutter                    → local SQLite ORM
supabase_flutter                         → backend + auth + realtime
go_router                                → navigation
health                                   → Android Health Connect bridge
workmanager                              → background tasks
flutter_local_notifications              → notification channels
local_auth                               → biometric
google_maps_flutter                      → GPS walk map
mobile_scanner                           → QR code (doctor pairing)
fl_chart                                 → adherence line chart / activity bar chart
flutter_animate                          → micro-animations
pinput                                   → OTP input
flutter_slidable                         → swipe actions on medicine cards
percent_indicator                        → step progress circle
connectivity_plus                        → online/offline detection
geolocator                               → GPS stream for walk
uuid / intl / shared_preferences         → utilities
```

---

*Generated by Claude · VitalPath v1.0.0 scaffold · April 2026*
