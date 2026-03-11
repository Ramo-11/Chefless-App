import 'package:flutter/material.dart';

import '../utils/extensions.dart';

/// Initial splash screen shown while the app initializes.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 64,
              color: context.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Chefless',
              style: context.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: context.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
