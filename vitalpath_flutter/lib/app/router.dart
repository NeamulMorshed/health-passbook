import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/user_select/user_select_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/face_id_screen.dart';
import '../screens/onboarding/permissions_screen.dart';
import '../screens/onboarding/health_profile_screen.dart';
import '../screens/patient/patient_shell.dart';
import '../screens/patient/home/home_screen.dart';
import '../screens/patient/care/care_screen.dart';
import '../screens/patient/activity/activity_screen.dart';
import '../screens/patient/profile/profile_screen.dart';
import '../screens/patient/my_doctors/my_doctors_screen.dart';
import '../screens/patient/appointments/appointments_screen.dart';
import '../screens/doctor/doctor_shell.dart';
import '../screens/doctor/dashboard/doc_dashboard_screen.dart';
import '../screens/doctor/patients/doc_patients_screen.dart';
import '../screens/doctor/appointments/doc_appointments_screen.dart';
import '../screens/doctor/patient_view/doc_patient_view_screen.dart';
import '../screens/doctor/profile/doc_profile_screen.dart';

// ── Auth-change notifier ──────────────────────────────────────────────────
// A thin ChangeNotifier whose only job is to ping GoRouter when auth state
// changes so it re-evaluates `redirect`.  This is kept separate from the
// GoRouter creation so we never recreate the router on auth changes.

class _AuthNotifier extends ChangeNotifier {
  void ping() => notifyListeners();
}

// ── Router provider ───────────────────────────────────────────────────────
//
// THE BUG this fixes:
//   Using `ref.watch(firebaseAuthStateProvider)` inside a Provider<GoRouter>
//   caused a brand-new GoRouter to be created every time the user signed in
//   or out.  A new GoRouter resets the navigation stack to its initialLocation,
//   so `context.go('/home')` in LoginScreen was immediately overwritten by the
//   newly-spawned router navigating back to '/splash'.
//
// THE FIX:
//   `ref.listen` (not `ref.watch`) registers a side-effect callback without
//   causing the Provider to rebuild.  The GoRouter is created exactly once.
//   When auth state changes we call _AuthNotifier.ping(), which triggers
//   GoRouter's `refreshListenable` — GoRouter re-evaluates `redirect` in
//   place without resetting the navigation stack.

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthNotifier();
  ref.onDispose(notifier.dispose);

  // Side-effect only — does NOT rebuild routerProvider.
  ref.listen<dynamic>(
    firebaseAuthStateProvider,
    (_, __) => notifier.ping(),
  );

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,

    redirect: (context, state) {
      // Always read the latest value — never close over a stale snapshot.
      final isAuthenticated =
          ref.read(firebaseAuthStateProvider).asData?.value != null;
      final loc = state.matchedLocation;

      // Splash and role-selection are always reachable.
      if (loc == '/splash' || loc == '/user-select') return null;

      // Redirect unauthenticated users away from protected routes.
      final isAuthRoute = loc.startsWith('/auth');
      if (!isAuthenticated && !isAuthRoute) return '/auth/login';

      return null;
    },

    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(
          path: '/user-select', builder: (_, __) => const UserSelectScreen()),

      // Auth routes
      GoRoute(
        path: '/auth',
        redirect: (_, __) => '/auth/login',
        routes: [
          GoRoute(path: 'login', builder: (_, __) => const LoginScreen()),
          GoRoute(path: 'faceid', builder: (_, __) => const FaceIdScreen()),
        ],
      ),

      // Onboarding
      GoRoute(
          path: '/onboarding/permissions',
          builder: (_, __) => const PermissionsScreen()),
      GoRoute(
          path: '/onboarding/health-profile',
          builder: (_, __) => const HealthProfileScreen()),

      // Patient shell
      ShellRoute(
        builder: (context, state, child) => PatientShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/care', builder: (_, __) => const CareScreen()),
          GoRoute(
              path: '/activity', builder: (_, __) => const ActivityScreen()),
          GoRoute(
              path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),

      GoRoute(
          path: '/my-doctors', builder: (_, __) => const MyDoctorsScreen()),
      GoRoute(
          path: '/appointments',
          builder: (_, __) => const AppointmentsScreen()),

      // Doctor shell
      ShellRoute(
        builder: (context, state, child) => DoctorShell(child: child),
        routes: [
          GoRoute(
              path: '/doc/dashboard',
              builder: (_, __) => const DocDashboardScreen()),
          GoRoute(
              path: '/doc/patients',
              builder: (_, __) => const DocPatientsScreen()),
          GoRoute(
              path: '/doc/appointments',
              builder: (_, __) => const DocAppointmentsScreen()),
          GoRoute(
              path: '/doc/profile',
              builder: (_, __) => const DocProfileScreen()),
        ],
      ),

      GoRoute(
        path: '/doc/patient/:patientId',
        builder: (_, state) => DocPatientViewScreen(
            patientId: state.pathParameters['patientId']!),
      ),
    ],

    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});
