import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/storage/preferences_service.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/detections/presentation/detections_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/inspection/presentation/inspection_screen.dart';
import '../features/maintenance/presentation/maintenance_screen.dart';
import '../features/map/presentation/live_map_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/robots/presentation/robot_list_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/waste/presentation/waste_screen.dart';
import '../features/zones/presentation/zone_selection_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);
  final prefs = ref.watch(preferencesServiceProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final isOnboardingDone = prefs.isOnboardingCompleted();
      final isAuth = authState.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';
      final isOnboarding = state.matchedLocation == '/onboarding';

      // 1. Force onboarding on first launch (MOB-ONB-002)
      if (!isOnboardingDone && !isOnboarding) {
        return '/onboarding';
      }

      // 2. Auth gating
      if (!isAuth && !isLoggingIn && isOnboardingDone) {
        return '/login';
      }

      // 3. Prevent logged-in users from seeing login/onboarding
      if (isAuth && (isLoggingIn || isOnboarding)) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/robots',
        builder: (context, state) => const RobotListScreen(),
      ),
      GoRoute(
        path: '/zones',
        builder: (context, state) => const ZoneSelectionScreen(),
      ),
      GoRoute(
        path: '/map',
        builder: (context, state) => const LiveMapScreen(),
      ),
      GoRoute(
        path: '/detections',
        builder: (context, state) => const DetectionsScreen(),
      ),
      GoRoute(
        path: '/inspection',
        builder: (context, state) => const InspectionScreen(),
      ),
      GoRoute(
        path: '/waste',
        builder: (context, state) => const WasteScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/maintenance',
        builder: (context, state) => const MaintenanceScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
