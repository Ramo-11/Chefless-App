import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_earth_globe/flutter_earth_globe.dart';
import 'package:flutter_earth_globe/flutter_earth_globe_controller.dart';
import 'package:flutter_earth_globe/globe_coordinates.dart';
import 'package:flutter_earth_globe/point.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/search_provider.dart';
import '../../utils/country_coordinates.dart';
import '../../utils/cuisine_data.dart';

const Color _darkBackground = Color(0xFF070D1A);

/// Taste the World — an immersive globe + cuisine-region browse experience.
class GlobeScreen extends ConsumerStatefulWidget {
  const GlobeScreen({super.key});

  @override
  ConsumerState<GlobeScreen> createState() => _GlobeScreenState();
}

class _GlobeScreenState extends ConsumerState<GlobeScreen>
    with TickerProviderStateMixin {
  late final FlutterEarthGlobeController _globeController;
  late final TabController _tabController;

  bool _isGlobeReady = false;
  String? _tappedCountry;
  String? _tappedFlag;
  bool _isNavigating = false;
  Timer? _navTimer;

  // Gesture tracking — only accept taps that are short AND stationary.
  // The globe package fires `onTap` on pointer-DOWN (via GestureDetector.onTapDown),
  // so we capture the coords there and only act on pointer-UP if it was a real tap.
  Offset? _downPos;
  DateTime? _downTime;
  int _pointerCount = 0;
  double _totalDelta = 0;
  double _maxDisplacement = 0;
  GlobeCoordinates? _pendingTapCoords;

  // Labels progressively reveal country names when zoomed in past threshold.
  static const double _labelExpandZoom = 1.15;
  bool _labelsExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _globeController = FlutterEarthGlobeController(
      rotationSpeed: 0.05,
      isRotating: false,
      isZoomEnabled: true,
      zoom: 0.6,
      minZoom: 0.0,
      maxZoom: 2.5,
      surface: const AssetImage('assets/images/8k_earth_daymap.jpg'),
      background: const AssetImage('assets/images/2k_stars_milky_way.jpg'),
      isBackgroundFollowingSphereRotation: false,
      showAtmosphere: true,
      atmosphereColor: const Color(0xFF9FD4FF),
      atmosphereBlur: 28,
      atmosphereThickness: 0.055,
      atmosphereOpacity: 0.38,
      surfaceLightingEnabled: true,
      lightIntensity: 0.55,
      ambientLight: 0.92,
      panSensitivity: 0.95,
    );

    _globeController.onLoaded = () {
      _addCountryMarkers();
      if (mounted) setState(() => _isGlobeReady = true);
    };

    _globeController.addListener(_onGlobeControllerChange);
  }

  void _onGlobeControllerChange() {
    final shouldExpand = _globeController.zoom > _labelExpandZoom;
    if (shouldExpand != _labelsExpanded) {
      _labelsExpanded = shouldExpand;
      _rebuildCountryMarkers();
    }
  }

  void _rebuildCountryMarkers() {
    for (final country in countryCoordinates) {
      _globeController.removePoint(country.name);
    }
    _addCountryMarkers();
  }

  void _addCountryMarkers() {
    final expanded = _labelsExpanded;
    for (final country in countryCoordinates) {
      _globeController.addPoint(
        Point(
          id: country.name,
          coordinates: GlobeCoordinates(country.lat, country.lng),
          // Zoomed-out: flag alone keeps the globe readable.
          // Zoomed-in: flag + name so unfamiliar flags are understandable.
          label: expanded ? '${country.flag} ${country.name}' : country.flag,
          isLabelVisible: true,
          labelTextStyle: TextStyle(
            fontSize: expanded ? 12 : 16,
            fontWeight: expanded ? FontWeight.w700 : FontWeight.w400,
            color: Colors.white,
            height: 1.05,
            letterSpacing: -0.1,
            shadows: const [
              Shadow(
                color: Colors.black87,
                blurRadius: 6,
                offset: Offset(0, 1),
              ),
            ],
          ),
          style: const PointStyle(
            color: Colors.transparent,
            size: 0,
          ),
        ),
      );
    }
  }

  bool get _wasGenuineTap {
    if (_downTime == null) return false;
    if (_pointerCount > 1) return false; // pinch-zoom
    if (_totalDelta > 6) return false; // finger wobbled
    if (_maxDisplacement > 6) return false; // finger drifted
    final duration = DateTime.now().difference(_downTime!);
    if (duration.inMilliseconds > 260) return false; // held too long = drag
    return true;
  }

  void _handleTapCoords(GlobeCoordinates coords) {
    if (_isNavigating) return;

    CountryCoord? nearest;
    double minDist = double.infinity;
    for (final c in countryCoordinates) {
      final dLat = c.lat - coords.latitude;
      final dLng = c.lng - coords.longitude;
      final dist = dLat * dLat + dLng * dLng;
      if (dist < minDist) {
        minDist = dist;
        nearest = c;
      }
    }
    if (nearest == null || minDist >= 64) return;

    HapticFeedback.selectionClick();
    final target = nearest;
    setState(() {
      _tappedCountry = target.name;
      _tappedFlag = target.flag;
      _isNavigating = true;
    });

    _navTimer?.cancel();
    _navTimer = Timer(const Duration(milliseconds: 560), () {
      if (!mounted) return;
      _navigateToCuisine(target.name);
      if (mounted) {
        setState(() {
          _tappedCountry = null;
          _tappedFlag = null;
          _isNavigating = false;
        });
      }
    });
  }

  void _navigateToCuisine(String name) {
    HapticFeedback.lightImpact();
    ref.read(searchQueryProvider.notifier).state = name;
    context.push('/search');
  }

  void _onCuisinePillTap(String name) {
    HapticFeedback.selectionClick();
    _navigateToCuisine(name);
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _globeController.removeListener(_onGlobeControllerChange);
    _globeController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBackground,
      appBar: AppBar(
        backgroundColor: _darkBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white, size: 22),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
          tooltip: 'Back',
        ),
        title: Text(
          'Taste the World',
          style: AppTheme.displayTitleMedium(color: Colors.white).copyWith(
            fontSize: 20,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _GlobeTabBar(controller: _tabController),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _GlobeTab(
            controller: _globeController,
            isReady: _isGlobeReady,
            tappedCountry: _tappedCountry,
            tappedFlag: _tappedFlag,
            onPointerDown: (e) {
              _pointerCount += 1;
              if (_pointerCount == 1) {
                _downPos = e.position;
                _downTime = DateTime.now();
                _totalDelta = 0;
                _maxDisplacement = 0;
                _pendingTapCoords = null;
              }
            },
            onPointerMove: (e) {
              if (_downPos != null) {
                _totalDelta += e.delta.distance;
                final disp = (e.position - _downPos!).distance;
                if (disp > _maxDisplacement) _maxDisplacement = disp;
              }
            },
            onPointerUp: (_) {
              if (_pointerCount > 0) _pointerCount -= 1;
              if (_pointerCount == 0) {
                final coords = _pendingTapCoords;
                final genuine = _wasGenuineTap;
                _downPos = null;
                _downTime = null;
                _totalDelta = 0;
                _maxDisplacement = 0;
                _pendingTapCoords = null;
                if (genuine && coords != null) {
                  _handleTapCoords(coords);
                }
              }
            },
            onPointerCancel: (_) {
              if (_pointerCount > 0) _pointerCount -= 1;
              if (_pointerCount == 0) {
                _downPos = null;
                _downTime = null;
                _totalDelta = 0;
                _maxDisplacement = 0;
                _pendingTapCoords = null;
              }
            },
            // Globe fires this on pointer-DOWN — capture, don't act yet.
            onTap: (coords) => _pendingTapCoords = coords,
          ),
          _CuisinesTab(onSelect: _onCuisinePillTap),
        ],
      ),
    );
  }
}

