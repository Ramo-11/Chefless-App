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
    const baseColor = AppTheme.gray100;
    const highlightColor = AppTheme.gray50;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.borderRadiusMedium,
        border: Border.all(color: AppTheme.gray200),
      ),
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
            padding: const EdgeInsets.all(AppTheme.spacing12),
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
                      borderRadius: AppTheme.borderRadiusFull,
                    ),
                    const SizedBox(width: AppTheme.spacingSm),
                    ShimmerBox(
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      gradientValue: gradientValue,
                      height: 20,
                      width: 80,
                      borderRadius: AppTheme.borderRadiusFull,
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

/// Shimmer matching [RecipeCompactRow] (thumbnail + text column).
class RecipeCompactRowShimmer extends StatelessWidget {
  const RecipeCompactRowShimmer({
    super.key,
    required this.gradientValue,
  });

  final double gradientValue;

  @override
  Widget build(BuildContext context) {
    const baseColor = AppTheme.gray100;
    const highlightColor = Color(0xFFF0EDE8);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(
            baseColor: baseColor,
            highlightColor: highlightColor,
            gradientValue: gradientValue,
            height: 68,
            width: 68,
            borderRadius: AppTheme.borderRadiusMedium,
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  gradientValue: gradientValue,
                  height: 16,
                  width: double.infinity,
                  borderRadius: AppTheme.borderRadiusSmall,
                ),
                const SizedBox(height: AppTheme.spacing6),
                ShimmerBox(
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  gradientValue: gradientValue,
                  height: 12,
                  width: 120,
                  borderRadius: AppTheme.borderRadiusSmall,
                ),
                const SizedBox(height: AppTheme.spacing8),
                Row(
                  children: [
                    ShimmerBox(
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      gradientValue: gradientValue,
                      height: 14,
                      width: 48,
                      borderRadius: AppTheme.borderRadiusSmall,
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    ShimmerBox(
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      gradientValue: gradientValue,
                      height: 18,
                      width: 52,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          ShimmerBox(
            baseColor: baseColor,
            highlightColor: highlightColor,
            gradientValue: gradientValue,
            height: 28,
            width: 40,
            borderRadius: AppTheme.borderRadiusSmall,
          ),
        ],
      ),
    );
  }
}

/// Shimmer matching [RecipeFeaturedHero] (rounded hero frame).
class RecipeFeaturedHeroShimmer extends StatelessWidget {
  const RecipeFeaturedHeroShimmer({
    super.key,
    required this.gradientValue,
  });

  final double gradientValue;

  @override
  Widget build(BuildContext context) {
    const baseColor = AppTheme.gray100;
    const highlightColor = Color(0xFFF0EDE8);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing4,
        AppTheme.spacing16,
        AppTheme.spacing20,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppTheme.borderRadiusXL,
          boxShadow: AppTheme.shadowHero,
        ),
        child: ClipRRect(
          borderRadius: AppTheme.borderRadiusXL,
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: ShimmerBox(
              baseColor: baseColor,
              highlightColor: highlightColor,
              gradientValue: gradientValue,
            ),
          ),
        ),
      ),
    );
  }
}

/// Home feed loading: one hero + full-width feed cards that mirror real layout.
class ExploreFeedShimmerList extends StatelessWidget {
  const ExploreFeedShimmerList({
    super.key,
    this.cardCount = 3,
  });

  final int cardCount;

  @override
  Widget build(BuildContext context) {
    return ShimmerAnimator(
      builder: (context, gradientValue) {
        return ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: AppTheme.spacing16),
          children: [
            RecipeFeaturedHeroShimmer(gradientValue: gradientValue),
            const SizedBox(height: AppTheme.spacing24),
            _ShimmerSectionHeader(gradientValue: gradientValue),
            const SizedBox(height: AppTheme.spacing8),
            ...List.generate(
              cardCount,
              (i) => RecipeFeedCardShimmer(gradientValue: gradientValue),
            ),
          ],
        );
      },
    );
  }
}

class _ShimmerSectionHeader extends StatelessWidget {
  const _ShimmerSectionHeader({required this.gradientValue});

  final double gradientValue;

  @override
  Widget build(BuildContext context) {
    const baseColor = AppTheme.gray100;
    const highlightColor = Color(0xFFF0EDE8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing8,
        AppTheme.spacing16,
        AppTheme.spacing12,
      ),
      child: Row(
        children: [
          ShimmerBox(
            baseColor: baseColor,
            highlightColor: highlightColor,
            gradientValue: gradientValue,
            width: 4,
            height: 18,
            borderRadius: BorderRadius.circular(2),
          ),
          const SizedBox(width: AppTheme.spacing8),
          ShimmerBox(
            baseColor: baseColor,
            highlightColor: highlightColor,
            gradientValue: gradientValue,
            height: 16,
            width: 180,
            borderRadius: AppTheme.borderRadiusSmall,
          ),
        ],
      ),
    );
  }
}

/// Shimmer matching [RecipeFeedCard] — image, title, author, metadata row.
class RecipeFeedCardShimmer extends StatelessWidget {
  const RecipeFeedCardShimmer({
    super.key,
    required this.gradientValue,
  });

  final double gradientValue;

