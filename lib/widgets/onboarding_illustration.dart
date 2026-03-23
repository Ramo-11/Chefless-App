import 'dart:math';

import 'package:flutter/material.dart';

/// A floating satellite element that orbits around the center of the illustration.
class Satellite {
  const Satellite({
    required this.icon,
    required this.color,
    required this.angle,
    required this.distance,
    this.iconSize = 22,
    this.containerSize = 44,
    this.bobAmplitude = 8,
    this.bobPhase = 0,
  });

  /// The icon to display.
  final IconData icon;

  /// Tint color for both the icon and its background bubble.
  final Color color;

  /// Position angle in radians around the center (0 = right, π/2 = bottom).
  final double angle;

  /// Distance in logical pixels from the center of the illustration.
  final double distance;

  /// Icon size inside the bubble.
  final double iconSize;

  /// Diameter of the circular bubble container.
  final double containerSize;

  /// Vertical bob amplitude in logical pixels.
  final double bobAmplitude;

  /// Phase offset (0–1) so each satellite bobs at a different time.
  final double bobPhase;
}

/// A playful animated illustration with a center icon surrounded by floating
/// satellite icons. Used across all onboarding screens.
class OnboardingIllustration extends StatefulWidget {
  const OnboardingIllustration({
    super.key,
    required this.centerIcon,
    required this.centerColor,
    this.centerIconSize = 48,
    this.centerCircleSize = 100,
    this.satellites = const [],
    this.size = 280,
    this.backdropColors,
    this.centerImageAsset,
  });

  final IconData centerIcon;
  final Color centerColor;

  /// If provided, displays this image asset instead of [centerIcon].
  final String? centerImageAsset;
  final double centerIconSize;
  final double centerCircleSize;
  final List<Satellite> satellites;
  final double size;

  /// Colors for soft blurred backdrop circles. Pass 2–3 brand colors.
  final List<Color>? backdropColors;

  @override
  State<OnboardingIllustration> createState() => _OnboardingIllustrationState();
}

class _OnboardingIllustrationState extends State<OnboardingIllustration>
    with TickerProviderStateMixin {
  late final AnimationController _bobController;
  late final AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _bobController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.size / 2;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_bobController, _entranceController]),
        builder: (context, _) {
          final entrance = CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ).value;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Soft backdrop blobs
              if (widget.backdropColors != null)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _BackdropPainter(
                      colors: widget.backdropColors!,
                      opacity: entrance,
                    ),
                  ),
                ),

              // Center icon with glow
              _buildCenter(center, entrance),

              // Floating satellites
              for (int i = 0; i < widget.satellites.length; i++)
                _buildSatellite(widget.satellites[i], i, center, entrance),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCenter(double center, double entrance) {
    final scale = Curves.easeOutBack.transform(entrance.clamp(0.0, 1.0));

    return Positioned(
      left: center - widget.centerCircleSize / 2,
      top: center - widget.centerCircleSize / 2,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: widget.centerCircleSize,
          height: widget.centerCircleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.centerColor.withValues(alpha: 0.12),
            boxShadow: [
              BoxShadow(
                color: widget.centerColor.withValues(alpha: 0.12),
                blurRadius: 32,
                spreadRadius: 8,
              ),
            ],
          ),
          child: widget.centerImageAsset != null
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Image.asset(
                    widget.centerImageAsset!,
                    width: widget.centerIconSize * 1.5,
                    height: widget.centerIconSize * 1.5,
                  ),
                )
              : Icon(
                  widget.centerIcon,
                  size: widget.centerIconSize,
                  color: widget.centerColor,
                ),
        ),
      ),
    );
  }

  Widget _buildSatellite(
    Satellite sat,
    int index,
    double center,
    double entrance,
  ) {
    // Bob offset from sine wave
    final bobOffset =
        sin((_bobController.value + sat.bobPhase) * 2 * pi) * sat.bobAmplitude;

    // Position from polar coordinates
    final x = center + cos(sat.angle) * sat.distance - sat.containerSize / 2;
    final y = center +
        sin(sat.angle) * sat.distance -
        sat.containerSize / 2 +
        bobOffset;

    // Staggered entrance: each satellite delays by 0.08 of the total duration
    final delay = index * 0.1;
    final t = ((entrance - delay) / (1 - delay)).clamp(0.0, 1.0);
    final satScale = Curves.easeOutBack.transform(t);

    return Positioned(
      left: x,
      top: y,
      child: Transform.scale(
        scale: satScale,
        child: Opacity(
          opacity: t,
          child: Container(
            width: sat.containerSize,
            height: sat.containerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: sat.color.withValues(alpha: 0.10),
              border: Border.all(
                color: sat.color.withValues(alpha: 0.18),
                width: 1.5,
              ),
            ),
            child: Icon(
              sat.icon,
              size: sat.iconSize,
              color: sat.color,
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints soft, blurred, overlapping gradient circles as an atmospheric backdrop.
class _BackdropPainter extends CustomPainter {
  _BackdropPainter({required this.colors, required this.opacity});

  final List<Color> colors;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width * 0.32;

    // Spread blobs slightly off-center for an organic feel.
    final offsets = [
      Offset(cx - 22, cy - 18),
      if (colors.length > 1) Offset(cx + 25, cy + 15),
      if (colors.length > 2) Offset(cx - 8, cy + 28),
    ];

    for (int i = 0; i < offsets.length && i < colors.length; i++) {
      final paint = Paint()
        ..color = colors[i].withValues(alpha: 0.07 * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);
      canvas.drawCircle(offsets[i], radius, paint);
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.opacity != opacity;
}
