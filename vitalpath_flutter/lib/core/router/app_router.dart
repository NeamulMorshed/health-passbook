import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/dashboard/presentation/screens/patient_dashboard_screen.dart';
import '../../features/medication/presentation/screens/medication_screen.dart';
import '../../features/activity/presentation/screens/activity_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/doctor_portal/presentation/screens/doctor_roster_screen.dart';
import '../../features/doctor_portal/presentation/screens/doctor_patient_screen.dart';
import '../../features/doctor_portal/presentation/screens/doctor_sync_screen.dart';
import '../constants/app_constants.dart';
import '../widgets/shell_scaffold.dart';

part 'app_router.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GoRouter — declarative routing with auth redirect guard
// ─────────────────────────────────────────────────────────────────────────────

@riverpod
GoRouter appRouter(AppRouterRef ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppConstants.routeSplash,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final isLoggedIn  = authState.valueOrNull?.isLoggedIn ?? false;
      final isAuthRoute = state.matchedLocation == AppConstants.routeLogin ||
                          state.matchedLocation == AppConstants.routeOtp  ||
                          state.matchedLocation == AppConstants.routeSplash;

      if (\!isLoggedIn && \!isAuthRoute) return AppConstants.routeLogin;
      if (isLoggedIn  && state.matchedLocation == AppConstants.routeLogin) {
        return AppConstants.routeHome;
      }
      return null;
    },
    routes: [
      // ── Splash ──────────────────────────────────────────────
      GoRoute(
        path: AppConstants.routeSplash,
        pageBuilder: (c, s) => _fadeTransition(s, const SplashScreen()),
      ),

      // ── Auth ─────────────────────────────────────────────────
      GoRoute(
        path: AppConstants.routeLogin,
        pageBuilder: (c, s) => _slideUpTransition(s, const LoginScreen()),
      ),
      GoRoute(
        path: AppConstants.routeOtp,
        pageBuilder: (c, s) => _slideUpTransition(
          s,
          OtpScreen(phone: s.extra as String? ?? ''),
        ),
      ),

      // ── Patient Shell (bottom nav) ────────────────────────────
      ShellRoute(
        builder: (ctx, state, child) => PatientShellScaffold(child: child),
        routes: [
          GoRoute(
            path: AppConstants.routeHome,
            pageBuilder: (c, s) => _noTransition(s, const PatientDashboardScreen()),
          ),
          GoRoute(
            path: AppConstants.routeMedication,
            pageBuilder: (c, s) => _noTransition(s, const MedicationScreen()),
          ),
          GoRoute(
            path: AppConstants.routeActivity,
            pageBuilder: (c, s) => _noTransition(s, const ActivityScreen()),
          ),
          GoRoute(
            path: AppConstants.routeProfile,
            pageBuilder: (c, s) => _noTransition(s, const ProfileScreen()),
          ),
        ],
      ),

      // ── Doctor Shell (bottom nav) ─────────────────────────────
      ShellRoute(
        builder: (ctx, state, child) => DoctorShellScaffold(child: child),
        routes: [
          GoRoute(
            path: AppConstants.routeDoctorRoster,
            pageBuilder: (c, s) => _noTransition(s, const DoctorRosterScreen()),
          ),
          GoRoute(
            path: AppConstants.routeDoctorSync,
            pageBuilder: (c, s) => _noTransition(s, const DoctorSyncScreen()),
          ),
        ],
      ),

      // ── Doctor Patient Detail (pushed, no shell) ──────────────
      GoRoute(
        path: '/doctor/patient/:patientId',
        pageBuilder: (c, s) => _slideUpTransition(
          s,
          DoctorPatientScreen(patientId: s.pathParameters['patientId']\!),
        ),
      ),
    ],
  );
}

// ── Page transition helpers ───────────────────────────────────────────────────

CustomTransitionPage<void> _fadeTransition(GoRouterState s, Widget child) =>
    CustomTransitionPage(
      key: s.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (ctx, anim, _, c) =>
          FadeTransition(opacity: anim, child: c),
    );

CustomTransitionPage<void> _slideUpTransition(GoRouterState s, Widget child) =>
    CustomTransitionPage(
      key: s.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 320),
      transitionsBuilder: (ctx, anim, _, c) {
        final tween = Tween(begin: const Offset(0, 0.06), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(position: anim.drive(tween), child: c),
        );
      },
    );

NoTransitionPage<void> _noTransition(GoRouterState s, Widget child) =>
    NoTransitionPage(key: s.pageKey, child: child);
