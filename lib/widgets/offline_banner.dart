import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
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

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing8,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.warningLight,
        border: Border(
          bottom: BorderSide(color: AppTheme.warning, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 18,
            color: AppTheme.gray700,
          ),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Text(
              'You\'re offline. Some features may be limited.',
              style: TextStyle(
                color: AppTheme.gray700,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
