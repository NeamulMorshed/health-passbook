import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/patient_provider.dart';

class CaregiverSetupScreen extends ConsumerStatefulWidget {
  const CaregiverSetupScreen({super.key});
  @override
  ConsumerState<CaregiverSetupScreen> createState() => _CaregiverSetupScreenState();
}

class _CaregiverSetupScreenState extends ConsumerState<CaregiverSetupScreen> {
  final _pageCtrl = PageController();
  int _page = 0;
  bool _saving = false;

  // Step 1 — Who are you caring for?
  final _nameCtrl = TextEditingController();
  final _ageCtrl  = TextEditingController();
  String _relationship = AppConstants.relationships.first;

  // Step 2 — Doctor (optional, stored as notes only; real linking done in-app)
  final _doctorNoteCtrl = TextEditingController();

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _doctorNoteCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == 0 && _nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your family member's name.")),
      );
      return;
    }
    if (_page < 2) {
      setState(() => _page++);
      _pageCtrl.animateToPage(_page,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_page > 0) {
      setState(() => _page--);
      _pageCtrl.animateToPage(_page,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _skip() {
    if (_page < 2) {
      setState(() => _page++);
      _pageCtrl.animateToPage(_page,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      final uid = ref.read(authRepositoryProvider).currentUid;
      if (uid == null) return;

      // Save the first family member
      await ref.read(familyMemberNotifierProvider.notifier).add(
        uid,
        name: _nameCtrl.text.trim(),
        relationship: _relationship,
        age: int.tryParse(_ageCtrl.text),
      );

      // Mark caregiver onboarding complete
      await ref.read(authRepositoryProvider).markOnboardingComplete(uid);

      if (mounted) context.go('/home');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const steps = ['Who you care for', 'Their Doctor', 'All Set'];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Caregiver Setup'),
        automaticallyImplyLeading: false,
        leading: _page > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _back,
              )
            : null,
      ),
      body: LoadingOverlay(
        isLoading: _saving,
        message: 'Setting up your account...',
        child: Column(children: [
          // ── Progress bar ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: List.generate(3, (i) => Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: i <= _page
                        ? const Color(0xFFF59E0B)
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ))),
              const SizedBox(height: 6),
              Text(
                'Step ${_page + 1} of 3 — ${steps[_page]}',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                    fontFamily: 'Inter'),
              ),
            ]),
          ),

          // ── Pages ─────────────────────────────────────────────────────────
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _Step1(
                  nameCtrl: _nameCtrl,
                  ageCtrl: _ageCtrl,
                  relationship: _relationship,
                  onRelationshipChanged: (r) => setState(() => _relationship = r),
                ),
                _Step2(doctorNoteCtrl: _doctorNoteCtrl),
                const _Step3(),
              ],
            ),
          ),

          // ── Bottom buttons ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Column(children: [
              GradientButton(
                label: _page == 0
                    ? 'Next'
                    : _page == 1
                        ? 'Next'
                        : 'Start Caring',
                colors: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                onPressed: _next,
                isLoading: _saving,
              ),
              if (_page > 0) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _skip,
                  child: Text(
                    _page < 2 ? 'Skip this step' : 'Skip',
                    style: const TextStyle(
                        color: AppColors.mutedForeground,
                        fontFamily: 'Inter'),
                  ),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Step 1: Who are you caring for? ───────────────────────────────────────────
class _Step1 extends StatelessWidget {
  final TextEditingController nameCtrl, ageCtrl;
  final String relationship;
  final ValueChanged<String> onRelationshipChanged;

