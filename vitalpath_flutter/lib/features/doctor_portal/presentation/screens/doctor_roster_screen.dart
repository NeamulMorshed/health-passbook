import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/patient_summary_entity.dart';
import '../providers/doctor_provider.dart';

class DoctorRosterScreen extends ConsumerWidget {
  const DoctorRosterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rosterAsync = ref.watch(patientRosterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Doctor Portal', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: AppColors.text3, letterSpacing: 1)),
                Text('Patient Roster', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                rosterAsync.when(
                  loading: () => _buildSkeleton(),
                  error: (e, _) => Text('Error: $e'),
                  data: (patients) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Metric cards
                      Row(
                        children: [
                          _MetricCard(value: '${patients.length}', label: 'Patients', icon: Icons.people_rounded, color: AppColors.primary),
                          const SizedBox(width: 10),
                          _MetricCard(
                            value: '${patients.where((p) => p.riskLevel == 'high').length}',
                            label: 'High Risk',
                            icon: Icons.warning_rounded,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 10),
                          _MetricCard(
                            value: '${(patients.map((p) => p.adherenceRate).reduce((a, b) => a + b) / patients.length * 100).round()}%',
                            label: 'Avg Adherence',
                            icon: Icons.trending_up_rounded,
                            color: AppColors.secondary,
                          ),
                        ],
                      ).animate().fadeIn(duration: 500.ms),
                      const SizedBox(height: 16),

                      // Filter chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['All', 'High Risk', 'Low Adherence', 'Pending Rx']
                              .map((f) => _FilterChip(label: f, isActive: f == 'All'))
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Patient cards
                      ...patients.asMap().entries.map((e) =>
                        _PatientCard(
                          patient: e.value,
                          onTap: () {
                            ref.read(selectedPatientProvider.notifier).state = e.value;
                            context.push('/doctor/patient/${e.value.id}');
                          },
                        ).animate().fadeIn(duration: 400.ms, delay: (e.key * 80).ms)
                            .slideY(begin: 0.04),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() => Column(
    children: List.generate(4, (i) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      height: 96,
      decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(18)),
    )),
  );
}

class _MetricCard extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _MetricCard({required this.value, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.text3, fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  );
}

class _FilterChip extends StatefulWidget {
  final String label;
  final bool isActive;
  const _FilterChip({required this.label, required this.isActive});
  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  late bool _active;
  @override
  void initState() { super.initState(); _active = widget.isActive; }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () { HapticFeedback.lightImpact(); setState(() => _active = \!_active); },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: _active ? AppColors.primaryLight : AppColors.surface,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: _active ? AppColors.primaryMid : AppColors.border,
          width: 1.5,
        ),
      ),
      child: Text(widget.label,
        style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: _active ? AppColors.primary : AppColors.text2,
        )),
    ),
  );
}

class _PatientCard extends StatelessWidget {
  final PatientSummaryEntity patient;
  final VoidCallback onTap;
  const _PatientCard({required this.patient, required this.onTap});

  Color get _riskColor {
    switch (patient.riskLevel) {
      case 'high':   return AppColors.error;
      case 'medium': return AppColors.warning;
      default:       return AppColors.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.cardShadows,
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Avatar
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary.withOpacity(0.7), AppColors.primary],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(child: Text(patient.initials,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(patient.name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
                      Text('${patient.primaryCondition ?? 'Unknown'} · ${patient.gender ?? '—'} · Age ${patient.age}',
                        style: const TextStyle(fontSize: 12, color: AppColors.text3)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _riskColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        (patient.riskLevel ?? 'low').toUpperCase(),
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _riskColor),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${(patient.adherenceRate * 100).round()}%',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _riskColor)),
                    const Text('adherence', style: TextStyle(fontSize: 9, color: AppColors.text3, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 7-day dot grid
            Row(
              children: [
                const Text('7d', style: TextStyle(fontSize: 10, color: AppColors.text3, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                ...patient.weeklyDots.map((done) => Container(
                  width: 24, height: 24, margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: done ? AppColors.secondary : AppColors.background,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: done ? AppColors.secondary : AppColors.border, width: 1),
                  ),
                  child: done ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : null,
                )),
                const Spacer(),
                // Progress bar
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: patient.adherenceRate,
                          minHeight: 6,
                          backgroundColor: AppColors.background,
                          valueColor: AlwaysStoppedAnimation<Color>(_riskColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
