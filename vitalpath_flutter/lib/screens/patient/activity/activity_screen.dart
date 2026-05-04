import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/notif_bell.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/patient_provider.dart';
import '../../../models/activity_log.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});
  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  // Activity type selection
  String _activityType = ActivityType.walk;

  // GPS tracking state
  bool _isTracking = false;
  bool _isPaused = false;
  Timer? _timer;
  int _seconds = 0;
  double _distanceKm = 0;

  // Pedometer
  int _steps = 0;
  int? _stepBaseline;
  bool _pedometerAvailable = false;
  StreamSubscription<StepCount>? _stepSub;

  // GPS for distance
  Position? _lastPosition;
  StreamSubscription<Position>? _positionSub;

  // Manual log controllers
  final _manualDurationCtrl = TextEditingController();
  final _manualCaloriesCtrl = TextEditingController();
  final _manualNotesCtrl = TextEditingController();

  bool get _isGpsType => ActivityType.gpsTracked.contains(_activityType);

  @override
  void dispose() {
    _timer?.cancel();
    _positionSub?.cancel();
    _stepSub?.cancel();
    _manualDurationCtrl.dispose();
    _manualCaloriesCtrl.dispose();
    _manualNotesCtrl.dispose();
    super.dispose();
  }

  // ── GPS tracking methods ──────────────────────────────────────────────────

  void _pauseTracking() {
    _timer?.cancel();
    _stepSub?.pause();
    _positionSub?.pause();
    setState(() => _isPaused = true);
  }

  void _resumeTracking() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _seconds++));
    _stepSub?.resume();
    _positionSub?.resume();
    setState(() => _isPaused = false);
  }

  Future<void> _startGpsTracking() async {
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

    final actPerm = await Permission.activityRecognition.request();

    setState(() {
      _isTracking = true;
      _seconds = 0;
      _distanceKm = 0;
      _steps = 0;
      _stepBaseline = null;
      _pedometerAvailable = false;
      _lastPosition = null;
    });

    _timer =
        Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _seconds++));

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

    if (actPerm.isGranted) {
      _stepSub = Pedometer.stepCountStream.listen(
        (StepCount event) {
          if (_stepBaseline == null) {
            setState(() {
              _stepBaseline = event.steps;
              _pedometerAvailable = true;
            });
          } else {
            setState(() => _steps = event.steps - _stepBaseline!);
          }
        },
        onError: (_) {
          setState(() => _pedometerAvailable = false);
        },
        cancelOnError: false,
      );
    }
  }

  Future<void> _stopGpsTracking() async {
    _timer?.cancel();
    _stepSub?.resume();
    _positionSub?.resume();
    await _positionSub?.cancel();
    await _stepSub?.cancel();
    setState(() => _isPaused = false);

    final finalSteps =
        _steps > 0 ? _steps : (_distanceKm * 1333).round();
    final kcal = _steps > 0
        ? (_steps * 0.04).round()
        : (_distanceKm * 60).round();

    setState(() => _isTracking = false);

    final user = await ref.read(currentUserProvider.future);
    if (user == null || !mounted) return;

    await ref.read(activityNotifierProvider.notifier).save(
          user.uid,
          type: _activityType,
          durationSeconds: _seconds,
          distanceKm: _distanceKm,
          steps: finalSteps,
          caloriesBurned: kcal,
        );

    if (mounted) {
      showAppSnack(context,
          '${ActivityType.labelFor(_activityType)} saved — ${_distanceKm.toStringAsFixed(2)} km · $finalSteps steps · ${_formatTime(_seconds)}');
    }
  }

  // ── Manual save ──────────────────────────────────────────────────────────

  Future<void> _saveManualActivity() async {
    final minutes = int.tryParse(_manualDurationCtrl.text.trim());
    if (minutes == null || minutes <= 0) {
      showAppSnack(context, 'Please enter a valid duration in minutes.',
          isError: true);
      return;
    }
    final calories = int.tryParse(_manualCaloriesCtrl.text.trim());
    final user = await ref.read(currentUserProvider.future);
    if (user == null || !mounted) return;

    await ref.read(activityNotifierProvider.notifier).save(
          user.uid,
          type: _activityType,
          durationSeconds: minutes * 60,
          steps: null,
          distanceKm: null,
          caloriesBurned: calories,
        );

    if (mounted) {
      _manualDurationCtrl.clear();
      _manualCaloriesCtrl.clear();
      _manualNotesCtrl.clear();
      showAppSnack(context,
          '${ActivityType.labelFor(_activityType)} logged — $minutes min${calories != null ? ' · $calories kcal' : ''}');
    }
  }

  String _formatTime(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  int get _displaySteps =>
      _steps > 0 ? _steps : (_distanceKm * 1333).round();
  int get _displayKcal => _steps > 0
      ? (_steps * 0.04).round()
      : (_distanceKm * 60).round();

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
            title: "Can't load right now",
            subtitle: 'Check your connection and try again.'),
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
                // P5.2 — Weekly activity trend chart (always shown at top)
                activityAsync.when(
                  data: (logs) => _WeeklyActivityChart(logs: logs),
                  loading: () => const SizedBox(
                    height: 140,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 20),

                // P5.1 — Activity type picker (only when not tracking)
                if (!_isTracking) ...[
                  const SectionHeader(title: 'Activity Type'),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ActivityType.allTypes.map((type) {
                        final sel = _activityType == type;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _activityType = type),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: sel ? AppColors.primary : AppColors.muted,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: sel
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    ActivityType.iconFor(type),
                                    size: 15,
                                    color: sel
                                        ? Colors.white
                                        : AppColors.mutedForeground,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    ActivityType.labelFor(type),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: sel
                                          ? Colors.white
                                          : AppColors.mutedForeground,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── GPS tracker card (for GPS types) or Manual form (for manual types)
                if (_isGpsType) _buildGpsCard() else _buildManualCard(),

                const SizedBox(height: 24),

                // Recent activity list
                const SectionHeader(title: 'Recent Activity'),
                const SizedBox(height: 12),
                activityAsync.when(
                  data: (logs) {
                    if (logs.isEmpty) {
                      return const EmptyState(
                          icon: Icons.directions_run_outlined,
                          title: 'No Activity Yet',
                          subtitle: 'Start a session or log an activity.');
                    }
                    return Column(
                      children: logs.take(10).map((log) {
                        final isGps =
                            ActivityType.gpsTracked.contains(log.type);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: AppColors.border)),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: AppColors.success
                                      .withValues(alpha: 0.1),
                                  borderRadius:
                                      BorderRadius.circular(8)),
                              child: Icon(
                                ActivityType.iconFor(log.type),
                                color: AppColors.success,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        ActivityType.labelFor(log.type),
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight:
                                                FontWeight.w600,
                                            fontFamily: 'Inter')),
                                    Text(
                                      isGps
                                          ? '${log.distanceKm?.toStringAsFixed(2) ?? 0} km · ${log.steps ?? 0} steps · ${log.formattedDuration}'
                                          : log.durationSeconds > 0
                                              ? '${log.durationSeconds ~/ 60} min'
                                              : 'Manual log',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors
                                              .mutedForeground,
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

  Widget _buildGpsCard() {
    final label = ActivityType.labelFor(_activityType);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isTracking
              ? [AppColors.success, const Color(0xFF15803D)]
              : [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color:
                  (_isTracking ? AppColors.success : AppColors.primary)
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
              Text('GPS $label Tracker',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontFamily: 'Inter')),
              if (_isTracking && _pedometerAvailable) ...[
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
                _WalkStat(_distanceKm.toStringAsFixed(2), 'km'),
                _WalkStat('$_displaySteps', 'steps'),
                _WalkStat('$_displayKcal', 'kcal'),
              ]),
          const SizedBox(height: 24),
          if (_isTracking)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              GestureDetector(
                onTap: _isPaused ? _resumeTracking : _pauseTracking,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle),
                  child: Icon(
                      _isPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      color: Colors.white,
                      size: 34),
                ),
              ),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: _stopGpsTracking,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.stop_rounded,
                      color: Colors.white, size: 34),
                ),
              ),
            ])
          else
            GestureDetector(
              onTap: _startGpsTracking,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 40),
              ),
            ),
          const SizedBox(height: 12),
          Text(
              _isTracking
                  ? (_isPaused
                      ? 'Paused — tap to resume or stop'
                      : 'Tap pause or stop')
                  : 'Start ${ActivityType.labelFor(_activityType)}',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontFamily: 'Inter')),
        ],
      ),
    );
  }

  Widget _buildManualCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(ActivityType.iconFor(_activityType),
                color: AppColors.primary, size: 22),
            const SizedBox(width: 10),
            Text(
              'Log ${ActivityType.labelFor(_activityType)}',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter'),
            ),
          ]),
          const SizedBox(height: 16),
          TextFormField(
            controller: _manualDurationCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Duration (minutes) *',
              hintText: 'e.g. 30',
              prefixIcon: Icon(Icons.timer_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _manualCaloriesCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Estimated calories (optional)',
              hintText: 'e.g. 150',
              prefixIcon: Icon(Icons.local_fire_department_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _manualNotesCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'e.g. Felt great, outdoor session',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 16),
          GradientButton(
            label: 'Save Activity',
            onPressed: _saveManualActivity,
          ),
        ],
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

// ── P5.2 — Weekly Activity Chart ──────────────────────────────────────────────
class _WeeklyActivityChart extends StatelessWidget {
  final List<ActivityLog> logs;
  const _WeeklyActivityChart({required this.logs});

  static const _dayLabels = [
    '',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun'
  ];

  List<int> _dailySteps() {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return logs
          .where((l) =>
              l.loggedAt.day == day.day &&
              l.loggedAt.month == day.month &&
              l.loggedAt.year == day.year)
          .fold<int>(0, (sum, l) => sum + (l.steps ?? 0));
    });
  }

  @override
  Widget build(BuildContext context) {
    final steps = _dailySteps();
    final maxSteps = steps.reduce((a, b) => a > b ? a : b);

    // Y-axis max: max of (10000, actual max) rounded up to nearest 2000
    const goal = 10000;
    final rawMax = maxSteps > goal ? maxSteps : goal;
    final yMax = ((rawMax / 2000).ceil() * 2000).toDouble();

    final weeklySteps = steps.fold<int>(0, (a, b) => a + b);
    final weeklyKm = logs.fold<double>(0, (a, l) => a + (l.distanceKm ?? 0));
    final activeDays = steps.where((s) => s > 0).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Weekly Activity',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter')),
          const SizedBox(height: 14),
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                maxY: yMax,
                minY: 0,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        final now = DateTime.now();
                        final day = now.subtract(
                            Duration(days: 6 - value.toInt()));
                        final label = _dayLabels[day.weekday];
                        final isToday = value.toInt() == 6;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'Inter',
                              color: isToday
                                  ? AppColors.primary
                                  : AppColors.mutedForeground,
                              fontWeight: isToday
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(7, (i) {
                  final s = steps[i];
                  Color barColor;
                  if (s >= goal) {
                    barColor = AppColors.primary;
                  } else if (s >= 5000) {
                    barColor = AppColors.success;
                  } else {
                    barColor = AppColors.warning;
                  }
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: s.toDouble(),
                        color: s == 0
                            ? AppColors.muted
                            : barColor,
                        width: 18,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ],
                  );
                }),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                        BarTooltipItem(
                      '${steps[groupIndex]}',
                      const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Weekly summary row
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'This week: $weeklySteps steps  ·  ${weeklyKm.toStringAsFixed(1)} km  ·  $activeDays active day${activeDays == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.mutedForeground,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
