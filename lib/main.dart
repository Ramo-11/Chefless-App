import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'services/database_service.dart';
import 'services/deep_link_service.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/home/app_shell.dart';
import 'screens/home/explore_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/onboarding/profile_setup_screen.dart';
import 'screens/onboarding/dietary_preferences_screen.dart';
import 'screens/onboarding/cuisine_preferences_screen.dart';
import 'screens/onboarding/premium_pitch_screen.dart';
import 'screens/onboarding/quick_tour_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/follow_requests_screen.dart';
import 'screens/profile/followers_screen.dart';
import 'screens/profile/following_screen.dart';
import 'screens/profile/other_user_profile_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/recipe_book/create_recipe_screen.dart';
import 'screens/recipe_book/edit_recipe_screen.dart';
import 'screens/recipe_book/recipe_book_screen.dart';
import 'screens/recipe_book/recipe_detail_screen.dart';
import 'screens/kitchen/create_kitchen_screen.dart';
import 'screens/kitchen/join_kitchen_screen.dart';
import 'screens/kitchen/kitchen_detail_screen.dart';
import 'screens/kitchen/kitchen_recipes_screen.dart';
import 'screens/kitchen/manage_permissions_screen.dart';
import 'screens/schedule/schedule_screen.dart';
import 'screens/schedule/suggestions_screen.dart';
import 'screens/search/search_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'widgets/notification_banner.dart';
import 'screens/settings/account_settings_screen.dart';
import 'screens/settings/notification_preferences_screen.dart';
import 'screens/paywall/paywall_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/shopping/shopping_list_detail_screen.dart';
import 'screens/shopping/shopping_list_screen.dart';
import 'screens/splash_screen.dart';
import 'utils/navigator_keys.dart';

// Navigator keys for each tab branch.
final _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _scheduleNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'schedule');
final _recipesNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'recipes');
final _shoppingNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shopping');
final _profileNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'profile');

/// Dismisses the keyboard automatically on every route transition (push, pop,
/// replace). Prevents the keyboard from getting stuck when navigating while
/// an input field is focused — a common iOS issue with route disposal timing.
class _KeyboardDismissObserver extends NavigatorObserver {
  void _dismiss() => FocusManager.instance.primaryFocus?.unfocus();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _dismiss();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _dismiss();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _dismiss();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _dismiss();
}

/// Notifies GoRouter to re-evaluate redirects when auth or user state changes,
/// without re-creating the entire router (which would cause GlobalKey conflicts).
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(currentUserProvider, (_, _) => notifyListeners());
  }
}

