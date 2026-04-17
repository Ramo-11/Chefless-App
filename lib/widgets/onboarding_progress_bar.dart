import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Segmented step progress indicator shared across the four preference
/// onboarding screens (profile → dietary → cuisine → premium).
///
/// Renders [total] rounded segments; segments below [current] are filled with
/// the accent, the current one animates a fill from left→right, and the rest
/// sit in a soft neutral. Sits directly under the AppBar to give the user a
/// calm sense of where they are without shouting.
class OnboardingProgressBar extends StatelessWidget {
  const OnboardingProgressBar({
    super.key,
    required this.current,
    this.total = 4,
    this.accent = AppTheme.primaryColor,
  });

  final int current;
  final int total;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    assert(current >= 1 && current <= total);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing32,
        AppTheme.spacing4,
        AppTheme.spacing32,
        AppTheme.spacing16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (int i = 1; i <= total; i++) ...[
                Expanded(
                  child: _Segment(
                    isActive: i == current,
                    isComplete: i < current,
                    accent: accent,
                  ),
                ),
                if (i != total) const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: AppTheme.spacing10),
          Text(
            'Step $current of $total',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.gray500,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.isActive,
    required this.isComplete,
    required this.accent,
  });

  final bool isActive;
  final bool isComplete;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final filled = isActive || isComplete;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      height: 4,
      decoration: BoxDecoration(
        color: filled ? accent : AppTheme.gray200,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
    );
  }
}
