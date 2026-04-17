import 'dart:async';
import 'dart:developer' as developer;

import 'package:app_links/app_links.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';

/// Handles deep links from two sources:
///
/// 1. Custom URL scheme — `chefless://recipe/abc123`, `chefless://user/abc123`, etc.
///    Registered in `ios/Runner/Info.plist` as the `chefless` scheme.
///    `app_links` intercepts these and passes them through [uriLinkStream].
///
/// 2. FCM push notification taps — when the user taps a notification while the
///    app is backgrounded ([onMessageOpenedApp]) or terminated
///    ([getInitialMessage]).  The notification payload must include a `route`
///    field (e.g. `"/recipe/abc123"`) or at minimum a `type` + ID fields so
///    the service can derive the route.
///
/// Usage:
/// ```dart
/// // In main(), before runApp:
/// final initialRoute = await DeepLinkService.instance.getInitialRoute();
///
/// // After GoRouter is built (inside routerProvider or right after runApp):
/// DeepLinkService.instance.initialize(router);
/// ```
class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  GoRouter? _router;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Call **once** after the [GoRouter] is available.
  /// Sets up listeners for:
  ///  - Subsequent custom URL scheme links (app already running)
  ///  - FCM notifications tapped while app is backgrounded
  void initialize(GoRouter router) {
    _router = router;
    _listenToAppLinks();
    _listenToFcmOpenedApp();
  }

  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
    _router = null;
  }

  // ---------------------------------------------------------------------------
  // Cold-start / initial route
  // ---------------------------------------------------------------------------

  /// Returns the initial deep-link route to navigate to on cold start, or
  /// `null` if the app was opened normally.
  ///
  /// Checks FCM initial message first (terminated → tapped notification),
  /// then the initial URL scheme link.
  Future<String?> getInitialRoute() async {
    // 1. FCM: app was terminated, user tapped a notification.
    try {
      final message = await FirebaseMessaging.instance
          .getInitialMessage()
          .timeout(const Duration(seconds: 2));
      if (message != null) {
        final route = _routeFromFcmMessage(message);
        if (route != null) {
          developer.log(
            'Initial FCM deep link: $route',
            name: 'DeepLinkService',
          );
          return route;
        }
      }
    } catch (e) {
      developer.log(
        'Failed to get initial FCM message: $e',
        name: 'DeepLinkService',
      );
    }

    // 2. Custom URL scheme: app opened via chefless:// link.
    try {
      final uri = await _appLinks
          .getInitialLink()
          .timeout(const Duration(seconds: 3));
      if (uri != null) {
        final route = _routeFromUri(uri);
        if (route != null) {
          developer.log(
            'Initial URL deep link: $route (from $uri)',
            name: 'DeepLinkService',
          );
          return route;
        }
      }
    } catch (e) {
      developer.log(
        'Failed to get initial app link: $e',
        name: 'DeepLinkService',
      );
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Ongoing listeners
  // ---------------------------------------------------------------------------

  void _listenToAppLinks() {
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        final route = _routeFromUri(uri);
        if (route != null) {
          developer.log(
            'App link received: $route (from $uri)',
            name: 'DeepLinkService',
          );
          _router?.go(route);
        }
      },
      onError: (Object err) {
        developer.log(
          'App link stream error: $err',
          name: 'DeepLinkService',
        );
      },
    );
  }

  void _listenToFcmOpenedApp() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final route = _routeFromFcmMessage(message);
      if (route != null) {
        developer.log(
          'FCM notification tap deep link: $route',
          name: 'DeepLinkService',
        );
        _router?.go(route);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Route derivation
  // ---------------------------------------------------------------------------

  /// MongoDB ObjectId format: 24 hex characters.
  static final _objectIdPattern = RegExp(r'^[a-fA-F0-9]{24}$');

  /// Maps a custom-scheme URI to an in-app GoRouter path.
  ///
  /// Supported URIs:
  ///   chefless://recipe/<id>      → /recipe/<id>
  ///   chefless://user/<id>        → /user/<id>
  ///   chefless://kitchen          → /kitchen
  ///   chefless://schedule         → /schedule
  ///   chefless://notifications    → /notifications
  static String? _routeFromUri(Uri uri) {
    if (uri.scheme != 'chefless') return null;

    final segments = uri.pathSegments;
    if (segments.isEmpty) return '/home';

    switch (segments[0]) {
      case 'recipe':
        if (segments.length >= 2 && _isValidId(segments[1])) {
          return '/recipe/${segments[1]}';
        }
      case 'user':
        if (segments.length >= 2 && _isValidId(segments[1])) {
          return '/user/${segments[1]}';
        }
      case 'kitchen':
        return '/kitchen';
      case 'schedule':
        return '/schedule';
      case 'notifications':
        return '/notifications';
      case 'home':
        return '/home';
    }

    return null;
  }

  static bool _isValidId(String id) =>
      id.isNotEmpty && _objectIdPattern.hasMatch(id);

  /// Derives an in-app route from an FCM [RemoteMessage].
  ///
  /// The API sets a `route` field in the notification data payload for direct
  /// routing. Falls back to deriving the route from `type` + ID fields for
  /// backwards compatibility.
  static String? _routeFromFcmMessage(RemoteMessage message) {
    final data = message.data;

    // Prefer explicit route set by the API server — validate against whitelist.
    final explicitRoute = data['route'] as String?;
    if (explicitRoute != null && _isAllowedRoute(explicitRoute)) {
      return explicitRoute;
    }

    // Fallback: derive from notification type + payload IDs.
    final type = data['type'] as String?;
    final recipeId = data['recipeId'] as String?;
    final actorId = data['actorId'] as String?;

    switch (type) {
      case 'recipe_liked':
      case 'recipe_forked':
      case 'recipe_saved':
      case 'recipe_shared':
        if (recipeId != null && recipeId.isNotEmpty) {
          return '/recipe/$recipeId';
        }
      case 'new_follower':
      case 'follow_request':
      case 'follow_accepted':
        if (actorId != null && actorId.isNotEmpty) {
          return '/user/$actorId';
        }
      case 'schedule_suggestion':
      case 'suggestion_approved':
      case 'suggestion_denied':
        return '/schedule';
      case 'kitchen_joined':
      case 'kitchen_removed':
      case 'kitchen_invite':
      case 'kitchen_invite_accepted':
        return '/kitchen';
      case 'kitchen_invite_received':
      case 'kitchen_invite_declined':
        return '/notifications';
    }

    return null;
  }

  /// Allowed route prefixes for FCM explicit routes.
  static const _allowedRoutePrefixes = [
    '/recipe/',
    '/user/',
    '/kitchen',
    '/schedule',
    '/notifications',
    '/home',
  ];

  static bool _isAllowedRoute(String route) {
    if (route.isEmpty || !route.startsWith('/')) return false;
    return _allowedRoutePrefixes.any((prefix) => route.startsWith(prefix));
  }
}
