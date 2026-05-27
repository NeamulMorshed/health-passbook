import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks whether the user has accepted the first-launch medical disclaimer.
/// Initialized in main.dart from SharedPreferences before runApp so the
/// router redirect can read it synchronously.
final disclaimerAcceptedProvider = StateProvider<bool>((ref) => false);
