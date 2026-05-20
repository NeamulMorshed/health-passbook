import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app/router.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'services/notification_service.dart';

void main() async {
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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable offline persistence so the app works on poor / no connection
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Bug 1 fix: initialize once here, then inject into the provider via
  // overrideWithValue so every caller shares the same initialized instance.
  final notificationService = NotificationService();
  await notificationService.initialize();

  runApp(
    ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: const OmraApp(),
    ),
  );

  // Bug 4 fix: handle the notification that cold-started the app (terminated state).
  // Must be called after runApp so the navigator is ready.
  notificationService.handleInitialMessage();
}

class OmraApp extends ConsumerWidget {
  const OmraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Bug 2 fix: keep FCM token in sync for the lifetime of the app.
    ref.watch(fcmTokenSyncProvider);

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Omra',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
