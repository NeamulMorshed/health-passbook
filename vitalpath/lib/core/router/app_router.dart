import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/health_profile_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/otp_verify_screen.dart';
import '../../features/auth/presentation/screens/phone_auth_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/doctor_sync/presentation/screens/adherence_report_screen.dart';
import '../../features/doctor_sync/presentation/screens/doctor_sync_screen.dart';
import '../../features/doctor_sync/presentation/screens/qr_scanner_screen.dart';
import '../../features/medicine/domain/entities/medicine_entity.dart';
import '../../features/medicine/presentation/screens/add_medicine_screen.dart';
import '../../features/medicine/presentation/screens/medicine_detail_screen.dart';
import '../../features/medicine/presentation/screens/medicine_list_screen.dart';
import '../../features/nutrition/presentation/screens/add_meal_screen.dart';
import '../../features/nutrition/presentation/screens/nutrition_screen.dart';
import '../../features/activity/presentation/screens/activity_screen.dart';
import '../../features/activity/presentation/screens/gps_walk_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/settings_screen.dart';
import '../../shared/widgets/vp_bottom_nav_shell.dart';
import '../constants/app_constants.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(Ref ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppConstants.routeSplash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthenticated = authState.maybeWhen(
        data: (user) => user != null,
        orElse: () => false,
      );

      final isOnboarding = state.matchedLocation.startsWith('/auth') ||
          state.matchedLocation == AppConstants.routeOnboarding ||
          state.matchedLocation == AppConstants.routeSplash;

      if (!isAuthenticated && !isOnboarding) {
        return AppConstants.routeSplash;
      }

      if (isAuthenticated && state.matchedLocation == AppConstants.routeSplash) {
        return AppConstants.routeDashboard;
      }

      return null;
    },
    routes: [
      // ── Splash ─────────────────────────────────────────────────
      GoRoute(
        path: AppConstants.routeSplash,
        pageBuilder: (context, state) => _buildPage(
          state,
          const SplashScreen(),
        ),
      ),

      // ── Onboarding ────────────────────────────────────────────
      GoRoute(
        path: AppConstants.routeOnboarding,
        pageBuilder: (context, state) => _buildPage(
          state,
          const OnboardingScreen(),
        ),
      ),

      // ── Auth Flow ─────────────────────────────────────────────
      GoRoute(
        path: AppConstants.routePhoneAuth,
        pageBuilder: (context, state) => _buildPage(
          state,
          const PhoneAuthScreen(),
        ),
      ),
      GoRoute(
        path: AppConstants.routeOtpVerify,
        pageBuilder: (context, state) {
          final phone = state.extra as String? ?? '';
          return _buildPage(
            state,
            OtpVerifyScreen(phoneNumber: phone),
          );
        },
      ),
      GoRoute(
        path: AppConstants.routeHealthProfile,
        pageBuilder: (context, state) => _buildPage(
          state,
          const HealthProfileScreen(),
        ),
      ),

      // ── Main App Shell (with Bottom Nav) ─────────────────────
      ShellRoute(
        builder: (context, state, child) => VpBottomNavShell(child: child),
        routes: [
          GoRoute(
            path: AppConstants.routeDashboard,
            pageBuilder: (context, state) => _buildPage(
              state,
              const DashboardScreen(),
            ),
          ),
          GoRoute(
            path: AppConstants.routeMedicineList,
            pageBuilder: (context, state) => _buildPage(
              state,
              const MedicineListScreen(),
            ),
            routes: [
              GoRoute(
                path: 'add',
                pageBuilder: (context, state) => _buildSlideUpPage(
                  state,
                  const AddMedicineScreen(),
                ),
              ),
              GoRoute(
                path: 'edit',
                pageBuilder: (context, state) {
                  final medicine = state.extra as MedicineEntity;
                  return _buildSlideUpPage(
                    state,
                    AddMedicineScreen(existingMedicine: medicine),
                  );
                },
              ),
              GoRoute(
                path: 'detail/:id',
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return _buildPage(
                    state,
                    MedicineDetailScreen(medicineId: id),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: AppConstants.routeNutrition,
            pageBuilder: (context, state) => _buildPage(
              state,
              const NutritionScreen(),
            ),
            routes: [
              GoRoute(
                path: 'add',
                pageBuilder: (context, state) => _buildSlideUpPage(
                  state,
                  const AddMealScreen(),
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppConstants.routeActivity,
            pageBuilder: (context, state) => _buildPage(
              state,
              const ActivityScreen(),
            ),
            routes: [
              GoRoute(
                path: 'walk',
                pageBuilder: (context, state) => _buildPage(
                  state,
                  const GpsWalkScreen(),
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppConstants.routeDoctorSync,
            pageBuilder: (context, state) => _buildPage(
              state,
              const DoctorSyncScreen(),
            ),
            routes: [
              GoRoute(
                path: 'scan',
                pageBuilder: (context, state) => _buildPage(
                  state,
                  const QrScannerScreen(),
                ),
              ),
              GoRoute(
                path: 'report/:patientId',
                pageBuilder: (context, state) {
                  final patientId = state.pathParameters['patientId']!;
                  return _buildPage(
                    state,
                    AdherenceReportScreen(patientId: patientId),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: AppConstants.routeProfile,
            pageBuilder: (context, state) => _buildPage(
              state,
              const ProfileScreen(),
            ),
          ),
        ],
      ),

      // ── Settings (full-screen, outside shell) ────────────────
      GoRoute(
        path: AppConstants.routeSettings,
        pageBuilder: (context, state) => _buildPage(
          state,
          const SettingsScreen(),
        ),
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(
          'Page not found: ${state.error}',
          style: const TextStyle(color: Colors.red),
        ),
      ),
    ),
  );
}

/// Cupertino-style slide-from-right page transition (Antigravity standard)
Page<void> _buildPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutCubicEmphasized,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(curvedAnimation),
        child: child,
      );
    },
  );
}

/// Bottom sheet-style slide-up page (for forms/modals)
Page<void> _buildSlideUpPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).animate(curvedAnimation),
        child: child,
      );
    },
  );
}
