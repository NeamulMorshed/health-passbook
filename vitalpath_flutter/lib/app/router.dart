import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../models/app_user.dart';
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
import '../screens/doctor/onboarding/doc_profile_setup_screen.dart';
import '../screens/patient/notifications/notifications_screen.dart';
import '../screens/patient/notifications/notification_settings_screen.dart';
import '../screens/patient/profile/edit_profile_screen.dart';
import '../screens/patient/profile/privacy_screen.dart';
import '../screens/patient/gamification/gamification_screen.dart';
import '../screens/patient/insights/insights_screen.dart';
import '../screens/patient/prescriptions/prescriptions_screen.dart';
import '../screens/patient/care/care_circle_screen.dart';
import '../screens/patient/care/invite_family_member_screen.dart';
import '../screens/patient/care/invite_caregiver_screen.dart';
import '../screens/patient/care/manage_caregiver_screen.dart';
import '../screens/caregiver/accept_invite_screen.dart';
import '../screens/caregiver/caregiver_patient_profile_screen.dart';
import '../screens/onboarding/caregiver_setup_screen.dart';
import '../screens/patient/vitals/vitals_screen.dart';
import '../models/caregiver_connection.dart';

// ── Auth-change notifier ──────────────────────────────────────────────────
// A thin ChangeNotifier whose only job is to ping GoRouter when auth state
// changes so it re-evaluates `redirect`.  This is kept separate from the
// GoRouter creation so we never recreate the router on auth changes.

class _AuthNotifier extends ChangeNotifier {
  void ping() => notifyListeners();
}

