import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' hide Text, Navigator, List, Radius, Circle, Timer;
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/patient_provider.dart';
import '../../../providers/doctor_provider.dart';
import '../../../models/doctor.dart';
import '../../../models/prescription.dart';

class MyDoctorsScreen extends ConsumerWidget {
  const MyDoctorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(title: const Text('My Doctors')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Something went wrong',
            subtitle: 'Pull to refresh or try again.'),
        data: (user) {
          if (user == null) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) {
                if (context.mounted) context.go('/user-select');
              },
            );
            return const Center(child: SizedBox.shrink());
          }

          final myDoctorsAsync = ref.watch(myDoctorsProvider(user.uid));
          final rxAsync = ref.watch(patientPrescriptionsProvider(user.uid));

          return DefaultTabController(
            length: 3,
            child: Column(
              children: [
                Container(
                  color: AppColors.surface,
                  child: const TabBar(
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.mutedForeground,
                    indicatorColor: AppColors.primary,
                    tabs: [
                      Tab(text: 'My Doctors'),
                      Tab(text: 'Find Doctors'),
                      Tab(text: 'Prescriptions'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _MyDoctorsTab(
                          myDoctorsAsync: myDoctorsAsync, uid: user.uid),
                      _FindDoctorsTab(uid: user.uid),
                      _PrescriptionsTab(rxAsync: rxAsync),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── My Doctors Tab ────────────────────────────────────────────────────────────
class _MyDoctorsTab extends ConsumerWidget {
  final AsyncValue<List<DoctorProfile>> myDoctorsAsync;
  final String uid;
  const _MyDoctorsTab({required this.myDoctorsAsync, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return myDoctorsAsync.when(
      loading: () => const _ShimmerDoctorList(),
      error: (_, __) => const EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Something went wrong',
          subtitle: 'Pull to refresh or try again.'),
      data: (doctors) {
        if (doctors.isEmpty) {
          return const EmptyState(
            icon: Icons.people_outline_rounded,
            title: 'No Doctors Yet',
            subtitle:
                'Use Find Doctors to search and book your first appointment.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          itemCount: doctors.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) =>
              _DoctorCard(doctor: doctors[i], patientId: uid, isConnected: true),
        );
      },
    );
  }
}

// ─── Find Doctors Tab ──────────────────────────────────────────────────────────
class _FindDoctorsTab extends ConsumerStatefulWidget {
  final String uid;
  const _FindDoctorsTab({required this.uid});
  @override
  ConsumerState<_FindDoctorsTab> createState() => _FindDoctorsTabState();
}

class _FindDoctorsTabState extends ConsumerState<_FindDoctorsTab> {
  final _searchCtrl = TextEditingController();
  String _nameQuery = '';
  String _specialty = '';
  String _city = '';
  Timer? _debounce;

  static const _specialties = [
    'General Physician',
    'Cardiologist',
    'Dermatologist',
    'Endocrinologist',
    'ENT Specialist',
    'Gastroenterologist',
    'Gynecologist',
    'Nephrologist',
    'Neurologist',
    'Oncologist',
    'Ophthalmologist',
    'Orthopedic Surgeon',
    'Pediatrician',
    'Psychiatrist',
    'Pulmonologist',
    'Rheumatologist',
    'Urologist',
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchAsync = ref.watch(
      doctorSearchProvider((nameQuery: _nameQuery, specialty: _specialty, city: _city)),
    );

    return Column(
      children: [
        // ── Search bar ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  if (mounted) setState(() => _nameQuery = v.trim());
                });
              },
            decoration: InputDecoration(
              hintText: 'Search by name, specialty or hospital…',
              prefixIcon: const Search(width: 20, height: 20),
              suffixIcon: _nameQuery.isNotEmpty
                  ? IconButton(
                      icon: const Xmark(width: 18, height: 18),
                      onPressed: () {
                        _debounce?.cancel();
                        _searchCtrl.clear();
                        setState(() => _nameQuery = '');
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

        // ── Specialty filter chips ───────────────────────────────────
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _SpecialtyChip(
                label: 'All',
                selected: _specialty.isEmpty,
                onTap: () => setState(() => _specialty = ''),
              ),
              const SizedBox(width: 6),
              ..._specialties.map((s) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _SpecialtyChip(
                      label: s,
                      selected: _specialty == s,
                      onTap: () =>
                          setState(() => _specialty = _specialty == s ? '' : s),
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // ── City filter chips ────────────────────────────────────────
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: AppConstants.cities.map((c) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _SpecialtyChip(
                label: c,
                selected: (c == 'All' && _city.isEmpty) || _city == c,
                onTap: () => setState(() => _city = c == 'All' ? '' : (_city == c ? '' : c)),
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 8),

        // ── Results ─────────────────────────────────────────────────
        Expanded(
          child: searchAsync.when(
            loading: () => const _ShimmerDoctorList(),
            error: (_, __) => const EmptyState(
                icon: Icons.wifi_off_rounded,
                title: "Can't search right now",
                subtitle: 'Check your connection and try again.'),
            data: (doctors) {
              if (doctors.isEmpty) {
                return const EmptyState(
                  icon: Icons.person_search_rounded,
                  title: 'No Doctors Found',
                  subtitle: 'Try a different name or specialty.',
                );
              }
              final connectedIds = ref.watch(myDoctorsProvider(widget.uid)).maybeWhen(
                data: (docs) => docs.map((d) => d.uid).toSet(),
                orElse: () => <String>{},
              );
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                itemCount: doctors.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _DoctorCard(
                  doctor: doctors[i],
                  patientId: widget.uid,
                  isConnected: connectedIds.contains(doctors[i].uid),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SpecialtyChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SpecialtyChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        // Selected conditional colors — kept as Container
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.muted,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : AppColors.foreground,
            ),
          ),
        ),
      );
}

// ─── Doctor Card ───────────────────────────────────────────────────────────────
class _DoctorCard extends ConsumerWidget {
  final DoctorProfile doctor;
  final String patientId;
  final bool isConnected;
  const _DoctorCard(
      {required this.doctor,
      required this.patientId,
      required this.isConnected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BentoCard(
      onTap: () => _showProfileSheet(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            AppAvatar(
                name: doctor.name,
                imageUrl: doctor.photoUrl,
                size: 50,
                backgroundColor: AppColors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text('Dr. ${doctor.name}',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600))),
                      if (doctor.verificationStatus == 'verified')
                        const ShieldCheck(width: 18, height: 18, color: AppColors.primary)
                      else if (doctor.verificationStatus == 'pending')
                        const Icon(Icons.hourglass_top_rounded,
                            color: AppColors.warning, size: 16),
                    ]),
                    if (doctor.specialty != null)
                      Text(doctor.specialty!,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500)),
                    if (doctor.hospital != null)
                      Text(doctor.hospital!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedForeground)),
                  ]),
            ),
            if (doctor.reviewCount > 0)
              Column(children: [
                Row(children: [
                  const Star(width: 16, height: 16, color: AppColors.warning),
                  const SizedBox(width: 2),
                  Text(doctor.rating.toStringAsFixed(1),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ]),
                Text('${doctor.reviewCount} reviews',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground)),
              ])
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('New',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground)),
              ),
          ]),
          const SizedBox(height: 10),
          // Availability info strip
          Row(children: [
            if (!doctor.acceptingNewPatients)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.destructive.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Not accepting patients',
                    style: TextStyle(fontSize: 12, color: AppColors.destructive, fontWeight: FontWeight.w500)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Accepting patients',
                    style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w500)),
              ),
            if (doctor.consultationFee != null && doctor.consultationFee!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(doctor.consultationFee!,
                  style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
            ],
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: doctor.acceptingNewPatients != true
                    ? null
                    : () => _showBookSheet(context, doctor),
                icon: const Calendar(width: 16, height: 16),
                label: const Text('Book Appointment'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: doctor.phone != null && doctor.phone!.isNotEmpty
                  ? () => _callDoctor(context, doctor.phone!)
                  : null,
              icon: const Phone(width: 16, height: 16),
              label: const Text('Call'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
            ),
            if (isConnected) ...[
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Remove doctor',
                icon: const Icon(Icons.person_remove_rounded,
                    size: 18, color: AppColors.destructive),
                onPressed: () => _confirmRemove(context, ref),
              ),
            ],
          ]),
        ],
      ),
    );
  }

  void _showProfileSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _DoctorProfileSheet(
          doctor: doctor, patientId: patientId, isConnected: isConnected),
    );
  }

  void _showBookSheet(BuildContext context, DoctorProfile doctor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) =>
          _BookAppointmentSheet(doctor: doctor, patientId: patientId),
    );
  }

  void _callDoctor(BuildContext context, String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to make calls on this device')));
      }
    }
  }

  void _confirmRemove(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Remove Doctor'),
        content: Text('Remove Dr. ${doctor.name} from your doctors list?'),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.destructive),
                onPressed: () async {
                  Navigator.pop(dialogCtx);
                  try {
                    await ref
                        .read(connectionNotifierProvider.notifier)
                        .remove(patientId, doctor.uid);
                    if (context.mounted) {
                      showAppSnack(context, 'Dr. ${doctor.name} removed from your list.');
                    }
                  } catch (_) {
                    if (context.mounted) {
                      showAppSnack(context, 'Failed to remove doctor. Please try again.');
                    }
                  }
                },
                child: const Text('Remove'),
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Doctor Profile Sheet ──────────────────────────────────────────────────────
class _DoctorProfileSheet extends StatelessWidget {
  final DoctorProfile doctor;
  final String patientId;
  final bool isConnected;
  const _DoctorProfileSheet(
      {required this.doctor,
      required this.patientId,
      required this.isConnected});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            // Drag handle
            Center(
              child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 24),

