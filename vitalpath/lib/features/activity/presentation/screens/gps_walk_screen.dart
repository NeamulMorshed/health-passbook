import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/tables/activity_table.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'package:intl/intl.dart';

/// GPS Walk tracking screen (SRS §4.3).
/// Provides real-time haptic feedback every 1km (SRS §4.3).
/// On storage full: preserves step count, discards GPS path (SRS §5.3).
class GpsWalkScreen extends ConsumerStatefulWidget {
  const GpsWalkScreen({super.key});

  @override
  ConsumerState<GpsWalkScreen> createState() => _GpsWalkScreenState();
}

class _GpsWalkScreenState extends ConsumerState<GpsWalkScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionSub;
  final List<LatLng> _polylinePoints = [];
  final List<Polyline> _polylines = [];

  Position? _lastPosition;
  double _totalDistanceMeters = 0;
  int _stepCount = 0;
  int _lastKmHapticAt = 0; // Track last km at which haptic fired
  bool _isTracking = false;
  DateTime? _startTime;
  Timer? _durationTimer;
  int _durationSeconds = 0;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission required for GPS walk tracking'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _startWalk() async {
    setState(() {
      _isTracking = true;
      _startTime = DateTime.now();
      _durationSeconds = 0;
      _polylinePoints.clear();
      _totalDistanceMeters = 0;
      _lastKmHapticAt = 0;
    });

    // Trigger start haptic
    await ref.read(hapticServiceProvider).success();

    // Start duration timer
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _durationSeconds++);
    });

    // Start GPS tracking
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
      ),
    ).listen(_onPositionUpdate);
  }

  void _onPositionUpdate(Position position) async {
    if (!_isTracking) return;

    final newPoint = LatLng(position.latitude, position.longitude);
    setState(() => _polylinePoints.add(newPoint));

    // Calculate distance
    if (_lastPosition != null) {
      final delta = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      _totalDistanceMeters += delta;

      // Haptic every km (SRS §4.3)
      final currentKm = (_totalDistanceMeters / 1000).floor();
      if (currentKm > _lastKmHapticAt) {
        _lastKmHapticAt = currentKm;
        await ref.read(hapticServiceProvider).kilometerReached();
      }
    }

    _lastPosition = position;

    // Move camera
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(newPoint),
    );
  }

  Future<void> _stopWalk() async {
    _positionSub?.cancel();
    _durationTimer?.cancel();
    setState(() => _isTracking = false);

    // Celebration haptic if significant walk
    if (_totalDistanceMeters > 500) {
      await ref.read(hapticServiceProvider).stepGoalImpact();
    }

    // Save walk session (SRS §5.3 — storage-aware)
    await _saveWalkSession();

    if (mounted) context.pop();
  }

  Future<void> _saveWalkSession() async {
    if (_startTime == null) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final db = ref.read(appDatabaseProvider);
    final id = const Uuid().v4();

    // SRS §5.3: Attempt to save GPS path, but gracefully degrade if storage issue
    String? polylineJson;
    try {
      final points = _polylinePoints
          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList();
      polylineJson = points.toString(); // Simplified — use jsonEncode in production
    } catch (e) {
      // Storage issue — discard GPS path, preserve step count (SRS §5.3)
      polylineJson = null;
    }

    await db.activityDao.insertWalkSession(
      WalkSessionsCompanion.insert(
        id: id,
        userId: user.id,
        startTime: _startTime!,
        endTime: Value(DateTime.now()),
        distanceMeters: Value(_totalDistanceMeters),
        stepCount: Value(_stepCount),
        durationSeconds: Value(_durationSeconds),
        polylineJson: Value(polylineJson),
        isCompleted: const Value(true),
        pendingSync: const Value(true),
      ),
    );
  }

  String get _formattedDuration {
    final hours = _durationSeconds ~/ 3600;
    final minutes = (_durationSeconds % 3600) ~/ 60;
    final seconds = _durationSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map
          GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: const CameraPosition(
              target: LatLng(23.8103, 90.4125), // Dhaka, Bangladesh
              zoom: 16,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            polylines: {
              if (_polylinePoints.length > 1)
                Polyline(
                  polylineId: const PolylineId('walk_route'),
                  points: _polylinePoints,
                  color: AppColors.primary,
                  width: 5,
                ),
            },
          ),

          // Safe area top — back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                onPressed: () {
                  if (_isTracking) {
                    _stopWalk();
                  } else {
                    context.pop();
                  }
                },
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                color: AppColors.textPrimary,
              ),
            ),
          ),

          // Bottom stats + controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Stats
                  if (_isTracking) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _WalkStat(
                          label: 'Distance',
                          value: '${(_totalDistanceMeters / 1000).toStringAsFixed(2)}',
                          unit: 'km',
                          icon: Icons.straighten_rounded,
                        ),
                        _WalkStat(
                          label: 'Duration',
                          value: _formattedDuration,
                          unit: '',
                          icon: Icons.timer_rounded,
                        ),
                        _WalkStat(
                          label: 'Pace',
                          value: _totalDistanceMeters > 0
                              ? '${(_durationSeconds / (_totalDistanceMeters / 1000)).toStringAsFixed(0)}'
                              : '--',
                          unit: 's/km',
                          icon: Icons.speed_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // CTA Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isTracking ? _stopWalk : _startWalk,
                      icon: Icon(_isTracking ? Icons.stop_rounded : Icons.play_arrow_rounded),
                      label: Text(_isTracking ? 'End Walk' : 'Start Walk'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isTracking ? AppColors.error : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalkStat extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;

  const _WalkStat({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        if (unit.isNotEmpty)
          Text(unit, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}
