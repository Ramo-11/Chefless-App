import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// A single animated shimmer rectangle used as a loading placeholder.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    required this.baseColor,
    required this.highlightColor,
    required this.gradientValue,
    this.height,
    this.width,
    this.borderRadius,
  });

  final Color baseColor;
  final Color highlightColor;
  final double gradientValue;
  final double? height;
  final double? width;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [baseColor, highlightColor, baseColor],
          stops: [
            (gradientValue - 0.3).clamp(0.0, 1.0),
            gradientValue.clamp(0.0, 1.0),
            (gradientValue + 0.3).clamp(0.0, 1.0),
          ],
        ),
      ),
    );
  }
}

/// Provides a shimmer animation value to its children via [builder].
///
/// Runs a repeating 1500ms animation that drives the gradient sweep.
class ShimmerAnimator extends StatefulWidget {
  const ShimmerAnimator({
    super.key,
    required this.builder,
  });

  final Widget Function(BuildContext context, double gradientValue) builder;

  @override
  State<ShimmerAnimator> createState() => _ShimmerAnimatorState();
}

class _ShimmerAnimatorState extends State<ShimmerAnimator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) => widget.builder(context, _animation.value),
    );
  }
}

/// Shimmer placeholder that matches the [RecipeCard] layout.
class RecipeCardShimmer extends StatelessWidget {
  const RecipeCardShimmer({
    super.key,
    required this.gradientValue,
  });

