import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../utils/extensions.dart';

/// Warm branded fallback when a recipe has no uploaded photo.
class RecipeImagePlaceholder extends StatelessWidget {
  const RecipeImagePlaceholder({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 22.0 : 42.0;
    final labelStyle = context.textTheme.labelMedium?.copyWith(
      color: Colors.white.withValues(alpha: 0.92),
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.accentPlayful.withValues(alpha: 0.95),
            const Color(0xFF7F5A46),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: compact ? -10 : -18,
            right: compact ? -10 : -18,
            child: Container(
              width: compact ? 30 : 76,
              height: compact ? 30 : 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: compact ? -14 : -26,
            left: compact ? -12 : -18,
            child: Container(
              width: compact ? 42 : 92,
              height: compact ? 42 : 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.08),
              ),
            ),
          ),
          Center(
            child: compact
                ? Icon(
                    Icons.soup_kitchen_rounded,
                    size: iconSize,
                    color: Colors.white.withValues(alpha: 0.95),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.soup_kitchen_rounded,
                        size: iconSize,
                        color: Colors.white.withValues(alpha: 0.96),
                      ),
                      const SizedBox(height: AppTheme.spacing8),
                      Text('Awaiting photo', style: labelStyle),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
