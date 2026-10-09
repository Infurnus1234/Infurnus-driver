import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/driver_session.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/registration_screen.dart';
import '../screens/auth/otp_verification_screen.dart';
import '../screens/auth/driver_onboarding_screen.dart';
import '../screens/auth/verification_status_screen.dart';
import '../screens/driver/production_driver_screen.dart';
import '../screens/fleet/provider_assets_screen.dart';
import '../screens/admin/provider_review_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final session = context.read<DriverSession>(), path = state.uri.path;
    if (path == '/login' || path == '/register') {
      return session.authenticated ? session.landingPath : null;
    }
    if (path == '/otp') {
      return session.challengeId == null && session.signupId == null
          ? session.landingPath
          : null;
    }
    if (!session.authenticated) return '/login';
    if (path.startsWith('/admin')) {
      return session.api.isAdmin ? null : session.landingPath;
    }
    if (session.api.isAdmin) return '/admin/dashboard';
    if (path.startsWith('/fleet')) {
      return session.api.hasFleetRole &&
              session.api.providerMode == 'fleet_owner'
          ? null
          : session.landingPath;
    }
    if (path == '/provider-assets') return null;
    if (!session.api.hasDriverRole || session.api.providerMode != 'driver') {
      return session.landingPath;
    }
    if (path == '/onboarding' || path == '/verification-status') return null;
    return session.dashboardAllowed ? null : session.landingPath;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, _) => const RegistrationScreen()),
    GoRoute(path: '/otp', builder: (_, _) => const OtpVerificationScreen()),
    GoRoute(
      path: '/onboarding',
      builder: (_, _) => const DriverOnboardingScreen(),
    ),
    GoRoute(
      path: '/verification-status',
      builder: (_, _) => const VerificationStatusScreen(),
    ),
    GoRoute(
      path: '/driver/dashboard',
      builder: (_, _) => const ProductionDriverScreen(),
    ),
    GoRoute(
      path: '/provider-assets',
      builder: (_, _) => const ProviderAssetsScreen(),
    ),
    GoRoute(
      path: '/fleet/dashboard',
      builder: (_, _) => const ProviderAssetsScreen(),
    ),
    GoRoute(
      path: '/admin/dashboard',
      builder: (_, _) => const ProviderReviewScreen(),
    ),
  ],
);