/// Auth-aware router that redirects unauthenticated users to /login and
/// users who haven't completed onboarding to the onboarding flow.
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  // Use the deep-link initial route if one was captured before runApp.
  // The redirect logic still runs, so auth/onboarding gates are respected.
  final startLocation = _initialDeepLinkRoute ?? '/';
  _initialDeepLinkRoute = null; // consume so it is only used once

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: startLocation,
    refreshListenable: notifier,
    observers: [_KeyboardDismissObserver()],
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final currentUser = ref.read(currentUserProvider);

      final isLoggedIn = authState.valueOrNull != null;
      final loc = state.matchedLocation;
      final isGuestRoute = loc == '/welcome' ||
          loc == '/login' ||
          loc == '/signup' ||
          loc == '/forgot-password';
      final isOnboardingRoute = loc.startsWith('/onboarding');
      final isSplash = loc == '/';

      // Still loading auth state for the first time — stay on splash.
      // When refreshing (hasValue), use the existing value instead of
      // bouncing to splash, which causes GlobalKey conflicts.
      if (authState.isLoading && !authState.hasValue) {
        return isSplash ? null : '/';
      }

      // ── Not logged in ──────────────────────────────────────────────
      if (!isLoggedIn) {
        if (isGuestRoute) return null;
        return '/welcome';
      }

      // ── Logged in ──────────────────────────────────────────────────

      // Still loading user profile for the first time — stay on splash.
      if (currentUser.isLoading && !currentUser.hasValue) {
        return isSplash ? null : '/';
      }

      // Connection error — stay on splash (it shows the error UI).
      if (currentUser.hasError) {
        return isSplash ? null : '/';
      }

      final user = currentUser.valueOrNull;

      // On a guest route while logged in — redirect forward.
      if (isGuestRoute) {
        if (user == null || !user.onboardingComplete) {
          return '/onboarding/profile';
        }
        return '/home';
      }

      // On any onboarding route — allow free movement between steps.
      // Only block if onboarding is already complete.
      if (isOnboardingRoute) {
        if (user != null && user.onboardingComplete) {
          return '/home';
        }
        return null;
      }

      // Not on onboarding, not on guest route — must have a profile.
      if (user == null) {
        return '/onboarding/profile';
      }

      // Profile exists but onboarding not complete.
      if (!user.onboardingComplete) {
        return '/onboarding/profile';
      }

      // On splash after everything loaded — go home.
      if (isSplash) return '/home';

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),

      // Welcome (landing page for unauthenticated users).
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),

      // Auth routes (push on top of everything, no bottom nav).
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Onboarding routes (push on top of everything, no bottom nav).
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/onboarding/profile',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/onboarding/dietary',
        builder: (context, state) => const DietaryPreferencesScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/onboarding/cuisine',
        builder: (context, state) => const CuisinePreferencesScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/onboarding/premium',
        builder: (context, state) => const PremiumPitchScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/onboarding/tour',
        builder: (context, state) => const QuickTourScreen(),
      ),

      // Main app shell with 5-tab bottom navigation.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          // Tab 1: Home / Explore
          StatefulShellBranch(
            navigatorKey: _homeNavigatorKey,
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) =>
                    const ExploreScreen(),
              ),
            ],
          ),

          // Tab 2: Schedule
          StatefulShellBranch(
            navigatorKey: _scheduleNavigatorKey,
            routes: [
              GoRoute(
                path: '/schedule',
                builder: (context, state) => const ScheduleScreen(),
                routes: [
                  GoRoute(
                    path: 'suggestions',
                    builder: (context, state) => const SuggestionsScreen(),
                  ),
                ],
              ),
            ],
          ),

          // Tab 3: Recipes
          StatefulShellBranch(
            navigatorKey: _recipesNavigatorKey,
            routes: [
              GoRoute(
                path: '/recipes',
                builder: (context, state) => const RecipeBookScreen(),
                routes: [
                  GoRoute(
                    path: 'create',
                    builder: (context, state) => const CreateRecipeScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final recipeId = state.pathParameters['id']!;
                      return RecipeDetailScreen(recipeId: recipeId);
                    },
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) {
                          final recipeId = state.pathParameters['id']!;
                          return EditRecipeScreen(recipeId: recipeId);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Tab 4: Shopping
          StatefulShellBranch(
            navigatorKey: _shoppingNavigatorKey,
            routes: [
              GoRoute(
                path: '/shopping',
                builder: (context, state) => const ShoppingListScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final listId = state.pathParameters['id']!;
                      return ShoppingListDetailScreen(listId: listId);
                    },
                  ),
                ],
              ),
            ],
          ),

          // Tab 5: Profile
          StatefulShellBranch(
            navigatorKey: _profileNavigatorKey,
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => const EditProfileScreen(),
                  ),
                  GoRoute(
                    path: 'followers',
                    builder: (context, state) => const FollowersScreen(),
                  ),
                  GoRoute(
                    path: 'following',
                    builder: (context, state) => const FollowingScreen(),
                  ),
                  GoRoute(
                    path: 'requests',
                    builder: (context, state) =>
                        const FollowRequestsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // Non-tabbed routes that push on top of the shell.
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/user/:id',
        builder: (context, state) {
          final userId = state.pathParameters['id']!;
          return OtherUserProfileScreen(userId: userId);
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/kitchen',
        builder: (context, state) => const KitchenDetailScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/kitchen/create',
        builder: (context, state) => const CreateKitchenScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/kitchen/join',
        builder: (context, state) => const JoinKitchenScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/kitchen/recipes',
        builder: (context, state) => const KitchenRecipesScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/kitchen/permissions',
        builder: (context, state) => const ManagePermissionsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      // Root-level recipe detail for navigation from search, notifications, etc.
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/recipe/:id',
        builder: (context, state) {
          final recipeId = state.pathParameters['id']!;
          return RecipeDetailScreen(recipeId: recipeId);
        },
        routes: [
          GoRoute(
            parentNavigatorKey: rootNavigatorKey,
            path: 'edit',
            builder: (context, state) {
              final recipeId = state.pathParameters['id']!;
              return EditRecipeScreen(recipeId: recipeId);
            },
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/settings/account',
        builder: (context, state) => const AccountSettingsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/settings/notifications',
        builder: (context, state) =>
            const NotificationPreferencesScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/paywall',
        builder: (context, state) => const PaywallScreen(),
      ),
    ],
  );

  // Wire up deep links (URL scheme + FCM background taps) to this router.
  DeepLinkService.instance.initialize(router);
  ref.onDispose(DeepLinkService.instance.dispose);

  return router;
});

/// Holds the initial deep-link route captured before [runApp].
/// The router uses this as the starting location when it is non-null, then
/// clears it so subsequent navigations are not affected.
String? _initialDeepLinkRoute;

/// Top-level FCM background message handler.
///
/// Required by firebase_messaging for background and terminated-state message
/// processing. Must be a top-level function (not a class method) and annotated
/// with @pragma('vm:entry-point') so the Dart AOT compiler keeps it alive in
/// the background isolate.
///
/// On iOS with a notification payload, APNs shows the system banner
/// automatically — this handler ensures any accompanying data is processed.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register the background handler BEFORE Firebase.initializeApp so that
  // the Dart VM registers it as a valid entry point for the background isolate.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize the local SQLite cache before the app starts.
  await DatabaseService.instance.database;

  // Capture any deep-link route from a cold-start URL or notification tap.
  // Use a timeout to prevent blocking app startup if APNs hasn't registered
  // yet (getInitialMessage can hang indefinitely without APNs).
  try {
    _initialDeepLinkRoute = await DeepLinkService.instance
        .getInitialRoute()
        .timeout(const Duration(seconds: 2));
  } catch (_) {
    _initialDeepLinkRoute = null;
  }

  runApp(const ProviderScope(child: CheflessApp()));
}

class CheflessApp extends ConsumerWidget {
  const CheflessApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Chefless',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
      builder: (context, child) {
        // Global tap-to-dismiss: tapping anywhere outside a text field
        // dismisses the keyboard. Acts as a safety net so the keyboard
        // can never get permanently stuck.
        return GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: NotificationBannerOverlay(
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
