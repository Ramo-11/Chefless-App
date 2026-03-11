import 'package:flutter/material.dart';

/// Spatula badge tiers, computed from a user's recipe count.
enum SpatulaBadge {
  silver,
  golden,
  diamond,
  ruby,
}

/// Returns the [SpatulaBadge] tier for the given recipe count, or `null` if
/// the user hasn't reached any badge threshold yet.
SpatulaBadge? computeSpatulaBadge(int recipesCount) {
  if (recipesCount >= 10000) return SpatulaBadge.ruby;
  if (recipesCount >= 1000) return SpatulaBadge.diamond;
  if (recipesCount >= 100) return SpatulaBadge.golden;
  if (recipesCount >= 10) return SpatulaBadge.silver;
  return null;
}

/// Returns the display color for the given badge tier.
Color badgeColor(SpatulaBadge badge) {
  switch (badge) {
    case SpatulaBadge.silver:
      return const Color(0xFFA0AEC0);
    case SpatulaBadge.golden:
      return const Color(0xFFD69E2E);
    case SpatulaBadge.diamond:
      return const Color(0xFF63B3ED);
    case SpatulaBadge.ruby:
      return const Color(0xFFE53E3E);
  }
}

/// Returns the icon for the given badge tier.
IconData badgeIcon(SpatulaBadge badge) {
  // All spatula badges use the restaurant icon; color differentiates them.
  switch (badge) {
    case SpatulaBadge.silver:
    case SpatulaBadge.golden:
    case SpatulaBadge.diamond:
    case SpatulaBadge.ruby:
      return Icons.restaurant;
  }
}

/// Returns a human-readable label for the badge tier.
String badgeLabel(SpatulaBadge badge) {
  switch (badge) {
    case SpatulaBadge.silver:
      return 'Silver Spatula';
    case SpatulaBadge.golden:
      return 'Golden Spatula';
    case SpatulaBadge.diamond:
      return 'Diamond Spatula';
    case SpatulaBadge.ruby:
      return 'Ruby Spatula';
  }
}