// ── Tab bar ──────────────────────────────────────────────────────────────────

class _GlobeTabBar extends StatelessWidget {
  const _GlobeTabBar({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _darkBackground,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TabBar(
          controller: controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing8,
            vertical: 6,
          ),
          indicator: BoxDecoration(
            color: AppTheme.accentPlayful,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentPlayful.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.55),
          labelStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          tabs: const [
            Tab(text: 'Globe'),
            Tab(text: 'Cuisines'),
          ],
        ),
      ),
    );
  }
}

// ── Globe tab ────────────────────────────────────────────────────────────────

class _GlobeTab extends StatefulWidget {
  const _GlobeTab({
    required this.controller,
    required this.isReady,
    required this.tappedCountry,
    required this.tappedFlag,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
    required this.onPointerCancel,
    required this.onTap,
  });

  final FlutterEarthGlobeController controller;
  final bool isReady;
  final String? tappedCountry;
  final String? tappedFlag;
  final ValueChanged<PointerDownEvent> onPointerDown;
  final ValueChanged<PointerMoveEvent> onPointerMove;
  final ValueChanged<PointerUpEvent> onPointerUp;
  final ValueChanged<PointerCancelEvent> onPointerCancel;
  final ValueChanged<GlobeCoordinates?> onTap;

