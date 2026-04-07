import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/extensions.dart';
import '../../widgets/onboarding_illustration.dart';

/// Tour card data for each swipeable page.
class _TourCard {
  const _TourCard({
    required this.centerIcon,
    required this.color,
    required this.title,
    required this.description,
    required this.satellites,
    this.backdropColors,
  });

  final IconData centerIcon;
  final Color color;
  final String title;
  final String description;
  final List<Satellite> satellites;
  final List<Color>? backdropColors;
}

const List<_TourCard> _tourCards = [
  _TourCard(
    centerIcon: Icons.explore_rounded,
    color: AppTheme.primaryColor,
    title: 'Home',
    description:
        'Discover recipes across For You, Trending, Friends, and Seasonal feeds.',
    backdropColors: [AppTheme.primaryColor, AppTheme.tertiaryColor],
    satellites: [
      Satellite(
        icon: Icons.search_rounded,
        color: AppTheme.primaryColor,
        angle: -pi / 3,
        distance: 82,
        bobPhase: 0,
        containerSize: 36,
        iconSize: 18,
        bobAmplitude: 6,
      ),
      Satellite(
        icon: Icons.trending_up_rounded,
        color: AppTheme.secondaryColor,
        angle: pi / 4,
        distance: 78,
        bobPhase: 0.35,
        containerSize: 34,
        iconSize: 18,
        bobAmplitude: 7,
      ),
      Satellite(
        icon: Icons.favorite_rounded,
        color: AppTheme.neutralColor,
        angle: 3 * pi / 4,
        distance: 76,
        bobPhase: 0.7,
        containerSize: 32,
        iconSize: 16,
        bobAmplitude: 5,
      ),
    ],
  ),
  _TourCard(
    centerIcon: Icons.people_rounded,
    color: AppTheme.secondaryColor,
    title: 'Kitchen',
    description:
        'Kitchen now has its own bottom tab so members, invites, and shared recipes are always easy to reach.',
    backdropColors: [AppTheme.secondaryColor, AppTheme.primaryColor],
    satellites: [
      Satellite(
        icon: Icons.restaurant_rounded,
        color: AppTheme.primaryColor,
        angle: -pi / 4,
        distance: 80,
        bobPhase: 0.1,
        containerSize: 36,
        iconSize: 18,
        bobAmplitude: 6,
      ),
      Satellite(
        icon: Icons.home_rounded,
        color: Color(0xFF8D6E63),
        angle: 2 * pi / 3,
        distance: 76,
        bobPhase: 0.45,
        containerSize: 34,
        iconSize: 18,
        bobAmplitude: 5,
      ),
      Satellite(
        icon: Icons.favorite_rounded,
        color: Color(0xFFE91E63),
        angle: pi + pi / 4,
        distance: 74,
        bobPhase: 0.8,
        containerSize: 32,
        iconSize: 16,
        bobAmplitude: 7,
      ),
    ],
  ),
  _TourCard(
    centerIcon: Icons.calendar_month_rounded,
    color: AppTheme.tertiaryColor,
    title: 'Schedule',
    description:
        'Tap any meal slot to add your own recipe, a member recipe, or a freeform meal.',
    backdropColors: [AppTheme.tertiaryColor, AppTheme.secondaryColor],
    satellites: [
      Satellite(
        icon: Icons.dinner_dining_rounded,
        color: AppTheme.primaryColor,
        angle: -pi / 3,
        distance: 78,
        bobPhase: 0,
        containerSize: 36,
        iconSize: 18,
        bobAmplitude: 5,
      ),
      Satellite(
        icon: Icons.schedule_rounded,
        color: AppTheme.neutralColor,
        angle: pi / 3,
        distance: 80,
        bobPhase: 0.4,
        containerSize: 34,
        iconSize: 18,
        bobAmplitude: 6,
      ),
      Satellite(
        icon: Icons.check_circle_rounded,
        color: AppTheme.neutralColor,
        angle: pi,
        distance: 74,
        bobPhase: 0.75,
        containerSize: 32,
        iconSize: 16,
        bobAmplitude: 7,
      ),
    ],
  ),
  _TourCard(
    centerIcon: Icons.menu_book_rounded,
    color: AppTheme.neutralColor,
    title: 'Recipe Book',
    description:
        'Keep your personal library organized, and choose which recipes stay private or shared.',
    backdropColors: [AppTheme.neutralColor, AppTheme.primaryColor],
    satellites: [
      Satellite(
        icon: Icons.bookmark_rounded,
        color: AppTheme.primaryColor,
        angle: -pi / 4,
        distance: 80,
        bobPhase: 0.15,
        containerSize: 36,
        iconSize: 18,
        bobAmplitude: 6,
      ),
      Satellite(
        icon: Icons.auto_awesome_rounded,
        color: AppTheme.secondaryColor,
        angle: 2 * pi / 3,
        distance: 76,
        bobPhase: 0.5,
        containerSize: 34,
        iconSize: 18,
        bobAmplitude: 5,
      ),
      Satellite(
        icon: Icons.lock_outline_rounded,
        color: AppTheme.tertiaryColor,
        angle: pi + pi / 5,
        distance: 74,
        bobPhase: 0.8,
        containerSize: 32,
        iconSize: 16,
        bobAmplitude: 7,
      ),
    ],
  ),
  _TourCard(
    centerIcon: Icons.shopping_bag_rounded,
    color: AppTheme.accentPlayful,
    title: 'Shopping',
    description:
        'Create grocery lists by hand or generate them from your scheduled meals for the week.',
    backdropColors: [AppTheme.accentPlayful, AppTheme.primaryColor],
    satellites: [
      Satellite(
        icon: Icons.add_shopping_cart_rounded,
        color: AppTheme.secondaryColor,
        angle: -pi / 4,
        distance: 78,
        bobPhase: 0,
        containerSize: 36,
        iconSize: 18,
        bobAmplitude: 5,
      ),
      Satellite(
        icon: Icons.calendar_today_rounded,
        color: AppTheme.primaryColor,
        angle: pi / 3,
        distance: 76,
        bobPhase: 0.35,
        containerSize: 34,
        iconSize: 18,
        bobAmplitude: 6,
      ),
      Satellite(
        icon: Icons.help_outline_rounded,
        color: AppTheme.neutralColor,
        angle: pi + pi / 4,
        distance: 72,
        bobPhase: 0.8,
        containerSize: 32,
        iconSize: 16,
        bobAmplitude: 7,
      ),
    ],
  ),
];

