# Omra — Session Change Log
<!-- Claude: Read TOP 80 lines only (most recent 2–3 sessions). Append NEW entries at the TOP. -->
<!-- Format per entry: ## YYYY-MM-DD · vX.X.X+N then bullets for changed/next -->

---
## 2026-06-03 · v2.12.0+42 (8-bug fix: notifications + visits page)
**Focus:** Fix all 8 bugs found in previous audit session. No features added.
**Changed:**
- `lib/services/firestore_service.dart` — V2: added `.orderBy('createdAt', descending: true)` before `.limit()` in `watchPatientAppointments` and `watchDoctorAppointments` (removed redundant client-side sort). V3: `updateAppointmentStatus` now writes in-app notification for `completed` status. V4: `updateAppointmentStatus` now accepts and uses `doctorName` for cancel notification body. N3: added composite index comment above dual-where query in `markAllNotificationsRead`.
- `lib/providers/doctor_provider.dart` — V3+V4: `DoctorAppointmentNotifier.cancel()` + `.complete()` now accept and pass `doctorName`/`patientId` through to firestore layer.
- `lib/screens/doctor/appointments/doc_appointments_screen.dart` — V3+V4: `_confirmCancel` passes `appt.doctorName`; `_confirmComplete` passes `appt.patientId` + `appt.doctorName`.
- `lib/screens/patient/appointments/appointments_screen.dart` — V1: patient cancel now checks `state is AsyncError` before showing success snack. V5: confirmed appointments within 24h now show info row "Cancellations require 24h notice."
- `lib/screens/patient/notifications/notifications_screen.dart` — N4: `_onNotifTap` now navigates on tap (appointment→/appointments, medicine/meal→/care). N3: error snack now fires when `markAllRead` fails (via rethrow in provider).
- `lib/providers/patient_provider.dart` — N3: `NotificationNotifier.markAllRead` now rethrows after logging so screen's catch block can show error snack.
- `lib/core/constants/app_constants.dart` — N2: added `notifChannelMeal = 'meal_reminders'` constant.
- `lib/services/notification_service.dart` — N2: added `notifChannelMeal` to `_channelPrefKeys` (mapped to `'notif_meals'`), added `_createChannel` call in `initialize()`, added route mapping to `_routeForChannel`.
- `lib/providers/patient_provider.dart` — N2: meal reminder scheduling now uses `notifChannelMeal` instead of `notifChannelGeneral`.
- `lib/screens/patient/notifications/notification_settings_screen.dart` — N2: `_onMealsToggle` cancels `notifChannelMeal` (not `notifChannelGeneral`).
- `lib/core/widgets/notif_bell.dart` — N1: returns `SizedBox.shrink()` for non-patient users (prevents PERMISSION_DENIED for caregiver/doctor UIDs).
**Build:** `flutter analyze` → 0 errors, 0 warnings, 32 pre-existing info. No pubspec changes.
**Next:** PR for entire `feature/ux-audit-improvements` branch (covers P0–P3 UX audit + crash fixes + 8 bug fixes).

---
## 2026-06-03 · v2.12.0+42 (bug audit — read-only, no code changes)
**Focus:** Full bug audit of in-app notification system and Visits (appointments) page. No code changes this session.
**Findings (8 bugs, no fixes applied yet):**
- BUG-N1: Caregiver NotifBell reads `patients/{caregiverUid}/notifications` → PERMISSION_DENIED → bell always 0, screen always empty
- BUG-N2: Meal reminders controlled by wrong pref key (`notif_doctors` not `notif_meals`) — `_channelPrefKeys` maps `notifChannelGeneral → 'notif_doctors'`; "Meal Reminders" toggle has no scheduling effect
- BUG-N3: `markAllNotificationsRead` uses dual `.where()` — requires composite Firestore index; silently fails without it
- BUG-N4: Appointment notification tap does nothing (no deep-link navigation to `/appointments`)
- BUG-V1: Patient cancel shows "Appointment cancelled" success snack even on Firestore failure (no `state is AsyncError` check, unlike doctor-side)
- BUG-V2: `watchPatientAppointments` uses `.limit()` without `.orderBy()` → wrong set returned when > limit appointments exist
- BUG-V3: Doctor marking appointment completed sends no in-app notification to patient
- BUG-V4: Doctor cancel notification body missing doctor name (doctorName not passed to `updateAppointmentStatus`)
- BUG-V5: No cancel option + no explanation within 24h of confirmed appointment
**Next:** Fix the 8 bugs above. Priority: N1, N2, V1, V2 first (most user-facing impact).

---
## 2026-06-03 · v2.12.0+42 (crash fixes — 3 Crashlytics issues)
**Focus:** Fix all 3 active crashes from Firebase Crashlytics dashboard. No feature changes.
**Changed:**
- `lib/screens/user_select/user_select_screen.dart` — fixed `assets/icons/icon.svg` → `assets/icons/Icon.svg` (case mismatch; Android FS is case-sensitive; crashed for all users on user-select screen — 20 events, 3 users).
- `lib/services/notification_service.dart` — `scheduleReminder()` now calls `canScheduleExactNotifications()` at runtime; falls back to `AndroidScheduleMode.inexact` when exact alarms not permitted (Android 12+ `exact_alarms_not_permitted` crash — 21 events, 1 user).
- `lib/main.dart` — added `GoogleFonts.config.allowRuntimeFetching = false` before `runApp`; prevents `_httpFetchFontAndSaveToDevice` crash on offline/restricted-network devices (2 events, 1 user). Cached fonts still render; others fall back to system font.
**Build:** `flutter analyze` → 0 new errors/warnings. APK built and distributed to `neamul.morshed.nahid@gmail.com` via Firebase App Distribution.
**Commit:** `d29862b` on `feature/ux-audit-improvements`.
**Next:** Create `testers` group in Firebase App Distribution console for future bulk distributes.

---
## 2026-06-02 · v2.12.0+41 (P3 explainability — tier 4 of P0–P3; multi-role deferred)
**Focus:** Final tier. Per scope decision, implemented the low-risk explainability piece; **multi-role (G-8) deferred** to its own brainstorm→spec→build cycle (architectural change to recently-stabilized auth/routing — high regression risk, warrants isolated effort + careful auth testing).
**Changed (G-5 needs-attention explainability):**
- `lib/models/patient_attention.dart` — added `mostRecentAbnormalAt` (DateTime?, optional).
- `lib/providers/doctor_attention_provider.dart` — populates it from `abnormal.first.recordedAt`.
- `lib/screens/doctor/dashboard/doc_dashboard_screen.dart` — adherence pill now reads "…% adherence · 7-day"; abnormal-vital pill appends relative time ("BP 165/95 · 2d ago"). Added `_relativeTime` helper. Doctor now sees *why now / since when*, not just a flag.
**Build:** `flutter analyze` → 0 errors, 0 warnings, 32 info. `flutter test` → 11/11.
**Deferred to dedicated efforts:** (1) Multi-role accounts without forced sign-out (G-8). (2) Full Material→HugeIcons migration (258 usages, see P2 entry).
**Next:** PR for P0+P1+P2+P3 (branch `feature/ux-audit-improvements`).

---
## 2026-06-02 · v2.12.0+41 (P2 consistency debt — tier 3 of P0–P3)
**Focus:** Mechanical consistency cleanup (safe/verifiable scope). Plan: `docs/superpowers/plans/2026-06-02-p2-consistency.md`. Branch `feature/ux-audit-improvements`.
**Audit correction:** The original audit's "194 Material icons" was a grep artifact (`grep Icons.` also matched `HugeIcons.strokeRounded*`). Real Material-icon usage = **258 across 40 files / ~110 distinct glyphs**.
**Changed:**
- `lib/core/utils/greeting.dart` — NEW. `greetingForHour()`. Replaced 3 duplicated `_greeting()` helpers (patient/caregiver/doctor). Doctor gains the 4th "Good Night" branch (cross-portal consistency).
- Exact raw-hex → `AppColors` tokens across 5 screens: `0xFF7C3AED`→inviteAccent (×10), `0xFFD97706`→warning, `0xFF3B82F6`→info, `0xFFEFF6FF`→infoLight. Google brand colors + decorative-gradient hex (5B21B6/8B5CF6/6366F1/0EA5E9/4338CA/22C55E/…) intentionally left raw (no exact token).
**Deferred (own dedicated pass):** the 258 Material-icon → HugeIcons migration. `Icon(Icons.X)` → `HugeIcon(icon:…, color:, size:)` is an API change (not a rename) with `const` cascades + appearance-preservation needs across 40 files; a *partial* swap creates a worse half-consistent state. Needs a verified Material→HugeIcons mapping table. ~110 distinct glyphs; many niche (medical/food/fitness) lack clean twins.
**Build:** `flutter analyze` → 0 errors, 0 warnings, 32 info. `flutter test` → 11/11.
**Next:** P3 (multi-role without forced sign-out; needs-attention explainability), then the dedicated icon-migration pass, then PR.