            // Avatar + name header
            Center(
              child: Column(children: [
                AppAvatar(
                    name: doctor.name,
                    imageUrl: doctor.photoUrl,
                    size: 72,
                    backgroundColor: AppColors.primary),
                const SizedBox(height: 14),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Dr. ${doctor.name}',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                  if (doctor.verificationStatus == 'verified') ...[
                    const SizedBox(width: 6),
                    const ShieldCheck(width: 20, height: 20, color: AppColors.primary),
                  ] else if (doctor.verificationStatus == 'pending') ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.hourglass_top_rounded,
                        color: AppColors.warning, size: 18),
                  ],
                ]),
                if (doctor.specialty != null) ...[
                  const SizedBox(height: 4),
                  Text(doctor.specialty!,
                      style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500)),
                ],
                if (doctor.hospital != null) ...[
                  const SizedBox(height: 2),
                  Text(doctor.hospital!,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.mutedForeground)),
                ],
                const SizedBox(height: 12),
                // Rating pill — only shown when doctor has reviews
                if (doctor.reviewCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Star(width: 16, height: 16, color: AppColors.warning),
                      const SizedBox(width: 4),
                      Text(doctor.rating.toStringAsFixed(1),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.warning)),
                      const SizedBox(width: 4),
                      Text('(${doctor.reviewCount} reviews)',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedForeground)),
                    ]),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                        color: AppColors.muted,
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('No reviews yet',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedForeground)),
                  ),
              ]),
            ),

            const SizedBox(height: 24),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 20),

            // Details
            if (doctor.hospital != null)
              _ProfileRow(const Hospital(width: 16, height: 16, color: AppColors.mutedForeground), 'Hospital', doctor.hospital!),
            if (doctor.specialty != null)
              _ProfileRow(const Icon(Icons.medical_information_rounded, size: 16, color: AppColors.mutedForeground), 'Specialty', doctor.specialty!),
            if (doctor.phone != null && doctor.phone!.isNotEmpty)
              _ProfileRow(const Phone(width: 16, height: 16, color: AppColors.mutedForeground), 'Phone', doctor.phone!),
            if (doctor.licenseNo != null && doctor.licenseNo!.isNotEmpty)
              _ProfileRow(const Medal(width: 16, height: 16, color: AppColors.mutedForeground), 'License', doctor.licenseNo!),
            if (doctor.availableHours != null && doctor.availableHours!.isNotEmpty)
              _ProfileRow(const Clock(width: 16, height: 16, color: AppColors.mutedForeground), 'Hours', doctor.availableHours!),
            if (doctor.consultationFee != null && doctor.consultationFee!.isNotEmpty)
              _ProfileRow(const Icon(Icons.payments_rounded, size: 16, color: AppColors.mutedForeground), 'Fee', doctor.consultationFee!),
            _ProfileRow(
              doctor.acceptingNewPatients
                  ? const CheckCircle(width: 16, height: 16, color: AppColors.mutedForeground)
                  : const Xmark(width: 16, height: 16, color: AppColors.mutedForeground),
              'Availability',
              doctor.acceptingNewPatients ? 'Accepting new patients' : 'Not accepting new patients',
              valueColor: doctor.acceptingNewPatients ? AppColors.success : AppColors.destructive,
            ),
            if (isConnected)
              _ProfileRow(
                const CheckCircle(width: 16, height: 16, color: AppColors.mutedForeground),
                'Status',
                'Connected — your doctor',
                valueColor: AppColors.success,
              ),

            const SizedBox(height: 24),

            // Action buttons
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (_) =>
                      _BookAppointmentSheet(doctor: doctor, patientId: patientId),
                );
              },
              icon: const Calendar(width: 16, height: 16),
              label: const Text('Book Appointment'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 46),
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
            if (doctor.phone != null && doctor.phone!.isNotEmpty) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse('tel:${doctor.phone}');
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
                icon: const Phone(width: 16, height: 16),
                label: const Text('Call Doctor'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 46)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final Widget icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _ProfileRow(this.icon, this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          icon,
          const SizedBox(width: 10),
          SizedBox(
              width: 90,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.mutedForeground))),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: valueColor ?? AppColors.foreground))),
        ]),
      );
}

