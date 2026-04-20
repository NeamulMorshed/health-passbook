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

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(firebaseAuthStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isAuthenticated = authState.asData?.value \!= null;
      final loc = state.matchedLocation;

      // Allow splash and user-select always
      if (loc == '/splash' || loc == '/user-select') return null;

      // Auth screens
      final isAuthRoute = loc.startsWith('/auth');
      if (\!isAuthenticated && \!isAuthRoute) return '/auth/login';

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/user-select', builder: (_, __) => const UserSelectScreen()),

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
      GoRoute(path: '/onboarding/permissions', builder: (_, __) => const PermissionsScreen()),
      GoRoute(path: '/onboarding/health-profile', builder: (_, __) => const HealthProfileScreen()),

      // Patient shell with nested routes
      ShellRoute(
        builder: (context, state, child) => PatientShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/care', builder: (_, __) => const CareScreen()),
          GoRoute(path: '/activity', builder: (_, __) => const ActivityScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),

      // Patient extra screens (no bottom nav)
      GoRoute(path: '/my-doctors', builder: (_, __) => const MyDoctorsScreen()),
      GoRoute(path: '/appointments', builder: (_, __) => const AppointmentsScreen()),

      // Doctor shell
      ShellRoute(
        builder: (context, state, child) => DoctorShell(child: child),
        routes: [
          GoRoute(path: '/doc/dashboard', builder: (_, __) => const DocDashboardScreen()),
          GoRoute(path: '/doc/patients', builder: (_, __) => const DocPatientsScreen()),
          GoRoute(path: '/doc/appointments', builder: (_, __) => const DocAppointmentsScreen()),
          GoRoute(path: '/doc/profile', builder: (_, __) => const DocProfileScreen()),
        ],
      ),

      // Doctor extra screens
      GoRoute(
        path: '/doc/patient/:patientId',
        builder: (_, state) => DocPatientViewScreen(patientId: state.pathParameters['patientId']\!),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});
