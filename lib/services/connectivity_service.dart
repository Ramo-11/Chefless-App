import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides a live stream of online/offline status.
///
/// Emits `true` when the device has an active network connection (wifi,
/// mobile, ethernet, or vpn) and `false` otherwise.
final connectivityProvider = StreamProvider<bool>((ref) {
  final controller = StreamController<bool>();
  final connectivity = Connectivity();

  // Emit the current state immediately.
  connectivity.checkConnectivity().then((results) {
    controller.add(_isConnected(results));
  });

  final subscription = connectivity.onConnectivityChanged.listen((results) {
    controller.add(_isConnected(results));
  });

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Convenience provider that returns the current online state as a plain bool.
///
/// Defaults to `true` while the connectivity state is still loading,
/// so the app optimistically tries network requests.
final isOnlineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.when(
    data: (isOnline) => isOnline,
    loading: () => true,
    error: (_, _) => true,
  );
});

bool _isConnected(List<ConnectivityResult> results) {
  if (results.contains(ConnectivityResult.none)) return false;
  if (results.isEmpty) return false;
  return true;
}
