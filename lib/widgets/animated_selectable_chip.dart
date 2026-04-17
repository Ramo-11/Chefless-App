import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';

/// Pill chip with a tactile scale-pop and haptic on selection.
///
/// Drop-in replacement for Material `FilterChip` in onboarding screens where
/// the flat flip felt static. Selected state swaps to [selectedFill] with a
/// 1.5px [selectedBorder]; a brief 1.0 → 1.06 → 1.0 pop fires on every tap.
class AnimatedSelectableChip extends StatefulWidget {
  const AnimatedSelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
    this.selectedFill = AppTheme.primaryLight,
    this.selectedBorder = AppTheme.primaryColor,
    this.selectedLabelColor = AppTheme.primaryDark,
    this.showCheckWhenSelected = true,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;
  final Color selectedFill;
  final Color selectedBorder;
  final Color selectedLabelColor;

  /// When `true` (default), a check icon replaces the leading slot once
  /// selected — good for text-only option lists. Pass `false` when the
  /// leading is itself the identity (e.g. a flag emoji) that should stay
  /// visible even after selection.
  final bool showCheckWhenSelected;

  @override
  State<AnimatedSelectableChip> createState() => _AnimatedSelectableChipState();
}

class _AnimatedSelectableChipState extends State<AnimatedSelectableChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.06)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.06, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 55,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.selectionClick();
    _controller.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final borderColor = selected ? widget.selectedBorder : AppTheme.gray200;

    return ScaleTransition(
      scale: _scale,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleTap,
          borderRadius: AppTheme.borderRadiusFull,
          splashColor: widget.selectedBorder.withValues(alpha: 0.10),
          highlightColor: widget.selectedBorder.withValues(alpha: 0.05),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: selected ? widget.selectedFill : AppTheme.surfaceElevated,
              borderRadius: AppTheme.borderRadiusFull,
              border: Border.all(
                color: borderColor,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected && widget.showCheckWhenSelected) ...[
                  Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: widget.selectedBorder,
                  ),
                  const SizedBox(width: 6),
                ] else if (widget.leading != null) ...[
                  widget.leading!,
                  const SizedBox(width: 6),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color:
                        selected ? widget.selectedLabelColor : AppTheme.gray700,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
