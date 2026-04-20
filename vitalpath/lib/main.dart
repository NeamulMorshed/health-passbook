import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import 'core/constants/app_theme.dart';
import 'core/network/supabase_config.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/services/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Environment ───────────────────────────────────────────────
  await dotenv.load();

  // ── System UI — Immersive, edge-to-edge ──────────────────────
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  // ── Portrait lock (mobile health app) ─────────────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── Supabase ──────────────────────────────────────────────────
  await SupabaseConfig.initialize();

  // ── WorkManager (background sync) ────────────────────────────
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );

  runApp(
    const ProviderScope(
      child: VitalPathApp(),
    ),
  );
}

class VitalPathApp extends ConsumerStatefulWidget {
  const VitalPathApp({super.key});

  @override
  ConsumerState<VitalPathApp> createState() => _VitalPathAppState();
}

class _VitalPathAppState extends ConsumerState<VitalPathApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Initialize notification service
    final notificationSvc = ref.read(notificationServiceProvider);
    await notificationSvc.initialize();

    // Register background sync tasks
    final syncSvc = ref.read(syncServiceProvider);
    await syncSvc.registerBackgroundTasks();
  }

  /// Biometric lock when app goes to background (Tech Blueprint §4)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App returned from background — biometric check handled by auth provider
      ref.read(appLifecycleProvider.notifier).onResumed();
    } else if (state == AppLifecycleState.paused) {
      ref.read(appLifecycleProvider.notifier).onPaused();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'VitalPath',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}

/// App lifecycle notifier — used to trigger biometric re-auth
class AppLifecycleNotifier extends Notifier<AppLifecycleState> {
  @override
  AppLifecycleState build() => AppLifecycleState.resumed;

  void onResumed() => state = AppLifecycleState.resumed;
  void onPaused() => state = AppLifecycleState.paused;
}

final appLifecycleProvider =
    NotifierProvider<AppLifecycleNotifier, AppLifecycleState>(
  AppLifecycleNotifier.new,
);
