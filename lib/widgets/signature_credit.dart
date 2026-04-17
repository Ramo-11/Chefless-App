import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../utils/extensions.dart';

/// "Created by [signature]" footer rendered at the bottom of a recipe when
/// the author has chosen to display their signature. The signature is a PNG
/// with a transparent background, sized as a personal sign-off.
class SignatureCredit extends StatelessWidget {
  const SignatureCredit({
    super.key,
    required this.authorName,
    required this.signatureUrl,
  });

  final String authorName;
  final String signatureUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacing20,
          AppTheme.spacing20,
          AppTheme.spacing20,
          AppTheme.spacing24,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: AppTheme.borderRadiusXL,
          boxShadow: AppTheme.shadowSubtle,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Created by',
              style: context.textTheme.labelMedium?.copyWith(
                color: AppTheme.gray500,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: AppTheme.spacing4),
            Text(
              authorName,
              style: context.textTheme.titleSmall?.copyWith(
                color: AppTheme.textPrimaryDeep,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 96,
                maxWidth: 240,
              ),
              child: CachedNetworkImage(
                imageUrl: signatureUrl,
                fit: BoxFit.contain,
                errorWidget: (context, url, error) => const SizedBox.shrink(),
                placeholder: (context, url) => const SizedBox(
                  height: 60,
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