---
## 2026-06-02 · v2.12.0+41 (P1 flow/heuristic gaps — tier 2 of P0–P3)
**Focus:** Second tier of the UX-audit program (brainstorm→spec→plan→build via superpowers). Branch `feature/ux-audit-improvements` (continues from P0). Spec/plan: `docs/superpowers/specs/2026-06-02-p1-flow-heuristic-design.md`, `docs/superpowers/plans/2026-06-02-p1-flow-heuristic.md`.
**Changed (NEW):**
- `lib/core/widgets/dose_undo.dart` — NEW. `logDoseWithUndo` — records a dose, shows an "Undo" SnackBar (~4s), then reverses it (if undone) or awards HP. **Deferred-HP** design: HP/streak awarded only after the undo window closes → no HP-farming, no gamification reverse needed.
- `lib/core/widgets/skeleton.dart` — NEW. `SkeletonBox` (shimmer, truly static under reduced motion) + `DashboardSkeleton`. 3 widget tests.
**Changed (G-2 undo plumbing):**
- `lib/services/firestore_service.dart` — `logDose(at:)`, NEW `unlogDose` (arrayRemove), `incrementPillCount` (txn) + family `logFamilyMemberDose(at:)` / `unlogFamilyMemberDose`.
- `lib/providers/patient_provider.dart` — `recordDose`→DateTime (no HP), `awardDoseHp`, `unlogDose`; family `recordDose`/`unlogDose`.
- `lib/screens/patient/care/care_screen.dart`, `patient/home/home_screen.dart`, `caregiver/home/caregiver_home_screen.dart` — dose buttons now use `logDoseWithUndo` (patient = HP, family = no HP).
**Changed (Nielsen #1 + G-1):**
- 3 dashboards — bare `CircularProgressIndicator` first-load → `DashboardSkeleton`.
- `patient/home/home_screen.dart` — light reorder: Upcoming Tasks #2, Refill #3, Awareness #4 (most-urgent above fold).
**Build:** `flutter analyze` → 0 errors, 0 warnings, 32 pre-existing info. `flutter test` → 11/11 pass.
**Next:** P2 (consistency debt: 194 Material icons→HugeIcons, 44 raw hex→tokens, dedupe greeting helpers), then P3 (multi-role without forced sign-out, needs-attention explainability). Manual smoke: undo (log→undo removes dose + no HP; log→wait awards HP), skeletons on cold load.

---
## 2026-06-02 · v2.12.0+41 (P0 emotion/generic-UI uplift — tier 1 of P0–P3)
**Focus:** First tier of the UX-audit improvement program. New deep audit (`50 - UX + Design/UX_Audit_2026-06-01.md`, fresh score 7.4/10) drove a brainstorm→spec→plan→build cycle via superpowers skills + ui-ux-pro-max visual companion. Branch: `feature/ux-audit-improvements`.
**Spec/plan:** `docs/superpowers/specs/2026-06-01-p0-emotion-ui-design.md`, `docs/superpowers/plans/2026-06-01-p0-emotion-ui.md`
**Changed (NEW):**
- `lib/core/widgets/status_hero_card.dart` — NEW. `StatusHeroCard` + `StatusHeroData` + `.schedule` variant + `ScheduleRow`. The single elevated daily-status hero per home screen (animated ring, status pill, all-done pulse). 5 widget tests.
- `lib/core/anim/reduced_motion.dart` — NEW. `prefersReducedMotion(context)` + `safeHaptic(context)`. 2 unit tests.
- `lib/core/theme/app_theme.dart` — `AppShadows.hero` / `.heroWarning` depth tokens.
**Changed (screens):**
- `lib/screens/patient/home/home_screen.dart` — status hero at top (ring + "mark dose" action, on-track/all-done/catch-up states); removed redundant `_DailySnapshotRow` + `_SnapshotChip` (folded into hero); AI insights card de-gradiented → `primaryXLight` on-brand + below fold; refresh toast.
- `lib/screens/caregiver/home/caregiver_home_screen.dart` — `_DailySummaryBanner` upgraded to `StatusHeroCard` (G-6: dominant "is she OK" glance); refresh toast.
- `lib/screens/doctor/dashboard/doc_dashboard_screen.dart` — `StatusHeroCard.schedule` today's-appointments hero (G-4 closed); refresh toast.
- `lib/screens/patient/care/care_screen.dart` — `HapticFeedback.mediumImpact` → reduced-motion-safe `safeHaptic`; status badge scale/fade on state change (check-off feedback).
- `.claude/DESIGN_SYSTEM.md` — documented StatusHeroCard, AppShadows elevation tier (one-hero-per-screen rule), Motion & Haptics section.
**Build:** `flutter analyze` → 0 errors, 0 warnings, 32 pre-existing info (baseline unchanged). `flutter test` → 8/8 pass.
**Next:** P1 (flow/heuristic gaps — mark-taken undo, skeleton loaders, patient-home reorder), then P2 (consistency debt: 194 Material icons→HugeIcons, 44 raw hex→tokens), then P3 (multi-role, needs-attention explainability). Manual visual smoke on 3 home screens before merge.

---
## 2026-06-01 · v2.12.0+41 (QA audit + 32-issue fix sweep)
**Focus:** Full QA audit via 5 parallel investigator agents, then systematic fix of all real bugs found
**QA findings (verified false positives — NOT fixed):** C-04 gamification null crash (single-statement if/return is correct Dart), H-15 stale HP (resetWeek doesn't reset HP), H-14 FCM payload null (already handled), C-03 disclaimer race (already fixed via main.dart prefs pre-load)
**Changed (16 files):**
- `lib/app/router.dart` — C-02: userState.hasError redirects to splash; H-03: incomplete patient blocked from ALL routes not just patient-only; H-05: patient/caregiver onboarding routes now separately guarded (caregiver can't reach /onboarding/health-profile)
- `lib/providers/auth_provider.dart` — H-13: fcmTokenSyncProvider wraps syncTokenForUser in try-catch with Crashlytics non-fatal logging
- `lib/main.dart` — L-01: Crashlytics boot log uses AppConstants.appVersion; L-02: disclaimer prefs key uses AppConstants.prefDisclaimerAccepted; added app_constants import
- `lib/core/constants/app_constants.dart` — L-02: added prefDisclaimerAccepted = 'disclaimerAccepted' constant
- `lib/screens/onboarding/disclaimer_screen.dart` — L-02: removed local _kDisclaimerPref const, uses AppConstants.prefDisclaimerAccepted; added app_constants import
- `lib/services/firestore_service.dart` — H-01 (×7): removed .where()+.orderBy() combos from watchMedicines, watchFamilyMemberMedicines, watchTodayMeals, watchRecentActivity, watchPatientPrescriptions, watchConsultationNotes, watchVitals; H-02 (×8): added try-catch+whereType to all 8 undefended stream .map() calls
- `lib/services/gamification_service.dart` — (no changes — C-04 and H-15 were false positives, code already correct)
- `lib/services/ai_insights_service.dart` — H-07: guards (data['content'] as List).first crash (empty list check); guards 'insights' key missing crash
- `lib/services/prescription_ai_service.dart` — H-08: readAsBytes wrapped in FileSystemException catch; HTTP call wrapped with TimeoutException catch; content list null/empty guard; added dart:async import
- `lib/services/rxnorm_service.dart` — H-09: _resolveToIngredient and _fetchRelatedIngredient both wrapped in try-catch returning null on any failure
- `lib/services/notification_service.dart` — L-06: silent catch(_){} replaced with debugPrint logging; M-05: malformed reminderTime now logs instead of silently skipping; added flutter/foundation import
- `lib/screens/patient/vitals/vitals_screen.dart` — H-12: _borderlineLow and _borderlineHigh got curly braces on bpSystolic||bpDiastolic branch (fixing glucose check being unreachable for bpDiastolic)
- `lib/screens/patient/prescriptions/prescriptions_screen.dart` — M-07: _RxCard and _RxDetailSheet now use typed Prescription instead of dynamic; all unsafe `as String`/`as List?` casts removed; added prescription model import
- `lib/screens/patient/home/home_screen.dart` — L-04: lunch _mealIcon now uses strokeRoundedSunCloud01 (distinct from breakfast Sun01)
- `lib/screens/doctor/appointments/doc_appointments_screen.dart` — H-11: Color(0xFF15803D) → AppColors.primaryDark
- `lib/screens/doctor/patient_view/doc_patient_view_screen.dart` — H-11: Color(0xFF5B21B6) ×2 → file-level const _prescriptionGradientEnd
- `lib/screens/caregiver/home/caregiver_home_screen.dart` — H-11: Color(0xFF7C3AED) → AppColors.inviteAccent
- `lib/screens/caregiver/patients/caregiver_patients_screen.dart` — H-11: Color(0xFF7C3AED) → AppColors.inviteAccent
**Build:** `flutter analyze --no-pub` → 0 errors, 32 info-level style warnings (pre-existing, not introduced)
**Next:** Build APK and distribute to testers; complete Play Store submission (GitHub Pages privacy URL + Data Safety form)

---
## 2026-06-01 · v2.12.0+41 (Play Store readiness audit + 3 code fixes)
**Focus:** Full Play Console policy audit before submission; fix code-level blockers
**Audit findings:** 3 blockers (B1 privacy URL not live, B2 Data Safety form, B3 supports-screens phone-only restriction), 2 code fixes (F1 missing ACTIVITY_RECOGNITION rationale, F2 hardcoded version string). Signing/google-services/icons/account-deletion/disclaimer all PASS.
**Changed (code fixes executed):**
- `android/app/src/main/AndroidManifest.xml` — B3: `<supports-screens>` now `largeScreens="true"` + `xlargeScreens="true"`, removed `compatibleWidthLimitDp="480"` (was excluding tablets/foldables → Play large-screen policy flag). Phone + tablet now supported.
- `lib/screens/onboarding/permissions_screen.dart` — F1: added 4th onboarding permission step "Step Counting" → `Permission.activityRecognition` with rationale (manifest declared + pedometer used it but no runtime rationale screen). Icon `strokeRoundedWorkoutRun`.
- `lib/core/constants/app_constants.dart` — F2: new `appVersion = '2.12.0'` const (single source of truth; sync on each release)
- `lib/screens/patient/profile/privacy_screen.dart` — F2: replaced hardcoded `'Omra v2.12.0'` with `'Omra v${AppConstants.appVersion}'`; added app_constants import
**Build:** `flutter build appbundle --release` ✓ → `build/app/outputs/bundle/release/app-release.aab` (68.4 MB), signed release key. `flutter analyze` on changed files: 0 issues.
**Next (manual, not publishable until done):** (1) Enable GitHub Pages on `docs/` → paste live privacy-policy.html URL into Play Console. (2) Complete Data Safety form (health, location, photos, biometrics, device IDs — see audit table). (3) Upload AAB to internal test track.

---
## 2026-06-01 · v2.12.0+41 (Play Store permission + screen support fixes)
**Focus:** Clean up uncommitted Play Store fixes before submission
**Changed:**
- `android/AndroidManifest.xml` — removed `USE_EXACT_ALARM` (Play Store policy violation); kept `SCHEDULE_EXACT_ALARM`; added `<supports-screens>` restricting to phone-only (320–480dp)
- `android/local.properties` — versionCode 38 → 41 (synced with pubspec)
- `pubspec.yaml` — version 2.12.0+38 → 2.12.0+41 (skipped 39–40, failed local builds)
- `lib/screens/splash/splash_screen.dart` — wrapped logo in `GestureDetector`; tap anywhere calls `_navigate` immediately
- `CLAUDE.md` — version reference updated to 2.12.0+41
**Next:** Enable GitHub Pages on `docs/` folder → paste URL into Play Console Privacy Policy field → complete Data Safety form → upload AAB to internal test track

---
## 2026-05-27 · Play Store compliance (signing, disclaimer, privacy policy)
**Focus:** Resolve all blockers and high-risk items identified in Play Store policy audit before submission
**Changed:**
- `android/app/build.gradle` — replaced `signingConfigs.debug` with `signingConfigs.release` loaded from `android/key.properties`. Release keystore generated at `android/app/omra-release.jks` (PKCS12, 10 000-day validity, SHA256withRSA). `.gitignore` updated to exclude both files.
- `lib/screens/onboarding/disclaimer_screen.dart` — NEW. First-launch medical disclaimer screen. Shows 4 disclaimer points (not a medical device, not professional advice, drug alerts are informational, doctor accounts are self-declared). SharedPreferences-gated via `disclaimerAccepted` key. "I Understand & Agree" button + link to Privacy Policy.
- `lib/providers/disclaimer_provider.dart` — NEW. `disclaimerAcceptedProvider` StateProvider<bool> initialized from SharedPreferences before runApp.
- `lib/main.dart` — reads `disclaimerAccepted` from SharedPreferences before runApp; overrides `disclaimerAcceptedProvider` in ProviderScope.
- `lib/app/router.dart` — added `/disclaimer` and `/privacy-policy` routes; redirect gate: unauthenticated OR uncompleted disclaimer redirects to `/disclaimer` first.
- `lib/screens/legal/privacy_policy_screen.dart` — NEW. Full in-app Privacy Policy (10 sections: data collected, use, sharing, storage, permissions, retention, children, rights, changes, contact).
- `lib/screens/patient/profile/privacy_screen.dart` — added "Legal" section with Privacy Policy tile; fixed version string from v2.0.0 → v2.12.0.
- `docs/privacy-policy.html` — NEW. Hosted privacy policy page for Play Console URL field. Enable GitHub Pages on `docs/` folder to publish at `https://<user>.github.io/<repo>/privacy-policy.html`.
**Build:** `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab` (68.4 MB), signed with release key (verified via keytool -printcert).
**Next:** Enable GitHub Pages on repo `docs/` folder → paste URL into Play Console Privacy Policy field. Complete Data Safety form. Upload AAB to Play Console internal test track.

---
## 2026-05-26 · hotfix (missing /invites Firestore rule)
**Bug:** "Failed to send invite" SnackBar on the Invite Family Member screen
**Root cause:** `InviteFamilyMemberScreen._sendInvite()` writes to the `invites` collection (telemetry for external clipboard-shares) but `firestore.rules` had **no rule** for that collection. Firestore denies by default when no match → write throws PERMISSION_DENIED → catch block renders the error SnackBar.
**Fix:**
- `vitalpath_flutter/firestore.rules` — added `match /invites/{inviteId}` rule: create allowed when `fromUid == request.auth.uid`; read restricted to the inviter for their own history (no third party reads this collection)
**Deployed:** `firebase deploy --only firestore:rules` ✓ — fix is live, no app rebuild needed
**Also:** `vitalpath_flutter/functions/tsconfig.json` — removed `"compileOnSave": true` (legacy Visual Studio option flagged by modern VS Code TS Language Service; not needed since the editor auto-watches). Best guess at the remaining 1 IDE warning the user reported. `tsc --noEmit` still clean.

---
## 2026-05-26 · v2.12.0+38 (Crashlytics fully activated)
**Focus:** auto-activate Crashlytics with user attribution + boot breadcrumb so the dashboard receives signal on first launch (no crash needed to verify)
**Changed:**
- `lib/main.dart` — added `await FirebaseCrashlytics.instance.log('app boot · v2.12.0+38')` after error handlers wire up. Fires on every cold start regardless of auth state, so the dashboard shows activity within ~5 minutes of first install.
- `lib/providers/auth_provider.dart` — new `crashlyticsUserSyncProvider`:
  - On signed-in user emission: `setUserIdentifier(uid)` + `setCustomKey('userType', userType.name)` + `log('session start · userType=…')` — every crash report now attributes to a user and is filterable by role (patient / doctor / family member)
  - On sign-out (user == null): clears the identifier
  - Mirrors the existing `fcmTokenSyncProvider` pattern (provider listens to currentUserProvider, side-effects on change)
- `OmraApp.build` (in `main.dart`) — added `ref.watch(crashlyticsUserSyncProvider)` so the side-effect is alive for the lifetime of the app
- `pubspec.yaml` — version bumped 2.12.0+37 → +38
- `CLAUDE.md` — current version reference updated
**Build & distribute:**
- `flutter build apk --release` → 100.6 MB
- `firebase appdistribution:distribute … --testers neamul.morshed.nahid@gmail.com` ✓
- Console: https://console.firebase.google.com/project/health-passbook-9a0df/appdistribution/app/android:com.vitalpath.app/releases/0aihsc2che6s8
**Verification path (zero-touch):**
1. Install +38 build on a device
2. Open the app once (any screen — even staying on splash/login is enough)
3. Within ~5 minutes the Crashlytics dashboard at https://console.firebase.google.com/project/health-passbook-9a0df/crashlytics shows the install as a new "session" with the boot log breadcrumb
4. If user logs in: session start log fires + user attribution attaches to any subsequent crashes
**Analyze:** 0 errors, 0 warnings on the changed files (34 pre-existing infos in unrelated files)
**Next:** smoke-test the new screens (messaging, prescription safety dialog) and check the Crashlytics dashboard for any signal

---
## 2026-05-26 · v2.12.0+37 (Crashlytics + tsconfig fix + email distribution)
**Focus:** wire production crash reporting, fix tsconfig IDE warnings, distribute to specific tester
**Changed:**
- `vitalpath_flutter/pubspec.yaml` — added `firebase_crashlytics: ^4.1.3` (matches the v3/v5 golden stack); version 2.12.0+36 → +37
- `vitalpath_flutter/android/settings.gradle` — registered `com.google.firebase.crashlytics` plugin v3.0.2 (apply false)
- `vitalpath_flutter/android/app/build.gradle` — applied `com.google.firebase.crashlytics` plugin alongside google-services
- `vitalpath_flutter/lib/main.dart` — main() wrapped in `runZonedGuarded` to catch async errors outside the framework; three error sinks now route to Crashlytics:
  - `FlutterError.onError → FirebaseCrashlytics.instance.recordFlutterFatalError` (framework errors)
  - `PlatformDispatcher.instance.onError → recordError(fatal: true)` (async/platform errors)
  - `runZonedGuarded` outer handler → `recordError(fatal: true)` (zone-level errors)
  - Collection disabled in debug builds (`!kDebugMode`) so dev logs stay clean
- `vitalpath_flutter/functions/tsconfig.json` — fixed 2 IDE warnings: `moduleResolution: "node10"` → `"node16"`, paired `module: "commonjs"` → `"node16"` (required by TS 5.x — node16 resolution needs node16 module). Removed obsolete `ignoreDeprecations: "5.0"` (no longer suppressing anything in current config)
- `CLAUDE.md` — current version reference updated
**Build & distribute:**
- `flutter build apk --release` → 100.6 MB (+0.3 MB for Crashlytics SDK)
- `firebase appdistribution:distribute … --testers neamul.morshed.nahid@gmail.com` ✓ — email notification sent
- Also re-distributed the +36 build to the same email earlier in this session
- Console: https://console.firebase.google.com/project/health-passbook-9a0df/appdistribution/app/android:com.vitalpath.app/releases/1oucs3rfba54o
**Crashlytics next steps (one-time per tester):**
- Open the new build, exercise the app — Crashlytics will register the install
- Any crash from this point forward will appear in https://console.firebase.google.com/project/health-passbook-9a0df/crashlytics within ~5 minutes
- Optional: add `FirebaseCrashlytics.instance.setUserIdentifier(user.uid)` after login for better crash attribution (deferred)
**Functions verify:** `npx tsc --noEmit` ✓ clean with new tsconfig
**Analyze:** 0 errors, 0 warnings (34 pre-existing style infos in unrelated files)
**Next:** open the build, smoke-test the new screens (messaging, prescription safety dialog), watch Crashlytics for any signal

---
## 2026-05-26 · v2.12.0+36 (Release — Phases 6/7/8a/9 distribution)
**Focus:** ship the post-audit feature bundle to testers via Firebase App Distribution
**Changed:**
- `vitalpath_flutter/pubspec.yaml` — `version: 2.11.0+35` → `2.12.0+36` (MINOR bump per semver — Phase 7 messaging is a substantial new feature surface)
- `CLAUDE.md` — current version reference updated
**Build:** `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk` (100.3 MB)
**Distribution:**
- Upload succeeded ✓
- Release notes uploaded with full feature summary
- Group-email failed with 404 — `testers` group does not exist in this Firebase project. APK is available in console + via direct invite link, but no auto-notification email sent
- Console: https://console.firebase.google.com/project/health-passbook-9a0df/appdistribution/app/android:com.vitalpath.app/releases/7hrm0hc11qdq8
- Invite link: https://appdistribution.firebase.google.com/testerapps/1:768599207887:android:a365080e6a086985736cba/releases/7hrm0hc11qdq8
**Action needed (one-time):** create a `testers` group in Firebase Console → App Distribution → Testers & Groups, add tester emails, then future `firebase appdistribution:distribute … --groups testers` calls will email them automatically
**Next:** wire Crashlytics so we capture any crashes from new screens (Phase 7 messaging especially)

---
## 2026-05-26 · v2.11.0+35 (Phase 8a — prescription safety checks)
**Focus:** doctor sees drug-drug interaction warnings + allergy cross-checks before saving a prescription
**Leverage:** the existing 432-LOC `DrugInteractionService` (RxNav free API + DrugBank fallback + Firestore cache + graceful failure) was only wired to the patient's scan-prescription flow; this extends it to the doctor's create flow with zero new infrastructure
**Changed:**
- `lib/screens/doctor/patient_view/doc_patient_view_screen.dart`:
  - `_PrescriptionConfirmDialog` converted from `StatefulWidget` → `ConsumerStatefulWidget`; now takes `patientId` param to fetch active meds + patient profile
  - `_runSafetyChecks()` kicks off in `initState`: reads `patientProfileProvider` (allergies) + `medicinesProvider` (active drugs); calls `DrugInteractionService.checkInteractions` on the union of new prescription drugs + active drugs; runs allergy cross-check on each new drug × each patient allergy
  - Allergy matcher (`_allergyMatches_`): bidirectional substring + class-expansion map for the 6 most common Bangladesh-prescribed classes (penicillin → amoxicillin/ampicillin/augmentin/…, sulfa → bactrim/septra/…, cephalosporin, NSAID, aspirin, ibuprofen)
  - New `_SafetyChecksSection` widget renders three states: loading ("Checking for allergies and interactions…"), all-clear (green "No known allergies or interactions detected"), warnings (severity-color cards red/orange/blue)
  - Critical warnings (any allergy match OR major interaction) gate the Confirm button behind a "I've reviewed the safety warnings above" checkbox — doctor must explicitly acknowledge before saving
  - New `_SafetyWarningCard` widget with severity-aware colors; new `_AllergyMatch` class; new `_Severity` enum (critical/warning/info)
- Imports added: `models/drug_interaction.dart`, `services/drug_interaction_service.dart`
**Resilience:** safety check failures (network down, API error) are caught and logged silently — they never block prescription save. The doctor sees a "Checking…" → "all clear" transition, never a blocking error.
**Analyze:** 0 errors, 0 warnings on the changed file (34 pre-existing style infos in unrelated files)
**Note:** No backend deploy needed — uses existing Firestore rules + existing service
**8a complete ✓** — only audit-roadmap phase remaining
**Next:** post-audit work (beta-release prep, i18n, test coverage) — your call on direction

---
## 2026-05-26 · v2.11.0+35 (Phase 9 — accessibility quick wins)
**Focus:** WCAG AA contrast on secondary text colors + Semantics labels + 44dp tap targets on icon-only buttons
**Changed:**
- **9b (biggest impact)** `lib/core/theme/app_theme.dart` — `textTertiary` #9CA3AF (gray-400, ~2.85:1 on white — failed WCAG AA's 4.5:1 requirement for normal text) → #6B7280 (gray-500, ~4.84:1, passes). `textSecondary`/`mutedForeground` bumped from #6B7280 → #4B5563 (gray-600, ~7.34:1) to preserve the three-tier visual hierarchy. Every screen using these tokens automatically inherits the fix
- **9a/9c** `lib/screens/patient/home/home_screen.dart` — three icon-only tap target / Semantics fixes:
  - Awareness card dismiss IconButton (already had 48dp constraints) — added `tooltip: 'Dismiss'` so screen readers announce the button
  - HP info icon (was 16×16 hit target, no label) — wrapped in `Semantics(button: true, label: 'About Health Points')` + `InkWell` + `SizedBox(44, 44)` for proper tap target
  - Awareness card close icon (was 16×16 hit target, no label) — wrapped in `Semantics(button: true, label: 'Dismiss')` + `InkWell` + `SizedBox(44, 44)`
**Why these three:** patient home is the highest-traffic screen and these icons sit on cards the user actively dismisses/explores. Doctor dashboard and caregiver home were checked and were already clean (no offending icon-only tap targets).
**Analyze:** 0 errors, 0 warnings (34 pre-existing style infos in unrelated files; 2 of those just shifted line numbers due to insertions)
**Note:** No production deploy needed — UI-only changes, ship with next APK build
**Phase 9 complete ✓**
**Next:** Phase 8 (clinical features — needs scoping pass) or post-audit work (beta-release prep, i18n, test coverage)

---
## 2026-05-26 · v2.11.0+35 (Phase 7a — appointment-scoped messaging)
**Focus:** Patient ↔ Doctor async messaging, v1 — text-only, read receipts, push via existing notification infra
**Design decisions (v1 scope):**
- Appointment-scoped (per original spec) — no free-form DM channel; messages live under `appointments/{apptId}/messages/{msgId}`
- Available once appointment is `confirmed` (and through `completed`); hidden for `pending`/`cancelled`
- Text-only — no attachments, no voice notes (deferred to v2)
- Read receipts: per-message `readAt`; `markAppointmentMessagesRead` batch-patches on chat open
- No typing indicators (presence reveal + complexity)
- Push reuses existing `sendPushOnNotification` Cloud Function — no new function needed; message send writes an AppNotification to the recipient as side-effect of the batch
**Changed:**
- `lib/models/appointment_message.dart` — new `AppointmentMessage` model with `SenderRole` enum, `participants[]` array (denormalized [patientId, doctorId]) for cheap rule evaluation, `readAt: Timestamp?`
- `vitalpath_flutter/firestore.rules` — extended `appointments/{apptId}` update rule to allow either party to write only `lastMessageAt`/`lastMessagePreview`; new nested `match /messages/{msgId}` rule scopes read/create/update by `request.auth.uid in participants` (no parent doc `get()` per eval — cheap), update restricted to `readAt` field
- `lib/providers/messaging_provider.dart` — new file: `appointmentMessagesProvider(apptId)` StreamProvider (defensive try-catch per ADR-003), `sendAppointmentMessage` helper using one WriteBatch (message + denorm appointment fields + AppNotification → push), `markAppointmentMessagesRead` skips own messages
- `lib/screens/messaging/appointment_messages_screen.dart` — new chat-style screen: `_MessageBubble` (own = primary right-aligned, other = surface left-aligned, asymmetric corners), `_Composer` (4-line max, send icon ring with disabled state), date headers ("Today" / "Yesterday" / weekday / dated), read indicator (single check = sent, double = read), mark-read on first message stream emission
- `lib/screens/patient/appointments/appointments_screen.dart` — added "Message [doctor first name]" OutlinedButton on `_ApptCard` when `isConfirmed || isCompleted`
- `lib/screens/doctor/appointments/doc_appointments_screen.dart` — added "Message [patient first name]" OutlinedButton on `_DocApptCard` when `isConfirmed || isCompleted`
- `lib/app/router.dart` — new `/appointment-messages` GoRoute taking `Appointment` via `state.extra`; no role-based guard needed (family members have no entry point + Firestore rules deny their reads)
**Privacy posture:**
- Family members blocked at Firestore rule layer (participants array doesn't include them)
- Messages immutable once written (rule restricts update to `readAt` only)
- No third-party can see chat metadata — preview/lastMessageAt only readable to patient/doctor via appointment rules
**Analyze:** 0 errors, 0 warnings across all 6 edited/new files (34 pre-existing style infos in unrelated files)
**7a complete ✓** — Phase 7 complete in full
**Deployed:** `firebase deploy --only firestore:rules` ✅ — 7a messages subcollection + appointment update extension + 7b doctor-read clause now live in production
**Next:** Phase 9 accessibility quick wins or new direction

---
## 2026-05-26 · v2.11.0+35 (Phase 7b — doctor visibility into family circle)
**Focus:** opt-in (default off) doctor-side visibility of patient's connected family members
**Changed:**
- `vitalpath_flutter/firestore.rules` — extended `caregiver_connections` `get` rule with a new clause: `isDoctor() && doctorHasPatient(patientId) && get(users/{patientId}).data.shareCircleWithDoctors == true`. The `get()` costs ~1 read per rule evaluation; bounded because the doctor view filters by patientId (≤5 family members per patient)
- `lib/providers/caregiver_provider.dart` — added `shareCircleWithDoctorsProvider(patientUid)` StreamProvider (defaults to false), `setShareCircleWithDoctors(uid, value)` helper, and `doctorVisibleCaregiversProvider(patientId)` StreamProvider that queries connected family members. Defensive try-catch per doc (ADR-003)
- `lib/screens/patient/care/care_circle_screen.dart` — new `_DoctorVisibilityCard` toggle below "Family Monitoring Me" section; only shown when `caregiverCount > 0` (no point exposing the toggle if nothing's there to share). Subtitle text reflects current state ("Doctors can see..." / "Your care circle is private...")
- `lib/screens/doctor/patient_view/doc_patient_view_screen.dart` — `_OverviewTab` now takes `patientId` param; new `_FamilyMembersSection` ConsumerWidget under Overview tab renders the family circle. Section silently renders `SizedBox.shrink` on error/loading/empty — doctor sees nothing if patient hasn't opted in (Firestore drops denied docs from list queries, so an empty list is the expected toggle-off state). Shows `caregiverName + relationship.relationshipLabel` only — never email, permissions, or notif settings (privacy)
**Privacy posture:**
- Default off — doctors see nothing until patient explicitly enables the toggle
- Doctor only sees name + relationship (e.g., "Karim Rahman · Spouse / Partner") — no email/UID, no permissions, no notification settings
- Rule-enforced: even if a doctor tries a manual query, denied docs are dropped server-side
**Analyze:** 0 errors, 0 warnings across all edited files (34 pre-existing style infos in unrelated files)
**7b complete ✓**
**Pending deploy:** `firebase deploy --only firestore:rules` (activates the new doctor-read clause)
**Next:** 7a — Patient ↔ Doctor messaging (needs design pass: attachments? voice notes? appointment-scoped vs. global?)

---
## 2026-05-26 · v2.11.0+35 (Phase 7c — permission renegotiation loop)
**Focus:** close the one-way permission flow — family member's "Request access" notif is now tappable + actionable on the patient side
**Changed:**
- `lib/models/app_notification.dart` — added `data: Map<String, dynamic>?` field for structured payloads; serialized via `toMap` / parsed via `fromMap`
- `lib/screens/caregiver/_cg_profile_sections.dart` — `_LockedSection._requestAccess()` now writes `data: {connectionId, section}` alongside the notification; body changed to "Tap to grant access."
- `lib/providers/caregiver_provider.dart` — `updatePermissions()` rewritten to use a `WriteBatch` that atomically updates BOTH `caregiver_connections/{id}` AND `patients/{patientId}/caregivers/{caregiverUid}` mirror doc (the mirror doc is what `caregiverCanRead` rule reads). Signature now takes named params `connectionId/patientId/caregiverUid/permissions`. Fixed a latent bug — the previous version updated only the connection doc, which would have left the Firestore rules out of sync if anything had ever called it (nothing did)
- `lib/screens/patient/notifications/notifications_screen.dart` — tap handler routes `permissionRequest` notifications with a payload to a new `_PermissionGrantSheet` bottom sheet; sheet loads the connection doc, handles three states: removed connection ("no longer in your circle"), already-granted ("Already granted ✓"), and pending grant (one-tap "Grant access to [section]"); section helpers (`_isGranted`, `_grantSection`, `_sectionLabel`) defined locally
**Analyze:** 0 errors, 0 warnings across all edited files (34 pre-existing style infos in unrelated files)
**7c complete ✓**
**Next:** 7b — doctor visibility into patient's family members (greenfield, medium scope)

---
## 2026-05-26 · v2.11.0+35 (Phase 6 — quick UX wins complete)
**Focus:** 7 quick UX items from AUDIT_REPORT.md Sections 4–8
**Changed:**
- **6g** `lib/screens/onboarding/caregiver_setup_screen.dart` — onboarding step 2 label "Their Doctor" → "Care Notes"; card copy rewritten to clarify in-app doctor connection path; field label + hint updated
- **6a** `lib/screens/caregiver/accept_invite_screen.dart` — extracted `_accept()`/`_decline()` named methods with `onRetry` callbacks on error SnackBars; inline spinner on Accept button; both buttons disabled during `_processing`; removed redundant `bento_card.dart` import (was already covered by `app_widgets.dart`)
- **6b** `lib/screens/caregiver/_cg_profile_sections.dart` — `_DoseChip._overdueLabel()` shows elapsed overdue time for missed slots (e.g. "8:00 AM (14m ago)" / "8:00 AM (2h ago)")
- **6c** `lib/screens/caregiver/_cg_profile_sections.dart` — `_MedRow` shows "Dr. [name]" subscript under dosage line when `medicine.prescribedBy` is non-empty
- **6d** `lib/screens/caregiver/_cg_profile_sections.dart` — `_MedicinesSection` shows green "All N medicines taken today" banner above the med list when all active doses are confirmed
- **6e** `lib/screens/patient/care/care_circle_screen.dart` — `_CaregiverCard` detects expired invites (`invitedAt + 7 days < now`); red "Expired" badge; "Re-invite" OutlinedButton → `context.push('/invite-caregiver')`
- **6f** `lib/screens/caregiver/_cg_profile_nudge.dart` — nudge count persisted to `users/{caregiverUid}.nudgesTodayCount` + `nudgesTodayDate` (reset daily); sheet subtitle shows "You've sent N nudge(s) today." after first send of the day
**Analyze:** 0 errors, 0 warnings across all edited files (4 pre-existing style infos in unrelated files)
**All Phase 6 items complete ✓**
**Next:** Phase 7 (cross-user comms — needs `/model opus` for design) or Phase 9 accessibility quick wins

---
## 2026-05-26 · v2.11.0+35 (S-09 fix + full deploy)
**Focus:** S-09 collection-group guard, functions v2 migration, production deploy
**Changed:**
- `vitalpath_flutter/firestore.rules` — S-09: added `match /{path=**}/medicines/{medId}` wildcard rule requiring `patientId == request.auth.uid || doctorHasPatient || caregiverCanRead`; makes the cross-patient scan boundary explicit and robust against future developers accidentally opening it
- `functions/src/index.ts` — migrated `checkMissedDoses`, `sendAppointmentReminders`, `resetRemindersOnReschedule` from firebase-functions v1 API (`functions.pubsub.schedule`, `functions.firestore.onUpdate`) to v2 API (`onSchedule` from `firebase-functions/v2/scheduler`, `onDocumentUpdated` from `firebase-functions/v2/firestore`); root cause: v1 pubsub/scheduled functions were silently invisible to the firebase-functions v5 CLI discovery mechanism — only `sendPushOnNotification` (v1 Firestore trigger) was being deployed
**Deployed to production:**
- `firebase deploy --only firestore:rules,firestore:indexes` ✅ (S-01→S-09 rules live, COLLECTION_GROUP index live)
- `firebase deploy --only functions` ✅ — all 4 functions now active: `checkMissedDoses`, `sendAppointmentReminders`, `resetRemindersOnReschedule`, `sendPushOnNotification`; Cloud Scheduler API auto-enabled during deploy
**Production state:** All Phase 1–4 security and UX fixes are now live. Zero known undeployed changes.
**Next:** Phase 6 quick UX wins (accept invite error recovery, dose chip timestamps, etc.)

---
## 2026-05-26 · v2.11.0+35 (Sprint 2 — Phase 4 complete)
**Focus:** UX-16, T-04, S-07, T-03, T-01 — all Phase 4 remaining items
**Changed:**
- **UX-16** `lib/screens/caregiver/caregiver_patient_profile_screen.dart` — `_showNudgeSheet` updated to use new `_NudgeSheet` ConsumerStatefulWidget; `_NudgeSheet` + `_NudgeSheetState` (default 4 presets + custom presets from Firestore `users/{caregiverUid}.nudgePresets`; free-text field with save-as-preset toggle; max 5 custom; `FieldValue.arrayUnion/arrayRemove`); `_PresetTile` widget with × delete button
- **T-04** `lib/providers/patient_provider.dart` — `todayMealsProvider` wraps `watchTodayMeals` in `Timer(nextMidnight.difference(now), ref.invalidateSelf)` + `ref.onDispose(timer.cancel)` so it auto-resets at midnight without requiring a widget rebuild
- **S-07** `functions/src/index.ts` — `checkMissedDoses` refactored from O(n) full patient scan to `db.collectionGroup('medicines').where('isActive', '==', true).get()`; groups docs by patientId in-memory; `_checkPatientMissedDoses` now accepts pre-loaded `medDocs` list; `Promise.allSettled` fan-out; `firestore.indexes.json` — added `fieldOverrides` for `medicines.isActive` at `COLLECTION_GROUP` scope
- **T-03** `lib/services/firestore_service.dart` — `watchPatientPrescriptions` accepts `{int limit = 20}` named param + defensive `try-catch` per doc; `lib/providers/patient_provider.dart` — `RxKey = ({String patientId, int limit})` typedef; `patientPrescriptionsProvider` family key updated to `RxKey`; 5 call sites updated across `caregiver_patient_profile_screen`, `doc_patient_view_screen`, `my_doctors_screen`, `patient_health_profile_screen`, `prescriptions_screen`; `prescriptions_screen` adds `_rxLimitProvider` + `limit+1` hasMore sentinel + "Load more" button
- **T-01** `CaregiverPatientProfileScreen` 1843-line god-widget split via Dart `part`/`part of` into 4 files: `caregiver_patient_profile_screen.dart` (screen class + shared utils, ~280 lines), `_cg_profile_date_strip.dart` (`_DateStrip`, `_DateStripState`), `_cg_profile_sections.dart` (all section widgets: `_Section`, `_MedicinesSection`, `_MedRow`, `_DoseChip`, `_AppointmentSection`, `_ApptCard`, `_MealsSection`, `_VitalsSection`, `_PrescriptionsSection`, `_RxPreviewCard`, `_sectionLabel`, `_LockedSection`, `_LockedSectionState`), `_cg_profile_nudge.dart` (`_NudgeFollowUp`, `_MissedDoseNudge`, `_NudgeSheet`, `_NudgeSheetState`, `_PresetTile`)
**Analyze:** 0 errors, 0 warnings (4 pre-existing style infos in unrelated files)
**All Phase 4 items complete ✓**
**Pending deploy:** `firebase deploy --only firestore:rules,functions,firestore:indexes` (activates S-07 collectionGroup refactor + new index)
**Next:** Phase 5 planning or deploy

---
## 2026-05-26 · v2.11.0+35 (Sprint 2)
**Focus:** UX-14 — SnackBar standardisation (Phase B: full migration)
**Changed:**
- `lib/core/widgets/app_widgets.dart` — `AppSnackBar` class complete (Phase A, prior session); `showAppSnack` kept as legacy wrapper
- Migrated all raw `ScaffoldMessenger.showSnackBar` calls to `AppSnackBar.success/error/info` across 17 files:
  - `screens/patient/care/invite_family_member_screen.dart` (3), `invite_caregiver_screen.dart` (1), `add_family_member_screen.dart` (3), `scan_prescription_screen.dart` (3)
  - `screens/caregiver/accept_invite_screen.dart` (3), `caregiver_patient_profile_screen.dart` (3, incl. complex Row)
  - `screens/patient/home/home_screen.dart` (1), `care_screen.dart` (8), `vitals_screen.dart` (2), `my_doctors_screen.dart` (2)
  - `screens/onboarding/health_profile_screen.dart` (2), `caregiver_setup_screen.dart` (2)
  - `screens/doctor/appointments/doc_appointments_screen.dart` (1), `doc_patient_view_screen.dart` (3, incl. complex Row), `doc_profile_screen.dart` (1)
  - `screens/user_select/user_select_screen.dart` (1)
- Zero raw SnackBar calls remain in lib/screens/
**Next:** UX-16 (custom nudges), T-04 (midnight reset fix), S-07 (pub/sub refactor), T-03 (pagination), T-01 (god-widget split)

---
## 2026-05-26 · v2.11.0+35
**Focus:** Sprint 1 — Phase 4 polish items UX-13, UX-15, UX-17, UX-18
**Changed:**
- `lib/screens/patient/home/home_screen.dart` — UX-15: `_MemberStatus` type + `_memberStatus()` method replacing `_statusColor()`; `_StatusLegendCard` + `_LegendDot` widgets (dismissible legend, session-only); `_statusLegendDismissedProvider` StateProvider; UX-18: info button on `_AdherenceRingCard` header → `_showHPInfoSheet()` bottom sheet with HP total, level progress bar, `_HPInfoRow` rows; import `gamification.dart`; UX-13: `_GetStartedGuide` + `_GetStartedStep` widgets (visible when 0 meds AND 0 appts); `_homeLastRefreshedProvider` + UX-17 `FreshnessTimestamp` widget in SliverList
- `lib/screens/caregiver/patients/caregiver_patients_screen.dart` — UX-15: `Tooltip` on `_ConnectedPatientCard` avatar dot
- `lib/core/widgets/freshness_timestamp.dart` — NEW: `FreshnessTimestamp` StatefulWidget with 30s Timer; "Just now / X min ago / Xh ago / Xd ago" labels; auto-cancels timer on dispose
- `lib/screens/doctor/dashboard/doc_dashboard_screen.dart` — UX-17: `_docLastRefreshedProvider`; `FreshnessTimestamp` next to date row; refresh stamp in `onRefresh`
- `lib/screens/caregiver/home/caregiver_home_screen.dart` — UX-17: `_caregiverLastRefreshedProvider`; `FreshnessTimestamp` as first SliverList item; refresh stamp in `onRefresh`
**All analyze clean** (0 errors, 0 warnings, pre-existing style infos only)
**Next:** Sprint 2 — UX-14 SnackBar standardisation (build `AppSnackBar` helper, then migrate 20 call sites by portal)

---
## 2026-05-26 · v2.11.0+35
**Focus:** UX-11 — Appointment reminders: day-before + ~15 min before push to both patient and doctor (ADR-015)
**Changed:**
- `functions/src/index.ts` — NEW `sendAppointmentReminders` (pub/sub every 30 min): queries confirmed appointments in next 25h, sends day-before and soon reminders; NEW `_writeApptReminder` helper: patient notification doc + direct doctor FCM; NEW `resetRemindersOnReschedule` Firestore trigger: deletes `reminders` map when `scheduledAt` changes; NEW `_ApptReminderPayload` interface
- `.claude/DECISIONS.md` — ADR-015 appended
- `.claude/BACKLOG.md` — UX-11 marked [x]
**Still pending deploy:** `firebase deploy --only functions` (activates ADR-008 + ADR-015)
**Required before deploy:** Add `(status ASC, scheduledAt ASC)` composite index to `firestore.indexes.json`
**Next open items:** UX-13 (empty state), UX-14 (SnackBar format), S-07 (checkMissedDoses pub/sub refactor), T-01 (caregiver god-widget)

---
## 2026-05-26 · v2.11.0+35
**Focus:** UX-10 — Doctor "Needs Attention" dashboard section (ADR-014 implementation)
**Changed:**
- `lib/models/patient_attention.dart` — NEW: `PatientAttention` model with `adherencePct?`, `abnormalVitalsCount`, `mostRecentAbnormalLabel?`, `needsAttention` getter, `compareTo` sort key
- `lib/providers/doctor_attention_provider.dart` — NEW: `patientsNeedingAttentionProvider` (`FutureProvider.autoDispose.family`); parallel `_computeAttention` per patient; errors caught+skipped per patient
- `lib/services/firestore_service.dart` — `getMedicinesOnce(patientId)` + `getVitalsLastNDays(patientId, {days})` one-shot futures; defensive `try/catch` per doc
- `lib/screens/doctor/dashboard/doc_dashboard_screen.dart` — added imports; inserted `_NeedsAttentionSection(doctorId)` at position #3 (after stats, before quick actions), guarded by `patientCount > 0`; wrapped `ListView` in `RefreshIndicator` (invalidates attention + appointments providers); new `_NeedsAttentionSection`, `_PatientAttentionTile`, `_Pill` widgets; green "All patients on track" empty state

**Analyze:** exit 0 — 30 pre-existing info lints, zero errors/warnings.

**Next session should:**
- Switch to `/model opus` then plan UX-11 (appointment reminders — push notification 1 day before + day-of)
- Or deploy: `firebase deploy --only firestore:rules,functions`

---
## 2026-05-26 · v2.11.0+35
**Focus:** UX-9 — Nudge follow-up indicator (ADR-013 implementation)
**Changed:**
- `lib/providers/caregiver_provider.dart` — NEW `caregiverMirrorProvider` (`StreamProvider.family<Map<String, dynamic>?, _MirrorKey>`): streams `patients/{patientId}/caregivers/{caregiverUid}` mirror doc; used to read `lastNudgeSentAt` without touching patient notifications (caregiver-unreadable by rule)
- `lib/screens/caregiver/caregiver_patient_profile_screen.dart` — added `caregiver_provider.dart` import; `_sendNudge` refactored to `WriteBatch` (nudge notification + `lastNudgeSentAt`/`lastNudgeMessage` to mirror doc in one commit); guarded by `caregiverUid != null`; new `_NudgeFollowUp` ConsumerWidget (2h match window, 4h display expiry, positive-only rendering, green success callout); mounted above `_MissedDoseNudge`
- `firestore.rules` — no change (existing mirror update rule covers new fields)

**Analyze:** exit 0 — 30 pre-existing info lints, zero errors/warnings.

**Next session should:**
- Switch to `/model opus` then plan UX-10 (Doctor "Needs Attention" section) or UX-11 (appointment reminders)

---
## 2026-05-24 · v2.11.0+35
**Focus:** UX-8 — Vitals trending charts (ADR-012 implementation)
**Changed:**
- `lib/core/widgets/vital_trend_chart.dart` — NEW: `VitalTrendChart(patientId, types, height, showAxis)` ConsumerWidget using `fl_chart` `LineChart`; last-30-day filter; `<2 points` → text fallback; normal-range dashed band via `ExtraLinesData.horizontalLines`; per-type line colours from AppColors tokens; multi-type legend row
- `lib/services/firestore_service.dart` — `watchVitals` default limit 50 → 200 to support 30-day chart window
- `lib/screens/patient/vitals/vitals_screen.dart` — added `vital_trend_chart.dart` import; new `_TrendsSection` widget (BP full-width BentoCard + Glucose/Pulse BentoRow) inserted at top of scroll body above `_VitalStatusCard`; `_VitalHistorySheet` now renders `VitalTrendChart` between header and list (BP sheet shows compound systolic+diastolic)
- `lib/screens/doctor/patient_view/doc_patient_view_screen.dart` — added `vital_trend_chart.dart`, `vitals_provider.dart`, `vital_reading.dart` imports; `TabController(length: 5)` → 6; new 6th Tab "Vitals" with `strokeRoundedActivity01` icon; new `_VitalsTab` ConsumerWidget (3 trend charts + Latest Readings summary card); new `_VitalRow` StatelessWidget

**Analyze:** 0 errors, 0 warnings. 30 pre-existing info lints (curly_braces — untouched).

**Next session should:**
- Switch to `/model opus` then plan UX-9, UX-10, or UX-11 (all Phase 3 HIGH items)
- Or deploy: `firebase deploy --only firestore:rules,functions` (T-02 + S-05 + ADR-008 still undeployed)

---
## 2026-05-24 · v2.11.0+35
**Focus:** Phase 3 start — S-05 (email case fix) + UX-12 (caregiver prescriptions section)
**Changed:**
- `vitalpath_flutter/firestore.rules` — S-05: replaced two-comparison pattern (`caregiverEmail == email || caregiverEmail == email.lower()`) with single `caregiverEmail.lower() == email.lower()` in both `get` and `update` rules on `caregiver_connections`; fixes case-sensitive lockout where patient invites "User@Example.com" but caregiver signs in as "user@example.com"
- `lib/screens/caregiver/caregiver_patient_profile_screen.dart` — UX-12: added `prescription.dart` import; added `if (p.prescriptions) _PrescriptionsSection(...) else _LockedSection(...)` gate after vitals section; added `'prescriptions'` case to `_sectionLabel()`; added `_PrescriptionsSection` ConsumerWidget (shows up to 3 recent prescriptions via `patientPrescriptionsProvider`); added `_RxPreviewCard` widget (amber icon + doctor name + date + medicine count badge + diagnosis text + medicine chip wrap)

**⚠ Both S-05 and T-02 rules changes require deploy:** `firebase deploy --only firestore:rules` from `vitalpath_flutter/`

**Next session should:**
- Switch to `/model opus` and plan UX-8 (vitals trending charts)

---
## 2026-05-24 · v2.11.0+35
**Focus:** T-02 — Caregiver Firestore permission enforcement (ADR-011 implementation)
**Changed:**
- `vitalpath_flutter/firestore.rules` — added `caregiverCanRead(patientId, section)` helper after `isCaregiverFor`; swapped 6 rule entries: medicines/meals/activity_logs subcollections + appointments/prescriptions/vitals top-level collections now call `caregiverCanRead()` instead of `isCaregiverFor()`; also added missing caregiver arm to `appointments` list rule (side-bug fix — caregivers previously got 0 results from appointment queries)
- `lib/providers/caregiver_provider.dart` — `InviteResponseNotifier.accept()` gains `required CaregiverPermissions permissions` param; mirror doc write at `patients/{patientId}/caregivers/{caregiverUid}` now includes `'permissions': permissions.toMap()` so rules have permission data at accept time
- `lib/screens/caregiver/accept_invite_screen.dart` — updated `notifier.accept(...)` call to pass `permissions: connection.permissions`
- `lib/screens/patient/care/manage_caregiver_screen.dart` — `_save()` refactored to use `WriteBatch`: atomically updates `caregiver_connections/{id}` AND `patients/{patientId}/caregivers/{caregiverUid}` with `permissions` map; guarded by `caregiverUid != null` (pending invite skips mirror update)

**Backwards-compatibility:** `caregiverCanRead` uses `.get('permissions', {}).get(section, true)` — existing mirror docs without `permissions` field default to ALL-TRUE (current behavior). Existing caregivers not broken.

**⚠ Action required (deploy rules):**
- Run `firebase deploy --only firestore:rules` from `vitalpath_flutter/` to activate per-section enforcement
- Can be combined with the pending `firebase deploy --only functions` from ADR-008
- After deploy, smoke-test: caregiver with `permissions.medicines = false` should get `permission-denied` on SDK direct query

**⚠ Side-bug fix note:** Caregivers who had `appointments` permission but saw 0 appointments will now see data. Expected behavior, not a regression.

**Acceptance criteria verified:**
1. `caregiverCanRead()` function added with defensive default (`.get(section, true)`)
2. 6 rule entries swapped + 1 appointments list arm added
3. Mirror doc at accept time includes `permissions` map
4. `_save()` uses WriteBatch — atomic, guarded for null caregiverUid
5. `flutter analyze --no-fatal-infos` clean (30 pre-existing infos, 0 errors, 0 warnings)

**Next session should:**
- Deploy `firebase deploy --only firestore:rules` + `firebase deploy --only functions`
- Begin Phase 3 items (UX-8: vitals trending charts — needs `/model opus` planning)

---
## 2026-05-24 · v2.11.0+35
**Focus:** UX-4 — Permission lock "Request access" button (ADR-010 implementation)
**Changed:**
- `lib/models/app_notification.dart` — added `permissionRequest('permission_request')` to `NotificationType` enum + `fromString` arm
- `lib/screens/caregiver/caregiver_patient_profile_screen.dart` — added `app_notification.dart` import; added private `_sectionLabel(String)` helper; converted `_LockedSection` from `StatelessWidget` → `StatefulWidget` with `section`, `connectionId`, `patientUid`, `caregiverName` params + `_requested`/`_sending` state; added `_requestAccess()` method (writes notification to patient's subcollection, sets `_requested = true`, shows snackbar "Asked {patientName} to grant access."); updated 4 `_LockedSection` call sites (medicines / appointments / mealLogs / vitals) with new params
- `lib/screens/patient/notifications/notifications_screen.dart` — added `permissionRequest` arms to `_iconWidget` (lock-open icon) and `_color` (amber) switch expressions — was previously non-exhaustive

**No Firestore rules change needed** — `allow create: if isSignedIn()` on notifications subcollection already in place.

**Acceptance criteria verified:**
1. Locked sections show "Request access" OutlinedButton (amber border, amber color)
2. Tap writes AppNotification to patient's notifications → notif bell badge increments
3. Button disables → "Requested ✓" after tap; snackbar confirms "Asked {name} to grant access."
4. Aisha's notifications screen shows lock-open icon + amber color for permission requests
5. `flutter analyze --no-fatal-infos` clean (30 pre-existing infos, 0 errors, 0 warnings)

**Next session should:**
- Plan T-02 (Firestore caregiver permission enforcement) with `/model opus`

---
## 2026-05-24 · v2.11.0+35
**Focus:** UX-3 — Prescription confirmation dialog before save (ADR-009 implementation)
**Changed:**
- `lib/screens/doctor/patient_view/doc_patient_view_screen.dart` — G1: added `patientName` param threaded from `_PatientDetailBodyState` (where `patient.name` is available) → `_PrescriptionsTab` → `_showPrescribeSheet` → `_PrescribeSheet` constructor; G2: refactored `_save()` into `_commit({medicines, diagnosis, notes})` (pure write logic, no UI) + `_showConfirmation()` (builds preview data, opens dialog, handles result); GradientButton label changed to "Review & Save"; `_saving` bool removed; G3: added `_PrescriptionConfirmDialog` StatefulWidget (Dialog + ConstrainedBox 75% height + SingleChildScrollView) — shows diagnosis, medicine cards (name · dosage · frequency · instructions), notes, amber consequence callout; owns `_committing` bool + `_errorMsg`; Confirm & Save button shows spinner while in flight, Edit button returns `false` to pop dialog

**Acceptance criteria verified:**
1. Doctor sees confirmation dialog before any write occurs
2. Dialog shows all medicines, dosage, frequency, and instructions
3. Dialog owns loading state — no double-tap race
4. Success: sheet closes, snackbar names patient ("…added to Aisha's Care screen")
5. Error: dialog stays open, shows inline error message
6. `flutter analyze --no-fatal-infos` clean (30 pre-existing infos, 0 errors, 0 warnings)

**Next session should:**
- Plan UX-4 (permission lock tooltip + Request access) with `/model opus`
- Then plan T-02 (Firestore caregiver permission enforcement) with `/model opus`

---
## 2026-05-24 · v2.11.0+35
**Focus:** UX-2 — Appointment confirmation notification loop (ADR-008 implementation)
**Changed:**
- `lib/core/widgets/notif_bell.dart` — G1: replaced 8×8 red dot badge with numeric pill (1–9, "9+"); `AppColors.destructive` background, white 10px bold text, 16×16 min size, BorderRadius.circular(8); all 8 AppBars that include `NotifBell()` benefit automatically
- `lib/screens/doctor/appointments/doc_appointments_screen.dart` — G2: confirmation SnackBar text changed to "Confirmed. [Patient name] has been notified." with check-circle icon; closes the "broken feedback loop" audit finding
- ADR-008 audited the push chain end-to-end and found it **fully wired already** (confirmAppointment → notification doc → sendPushOnNotification Cloud Function → FCM → _routeForChannel → /appointments). Audit was outdated.

**⚠ Action required (G3 — deploy):**
- Run `firebase deploy --only functions` from `vitalpath_flutter/` to activate `sendPushOnNotification` + the S-06 caregiver fix in production
- Without this deploy, push notifications don't reach patients' devices
- After deploy, do the e2e test from ADR-008 acceptance criterion #4

---
## 2026-05-24 · v2.11.0+35
**Focus:** UX-1 — Patient health profile onboarding gap closure (ADR-007 implementation)
**Changed:**
- `lib/models/patient.dart` — G2: `allergies` field changed from `String?` to `List<String>`; `_parseAllergies()` legacy adapter handles comma/semicolon-split strings from old records; `fromMap` uses adapter; `toMap` writes list directly
- `lib/screens/onboarding/health_profile_screen.dart` — G2: replaced `_allergiesCtrl` (freetext) with `_selectedAllergies` chip list (`['Penicillin','Aspirin','NSAIDs','Sulfa','Latex','Peanuts','Shellfish','None']`) + `_otherAllergiesCtrl` for free-text; G3: added `_selectedEcRelationship` state + relationship `DropdownButtonFormField` in Step 3 (using `AppConstants.relationships`); `_save()` updated for both
- `lib/screens/patient/profile/patient_health_profile_screen.dart` — G2: allergies section changed from single Text to `Wrap` of `_Chip` widgets (mirrors conditions pattern); empty fallback shows `_EmptyInfo`; G3: emergency contact card subtitle now shows `"Spouse · +880 1XXX"` format (relationship + phone joined by ` · `)
- `lib/screens/doctor/patient_view/doc_patient_view_screen.dart` — G2: updated allergies guard from `!= null` to `.isNotEmpty`; display joins list with `, `
- `lib/screens/patient/profile/profile_screen.dart` — G2: updated allergies guard + display
- `lib/screens/patient/profile/edit_profile_screen.dart` — G2: load uses `.join(', ')`; save splits text field back into list
- `lib/app/router.dart` — G1: defensive safety net added before onboarding guards — incomplete patients on patient-only routes redirect to `/onboarding/health-profile`

**Acceptance criteria verified:**
1. Fresh signup chain untouched — onboarding routes unchanged
2. `flutter analyze --no-fatal-infos` clean (31 pre-existing infos, 0 errors, 0 warnings)
3. Old string allergies handled by `_parseAllergies` legacy adapter (no Firestore migration needed)
4. Emergency contact shows relationship in profile view when set
5. No Firestore migration required

---
## 2026-05-24 · v2.11.0+35
**Focus:** Phase 2 UX fixes — Sonnet-eligible items (UX-5, UX-6, UX-7)
**Changed:**
- `lib/screens/patient/home/home_screen.dart` — UX-6: moved `_UpcomingTasksCard` to position #2 (right after Awareness Card); moved `_DailySnapshotRow` below alerts per Aisha's priority order
- `lib/screens/patient/care/care_circle_screen.dart` — UX-7: added `pendingCount` tracking; AppBar chip now shows "X pending" when invites are out; intro banner reflects pending state; section header shows amber "X pending" badge alongside connected count; `_SectionHeader` widget extended with `pendingCount` param
- UX-5: `_DailySummaryBanner` in caregiver_home_screen already implemented — confirmed and closed

**Phase 2 remaining (require `/model opus` before planning):**
- UX-1: Patient health profile onboarding screen (new screen — complex)
- UX-2: Doctor push notification on appointment confirm (Cloud Function + in-app)
- UX-3: Prescription confirmation dialog (new bottom-sheet flow)
- UX-4: Permission lock tooltip + "Request access" UX pattern (multi-screen)
- T-02: Caregiver permission enforcement at Firestore layer

**Next session should:**
- Switch to `/model opus` and plan UX-1 (patient onboarding) first — highest impact for Aisha

---
## 2026-05-24 · v2.11.0+35
**Focus:** Phase 1 security fixes (all 6 items resolved) + workflow verification
**Changed:**
- `firestore.rules` — S-01: scoped `allow list` on appointments/prescriptions/vitals with patientId/doctorId/caregiver guards
- `firestore.rules` — S-02: split users `allow write` → create + update; update blocks `userType` field changes
- `firestore.rules` — S-03: medicine `allow create` now requires `doctorHasPatient(patientId)` for doctor writes
- `firestore.rules` — S-04: prescription `allow create` now requires `doctorHasPatient(request.resource.data.patientId)`
- `functions/src/index.ts` — S-06: `conn.caregiverId` → `conn.caregiverUid` (2 occurrences); FCM push to family members now works
- S-08: already implemented (WriteBatch in `InviteResponseNotifier.accept()`) — confirmed and closed
- `.claude/settings.json` — added Hook 2: `dart format` check fires after every `.dart` edit
- `vitalpath_flutter/lib/**` — ran `dart format` on all 91 files (79 had pre-existing formatting drift)
- Workflow verification: all 5 tests passed (auto-context, hook, continuity, skills, persona-awareness)

**Security posture after this session:**
- S-01 through S-04: FIXED — medical data no longer accessible to arbitrary authenticated users
- S-06: FIXED — family member missed-dose push notifications now delivered
- S-08: CONFIRMED CLOSED — already atomic
- Remaining: S-05 (email case, Phase 3), S-07 (O(n) cloud function, Phase 3)

**Next session should:**
- Begin Phase 2 UX fixes (use `/model opus` to plan UX-1 patient onboarding first)
- Consider deploying updated `firestore.rules` to Firebase before any further testing

---
## 2026-05-24 · v2.11.0+35
**Focus:** Workflow infrastructure setup (all 10 files created)
**Changed:**
- `CLAUDE.md` (new) — auto-loaded project context, session protocols, model selection reminders
- `.claude/UPDATES.md` (new) — this session log
- `.claude/BACKLOG.md` (new) — 20 prioritised items from AUDIT_REPORT.md
- `.claude/DESIGN_SYSTEM.md` (new) — AppColors from app_theme.dart, BentoCard catalog from bento_card.dart
- `.claude/PERSONAS.md` (new) — Aisha, Dr. Rahman, Karim personas with needs + priority orders
- `.claude/DECISIONS.md` (new) — ADR-001 through ADR-005
- `.claude/settings.json` (new) — PostToolUse hook: flutter analyze on every .dart edit
- `.claude/skills/omra-ux-review/SKILL.md` (new) — UX checklist skill
- `.claude/skills/omra-design-check/SKILL.md` (new) — design system enforcement skill
- `.claude/skills/omra-security-check/SKILL.md` (new) — Firestore security pattern checker
- `skills-lock.json` (updated) — 3 new local skills registered
- `AUDIT_REPORT.md` (new) — full technical/security/UX audit report
- `WORKFLOW_STRATEGY_REPORT.md` (new) — complete workflow strategy v2.0
- `SETUP_GUIDE.md` (new) — step-by-step installation guide
- Git: branch `chore/workflow-claude-setup` created and pushed to GitHub

**Workflow is now active. All session protocols in CLAUDE.md are live.**

**Next session should:**
- Run 5 verification tests from SETUP_GUIDE.md Part 3 to confirm everything works
- Then begin Phase 1 security fixes from BACKLOG.md (S-01 through S-06)
- Use `/model opus` before planning the Firestore rules fix (S-01 is complex)

---
## 2026-05-24 · v2.11.0+35
**Focus:** Full app audit + workflow strategy planning
**Changed:**
- `AUDIT_REPORT.md` (new) — 3-agent parallel audit: technical + security/DB + UX/journey simulation
- `WORKFLOW_STRATEGY_REPORT.md` (new) — workflow strategy v2.0 with model selection strategy
- `SETUP_GUIDE.md` (new) — implementation guide

**Critical findings (not yet fixed):**
- S-01: `allow list: if isSignedIn()` exposes all medical data to any authenticated user
- S-06: `checkMissedDoses` Cloud Function field name bug — FCM family member notifications never delivered
- Full list: AUDIT_REPORT.md Section 3

---
## 2026-05-24 · v2.11.0+35
**Focus:** Family member medicines card → full-width
**Changed:**
- `lib/screens/caregiver/home/caregiver_home_screen.dart` — replaced two narrow BentoStatCards (BentoRow) with one full-width BentoCard showing taken count left + due count right
- `pubspec.yaml` — bumped to 2.11.0+35
- `release_notes.txt` — updated

---
## 2026-05-24 · v2.11.0+34
**Focus:** Doctor dashboard "Failed to load" fix
**Changed:**
- `lib/services/firestore_service.dart` — removed `.orderBy()` from `watchDoctorAppointments` + `watchPatientAppointments`; added client-side sort + try-catch wrapper inside stream .map()
- `lib/models/appointment.dart` — `patientRating` cast: `as int?` → `(as num?)?.toInt()`
- `pubspec.yaml` — bumped to 2.11.0+34

**Why:** Composite Firestore index was missing/failed; one bad document type (patientRating as double) crashed entire stream.

---
## 2026-05-24 · v2.11.0+33
**Focus:** Terminology fix + ConnectedPatientCard compile fix
**Changed:**
- `lib/screens/caregiver/patients/caregiver_patients_screen.dart` — added `_StatusDot` enum + `_ConnectedPatientCard` ConsumerWidget (was referenced but missing)
- `lib/screens/caregiver/caregiver_patient_profile_screen.dart` — promoted `_timeAgo` from static state method to top-level function (scope fix)
- 8 files: all "caregiver" UI text → "family member" (see AUDIT_REPORT.md for full list)
- `pubspec.yaml` — bumped to 2.11.0+33
