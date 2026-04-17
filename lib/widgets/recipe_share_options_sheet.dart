import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/theme/app_theme.dart';
import '../utils/app_icons.dart';
import '../screens/recipe_book/share_recipe_sheet.dart';

/// Opens a short chooser: system share sheet (other apps) vs in-app Chefless share.
Future<void> showRecipeShareOptions({
  required BuildContext context,
  required String recipeId,
  required String recipeTitle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Share recipe',
              style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.gray900,
                  ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              'Share a link with any app, or send it to someone on Chefless.',
              style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.gray600,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: AppTheme.spacing20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppTheme.gray100,
                child: Icon(AppIcons.share, color: AppTheme.gray700),
              ),
              title: const Text('Other apps'),
              subtitle: const Text(
                'Instagram, WhatsApp, Messages, Mail…',
              ),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final link = 'chefless://recipe/$recipeId';
                final body = 'Check out "$recipeTitle" on Chefless\n\n'
                    'Open in the app:\n$link';
                final box = sheetContext.findRenderObject() as RenderBox?;
                Rect? origin;
                if (box != null && box.hasSize) {
                  origin = box.localToGlobal(Offset.zero) & box.size;
                }
                await SharePlus.instance.share(
                  ShareParams(
                    text: body,
                    subject: recipeTitle,
                    title: recipeTitle,
                    sharePositionOrigin: origin,
                  ),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppTheme.accentPlayfulLight,
                child: Icon(
                  Icons.group_outlined,
                  color: AppTheme.accentPlayful,
                ),
              ),
              title: const Text('Chefless'),
              subtitle: const Text('Pick someone who uses Chefless'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!context.mounted) return;
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (ctx) => ShareRecipeSheet(recipeId: recipeId),
                  );
                });
              },
            ),
          ],
        ),
      );
    },
  );
}
