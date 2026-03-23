import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../utils/badge_utils.dart';

/// A reusable circular avatar widget that shows a profile picture via
/// [CachedNetworkImage], or falls back to a coloured circle with the user's
/// initials. Optionally renders a spatula badge overlay in the bottom-right
/// corner.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.fullName,
    this.profilePictureUrl,
    this.size = 48,
    this.badge,
  });

  /// The user's full name, used to derive initials for the fallback.
  final String fullName;

  /// Cloudinary URL for the profile picture. If `null`, initials are shown.
  final String? profilePictureUrl;

  /// Diameter of the avatar circle in logical pixels.
  final double size;

  /// Optional spatula badge to render as a small overlay.
  final SpatulaBadge? badge;

  String get _initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final isLocalFile = profilePictureUrl != null &&
        profilePictureUrl!.isNotEmpty &&
        !profilePictureUrl!.startsWith('http');

    final avatar = profilePictureUrl != null && profilePictureUrl!.isNotEmpty
        ? CircleAvatar(
            radius: size / 2,
            backgroundColor: colorScheme.surfaceContainerHighest,
            backgroundImage: isLocalFile
                ? FileImage(File(profilePictureUrl!))
                : CachedNetworkImageProvider(profilePictureUrl!)
                    as ImageProvider,
          )
        : CircleAvatar(
            radius: size / 2,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              _initials,
              style: TextStyle(
                fontSize: size * 0.36,
                fontWeight: FontWeight.w600,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          );

    if (badge == null) return avatar;

    final badgeSize = size * 0.35;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                color: badgeColor(badge!),
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.surface,
                  width: 2,
                ),
              ),
              child: Icon(
                badgeIcon(badge!),
                size: badgeSize * 0.55,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
