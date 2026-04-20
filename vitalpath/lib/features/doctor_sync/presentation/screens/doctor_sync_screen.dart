import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Doctor sync screen — manage doctor connections, view prescriptions (SRS §4.4).
class DoctorSyncScreen extends ConsumerWidget {
  const DoctorSyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final connectionsAsync = user != null
        ? ref.watch(_doctorConnectionsProvider(user.id))
        : const AsyncValue<List<DoctorConnection>>.data([]);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Doctor Sync'),
      ),
      body: connectionsAsync.when(
        data: (connections) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Sync with doctor card
              _SyncWithDoctorCard(
                onScan: () => context.push(AppConstants.routeQrScanner),
              ).animate().fadeIn(),

              const SizedBox(height: 24),

              // Connected doctors
              if (connections.isNotEmpty) ...[
                const Text(
                  'Connected Doctors',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ...connections.map((conn) => _DoctorConnectionCard(
                      connection: conn,
                    ).animate().fadeIn()),
              ] else ...[
                _EmptyDoctors(
                  onScan: () => context.push(AppConstants.routeQrScanner),
                ).animate().fadeIn(),
              ],

              const SizedBox(height: 80),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

@riverpod
Stream<List<DoctorConnection>> _doctorConnections(Ref ref, String patientId) {
  return ref.watch(appDatabaseProvider).doctorSyncDao.watchConnections(patientId);
}

class _SyncWithDoctorCard extends StatelessWidget {
  final VoidCallback onScan;

  const _SyncWithDoctorCard({required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B6E4F), Color(0xFF1A9A70)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.medical_services_rounded, color: Colors.white, size: 32),
          const SizedBox(height: 12),
          const Text(
            'Connect with your Doctor',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Scan the QR code or enter the 6-digit sync code your doctor provides.',
            style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onScan,
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
            label: const Text('Scan QR Code'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorConnectionCard extends StatelessWidget {
  final DoctorConnection connection;

  const _DoctorConnectionCard({required this.connection});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dr. ${connection.doctorName}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (connection.clinicName != null)
                  Text(
                    connection.clinicName!,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: connection.status == 'active'
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              connection.status.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: connection.status == 'active'
                    ? AppColors.success
                    : AppColors.warning,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => context.push(
              '${AppConstants.routeDoctorSync}/report/${connection.patientId}',
            ),
            icon: const Icon(Icons.bar_chart_rounded, color: AppColors.textTertiary),
            tooltip: 'Adherence Report',
          ),
        ],
      ),
    );
  }
}

class _EmptyDoctors extends StatelessWidget {
  final VoidCallback onScan;

  const _EmptyDoctors({required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.local_hospital_rounded,
                size: 56, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            const Text(
              'No doctors connected yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask your doctor for a sync code\nor QR code to connect.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
