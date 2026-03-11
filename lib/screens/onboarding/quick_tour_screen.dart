import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/extensions.dart';

/// Tour card data for each swipeable page.
class _TourCard {
  const _TourCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
}

const List<_TourCard> _tourCards = [
  _TourCard(
    icon: Icons.menu_book_rounded,
    title: 'Recipe Book',
    description: 'Organize all your recipes in one place.',
    color: AppTheme.primaryColor,
  ),
  _TourCard(
    icon: Icons.people_rounded,
    title: 'Kitchen',
    description: 'Share meals with family and roommates.',
    color: AppTheme.secondaryColor,
  ),
  _TourCard(
    icon: Icons.calendar_month_rounded,
    title: 'Schedule',
    description: 'Plan your week\'s meals together.',
    color: AppTheme.tertiaryColor,
  ),
  _TourCard(
    icon: Icons.explore_rounded,
    title: 'Explore',
    description: 'Discover recipes from the community.',
    color: AppTheme.neutralColor,
  ),
];

/// Final onboarding step: swipeable feature tour with dot indicators.
class QuickTourScreen extends ConsumerStatefulWidget {
  const QuickTourScreen({super.key});

  @override
  ConsumerState<QuickTourScreen> createState() => _QuickTourScreenState();
}

class _QuickTourScreenState extends ConsumerState<QuickTourScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isCompleting = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);

    try {
      final apiService = await ref.read(apiServiceProvider.future);
      final result = await apiService.put(
        '/users/me',
        data: {'onboardingComplete': true},
      );

      if (!mounted) return;

      if (result.isFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Failed to complete onboarding.'),
          ),
        );
        setState(() => _isCompleting = false);
        return;
      }

      ref.invalidate(currentUserProvider);
      context.go('/home');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An unexpected error occurred.')),
      );
      setState(() => _isCompleting = false);
    }
  }

  bool get _isLastPage => _currentPage == _tourCards.length - 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button row
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: AppTheme.spacingSm,
                  right: AppTheme.spacingMd,
                ),
                child: TextButton(
                  onPressed: _isCompleting ? null : _completeOnboarding,
                  child: const Text('Skip'),
                ),
              ),
            ),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _tourCards.length,
                onPageChanged: (index) {
                  if (mounted) setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final card = _tourCards[index];
                  return _TourPage(card: card);
                },
              ),
            ),

            // Dot indicators
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppTheme.spacingMd,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_tourCards.length, (index) {
                  final isActive = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? context.colorScheme.primary
                          : context.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // Action button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingXl,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isCompleting
                      ? null
                      : _isLastPage
                          ? _completeOnboarding
                          : () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.spacingMd,
                    ),
                  ),
                  child: _isCompleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isLastPage ? 'Get Started' : 'Next'),
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacingXl),
          ],
        ),
      ),
    );
  }
}

class _TourPage extends StatelessWidget {
  const _TourPage({required this.card});

  final _TourCard card;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: card.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              card.icon,
              size: 56,
              color: card.color,
            ),
          ),
          const SizedBox(height: AppTheme.spacingXl),
          Text(
            card.title,
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            card.description,
            style: context.textTheme.bodyLarge?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
