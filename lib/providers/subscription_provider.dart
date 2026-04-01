import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../services/subscription_service.dart';
import '../utils/constants.dart';
import 'auth_provider.dart';

/// Provides the singleton [SubscriptionService] instance.
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  final service = SubscriptionService();
  ref.onDispose(service.dispose);
  return service;
});

/// Initializes RevenueCat when the user is authenticated.
/// Must complete before offerings or premium status can be checked.
final subscriptionInitProvider = FutureProvider<void>((ref) async {
  if (!RevenueCatConstants.isConfigured) return;

  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return;

  final service = ref.read(subscriptionServiceProvider);
  await service.init(userId: user.id);
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
  // Ensure RevenueCat is initialized before fetching offerings.
  await ref.watch(subscriptionInitProvider.future);

  final service = ref.read(subscriptionServiceProvider);
  return service.getOfferings();
});
