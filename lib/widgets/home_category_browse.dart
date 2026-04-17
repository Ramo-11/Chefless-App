import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../providers/search_provider.dart';
import '../utils/extensions.dart';

/// Browseable category cards on the home screen.
///
/// Horizontal scroll of warm-toned category cards. Tapping a category
/// navigates to the search screen with the category name pre-filled.
class HomeCategoryBrowse extends StatelessWidget {
  const HomeCategoryBrowse({super.key});

  static const _categories = [
    _Category(
      label: 'Quick Meals',
      icon: Icons.bolt_rounded,
      bgColor: Color(0xFFF9DDD1),
      fgColor: Color(0xFFB8442A),
    ),
    _Category(
      label: 'Vegetarian',
      icon: Icons.eco_rounded,
      bgColor: Color(0xFFD5EFD9),
      fgColor: Color(0xFF2E7D3C),
    ),
    _Category(
      label: 'Italian',
      icon: Icons.local_pizza_rounded,
      bgColor: Color(0xFFDAE0FC),
      fgColor: Color(0xFF3A53CC),
    ),
    _Category(
      label: 'Asian',
      icon: Icons.ramen_dining_rounded,
      bgColor: Color(0xFFF2DCC8),
      fgColor: Color(0xFF9A5E30),
    ),
    _Category(
      label: 'Desserts',
      icon: Icons.cake_rounded,
      bgColor: Color(0xFFE4D5F0),
      fgColor: Color(0xFF6B4899),
    ),
    _Category(
      label: 'Healthy',
      icon: Icons.favorite_rounded,
      bgColor: Color(0xFFFBD6D0),
      fgColor: Color(0xFFD13B2E),
    ),
    _Category(
      label: 'Breakfast',
      icon: Icons.free_breakfast_rounded,
      bgColor: Color(0xFFF5DFC2),
      fgColor: Color(0xFFB06B28),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            AppTheme.spacing20,
            AppTheme.spacing16,
            AppTheme.spacing12,
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: AppTheme.accentPlayful,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              Text(
                'Browse by craving',
                style: AppTheme.displayTitleSmall().copyWith(
                  fontSize: 19,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(
              left: AppTheme.spacing16,
              right: AppTheme.spacing8,
            ),
            itemCount: _categories.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: AppTheme.spacing10),
            itemBuilder: (context, index) {
              return _CategoryCard(category: _categories[index]);
            },
          ),
        ),
        const SizedBox(height: AppTheme.spacing4),
      ],
    );
  }
}

class _Category {
  const _Category({
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.fgColor,
  });

  final String label;
  final IconData icon;
  final Color bgColor;
  final Color fgColor;
}

class _CategoryCard extends ConsumerWidget {
  const _CategoryCard({required this.category});

  final _Category category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: category.bgColor,
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(searchQueryProvider.notifier).state = category.label;
          context.push('/search');
        },
        splashColor: category.fgColor.withValues(alpha: 0.15),
        highlightColor: category.fgColor.withValues(alpha: 0.08),
        child: SizedBox(
          width: 104,
          height: 108,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    category.icon,
                    size: 22,
                    color: category.fgColor,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing8),
                Text(
                  category.label,
                  style: context.textTheme.labelMedium?.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: category.fgColor,
                    letterSpacing: -0.1,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
