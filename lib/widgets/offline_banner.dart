import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/connectivity_service.dart';

/// A banner displayed at the top of screens when the device is offline.
///
/// Listens to [connectivityProvider] and animates in/out. The user can
/// dismiss it, but it reappears on the next build cycle if still offline.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);

    if (isOnline) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return MaterialBanner(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      content: Text(
        'You\'re offline. Some features may be limited.',
        style: TextStyle(
          color: colorScheme.onErrorContainer,
          fontSize: 14,
        ),
      ),
      leading: Icon(
        Icons.cloud_off,
        color: colorScheme.onErrorContainer,
      ),
      backgroundColor: colorScheme.errorContainer,
      actions: const [SizedBox.shrink()],
    );
  }
}
