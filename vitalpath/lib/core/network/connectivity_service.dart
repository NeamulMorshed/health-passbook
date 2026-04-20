import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_service.g.dart';

/// Monitors network connectivity for the offline-first sync engine.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  Stream<bool> get connectivityStream => _connectivity.onConnectivityChanged
      .map((results) => results.any((r) => r != ConnectivityResult.none));

  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }
}

@riverpod
ConnectivityService connectivityService(Ref ref) => ConnectivityService();

/// Reactive connectivity stream provider — rebuilds when network changes
@riverpod
Stream<bool> connectivity(Ref ref) {
  return ref.watch(connectivityServiceProvider).connectivityStream;
}