  const _Step1({
    required this.nameCtrl,
    required this.ageCtrl,
    required this.relationship,
    required this.onRelationshipChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      children: [
        _infoBox(
          'Tell us about the person you\'re caring for so we can set up their health profile.',
          const Color(0xFFF59E0B),
        ),
        const SizedBox(height: 24),
        _label('Their Full Name *'),
        TextField(
          controller: nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Aryan Ahmed'),
        ),
        const SizedBox(height: 16),
        _label('Relationship'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AppConstants.relationships.map((r) {
            final selected = relationship == r;
            return GestureDetector(
              onTap: () => onRelationshipChanged(r),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFF59E0B)
                      : AppColors.muted,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFF59E0B)
                        : AppColors.border,
                  ),
                ),
                child: Text(
                  r,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: selected ? Colors.white : AppColors.foreground,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _label('Their Age (optional)'),
        TextField(
          controller: ageCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(hintText: 'e.g. 68'),
        ),
      ],
    );
  }
}

// ── Step 2: Their Doctor ───────────────────────────────────────────────────────
class _Step2 extends StatelessWidget {
  final TextEditingController doctorNoteCtrl;
  const _Step2({required this.doctorNoteCtrl});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      children: [
        _infoBox(
          'Optional — you can always connect with doctors from the Care tab later.',
          const Color(0xFFF59E0B),
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.local_hospital_rounded,
                color: Color(0xFFF59E0B), size: 28),
            const SizedBox(height: 12),
            const Text(
              'Connect with their doctor',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                  color: AppColors.foreground),
            ),
            const SizedBox(height: 6),
            const Text(
              'Once inside the app, go to Care → My Doctors to search for and connect with their healthcare provider. Doctors can then send prescriptions and approve appointment requests directly.',
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.mutedForeground,
                  fontFamily: 'Inter',
                  height: 1.5),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        _label('Doctor name or notes (optional)'),
        TextField(
          controller: doctorNoteCtrl,
          decoration: const InputDecoration(
              hintText: 'e.g. Dr. Mehnaz – City General Hospital'),
          maxLines: 2,
        ),
        const SizedBox(height: 24),
        _featureTile(
          Icons.search_rounded,
          'Search by name or hospital',
          'Find any verified doctor on Omra',
        ),
        const SizedBox(height: 10),
        _featureTile(
          Icons.send_rounded,
          'Request a connection',
          'The doctor confirms and joins your care circle',
        ),
        const SizedBox(height: 10),
        _featureTile(
          Icons.description_rounded,
          'Receive prescriptions instantly',
          'Digital prescriptions arrive in the app',
        ),
      ],
    );
  }

  Widget _featureTile(IconData icon, String title, String subtitle) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFFF59E0B)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                    color: AppColors.foreground)),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                    fontFamily: 'Inter')),
          ]),
        ),
      ]);
}

// ── Step 3: All Set ────────────────────────────────────────────────────────────
class _Step3 extends StatefulWidget {
  const _Step3();
  @override
  State<_Step3> createState() => _Step3State();
}

class _Step3State extends State<_Step3> {
  bool _notifGranted = false;

  @override
  void initState() {
    super.initState();
    _checkNotifStatus();
  }

  Future<void> _checkNotifStatus() async {
    final status = await Permission.notification.status;
    if (mounted) setState(() => _notifGranted = status.isGranted);
  }

  Future<void> _requestNotifications() async {
    final status = await Permission.notification.request();
    if (mounted) setState(() => _notifGranted = status.isGranted);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_rounded,
                size: 44, color: Color(0xFFF59E0B)),
          ),
        ),
        const SizedBox(height: 24),
        const Center(
          child: Text(
            'You\'re all set!',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
                color: AppColors.foreground),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Omra will help you stay on top of\ntheir medicines, meals, and appointments.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14,
                color: AppColors.mutedForeground,
                fontFamily: 'Inter',
                height: 1.5),
          ),
        ),
        const SizedBox(height: 32),
        // Notifications block
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _notifGranted
                ? AppColors.success.withValues(alpha: 0.06)
                : const Color(0xFFF59E0B).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _notifGranted
                  ? AppColors.success.withValues(alpha: 0.25)
                  : const Color(0xFFF59E0B).withValues(alpha: 0.25),
            ),
          ),
          child: Row(children: [
            Icon(
              _notifGranted
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_outlined,
              color: _notifGranted ? AppColors.success : const Color(0xFFF59E0B),
              size: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _notifGranted
                      ? 'Reminders enabled'
                      : 'Enable medicine reminders',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                      color: _notifGranted
                          ? AppColors.success
                          : const Color(0xFFF59E0B)),
                ),
                const SizedBox(height: 2),
                Text(
                  _notifGranted
                      ? 'You\'ll be notified when it\'s time for their medicine.'
                      : 'Get alerted when it\'s time for their medicine.',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                      fontFamily: 'Inter'),
                ),
              ]),
            ),
            if (!_notifGranted) ...[
              const SizedBox(width: 10),
              TextButton(
                onPressed: _requestNotifications,
                style: TextButton.styleFrom(
                  backgroundColor:
                      const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Allow',
                    style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Inter',
                        color: Color(0xFFF59E0B),
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 20),
        // Feature summary cards
        _summaryTile(Icons.medication_rounded, AppColors.primary,
            'Medicine Tracker', 'Log and schedule their daily medications'),
        const SizedBox(height: 10),
        _summaryTile(Icons.restaurant_rounded, AppColors.success,
            'Meal Logging', 'Track breakfast, lunch, and dinner'),
        const SizedBox(height: 10),
        _summaryTile(Icons.calendar_month_rounded, const Color(0xFFF59E0B),
            'Appointments', 'Book and manage doctor visits'),
      ],
    );
  }

  Widget _summaryTile(
          IconData icon, Color color, String title, String subtitle) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                      color: color)),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                      fontFamily: 'Inter')),
            ]),
          ),
        ]),
      );
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _label(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(t,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
              fontFamily: 'Inter')),
    );

Widget _infoBox(String text, Color color) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(Icons.info_outline_rounded, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13, color: color, fontFamily: 'Inter'))),
      ]),
    );
