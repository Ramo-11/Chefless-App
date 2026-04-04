import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../utils/extensions.dart';

/// A serving count adjuster with +/- buttons and an "Original: X" label
/// when the serving count has been changed from the base.
class IngredientScaling extends StatelessWidget {
  const IngredientScaling({
    super.key,
    required this.currentServings,
    required this.baseServings,
    required this.onChanged,
  });

  final int currentServings;
  final int baseServings;
  final ValueChanged<int> onChanged;

  bool get _isAdjusted => currentServings != baseServings;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AdjustButton(
              icon: Icons.remove,
              onPressed:
                  currentServings > 1 ? () => onChanged(currentServings - 1) : null,
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppTheme.spacing20),
              child: Text(
                '$currentServings',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.gray900,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            _AdjustButton(
              icon: Icons.add,
              onPressed: () => onChanged(currentServings + 1),
            ),
          ],
        ),
        if (_isAdjusted) ...[
          const SizedBox(height: AppTheme.spacing6),
          Text(
            'Original: $baseServings',
            style: context.textTheme.bodySmall?.copyWith(
              color: AppTheme.gray400,
            ),
          ),
        ],
      ],
    );
  }
}

class _AdjustButton extends StatelessWidget {
  const _AdjustButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: AppTheme.borderRadiusSmall,
          border: Border.all(
            color: isDisabled ? AppTheme.gray200 : AppTheme.gray300,
          ),
          color: isDisabled ? AppTheme.gray50 : Colors.white,
        ),
        child: Icon(
          icon,
          size: 18,
          color: isDisabled ? AppTheme.gray300 : AppTheme.gray700,
        ),
      ),
    );
  }
}