// ── Patient shell routes ──────────────────────────────────────────────────
// All routes that should only be accessible to patients / caregivers.
const _patientRoutes = {
  '/home', '/vitals', '/care', '/appointments', '/profile',
  '/medicines', '/activity', '/gamification', '/insights',
  '/notifications', '/care-circle', '/my-doctors', '/prescriptions',
};

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
      final authState = ref.read(firebaseAuthStateProvider);

      // If we are still loading the auth state, don't redirect yet.
      // This prevents bouncing users back to login while the stream is initializing.
      if (authState.isLoading) return null;

      final isAuthenticated = authState.asData?.value != null;
      final loc = state.matchedLocation;

      // Splash is always reachable — no redirect.
      if (loc == '/splash') return null;

      // Fix H1 — Block authenticated users from /user-select.
      if (loc == '/user-select') {
        if (!isAuthenticated) return null;
        // User is logged in — redirect to role-appropriate home.
        final userState = ref.read(currentUserProvider);
        if (userState.isLoading) return null;
        final user = userState.asData?.value;
        if (user == null) return null;
        return user.userType == UserType.doctor ? '/doc/dashboard' : '/home';
      }

      // Redirect unauthenticated users away from protected routes.
      final isAuthRoute = loc.startsWith('/auth');
      if (!isAuthenticated && !isAuthRoute) return '/auth/login';

      // --- Role-based checks below require a resolved user. ---
      if (!isAuthenticated) return null;

      final userState = ref.read(currentUserProvider);
      // Still loading the AppUser — let the route render, guard will re-run.
      if (userState.isLoading) return null;
      final user = userState.asData?.value;
      if (user == null) return null;

      final isDoctor = user.userType == UserType.doctor;
      final isPatientOrCaregiver =
          user.userType == UserType.patient || user.userType == UserType.caregiver;

      // Fix C1 — Role-based route guards.
      if (loc.startsWith('/doc/') && !isDoctor) {
        return '/home';
      }
      if (_patientRoutes.any((r) => loc == r || loc.startsWith('$r/')) &&
          !isPatientOrCaregiver) {
        return '/doc/dashboard';
      }

      // Fix H2 — Guard onboarding routes by role and onboarding state.
      if (loc == '/onboarding/permissions' ||
          loc == '/onboarding/health-profile' ||
          loc == '/onboarding/caregiver-setup') {
        if (!isPatientOrCaregiver) return '/doc/dashboard';
        if (user.onboardingComplete) return '/home';
      }
      if (loc == '/doc/onboarding/profile') {
        if (!isDoctor) return '/home';
        if (user.onboardingComplete) return '/doc/dashboard';
      }

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
          GoRoute(
            path: 'login',
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return LoginScreen(userType: extra?['userType'] as String?);
            },
          ),
          GoRoute(
              path: 'faceid',
              builder: (_, __) => const FaceIdScreen(isSetupMode: false)),
        ],
      ),

      // Patient onboarding
      GoRoute(
          path: '/onboarding/permissions',
          builder: (_, __) => const PermissionsScreen()),
      GoRoute(
          path: '/onboarding/health-profile',
          builder: (_, __) => const HealthProfileScreen()),
      GoRoute(
          path: '/onboarding/caregiver-setup',
          builder: (_, __) => const CaregiverSetupScreen()),

      // Doctor onboarding
      GoRoute(
          path: '/doc/onboarding/profile',
          builder: (_, __) => const DocProfileSetupScreen()),

      // Patient shell — 5 tabs: Home, Medicines, Vitals, Appointments, Profile
      ShellRoute(
        builder: (context, state, child) => PatientShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/care', builder: (_, __) => const CareScreen()),
          GoRoute(path: '/vitals', builder: (_, __) => const VitalsScreen()),
          GoRoute(
              path: '/appointments',
              builder: (_, __) => const AppointmentsScreen()),
          GoRoute(
              path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),

      // Care Circle is a push route accessible from Profile and Home
      GoRoute(
          path: '/care-circle',
          builder: (_, __) => const CareCircleScreen()),

      // Activity is a full-screen push route (accessible from Home)
      GoRoute(
          path: '/activity', builder: (_, __) => const ActivityScreen()),

      GoRoute(
          path: '/my-doctors', builder: (_, __) => const MyDoctorsScreen()),
      GoRoute(
          path: '/notifications',
          builder: (_, __) => const NotificationsScreen()),
      GoRoute(
          path: '/notification-settings',
          builder: (_, __) => const NotificationSettingsScreen()),
      GoRoute(
          path: '/edit-profile',
          builder: (_, __) => const EditProfileScreen()),
      GoRoute(
          path: '/privacy-security',
          builder: (_, __) => const PrivacySecurityScreen()),
      GoRoute(
          path: '/gamification',
          builder: (_, __) => const GamificationScreen()),
      GoRoute(
          path: '/insights',
          builder: (_, __) => const InsightsScreen()),
      GoRoute(
          path: '/prescriptions',
          builder: (_, __) => const PrescriptionsScreen()),
      GoRoute(
          path: '/invite-family',
          builder: (_, __) => const InviteFamilyMemberScreen()),
      GoRoute(
          path: '/invite-caregiver',
          builder: (_, __) => const InviteCaregiverScreen()),

      // Fix C2 — Null-safe CaregiverConnection casts.
      GoRoute(
        path: '/manage-caregiver',
        builder: (_, state) {
          if (state.extra is! CaregiverConnection) {
            return const Scaffold(
              body: Center(child: Text('Page not found: /manage-caregiver')),
            );
          }
          return ManageCaregiverScreen(
              connection: state.extra as CaregiverConnection);
        },
      ),
      GoRoute(
        path: '/accept-invite',
        builder: (_, state) {
          if (state.extra is! CaregiverConnection) {
            return const Scaffold(
              body: Center(child: Text('Page not found: /accept-invite')),
            );
          }
          return AcceptInviteScreen(
              connection: state.extra as CaregiverConnection);
        },
      ),
      GoRoute(
        path: '/caregiver-patient-profile',
        builder: (_, state) {
          if (state.extra is! CaregiverConnection) {
            return const Scaffold(
              body: Center(
                  child: Text(
                      'Page not found: /caregiver-patient-profile')),
            );
          }
          return CaregiverPatientProfileScreen(
              connection: state.extra as CaregiverConnection);
        },
      ),

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

    // Fix Low — error page without exposing state.error.toString().
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.uri.path}')),
    ),
  );
});
