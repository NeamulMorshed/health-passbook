import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'app/router.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/disclaimer_provider.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  // Wrap everything in a Zone so async errors outside the Flutter framework
  // (e.g. from background isolates, async gaps) also get routed to Crashlytics.
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Lock to portrait orientation
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    // Initialize Firebase
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);

    // Crashlytics — disabled in debug so dev logs aren't polluted.
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode);

    // Route Flutter framework errors to Crashlytics.
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // Route async/platform errors to Crashlytics.
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    // App-boot breadcrumb — shows up in the Crashlytics dashboard within
    // ~5 min of first launch, confirms the SDK is wired before any login.
    await FirebaseCrashlytics.instance.log('app boot · v${AppConstants.appVersion}');

    // Enable offline persistence so the app works on poor / no connection
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Bug 1 fix: initialize once here, then inject into the provider via
    // overrideWithValue so every caller shares the same initialized instance.
    final notificationService = NotificationService();
    await notificationService.initialize();

    // Load disclaimer state before runApp so the router redirect can read it
    // synchronously on first navigation evaluation.
    final prefs = await SharedPreferences.getInstance();
    final disclaimerAccepted = prefs.getBool(AppConstants.prefDisclaimerAccepted) ?? false;

    runApp(
      ProviderScope(
        overrides: [
          notificationServiceProvider.overrideWithValue(notificationService),
          disclaimerAcceptedProvider.overrideWith((ref) => disclaimerAccepted),
        ],
        child: const OmraApp(),
      ),
    );

    // Bug 4 fix: handle the notification that cold-started the app (terminated state).
    // Must be called after runApp so the navigator is ready.
    notificationService.handleInitialMessage();
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

class OmraApp extends ConsumerWidget {
  const OmraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Bug 2 fix: keep FCM token in sync for the lifetime of the app.
    ref.watch(fcmTokenSyncProvider);

    // Crashlytics: tag crash reports with the signed-in user.
    ref.watch(crashlyticsUserSyncProvider);

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Omra',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
