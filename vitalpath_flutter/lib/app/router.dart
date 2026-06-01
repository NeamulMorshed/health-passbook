import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'navigation_key.dart';

import '../providers/auth_provider.dart';
import '../providers/disclaimer_provider.dart';
import '../models/app_user.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/onboarding/disclaimer_screen.dart';
import '../screens/legal/privacy_policy_screen.dart';
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
import '../screens/caregiver/caregiver_shell.dart';
import '../screens/caregiver/home/caregiver_home_screen.dart';
import '../screens/caregiver/patients/caregiver_patients_screen.dart';
import '../screens/caregiver/profile/caregiver_profile_screen.dart';
import '../screens/onboarding/caregiver_setup_screen.dart';
import '../screens/patient/vitals/vitals_screen.dart';
import '../screens/patient/profile/patient_health_profile_screen.dart';
import '../screens/messaging/appointment_messages_screen.dart';
import '../models/appointment.dart';
import '../models/caregiver_connection.dart';

// ── Auth-change notifier ──────────────────────────────────────────────────
// A thin ChangeNotifier whose only job is to ping GoRouter when auth state
// changes so it re-evaluates `redirect`.  This is kept separate from the
// GoRouter creation so we never recreate the router on auth changes.

class _AuthNotifier extends ChangeNotifier {
  void ping() => notifyListeners();
}

// Routes only patients (not caregivers, not doctors) may access.
const _patientOnlyRoutes = {
  '/home',
  '/vitals',
  '/profile',
  '/my-doctors',
  '/prescriptions',
  '/care-circle',
  '/activity',
  '/gamification',
  '/insights',
  '/health-profile',
};

