import 'package:flutter/material.dart';

/// Warm branded fallback when a recipe has no uploaded photo.
class RecipeImagePlaceholder extends StatelessWidget {
  const RecipeImagePlaceholder({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 22.0 : 40.0;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF5E7D6),
            Color(0xFFE4C9AA),
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
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x38FFFFFF),
              ),
            ),
          ),
          Positioned(
            bottom: compact ? -14 : -26,
            left: compact ? -12 : -18,
            child: Container(
              width: compact ? 42 : 92,
              height: compact ? 42 : 92,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x24FFFFFF),
              ),
            ),
          ),
          Center(
            child: Icon(
              Icons.ramen_dining_rounded,
              size: iconSize,
              color: const Color(0xFF8A5A2B),
            ),
          ),
        ],
      ),
    );
  }
}
