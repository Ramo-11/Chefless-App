import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A semi-transparent signature watermark positioned in the bottom-right
/// corner of its parent [Stack].
class SignatureOverlay extends StatelessWidget {
  const SignatureOverlay({
    super.key,
    required this.signatureUrl,
    this.size = 80,
    this.opacity = 0.3,
  });

  /// Cloudinary URL of the signature PNG (transparent background).
  final String signatureUrl;

  /// Width and height of the signature image.
  final double size;

  /// Opacity of the watermark (0.0 to 1.0).
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 12,
      bottom: 24,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: CachedNetworkImage(
            imageUrl: signatureUrl,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorWidget: (context, url, error) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