// Routes patients and caregivers share (doctors are blocked).
const _sharedNonDoctorRoutes = {
  '/care',
  '/appointments',
  '/notifications',
  '/notification-settings',
  '/edit-profile',
  '/privacy-security',
  '/invite-family',
  '/invite-caregiver',
  '/manage-caregiver',
  '/accept-invite',
  '/caregiver-patient-profile',
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
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: notifier,

    redirect: (context, state) {
      final loc = state.matchedLocation;

      // Disclaimer gate — must accept before anything else is reachable.
      final disclaimerAccepted = ref.read(disclaimerAcceptedProvider);
      if (!disclaimerAccepted && loc != '/disclaimer' && loc != '/privacy-policy') {
        return '/disclaimer';
      }
      if (disclaimerAccepted && loc == '/disclaimer') return '/splash';

      final authState = ref.read(firebaseAuthStateProvider);

      // If we are still loading the auth state, don't redirect yet.
      // This prevents bouncing users back to login while the stream is initializing.
      if (authState.isLoading) return null;

      final isAuthenticated = authState.asData?.value != null;

      // Splash is always reachable — no redirect.
      if (loc == '/splash') return null;

      // /user-select is always accessible — authenticated users can visit it
      // to switch roles or sign out. The screen itself handles role-aware
      // navigation via _handleRoleSelected and shows a mismatch dialog when
      // the tapped role differs from the stored userType.
      if (loc == '/user-select') return null;

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
      final isCaregiver = user.userType == UserType.caregiver;
      final isPatient = user.userType == UserType.patient;

      // Fix C1 — Role-based route guards.

      // Doctors may not access patient or caregiver areas.
      if (isDoctor) {
        final inPatient =
            _patientOnlyRoutes.any((r) => loc == r || loc.startsWith('$r/'));
        final inShared = _sharedNonDoctorRoutes
            .any((r) => loc == r || loc.startsWith('$r/'));
        final inCaregiver = loc.startsWith('/caregiver');
        if (inPatient || inShared || inCaregiver) return '/doc/dashboard';
      }

      // Non-doctors may not access doctor area.
      if (!isDoctor && loc.startsWith('/doc/')) {
        return isCaregiver ? '/caregiver/home' : '/home';
      }

      // Caregivers may not access patient-only routes.
      if (isCaregiver &&
          _patientOnlyRoutes.any((r) => loc == r || loc.startsWith('$r/'))) {
        return '/caregiver/home';
      }

      // Patients may not access caregiver portal.
      if (isPatient && loc.startsWith('/caregiver')) {
        return '/home';
      }

      // Safety net: incomplete patients on patient-only routes → resume onboarding.
      if (isPatient &&
          !user.onboardingComplete &&
          _patientOnlyRoutes.any((r) => loc == r || loc.startsWith('$r/'))) {
        return '/onboarding/health-profile';
      }

      // Fix H2 — Guard onboarding routes by role and onboarding state.
      if (loc == '/onboarding/permissions' ||
          loc == '/onboarding/health-profile' ||
          loc == '/onboarding/caregiver-setup') {
        if (isDoctor) return '/doc/dashboard';
        if (user.onboardingComplete) {
          return isCaregiver ? '/caregiver/home' : '/home';
        }
      }
      if (loc == '/doc/onboarding/profile') {
        if (!isDoctor) return '/home';
        if (user.onboardingComplete) return '/doc/dashboard';
      }

      return null;
    },

    routes: [
      GoRoute(path: '/disclaimer', builder: (_, __) => const DisclaimerScreen()),
      GoRoute(path: '/privacy-policy', builder: (_, __) => const PrivacyPolicyScreen()),
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(
          path: '/user-select', builder: (_, __) => const UserSelectScreen()),

      // Auth routes
      GoRoute(
        path: '/auth',
        // Only redirect the bare /auth path to /auth/login. Without the guard
        // this parent redirect also fires for the /auth/login child match,
        // producing an infinite redirect loop → "Page not found" error screen.
        redirect: (_, state) =>
            state.uri.path == '/auth' ? '/auth/login' : null,
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

      // Patient shell — 5 tabs: Home, Care, Vitals, Appointments, Profile
      ShellRoute(
        builder: (context, state, child) => PatientShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(
            path: '/care',
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return CareScreen(initialMemberId: extra?['memberId'] as String?);
            },
          ),
          GoRoute(path: '/vitals', builder: (_, __) => const VitalsScreen()),
          GoRoute(
              path: '/appointments',
              builder: (_, __) => const AppointmentsScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),

      // Care Circle is a push route accessible from Profile and Home
      GoRoute(
          path: '/care-circle', builder: (_, __) => const CareCircleScreen()),

      // Activity is a full-screen push route (accessible from Home)
      GoRoute(path: '/activity', builder: (_, __) => const ActivityScreen()),

      GoRoute(path: '/my-doctors', builder: (_, __) => const MyDoctorsScreen()),
      GoRoute(
          path: '/notifications',
          builder: (_, __) => const NotificationsScreen()),
      GoRoute(
          path: '/notification-settings',
          builder: (_, __) => const NotificationSettingsScreen()),
      GoRoute(
          path: '/edit-profile', builder: (_, __) => const EditProfileScreen()),
      GoRoute(
          path: '/privacy-security',
          builder: (_, __) => const PrivacySecurityScreen()),
      GoRoute(
          path: '/gamification',
          builder: (_, __) => const GamificationScreen()),
      GoRoute(path: '/insights', builder: (_, __) => const InsightsScreen()),
      GoRoute(
          path: '/prescriptions',
          builder: (_, __) => const PrescriptionsScreen()),
      GoRoute(
          path: '/health-profile',
          builder: (_, __) => const PatientHealthProfileScreen()),
      GoRoute(
          path: '/invite-family',
          builder: (_, __) => const InviteFamilyMemberScreen()),
      GoRoute(
          path: '/invite-caregiver',
          builder: (_, __) => const InviteCaregiverScreen()),

      // 7a: Appointment-scoped messaging
      GoRoute(
        path: '/appointment-messages',
        builder: (_, state) {
          if (state.extra is! Appointment) {
            return const Scaffold(
              body: Center(child: Text('Page not found: /appointment-messages')),
            );
          }
          return AppointmentMessagesScreen(
              appointment: state.extra as Appointment);
        },
      ),

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
                  child: Text('Page not found: /caregiver-patient-profile')),
            );
          }
          return CaregiverPatientProfileScreen(
              connection: state.extra as CaregiverConnection);
        },
      ),

      // Caregiver shell — 3 tabs: Home, Family, Profile
      ShellRoute(
        builder: (context, state, child) => CaregiverShell(child: child),
        routes: [
          GoRoute(
              path: '/caregiver/home',
              builder: (_, __) => const CaregiverHomeScreen()),
          GoRoute(
              path: '/caregiver/patients',
              builder: (_, __) => const CaregiverPatientsScreen()),
          GoRoute(
              path: '/caregiver/profile',
              builder: (_, __) => const CaregiverProfileScreen()),
        ],
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
              builder: (_, state) {
                final extra = state.extra as Map<String, dynamic>?;
                return DocPatientsScreen(mode: extra?['mode'] as String?);
              }),
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
        builder: (_, state) =>
            DocPatientViewScreen(patientId: state.pathParameters['patientId']!),
      ),
    ],

    // Fix Low — error page without exposing state.error.toString().
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.uri.path}')),
    ),
  );
});
