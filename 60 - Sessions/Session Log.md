# Session Log

#sessions

> Individual session notes live in this folder.  
> Use template: [[70 - Reference/Templates/Session]]

---

## 2026-06-01 — v2.12.0+41

**Focus:** Play Store permission + screen support fixes  
**Changed:**
- `android/AndroidManifest.xml` — removed `USE_EXACT_ALARM`; added `<supports-screens>` phone-only
- `android/local.properties` — versionCode synced to 41
- `pubspec.yaml` — version 2.12.0+38 → 2.12.0+41
- `lib/screens/splash/splash_screen.dart` — tap-anywhere-to-skip

**Next:** GitHub Pages → Privacy Policy URL → Play Console submission

---

## 2026-05-27 — Play Store Compliance

**Focus:** Signing, disclaimer, privacy policy  
**Changed:**
- Release keystore generated (`omra-release.jks`, not in git)
- `build.gradle` — release signing config
- Disclaimer screen (first-launch, SharedPreferences-gated)
- Privacy policy screen (in-app + `docs/privacy-policy.html`)
- Router updated with `/disclaimer` + `/privacy-policy` routes

---

## 2026-05-26 — v2.12.0+38 (Crashlytics)

**Focus:** Crashlytics activation + user attribution  
**Changed:**
- `lib/main.dart` — boot breadcrumb log
- `lib/providers/auth_provider.dart` — `crashlyticsUserSyncProvider`
- `pubspec.yaml` — +36 → +38

---

## Earlier Sessions
> See `.claude/UPDATES.md` for full log