// ─── Book Appointment Sheet ────────────────────────────────────────────────────
class _BookAppointmentSheet extends ConsumerStatefulWidget {
  final DoctorProfile doctor;
  final String patientId;
  const _BookAppointmentSheet(
      {required this.doctor, required this.patientId});
  @override
  ConsumerState<_BookAppointmentSheet> createState() =>
      _BookAppointmentSheetState();
}

class _BookAppointmentSheetState
    extends ConsumerState<_BookAppointmentSheet> {
  final _noteCtrl = TextEditingController();
  DateTime? _preferredDate;
  String? _preferredTime;
  bool _isBooking = false;

  static const _timeSlots = [
    'Morning (8–12)',
    'Afternoon (12–5)',
    'Evening (5–8)',
    'Flexible',
  ];

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _book() async {
    if (_isBooking) return;
    setState(() => _isBooking = true);
    try {
      final user = await ref.read(currentUserProvider.future);
      if (user == null) return;

      final parts = <String>[
        if (_noteCtrl.text.trim().isNotEmpty) _noteCtrl.text.trim(),
        if (_preferredDate != null)
          'Preferred date: ${DateFormat('EEE, MMM d, y').format(_preferredDate!)}',
        if (_preferredTime != null) 'Preferred time: $_preferredTime',
      ];
      await ref.read(appointmentNotifierProvider.notifier).book(
            patientId: user.uid,
            patientName: user.name,
            doctorId: widget.doctor.uid,
            doctorName: widget.doctor.name,
            doctorSpecialty: widget.doctor.specialty,
            note: parts.isEmpty ? null : parts.join('\n'),
          );
      if (mounted) {
        Navigator.pop(context);
        showAppSnack(context,
            'Appointment request sent to Dr. ${widget.doctor.name}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to book appointment. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text('Book with Dr. ${widget.doctor.name}',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            if (widget.doctor.specialty != null) ...[
              const SizedBox(height: 4),
              Text(widget.doctor.specialty!,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.mutedForeground)),
            ],
            const SizedBox(height: 20),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Reason for visit (optional)',
                  hintText: 'Describe your symptoms or concern...'),
            ),
            const SizedBox(height: 16),
            const Text('Preferred date (optional)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 1)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 90)),
                );
                if (date != null) setState(() => _preferredDate = date);
              },
              // Conditional border color — kept as Container
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: _preferredDate != null
                      ? AppColors.primary.withValues(alpha: 0.06)
                      : AppColors.muted,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _preferredDate != null
                        ? AppColors.primary.withValues(alpha: 0.4)
                        : AppColors.border,
                  ),
                ),
                child: Row(children: [
                  Calendar(
                      width: 16, height: 16,
                      color: _preferredDate != null
                          ? AppColors.primary
                          : AppColors.mutedForeground),
                  const SizedBox(width: 10),
                  Text(
                    _preferredDate != null
                        ? DateFormat('EEE, MMM d, y').format(_preferredDate!)
                        : 'Tap to pick a date',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: _preferredDate != null
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: _preferredDate != null
                            ? AppColors.primary
                            : AppColors.mutedForeground),
                  ),
                  if (_preferredDate != null) ...[
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _preferredDate = null),
                      child: const Xmark(width: 16, height: 16, color: AppColors.mutedForeground),
                    ),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Preferred time',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _timeSlots.map((slot) {
                final selected = _preferredTime == slot;
                return GestureDetector(
                  onTap: () => setState(() => _preferredTime = selected ? null : slot),
                  // Selected conditional colors — kept as Container
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.muted,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: selected ? AppColors.primary : AppColors.border),
                    ),
                    child: Text(slot,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: selected ? Colors.white : AppColors.foreground)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(10)),
              child: const Row(children: [
                Icon(Icons.info_outline_rounded,
                    color: AppColors.warning, size: 18),
                SizedBox(width: 10),
                Expanded(
                    child: Text(
                        'The doctor will confirm the appointment date and time.',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.warning))),
              ]),
            ),
            const SizedBox(height: 20),
            _isBooking
                ? const Center(child: CircularProgressIndicator())
                : GradientButton(
                    label: 'Send Request',
                    colors: const [AppColors.primary, Color(0xFF5B21B6)],
                    onPressed: _book),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Prescriptions Tab ─────────────────────────────────────────────────────────