/// Final onboarding step: swipeable feature tour with dot indicators.
class QuickTourScreen extends ConsumerStatefulWidget {
  const QuickTourScreen({
    super.key,
    this.replayMode = false,
  });

  final bool replayMode;

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
    if (widget.replayMode) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
      return;
    }

    setState(() => _isCompleting = true);

    try {
      final apiService = await ref.read(apiServiceProvider.future);
      final result = await apiService.patch(
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
      await ref.read(currentUserProvider.future);
      if (mounted) context.go('/home');
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Navigation row
            Padding(
              padding: const EdgeInsets.only(
                top: AppTheme.spacing8,
                left: AppTheme.spacing4,
                right: AppTheme.spacing16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      if (widget.replayMode) {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/settings');
                        }
                        return;
                      }
                      context.go('/onboarding/premium');
                    },
                    tooltip: 'Back',
                  ),
                  TextButton(
                    onPressed: _isCompleting ? null : _completeOnboarding,
                    child: Text(widget.replayMode ? 'Close' : 'Skip'),
                  ),
                ],
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
                vertical: AppTheme.spacing20,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_tourCards.length, (index) {
                  final isActive = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.primaryColor
                          : AppTheme.gray200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // Action button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing32,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
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
                    shape: RoundedRectangleBorder(
                      borderRadius: AppTheme.borderRadiusMedium,
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
                      : Text(
                          _isLastPage
                              ? (widget.replayMode ? 'Done' : 'Get Started')
                              : 'Next',
                        ),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacing12),
            TextButton.icon(
              onPressed: () => context.push('/help/faqs'),
              icon: const Icon(Icons.help_outline_rounded, size: 18),
              label: const Text('Open Help & FAQs'),
            ),

            const SizedBox(height: AppTheme.spacing40),
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
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OnboardingIllustration(
            size: 240,
            centerIcon: card.centerIcon,
            centerColor: card.color,
            centerIconSize: 48,
            centerCircleSize: 96,
            backdropColors: card.backdropColors,
            satellites: card.satellites,
          ),
          const SizedBox(height: AppTheme.spacing40),
          Text(
            card.title,
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: AppTheme.gray900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            card.description,
            style: context.textTheme.bodyLarge?.copyWith(
              color: AppTheme.gray500,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
