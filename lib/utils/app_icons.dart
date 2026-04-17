import 'package:flutter/material.dart';

/// Shared [IconData] for actions that appear in multiple screens.
abstract final class AppIcons {
  AppIcons._();

  /// Share / forward — paper-plane style (reads clearly at 18–22dp).
  static const IconData share = Icons.send_rounded;
}
