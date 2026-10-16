import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/driver_session.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/registration_screen.dart';
import '../screens/auth/otp_verification_screen.dart';
import '../screens/auth/driver_onboarding_screen.dart';
import '../screens/auth/verification_status_screen.dart';
import '../screens/auth/welcome_screen.dart';
import '../screens/auth/role_selection_screen.dart';
import '../screens/auth/personal_details_screen.dart';
import '../screens/auth/profile_photo_screen.dart';
import '../screens/auth/document_upload_screen.dart';
import '../screens/driver/production_driver_screen.dart';
import '../screens/driver/my_trips_screen.dart';
import '../screens/driver/earnings_screen.dart';
import '../screens/driver/wallet_screen.dart';
import '../screens/driver/navigate_to_pickup_screen.dart';
import '../screens/driver/on_ride_screen.dart';
import '../screens/driver/trip_completed_screen.dart';
import '../screens/driver/ride_requests_screen.dart';
import '../screens/common/provider_profile_screen.dart';
import '../screens/common/notifications_screen.dart';
import '../screens/fleet/provider_assets_screen.dart';
import '../screens/admin/provider_review_screen.dart';
import '../screens/common/support_tickets_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final session = context.read<DriverSession>(), path = state.uri.path;
    if (!kReleaseMode && session.isPreview && path == '/driver/dashboard') {
      return null;
    }
    if (path == '/welcome' ||
        path == '/login' ||
        path == '/register' ||
        path == '/role-selection' ||
        path == '/personal-details' ||
        path == '/profile-photo' ||
        path == '/document-upload') {
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
    if (path == '/support-tickets') return null;
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
    GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
    GoRoute(
      path: '/support-tickets',
      builder: (_, _) => const SupportTicketsScreen(),
    ),
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, _) => const RegistrationScreen()),
    GoRoute(path: '/otp', builder: (_, _) => const OtpVerificationScreen()),
    GoRoute(
      path: '/role-selection',
      builder: (_, _) => const RoleSelectionScreen(),
    ),
    GoRoute(
      path: '/personal-details',
      builder: (_, _) => const PersonalDetailsScreen(),
    ),
    GoRoute(
      path: '/profile-photo',
      builder: (_, _) => const ProfilePhotoScreen(),
    ),
    GoRoute(
      path: '/document-upload',
      builder: (_, _) => const DocumentUploadScreen(),
    ),
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
      path: '/driver/trips',
      builder: (_, _) => const MyTripsScreen(),
    ),
    GoRoute(
      path: '/driver/earnings',
      builder: (_, _) => const EarningsScreen(),
    ),
    GoRoute(
      path: '/driver/wallet',
      builder: (_, _) => const WalletScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (_, _) => const ProviderProfileScreen(),
    ),
    GoRoute(
      path: '/driver/profile',
      builder: (_, _) => const ProviderProfileScreen(),
    ),
    GoRoute(
      path: '/driver/ride-requests',
      builder: (_, _) => const RideRequestsScreen(),
    ),
    GoRoute(
      path: '/driver/navigate-pickup',
      builder: (_, _) => const NavigateToPickupScreen(),
    ),
    GoRoute(
      path: '/driver/on-ride',
      builder: (_, _) => const OnRideScreen(),
    ),
    GoRoute(
      path: '/driver/trip-completed',
      builder: (_, _) => const TripCompletedScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (_, _) => const NotificationsScreen(),
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
