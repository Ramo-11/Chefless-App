import 'package:flutter/material.dart';

/// Global navigator key shared between the GoRouter (in main.dart) and
/// the notification banner overlay so the banner can navigate without
/// needing a context below the Router.
final rootNavigatorKey = GlobalKey<NavigatorState>();
