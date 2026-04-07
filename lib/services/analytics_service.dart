import 'dart:developer' as developer;

/// Lightweight analytics event tracker.
///
/// Currently logs events locally. Connect to your analytics backend
/// (Mixpanel, Amplitude, PostHog, etc.) by updating [_dispatch].
class AnalyticsService {
  AnalyticsService._();
  static final instance = AnalyticsService._();

  /// Tracks a named event with optional properties.
  void track(String event, [Map<String, dynamic>? properties]) {
    developer.log(
      properties != null ? '$event $properties' : event,
      name: 'Analytics',
    );
    _dispatch(event, properties);
  }

  /// Tracks a screen view.
  void screenView(String screenName) {
    track('screen_view', {'screen': screenName});
  }

  /// Override this to send events to your analytics provider.
  void _dispatch(String event, Map<String, dynamic>? properties) {
    // TODO: Connect to analytics backend.
    // Example:
    // PostHog.capture(event, properties: properties);
    // Mixpanel.track(event, properties);
  }
}
