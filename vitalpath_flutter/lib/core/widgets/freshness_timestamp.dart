import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FreshnessTimestamp extends StatefulWidget {
  final DateTime lastUpdated;
  const FreshnessTimestamp({super.key, required this.lastUpdated});

  @override
  State<FreshnessTimestamp> createState() => _FreshnessTimestampState();
}

class _FreshnessTimestampState extends State<FreshnessTimestamp> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _label() {
    final diff = DateTime.now().difference(widget.lastUpdated);
    if (diff.inSeconds < 30) return 'Last updated just now';
    if (diff.inMinutes < 60) return 'Last updated ${diff.inMinutes} min ago';
    if (diff.inHours < 24) return 'Last updated ${diff.inHours}h ago';
    return 'Last updated ${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _label(),
      style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
    );
  }
}