  @override
  State<_GlobeTab> createState() => _GlobeTabState();
}

class _GlobeTabState extends State<_GlobeTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Stack(
      children: [
        // Globe widget centers its sphere on MediaQuery.size, NOT its parent
        // constraints. So we give it a local MediaQuery matching the body —
        // LayoutBuilder reports the TabBarView slot, which we feed as the
        // virtual "screen" so the sphere sits in the true visual center.
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final shortest =
                  math.min(constraints.maxWidth, constraints.maxHeight);
              // Target sphere diameter ~86% of short side at the initial
              // zoom (0.6). Package formula: displayed = radius * 2^zoom.
              final targetDisplayedRadius = shortest * 0.43;
              final radius = targetDisplayedRadius / math.pow(2, 0.6);
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  padding: EdgeInsets.zero,
                  viewPadding: EdgeInsets.zero,
                ),
                child: Listener(
                  onPointerDown: widget.onPointerDown,
                  onPointerMove: widget.onPointerMove,
                  onPointerUp: widget.onPointerUp,
                  onPointerCancel: widget.onPointerCancel,
                  child: FlutterEarthGlobe(
                    radius: radius.toDouble(),
                    controller: widget.controller,
                    onTap: widget.onTap,
                  ),
                ),
              );
            },
          ),
        ),
        // Loading overlay — fades when globe textures are ready.
        Positioned.fill(
          child: IgnorePointer(
            ignoring: widget.isReady,
            child: AnimatedOpacity(
              opacity: widget.isReady ? 0 : 1,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              child: const _GlobeLoadingOverlay(),
            ),
          ),
        ),
        // Bottom UI: animated tap toast + persistent spin hint.
        Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.paddingOf(context).bottom + AppTheme.spacing24,
          child: IgnorePointer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TapFeedbackToast(
                  country: widget.tappedCountry,
                  flag: widget.tappedFlag,
                ),
                const _GlobeHintPill(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TapFeedbackToast extends StatelessWidget {
  const _TapFeedbackToast({this.country, this.flag});

  final String? country;
  final String? flag;

  @override
  Widget build(BuildContext context) {
    final active = country != null;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1).animate(anim),
            child: child,
          ),
        );
      },
      child: active
          ? Padding(
              key: ValueKey<String>('toast-$country'),
              padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
              child: _ToastPill(country: country!, flag: flag ?? ''),
            )
          : const SizedBox.shrink(key: ValueKey<String>('toast-empty')),
    );
  }
}

class _ToastPill extends StatelessWidget {
  const _ToastPill({required this.country, required this.flag});