class _PrescriptionsTab extends StatelessWidget {
  final AsyncValue<List<Prescription>> rxAsync;
  const _PrescriptionsTab({required this.rxAsync});

  @override
  Widget build(BuildContext context) {
    return rxAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Something went wrong',
          subtitle: 'Pull to refresh or try again.'),
      data: (prescriptions) {
        if (prescriptions.isEmpty) {
          return const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No Prescriptions',
              subtitle:
                  'Prescriptions from your doctors will appear here.');
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          itemCount: prescriptions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _PrescriptionCard(rx: prescriptions[i]),
        );
      },
    );
  }
}

class _PrescriptionCard extends StatelessWidget {
  final Prescription rx;
  const _PrescriptionCard({required this.rx});

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Notes(
                  color: AppColors.success, width: 20, height: 20)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Dr. ${rx.doctorName}',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                Text(
                    DateFormat('MMM d, y').format(rx.issuedAt),
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground)),
              ])),
          StatusBadge.info('${rx.medicines.length} meds'),
        ]),
        if (rx.diagnosis != null) ...[
          const SizedBox(height: 10),
          Text('Diagnosis: ${rx.diagnosis}',
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.foreground)),
        ],
        const SizedBox(height: 10),
        const Divider(),
        const SizedBox(height: 8),
        ...rx.medicines.map((med) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                const Icon(Icons.circle, size: 6, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('${med.name} - ${med.dosage}',
                        style: const TextStyle(fontSize: 13))),
                Text(med.frequency,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground)),
              ]),
            )),
        if (rx.notes != null) ...[
          const SizedBox(height: 8),
          Text('Note: ${rx.notes}',
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.mutedForeground,
                  fontStyle: FontStyle.italic)),
        ],
      ]),
    );
  }
}

class _ShimmerDoctorList extends StatelessWidget {
  const _ShimmerDoctorList();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.muted,
      highlightColor: AppColors.surface,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Container(
          height: 130,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
