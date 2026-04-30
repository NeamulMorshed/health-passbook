import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/notif_bell.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/patient_provider.dart';
// import '../../../providers/gamification_provider.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});
  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  bool _isWalking = false;
  bool _isPaused = false;
  Timer? _timer;
  int _seconds = 0;
  double _distanceKm = 0;

  // Pedometer-based step tracking
  int _steps = 0;
  int? _stepBaseline;
  bool _pedometerAvailable = false;
  StreamSubscription<StepCount>? _stepSub;

  // GPS for distance
  Position? _lastPosition;
  StreamSubscription<Position>? _positionSub;

  final _stepsCtrl = TextEditingController();

  @override
  void dispose() {
    _timer?.cancel();
    _positionSub?.cancel();
    _stepSub?.cancel();
    _stepsCtrl.dispose();
    super.dispose();
  }

  void _toggleWalk() async {
    if (_isWalking) {
      await _stopWalk();
    } else {
      await _startWalk();
    }
  }

  void _pauseWalk() {
    _timer?.cancel();
    _stepSub?.pause();
    _positionSub?.pause();
    setState(() => _isPaused = true);
  }

  void _resumeWalk() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _seconds++));
    _stepSub?.resume();
    _positionSub?.resume();
    setState(() => _isPaused = false);
  }

  Future<void> _startWalk() async {
    // ── Location permission ──────────────────────────────────────────────
    var locPerm = await Geolocator.checkPermission();
    if (locPerm == LocationPermission.denied) {
      locPerm = await Geolocator.requestPermission();
    }
    if (locPerm == LocationPermission.denied ||
        locPerm == LocationPermission.deniedForever) {
      if (mounted) {
        showAppSnack(context,
            'Location permission is required. Enable it in Settings.');
      }
      return;
    }

    // ── Activity recognition permission (step sensor, Android 10+) ──────
    final actPerm = await Permission.activityRecognition.request();

    setState(() {
      _isWalking = true;
      _seconds = 0;
      _distanceKm = 0;
      _steps = 0;
      _stepBaseline = null;
      _pedometerAvailable = false;
      _lastPosition = null;
    });

    // ── Timer ────────────────────────────────────────────────────────────
    _timer =
        Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _seconds++));

    // ── GPS stream (distance) ────────────────────────────────────────────
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      if (_lastPosition != null) {
        final d = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          pos.latitude,
          pos.longitude,
        );
        setState(() => _distanceKm += d / 1000);
      }
      _lastPosition = pos;
    }, onError: (_) {});

    // ── Pedometer stream (steps) ─────────────────────────────────────────
    if (actPerm.isGranted) {
      _stepSub = Pedometer.stepCountStream.listen(
        (StepCount event) {
          if (_stepBaseline == null) {
            // First event — capture baseline so we count delta from here
            setState(() {
              _stepBaseline = event.steps;
              _pedometerAvailable = true;
            });
          } else {
            setState(() => _steps = event.steps - _stepBaseline!);
          }
        },
        onError: (_) {
          // Hardware sensor not available — GPS-based estimation used at save
          setState(() => _pedometerAvailable = false);
        },
        cancelOnError: false,
      );
    }
  }

  Future<void> _stopWalk() async {
    _timer?.cancel();
    _stepSub?.resume(); // resume before cancel so pause-cancel works correctly
    _positionSub?.resume();
    await _positionSub?.cancel();
    await _stepSub?.cancel();
    setState(() => _isPaused = false);

    // If pedometer had no data, fall back to stride-length estimate from GPS
    final finalSteps =
        _steps > 0 ? _steps : (_distanceKm * 1333).round();
    // ~0.04 kcal/step or ~60 kcal/km
    final kcal = _steps > 0
        ? (_steps * 0.04).round()
        : (_distanceKm * 60).round();

    setState(() => _isWalking = false);

    final user = await ref.read(currentUserProvider.future);
    if (user == null || !mounted) return;

    await ref.read(activityNotifierProvider.notifier).save(
          user.uid,
          type: 'walk',
          durationSeconds: _seconds,
          distanceKm: _distanceKm,
          steps: finalSteps,
          caloriesBurned: kcal,
        );
    // final hp = await ref.read(gamificationServiceProvider).awardActivity(user.uid, steps: finalSteps, type: 'walk');
    if (mounted) {
      showAppSnack(context,
          'Walk saved — ${_distanceKm.toStringAsFixed(2)} km · $finalSteps steps · ${_formatTime(_seconds)}');
    }
  }

  String _formatTime(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  // Live display values: use pedometer steps when available, else GPS estimate
  int get _displaySteps =>
      _steps > 0 ? _steps : (_distanceKm * 1333).round();
  int get _displayKcal => _steps > 0
      ? (_steps * 0.04).round()
      : (_distanceKm * 60).round();

  void _addManualSteps() async {
    final text = _stepsCtrl.text.trim();
    final count = int.tryParse(text);
    if (count == null || count <= 0) {
      showAppSnack(context, 'Please enter a valid step count.', isError: true);
      return;
    }
    if (count > 100000) {
      showAppSnack(context, 'That seems too high. Please enter a realistic step count.', isError: true);
      return;
    }
    final user = await ref.read(currentUserProvider.future);
    if (user == null) return;
    await ref.read(activityNotifierProvider.notifier).save(
          user.uid,
          type: 'steps',
          durationSeconds: 0,
          steps: count,
          caloriesBurned: (count * 0.04).round(),
        );
    if (mounted) {
      _stepsCtrl.clear();
      showAppSnack(context, '$count steps added successfully.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          title: const Text('Activity'),
          automaticallyImplyLeading: false,
          actions: const [NotifBell()]),
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
                    boxShadow: [
                      BoxShadow(
                          color: (_isWalking
                                  ? AppColors.success
                                  : AppColors.primary)
                              .withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6))
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('GPS Walk Tracker',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontFamily: 'Inter')),
                          if (_isWalking && _pedometerAvailable) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Step Sensor Active',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontFamily: 'Inter')),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _formatTime(_seconds),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 56,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter'),
                      ),
                      const SizedBox(height: 16),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _WalkStat(
                                _distanceKm.toStringAsFixed(2), 'km'),
                            _WalkStat('$_displaySteps', 'steps'),
                            _WalkStat('$_displayKcal', 'kcal'),
                          ]),
                      const SizedBox(height: 24),
                      if (_isWalking)
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          GestureDetector(
                            onTap: _isPaused ? _resumeWalk : _pauseWalk,
                            child: Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle),
                              child: Icon(
                                  _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                                  color: Colors.white,
                                  size: 34),
                            ),
                          ),
                          const SizedBox(width: 24),
                          GestureDetector(
                            onTap: _toggleWalk,
                            child: Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.stop_rounded, color: Colors.white, size: 34),
                            ),
                          ),
                        ])
                      else
                        GestureDetector(
                          onTap: _toggleWalk,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                          _isWalking
                              ? (_isPaused ? 'Paused — tap to resume or stop' : 'Tap pause or stop')
                              : 'Tap to Start Walk',
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontFamily: 'Inter')),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Manual steps
                const SectionHeader(title: 'Log Manual Steps'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _stepsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            hintText: 'Enter step count',
                            prefixIcon:
                                Icon(Icons.directions_walk_rounded),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _addManualSteps,
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(80, 44)),
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
                    if (logs.isEmpty) {
                      return const EmptyState(
                          icon: Icons.directions_run_outlined,
                          title: 'No Activity Yet',
                          subtitle:
                              'Start a walk or log your steps.');
                    }
                    return Column(
                      children: logs.take(10).map((log) {
                        final isWalk = log.type == 'walk';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.border)),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: AppColors.success
                                      .withValues(alpha: 0.1),
                                  borderRadius:
                                      BorderRadius.circular(8)),
                              child: Icon(
                                  isWalk
                                      ? Icons.directions_walk_rounded
                                      : Icons.stairs_rounded,
                                  color: AppColors.success,
                                  size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        isWalk
                                            ? 'GPS Walk'
                                            : 'Manual Steps',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight:
                                                FontWeight.w600,
                                            fontFamily: 'Inter')),
                                    Text(
                                      isWalk
                                          ? '${log.distanceKm?.toStringAsFixed(2) ?? 0} km · ${log.steps ?? 0} steps · ${log.formattedDuration}'
                                          : '${log.steps ?? 0} steps',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color:
                                              AppColors.mutedForeground,
                                          fontFamily: 'Inter'),
                                    ),
                                  ]),
                            ),
                            if (log.caloriesBurned != null)
                              Text('${log.caloriesBurned} kcal',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.warning,
                                      fontFamily: 'Inter')),
                          ]),
                        );
                      }).toList(),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const SizedBox.shrink(),
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
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter')),
        Text(label,
            style: const TextStyle(
                color: Colors.white70, fontSize: 12, fontFamily: 'Inter')),
      ]);
}
