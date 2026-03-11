import 'package:flutter/material.dart';

/// Convenience extensions on [BuildContext] for quick access to theme data.
extension BuildContextThemeExtensions on BuildContext {
  /// Shorthand for `Theme.of(context).colorScheme`.
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Shorthand for `Theme.of(context).textTheme`.
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Shorthand for `MediaQuery.sizeOf(context)`.
  Size get screenSize => MediaQuery.sizeOf(this);

  /// Shorthand for `MediaQuery.paddingOf(context)`.
  EdgeInsets get viewPadding => MediaQuery.paddingOf(this);

  /// Whether the current brightness is dark.
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