  final String country;
  final String flag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing20,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        boxShadow: AppTheme.shadowLg,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(flag, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Text(
            'Tasting $country cuisine',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryDeep,
              fontSize: 14,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 10),
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppTheme.accentPlayful),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobeHintPill extends StatelessWidget {
  const _GlobeHintPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.rotate_right_rounded,
            size: 15,
            color: Colors.white.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 7),
          Text(
            'Spin  ·  pinch to zoom  ·  tap to taste',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobeLoadingOverlay extends StatelessWidget {
  const _GlobeLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _darkBackground,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 112,
              height: 112,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.3, -0.3),
                        colors: [
                          Colors.white.withValues(alpha: 0.12),
                          Colors.white.withValues(alpha: 0.02),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 112,
                    height: 112,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation(AppTheme.accentPlayful),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacing24),
            Text(
              'Bringing the world to you',
              style:
                  AppTheme.displayTitleSmall(color: Colors.white).copyWith(
                fontSize: 17,
              ),
            ),
            const SizedBox(height: AppTheme.spacing4),
            Text(
              'Loading cuisines across 140+ countries',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Cuisines tab ─────────────────────────────────────────────────────────────

class _CuisinesTab extends StatefulWidget {
  const _CuisinesTab({required this.onSelect});

  final void Function(String cuisine) onSelect;

  @override
  State<_CuisinesTab> createState() => _CuisinesTabState();
}

class _CuisinesTabState extends State<_CuisinesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ColoredBox(
      color: _darkBackground,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          const SliverToBoxAdapter(child: _CuisinesIntro()),
          SliverToBoxAdapter(
            child: _QuickPicksRow(onSelect: widget.onSelect),
          ),
          for (final region in cuisineRegions)
            SliverToBoxAdapter(
              child: _RegionBlock(
                region: region,
                onSelect: widget.onSelect,
              ),
            ),
          const SliverToBoxAdapter(child: _EndMarker()),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom:
                  MediaQuery.paddingOf(context).bottom + AppTheme.spacing16,
            ),
          ),
        ],
      ),
    );
  }
}

class _CuisinesIntro extends StatelessWidget {
  const _CuisinesIntro();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing20,
        AppTheme.spacing24,
        AppTheme.spacing20,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 3,
                decoration: BoxDecoration(
                  color: AppTheme.accentPlayful,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'BROWSE THE WORLD',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentPlayful,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing10),
          Text(
            'Taste by culture',
            style: AppTheme.displayTitleMedium(color: Colors.white).copyWith(
              fontSize: 24,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            'Tap a cuisine to surface recipes from that culinary tradition.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickPicksRow extends StatelessWidget {
  const _QuickPicksRow({required this.onSelect});

  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            label: 'Popular picks',
            trailing: '${quickPickCuisines.length}',
          ),
          const SizedBox(height: AppTheme.spacing14),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(
                left: AppTheme.spacing20,
                right: AppTheme.spacing8,
              ),
              physics: const BouncingScrollPhysics(),
              itemCount: quickPickCuisines.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: AppTheme.spacing12),
              itemBuilder: (context, i) {
                final c = quickPickCuisines[i];
                return _QuickPickCard(
                  cuisine: c,
                  onTap: () => onSelect(c.name),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickPickCard extends StatelessWidget {
  const _QuickPickCard({required this.cuisine, required this.onTap});

  final CuisineItem cuisine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 116,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            splashColor: AppTheme.accentPlayful.withValues(alpha: 0.18),
            highlightColor: AppTheme.accentPlayful.withValues(alpha: 0.08),
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1B2640),
                    Color(0xFF0D1423),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 12,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        cuisine.flag,
                        style: const TextStyle(fontSize: 46),
                      ),
                    ),
                    Text(
                      cuisine.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RegionBlock extends StatelessWidget {
  const _RegionBlock({required this.region, required this.onSelect});

  final CuisineRegion region;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spacing32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            label: region.name,
            trailing: '${region.cuisines.length}',
          ),
          const SizedBox(height: AppTheme.spacing14),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing20,
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in region.cuisines)
                  _CuisinePill(
                    cuisine: c,
                    onTap: () => onSelect(c.name),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label, this.trailing});

  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: AppTheme.accentPlayful,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppTheme.spacing10),
          Expanded(
            child: Text(
              label,
              style: AppTheme.displayTitleSmall(color: Colors.white)
                  .copyWith(fontSize: 19, height: 1.15),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppTheme.spacing8),
            Text(
              trailing!,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.45),
                letterSpacing: -0.1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CuisinePill extends StatelessWidget {
  const _CuisinePill({required this.cuisine, required this.onTap});

  final CuisineItem cuisine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Material(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: AppTheme.accentPlayful.withValues(alpha: 0.16),
          highlightColor: AppTheme.accentPlayful.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing12,
              vertical: 9,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cuisine.flag,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  cuisine.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.15,
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

class _EndMarker extends StatelessWidget {
  const _EndMarker();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing40,
        vertical: AppTheme.spacing32,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppTheme.accentPlayful,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}
