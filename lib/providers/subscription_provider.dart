import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../services/subscription_service.dart';

/// Provides the singleton [SubscriptionService] instance.
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  final service = SubscriptionService();
  ref.onDispose(service.dispose);
  return service;
});

/// Streams whether the current user has an active premium subscription.
///
/// Emits `false` until the service is initialized and a customer info
/// update arrives.
final isPremiumProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(subscriptionServiceProvider);
  return service.isPremiumStream;
});

/// Fetches the available RevenueCat offerings (subscription packages).
final offeringsProvider = FutureProvider<Offerings>((ref) async {
  final service = ref.watch(subscriptionServiceProvider);
  return service.getOfferings();
});
