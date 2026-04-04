import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// A small premium badge displayed next to premium users' names.
///
/// Uses the primary blue palette for a subtle, cohesive look.
class PremiumBadge extends StatelessWidget {
  const PremiumBadge({
    super.key,
    this.size = 16,
  });

  /// The icon size. Defaults to 16.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Premium member',
      child: Icon(
        Icons.workspace_premium,
        size: size,
        color: AppTheme.primaryColor,
      ),
    );
  }
}
