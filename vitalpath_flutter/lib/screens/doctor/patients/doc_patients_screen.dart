import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' hide Text, Navigator, List, Radius, Circle;
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/doctor_provider.dart';
import '../../../models/patient.dart';

enum _SortOrder { nameAsc, nameDesc, ageAsc, ageDesc }

class DocPatientsScreen extends ConsumerStatefulWidget {
  const DocPatientsScreen({super.key});
  @override
  ConsumerState<DocPatientsScreen> createState() => _DocPatientsScreenState();
}

class _DocPatientsScreenState extends ConsumerState<DocPatientsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  _SortOrder _sort = _SortOrder.nameAsc;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<PatientProfile> _applyFilter(List<PatientProfile> all) {
    final q = _query.toLowerCase();
    var filtered = q.isEmpty
        ? all
        : all.where((p) => p.name.toLowerCase().contains(q)).toList();

    switch (_sort) {
      case _SortOrder.nameAsc:
        filtered.sort((a, b) => a.name.compareTo(b.name));
      case _SortOrder.nameDesc:
        filtered.sort((a, b) => b.name.compareTo(a.name));
      case _SortOrder.ageAsc:
        filtered.sort((a, b) => (a.age ?? 0).compareTo(b.age ?? 0));
      case _SortOrder.ageDesc:
        filtered.sort((a, b) => (b.age ?? 0).compareTo(a.age ?? 0));
    }
    return filtered;
  }

  String get _sortLabel {
    switch (_sort) {
      case _SortOrder.nameAsc:  return 'Name A–Z';
      case _SortOrder.nameDesc: return 'Name Z–A';
      case _SortOrder.ageAsc:   return 'Age ↑';
      case _SortOrder.ageDesc:  return 'Age ↓';
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('My Patients'),
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton<_SortOrder>(
            tooltip: 'Sort',
            icon: const Sort(width: 24, height: 24),
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: _SortOrder.nameAsc,  child: Text('Name A–Z')),
              const PopupMenuItem(value: _SortOrder.nameDesc, child: Text('Name Z–A')),
              const PopupMenuItem(value: _SortOrder.ageAsc,   child: Text('Age (youngest first)')),
              const PopupMenuItem(value: _SortOrder.ageDesc,  child: Text('Age (oldest first)')),
            ],
          ),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const EmptyState(icon: Icons.error_outline_rounded, title: 'Something went wrong', subtitle: 'Pull to refresh or try again.'),
        data: (user) {
          if (user == null) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) { if (context.mounted) context.go('/user-select'); },
            );
            return const Center(child: SizedBox.shrink());
          }
          final patientsAsync = ref.watch(doctorPatientsStreamProvider(user.uid));

          return patientsAsync.when(
            loading: () => const _ShimmerPatientList(),
            error: (_, __) => const EmptyState(icon: Icons.error_outline_rounded, title: 'Something went wrong', subtitle: 'Pull to refresh or try again.'),
            data: (patients) {
              if (patients.isEmpty) {
                return const EmptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'No Patients Yet',
                  subtitle: 'Patients will appear here once they book an appointment with you.',
                );
              }

              final visible = _applyFilter(patients);

              return Column(children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search patients by name…',
                      prefixIcon: const Search(width: 20, height: 20),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Xmark(width: 18, height: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.muted,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                // Count + sort label
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Text(
                      '${visible.length} patient${visible.length == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                    ),
                    const Spacer(),
                    Text(
                      'Sorted: $_sortLabel',
                      style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),

                // List
                Expanded(
                  child: visible.isEmpty
                      ? const EmptyState(
                          icon: Icons.person_search_rounded,
                          title: 'No Match',
                          subtitle: 'Try a different name.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) =>
                              _PatientCard(patient: visible[i], doctorId: user.uid),
                        ),
                ),
              ]);
            },
          );
        },
      ),
    );
  }
}

class _PatientCard extends ConsumerWidget {
  final PatientProfile patient;
  final String doctorId;
  const _PatientCard({required this.patient, required this.doctorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BentoCard(
      onTap: () => context.push('/doc/patient/${patient.uid}'),
      child: Row(children: [
        AppAvatar(name: patient.name, size: 48),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(patient.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(children: [
                if (patient.age != null) _InfoChip('${patient.age} yrs'),
                if (patient.age != null) const SizedBox(width: 6),
                if (patient.bloodType != null)
                  _InfoChip(patient.bloodType!),
                if (patient.bloodType != null) const SizedBox(width: 6),
                if (patient.conditions.isNotEmpty)
                  _InfoChip(patient.conditions.first),
              ]),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Remove patient',
          icon: const Icon(Icons.person_remove_rounded,
              size: 18, color: AppColors.destructive),
          onPressed: () => _confirmRemove(context, ref),
        ),
        const NavArrowRight(width: 14, height: 14, color: AppColors.mutedForeground),
      ]),
    );
  }

  void _confirmRemove(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Remove Patient'),
        content: Text('Remove ${patient.name} from your patients list?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await ref
                    .read(connectionNotifierProvider.notifier)
                    .remove(patient.uid, doctorId);
                if (context.mounted) {
                  showAppSnack(context, '${patient.name} removed from your list.');
                }
              } catch (_) {
                if (context.mounted) {
                  showAppSnack(context, 'Failed to remove patient. Please try again.');
                }
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  const _InfoChip(this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
  );
}

class _ShimmerPatientList extends StatelessWidget {
  const _ShimmerPatientList();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.muted,
      highlightColor: AppColors.surface,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => Container(
          height: 76,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