  @override
  Widget build(BuildContext context) {
    const baseColor = AppTheme.gray100;
    const highlightColor = Color(0xFFF0EDE8);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        0,
        AppTheme.spacing16,
        AppTheme.spacing16,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: AppTheme.surfaceElevated,
          boxShadow: AppTheme.shadowCard,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 11,
                child: ShimmerBox(
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  gradientValue: gradientValue,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      gradientValue: gradientValue,
                      height: 18,
                      width: 240,
                      borderRadius: AppTheme.borderRadiusSmall,
                    ),
                    const SizedBox(height: AppTheme.spacing6),
                    ShimmerBox(
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      gradientValue: gradientValue,
                      height: 12,
                      width: 120,
                      borderRadius: AppTheme.borderRadiusSmall,
                    ),
                    const SizedBox(height: AppTheme.spacing12),
                    Row(
                      children: [
                        ShimmerBox(
                          baseColor: baseColor,
                          highlightColor: highlightColor,
                          gradientValue: gradientValue,
                          height: 14,
                          width: 46,
                          borderRadius: AppTheme.borderRadiusSmall,
                        ),
                        const SizedBox(width: AppTheme.spacing12),
                        ShimmerBox(
                          baseColor: baseColor,
                          highlightColor: highlightColor,
                          gradientValue: gradientValue,
                          height: 14,
                          width: 52,
                          borderRadius: AppTheme.borderRadiusSmall,
                        ),
                        const Spacer(),
                        ShimmerBox(
                          baseColor: baseColor,
                          highlightColor: highlightColor,
                          gradientValue: gradientValue,
                          height: 26,
                          width: 78,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusFull,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
        const baseColor = AppTheme.gray100;
        const highlightColor = AppTheme.gray50;

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
        const baseColor = AppTheme.gray100;
        const highlightColor = Color(0xFFF0EDE8);

        return ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            AppTheme.spacing12,
            AppTheme.spacing16,
            AppTheme.spacing24,
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppTheme.borderRadiusXL,
              ),
              child: Column(
                children: [
                  ShimmerBox(
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    gradientValue: gradientValue,
                    height: 88,
                    width: 88,
                    borderRadius: const BorderRadius.all(Radius.circular(44)),
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  ShimmerBox(
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    gradientValue: gradientValue,
                    height: 22,
                    width: 180,
                    borderRadius: AppTheme.borderRadiusSmall,
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  ShimmerBox(
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    gradientValue: gradientValue,
                    height: 14,
                    width: 120,
                    borderRadius: AppTheme.borderRadiusSmall,
                  ),
                  const SizedBox(height: AppTheme.spacing12),
                  ShimmerBox(
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    gradientValue: gradientValue,
                    height: 14,
                    width: double.infinity,
                    borderRadius: AppTheme.borderRadiusSmall,
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  ShimmerBox(
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    gradientValue: gradientValue,
                    height: 14,
                    width: 220,
                    borderRadius: AppTheme.borderRadiusSmall,
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  Wrap(
                    spacing: AppTheme.spacing8,
                    runSpacing: AppTheme.spacing8,
                    alignment: WrapAlignment.center,
                    children: List.generate(
                      3,
                      (_) => ShimmerBox(
                        baseColor: baseColor,
                        highlightColor: highlightColor,
                        gradientValue: gradientValue,
                        height: 30,
                        width: 94,
                        borderRadius: AppTheme.borderRadiusFull,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  Row(
                    children: List.generate(3, (index) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: index == 0 ? 0 : AppTheme.spacing4,
                            right: index == 2 ? 0 : AppTheme.spacing4,
                          ),
                          child: ShimmerBox(
                            baseColor: baseColor,
                            highlightColor: highlightColor,
                            gradientValue: gradientValue,
                            height: 64,
                            borderRadius: AppTheme.borderRadiusMedium,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  Row(
                    children: [
                      Expanded(
                        child: ShimmerBox(
                          baseColor: baseColor,
                          highlightColor: highlightColor,
                          gradientValue: gradientValue,
                          height: 44,
                          borderRadius: AppTheme.borderRadiusMedium,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacing12),
                      Expanded(
                        child: ShimmerBox(
                          baseColor: baseColor,
                          highlightColor: highlightColor,
                          gradientValue: gradientValue,
                          height: 44,
                          borderRadius: AppTheme.borderRadiusMedium,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacing20),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppTheme.borderRadiusXL,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    gradientValue: gradientValue,
                    height: 18,
                    width: 150,
                    borderRadius: AppTheme.borderRadiusSmall,
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  ShimmerBox(
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    gradientValue: gradientValue,
                    height: 14,
                    width: 240,
                    borderRadius: AppTheme.borderRadiusSmall,
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  ShimmerBox(
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    gradientValue: gradientValue,
                    height: 38,
                    borderRadius: AppTheme.borderRadiusFull,
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  RecipeCompactRowShimmer(gradientValue: gradientValue),
                  RecipeCompactRowShimmer(gradientValue: gradientValue),
                  RecipeCompactRowShimmer(gradientValue: gradientValue),
                ],
              ),
            ),
          ],
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
        const baseColor = AppTheme.gray100;
        const highlightColor = AppTheme.gray50;

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
