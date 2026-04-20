# VitalPath - Flutter + Firebase Setup Guide

## Prerequisites
- Flutter SDK 3.1+ (https://flutter.dev/docs/get-started/install)
- Android Studio with Flutter plugin
- Firebase CLI (`npm install -g firebase-tools`)
- FlutterFire CLI (`dart pub global activate flutterfire_cli`)

## Step 1: Clean Up Old Files
Delete these leftover folders from a previous build (they are NOT used):
- `lib/features/` (entire folder)
- `lib/app.dart`
- `lib/core/router/`
- `lib/core/theme/app_colors.dart`
- `lib/core/errors/`
- `lib/core/widgets/shell_scaffold.dart`
- `backend/` (entire folder - old Supabase config)

## Step 2: Create Flutter Project Wrapper
Open Terminal in this folder and run:
```bash
flutter create . --org com.vitalpath --project-name vitalpath
```
This generates the android/, ios/, web/ folders and platform configs around the existing lib/ code.

## Step 3: Firebase Setup
1. Go to https://console.firebase.google.com
2. Create a new project called "VitalPath"
3. Enable Authentication:
   - Phone (for OTP login)
   - Google (for Google Sign-In)
4. Create a Cloud Firestore database (Start in test mode, then apply firestore.rules)
5. Enable Cloud Storage
6. Enable Cloud Messaging

### Connect Firebase to Flutter:
```bash
firebase login
flutterfire configure --project=YOUR_PROJECT_ID
```
This auto-generates `lib/firebase_options.dart` with your real config values.

## Step 4: Android Configuration
In `android/app/build.gradle`, ensure:
```gradle
android {
    compileSdkVersion 34
    defaultConfig {
        applicationId "com.vitalpath.app"
        minSdkVersion 23
        targetSdkVersion 34
        multiDexEnabled true
    }
}
```

Add to `android/app/src/main/AndroidManifest.xml` inside `<manifest>`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
```

## Step 5: Deploy Firestore Rules & Indexes
```bash
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

## Step 6: Install Dependencies & Run
```bash
flutter pub get
flutter run
```

## Step 7: Create Asset Folders
```bash
mkdir -p assets/images assets/icons assets/lottie
```
Add placeholder files so Flutter doesn't error on missing assets.

---

## Project Architecture

```
lib/
  main.dart                    # App entry point
  firebase_options.dart        # Firebase config (auto-generated)
  app/
    router.dart                # GoRouter navigation
  core/
    theme/app_theme.dart       # Shadcn-inspired design tokens
    constants/app_constants.dart
    widgets/app_widgets.dart   # Shared UI components
  models/                      # Data models (Firestore-compatible)
    app_user.dart
    patient.dart, doctor.dart
    medicine.dart, meal.dart
    appointment.dart, prescription.dart
    activity_log.dart
  services/                    # Firebase service layer
    auth_service.dart          # Phone OTP + Google Sign-In
    firestore_service.dart     # All CRUD operations
    storage_service.dart       # Photo/document uploads
    notification_service.dart  # FCM + local notifications
  providers/                   # Riverpod state management
    auth_provider.dart
    patient_provider.dart
    doctor_provider.dart
  screens/
    splash/                    # Animated 3-step splash
    user_select/               # Patient vs Doctor role picker
    auth/                      # Login, OTP, Face ID
    onboarding/                # Permissions + Health Profile setup
    patient/                   # Patient flow (4-tab bottom nav)
      home/                    # Dashboard with stats
      care/                    # Medicine + Food tabs
      activity/                # GPS walk tracker + manual steps
      profile/                 # Profile + settings
      my_doctors/              # Doctor search + prescriptions
      appointments/            # Appointment list
    doctor/                    # Doctor flow (4-tab bottom nav)
      dashboard/               # Doctor overview
      patients/                # Patient list
      appointments/            # Appointment management
      patient_view/            # Patient details + write Rx
      profile/                 # Doctor profile + settings
```

## Firestore Schema

```
users/{uid}           -> name, phone, email, userType, photoUrl, onboardingComplete
patients/{uid}        -> name, age, weight, height, bloodType, conditions[]
  /medicines/{id}     -> name, dosage, frequency, loggedDoses[], isActive
  /meals/{id}         -> mealType, description, calories, protein, carbs, fat
  /activity_logs/{id} -> type, durationSeconds, distanceKm, steps
doctors/{uid}         -> name, specialty, hospital, licenseNo, rating, patientIds[]
appointments/{id}     -> patientId, doctorId, status, scheduledAt, notes
prescriptions/{id}    -> patientId, doctorId, medicines[], diagnosis, notes
```

## Features
- Phone OTP + Google Sign-In authentication
- Role-based flows (Patient / Doctor)
- Medicine tracking with dose logging
- Meal/nutrition logging with calorie tracking
- GPS walk tracker with distance + step counting
- Doctor search and appointment booking
- Doctor appointment management with date/time confirmation
- Prescription writing (doctor -> patient, auto-adds to medicine list)
- Real-time Firestore data streaming
- Push notifications via FCM
- Biometric authentication support
- Profile photos via Firebase Storage
