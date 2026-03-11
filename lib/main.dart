import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'services/database_service.dart';
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
import 'screens/settings/notification_preferences_screen.dart';
import 'screens/paywall/paywall_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/shopping/shopping_list_detail_screen.dart';
import 'screens/shopping/shopping_list_screen.dart';
import 'screens/splash_screen.dart';

// Navigator keys for each tab branch.
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _scheduleNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'schedule');
final _recipesNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'recipes');
final _shoppingNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shopping');
final _profileNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'profile');

/// Auth-aware router that redirects unauthenticated users to /login and
/// users who haven't completed onboarding to the onboarding flow.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final currentUser = ref.watch(currentUserProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/forgot-password';
      final isOnboardingRoute =
          state.matchedLocation.startsWith('/onboarding');

      // Still loading auth state — stay on splash.
      if (authState.isLoading) return '/';

      // Not logged in and not on an auth route — redirect to login.
      if (!isLoggedIn && !isAuthRoute) return '/login';

      // Logged in but on an auth route — check onboarding first.
      if (isLoggedIn && isAuthRoute) {
        final user = currentUser.valueOrNull;
        if (user != null && !user.onboardingComplete) {
          return '/onboarding';
        }
        return '/home';
      }

      // Logged in — check onboarding status.
      if (isLoggedIn) {
        final user = currentUser.valueOrNull;

        // Still loading user profile — stay on splash.
        if (currentUser.isLoading) return '/';

        // User loaded and onboarding not complete — redirect to onboarding.
        if (user != null && !user.onboardingComplete && !isOnboardingRoute) {
          return '/onboarding';
        }

        // User loaded, onboarding complete, but on onboarding route — go home.
        if (user != null && user.onboardingComplete && isOnboardingRoute) {
          return '/home';
        }

        // On splash after everything loaded — go home.
        if (state.matchedLocation == '/') return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth routes (push on top of everything, no bottom nav).
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Onboarding routes (push on top of everything, no bottom nav).
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/onboarding',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/onboarding/profile',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/onboarding/dietary',
        builder: (context, state) => const DietaryPreferencesScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/onboarding/cuisine',
        builder: (context, state) => const CuisinePreferencesScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/onboarding/premium',
        builder: (context, state) => const PremiumPitchScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
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
        parentNavigatorKey: _rootNavigatorKey,
        path: '/user/:id',
        builder: (context, state) {
          final userId = state.pathParameters['id']!;
          return OtherUserProfileScreen(userId: userId);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/kitchen',
        builder: (context, state) => const KitchenDetailScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/kitchen/create',
        builder: (context, state) => const CreateKitchenScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/kitchen/join',
        builder: (context, state) => const JoinKitchenScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/kitchen/recipes',
        builder: (context, state) => const KitchenRecipesScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/kitchen/permissions',
        builder: (context, state) => const ManagePermissionsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings/notifications',
        builder: (context, state) =>
            const NotificationPreferencesScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/paywall',
        builder: (context, state) => const PaywallScreen(),
      ),
    ],
  );
});

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize the local SQLite cache before the app starts.
  await DatabaseService.instance.database;

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
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