  final double gradientValue;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = colorScheme.surfaceContainerHighest;
    final highlightColor = colorScheme.surfaceContainerLowest;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo placeholder
          AspectRatio(
            aspectRatio: 16 / 10,
            child: ShimmerBox(
              baseColor: baseColor,
              highlightColor: highlightColor,
              gradientValue: gradientValue,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                ShimmerBox(
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  gradientValue: gradientValue,
                  height: 16,
                  width: 200,
                  borderRadius: AppTheme.borderRadiusSmall,
                ),
                const SizedBox(height: AppTheme.spacingSm),
                // Author
                ShimmerBox(
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  gradientValue: gradientValue,
                  height: 12,
                  width: 120,
                  borderRadius: AppTheme.borderRadiusSmall,
                ),
                const SizedBox(height: AppTheme.spacingMd),
                // Tags
                Row(
                  children: [
                    ShimmerBox(
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      gradientValue: gradientValue,
                      height: 20,
                      width: 60,
                      borderRadius: AppTheme.borderRadiusSmall,
                    ),
                    const SizedBox(width: AppTheme.spacingSm),
                    ShimmerBox(
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      gradientValue: gradientValue,
                      height: 20,
                      width: 80,
                      borderRadius: AppTheme.borderRadiusSmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A list of shimmer recipe cards, ready to drop into a loading state.
class RecipeCardShimmerList extends StatelessWidget {
  const RecipeCardShimmerList({
    super.key,
    this.itemCount = 5,
  });

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ShimmerAnimator(
      builder: (context, gradientValue) {
        return ListView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMd,
            vertical: AppTheme.spacingSm,
          ),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
              child: RecipeCardShimmer(gradientValue: gradientValue),
            );
          },
        );
      },
    );
  }
}

/// Shimmer placeholder for user list items (e.g. followers, search results).
class UserListShimmer extends StatelessWidget {
  const UserListShimmer({
    super.key,
    this.itemCount = 8,
  });

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ShimmerAnimator(
      builder: (context, gradientValue) {
        final colorScheme = Theme.of(context).colorScheme;
        final baseColor = colorScheme.surfaceContainerHighest;
        final highlightColor = colorScheme.surfaceContainerLowest;

        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMd,
                vertical: AppTheme.spacingSm,
              ),
              child: Row(
                children: [
                  // Avatar circle
                  ShimmerBox(
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    gradientValue: gradientValue,
                    height: 44,
                    width: 44,
                    borderRadius: const BorderRadius.all(Radius.circular(22)),
                  ),
                  const SizedBox(width: AppTheme.spacingSm + 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(
                          baseColor: baseColor,
                          highlightColor: highlightColor,
                          gradientValue: gradientValue,
                          height: 14,
                          width: 140,
                          borderRadius: AppTheme.borderRadiusSmall,
                        ),
                        const SizedBox(height: AppTheme.spacingXs),
                        ShimmerBox(
                          baseColor: baseColor,
                          highlightColor: highlightColor,
                          gradientValue: gradientValue,
                          height: 10,
                          width: 100,
                          borderRadius: AppTheme.borderRadiusSmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Shimmer placeholder for the profile screen layout.
class ProfileShimmer extends StatelessWidget {
  const ProfileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerAnimator(
      builder: (context, gradientValue) {
        final colorScheme = Theme.of(context).colorScheme;
        final baseColor = colorScheme.surfaceContainerHighest;
        final highlightColor = colorScheme.surfaceContainerLowest;

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingLg,
            vertical: AppTheme.spacingMd,
          ),
          child: Column(
            children: [
              // Avatar
              ShimmerBox(
                baseColor: baseColor,
                highlightColor: highlightColor,
                gradientValue: gradientValue,
                height: 96,
                width: 96,
                borderRadius: const BorderRadius.all(Radius.circular(48)),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              // Name
              ShimmerBox(
                baseColor: baseColor,
                highlightColor: highlightColor,
                gradientValue: gradientValue,
                height: 20,
                width: 160,
                borderRadius: AppTheme.borderRadiusSmall,
              ),
              const SizedBox(height: AppTheme.spacingSm),
              // Bio
              ShimmerBox(
                baseColor: baseColor,
                highlightColor: highlightColor,
                gradientValue: gradientValue,
                height: 14,
                width: 220,
                borderRadius: AppTheme.borderRadiusSmall,
              ),
              const SizedBox(height: AppTheme.spacingLg),
              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(3, (_) {
                  return Column(
                    children: [
                      ShimmerBox(
                        baseColor: baseColor,
                        highlightColor: highlightColor,
                        gradientValue: gradientValue,
                        height: 18,
                        width: 40,
                        borderRadius: AppTheme.borderRadiusSmall,
                      ),
                      const SizedBox(height: AppTheme.spacingXs),
                      ShimmerBox(
                        baseColor: baseColor,
                        highlightColor: highlightColor,
                        gradientValue: gradientValue,
                        height: 12,
                        width: 60,
                        borderRadius: AppTheme.borderRadiusSmall,
                      ),
                    ],
                  );
                }),
              ),
              const SizedBox(height: AppTheme.spacingLg),
              // Button placeholder
              ShimmerBox(
                baseColor: baseColor,
                highlightColor: highlightColor,
                gradientValue: gradientValue,
                height: 44,
                borderRadius: AppTheme.borderRadiusSmall,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Shimmer for notification list items.
class NotificationListShimmer extends StatelessWidget {
  const NotificationListShimmer({
    super.key,
    this.itemCount = 10,
  });

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ShimmerAnimator(
      builder: (context, gradientValue) {
        final colorScheme = Theme.of(context).colorScheme;
        final baseColor = colorScheme.surfaceContainerHighest;
        final highlightColor = colorScheme.surfaceContainerLowest;

        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMd,
                vertical: AppTheme.spacingSm + 4,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar circle
                  ShimmerBox(
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    gradientValue: gradientValue,
                    height: 44,
                    width: 44,
                    borderRadius: const BorderRadius.all(Radius.circular(22)),
                  ),
                  const SizedBox(width: AppTheme.spacingSm + 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(
                          baseColor: baseColor,
                          highlightColor: highlightColor,
                          gradientValue: gradientValue,
                          height: 14,
                          width: double.infinity,
                          borderRadius: AppTheme.borderRadiusSmall,
                        ),
                        const SizedBox(height: AppTheme.spacingXs),
                        ShimmerBox(
                          baseColor: baseColor,
                          highlightColor: highlightColor,
                          gradientValue: gradientValue,
                          height: 14,
                          width: 180,
                          borderRadius: AppTheme.borderRadiusSmall,
                        ),
                        const SizedBox(height: AppTheme.spacingSm),
                        ShimmerBox(
                          baseColor: baseColor,
                          highlightColor: highlightColor,
                          gradientValue: gradientValue,
                          height: 10,
                          width: 60,
                          borderRadius: AppTheme.borderRadiusSmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
