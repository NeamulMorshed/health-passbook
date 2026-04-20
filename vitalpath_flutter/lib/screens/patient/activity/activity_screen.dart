import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/patient_provider.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});
  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  bool _isWalking = false;
  Timer? _timer;
  int _seconds = 0;
  double _distanceKm = 0;
  int _steps = 0;
  Position? _lastPosition;
  StreamSubscription<Position>? _positionSub;
  int _manualSteps = 0;
  final _stepsCtrl = TextEditingController();

  @override
  void dispose() {
    _timer?.cancel();
    _positionSub?.cancel();
    _stepsCtrl.dispose();
    super.dispose();
  }

  void _toggleWalk() async {
    if (_isWalking) {
      _stopWalk();
    } else {
      await _startWalk();
    }
  }

  Future<void> _startWalk() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (mounted) showAppSnack(context, 'Location permission required for GPS tracking.');
      return;
    }
    setState(() { _isWalking = true; _seconds = 0; _distanceKm = 0; _steps = 0; _lastPosition = null; });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _seconds++));
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen((pos) {
      if (_lastPosition \!= null) {
        final d = Geolocator.distanceBetween(_lastPosition\!.latitude, _lastPosition\!.longitude, pos.latitude, pos.longitude);
        setState(() { _distanceKm += d / 1000; _steps += (d / 0.75).round(); });
      }
      _lastPosition = pos;
    });
  }

  void _stopWalk() async {
    _timer?.cancel();
    await _positionSub?.cancel();
    setState(() => _isWalking = false);

    final user = await ref.read(currentUserProvider.future);
    if (user == null || \!mounted) return;

    await ref.read(activityNotifierProvider.notifier).save(
      user.uid,
      type: 'walk',
      durationSeconds: _seconds,
      distanceKm: _distanceKm,
      steps: _steps,
      caloriesBurned: (_distanceKm * 60).round(),
    );
    if (mounted) showAppSnack(context, 'Walk saved - ${_distanceKm.toStringAsFixed(2)}km in ${_formatTime(_seconds)}');
  }

  String _formatTime(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  void _addManualSteps() async {
    final count = int.tryParse(_stepsCtrl.text);
    if (count == null || count <= 0) return;
    final user = await ref.read(currentUserProvider.future);
    if (user == null) return;
    await ref.read(activityNotifierProvider.notifier).save(user.uid, type: 'steps', durationSeconds: 0, steps: count);
    if (mounted) {
      _stepsCtrl.clear();
      showAppSnack(context, '$count steps added');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Activity'), automaticallyImplyLeading: false),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (user) {
          if (user == null) return const Center(child: CircularProgressIndicator());
          final activityAsync = ref.watch(activityLogsProvider(user.uid));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // GPS Walk Tracker card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isWalking
                          ? [AppColors.success, const Color(0xFF15803D)]
                          : [AppColors.primary, AppColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: (_isWalking ? AppColors.success : AppColors.primary).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: Column(
                    children: [
                      const Text('GPS Walk Tracker', style: TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Inter')),
                      const SizedBox(height: 16),
                      Text(_formatTime(_seconds), style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w700, fontFamily: 'Inter')),
                      const SizedBox(height: 16),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                        _WalkStat('${_distanceKm.toStringAsFixed(2)}', 'km'),
                        _WalkStat('$_steps', 'steps'),
                        _WalkStat('${(_distanceKm * 60).round()}', 'kcal'),
                      ]),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: _toggleWalk,
                        child: Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                          child: Icon(_isWalking ? Icons.stop_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 40),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(_isWalking ? 'Tap to Stop' : 'Tap to Start Walk', style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Inter')),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Manual steps
                const SectionHeader(title: 'Log Manual Steps'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _stepsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: 'Enter step count', prefixIcon: Icon(Icons.directions_walk_rounded), filled: false, border: InputBorder.none, enabledBorder: InputBorder.none),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _addManualSteps,
                      style: ElevatedButton.styleFrom(minimumSize: const Size(80, 44)),
                      child: const Text('Add'),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),

                // Recent activity
                const SectionHeader(title: 'Recent Activity'),
                const SizedBox(height: 12),
                activityAsync.when(
                  data: (logs) {
                    if (logs.isEmpty) return const EmptyState(icon: Icons.directions_run_outlined, title: 'No Activity Yet', subtitle: 'Start a walk or log your steps.');
                    return Column(
                      children: logs.take(10).map((log) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Icon(log.type == 'walk' ? Icons.directions_walk_rounded : Icons.stairs_rounded, color: AppColors.success, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(log.type == 'walk' ? 'GPS Walk' : 'Manual Steps', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                            Text(
                              log.type == 'walk'
                                  ? '${log.distanceKm?.toStringAsFixed(2) ?? 0}km - ${log.formattedDuration}'
                                  : '${log.steps ?? 0} steps',
                              style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontFamily: 'Inter'),
                            ),
                          ])),
                          if (log.caloriesBurned \!= null)
                            Text('${log.caloriesBurned} kcal', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warning, fontFamily: 'Inter')),
                        ]),
                      )).toList(),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('$e'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WalkStat extends StatelessWidget {
  final String value, label;
  const _WalkStat(this.value, this.label);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, fontFamily: 'Inter')),
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Inter')),
  ]);
}
