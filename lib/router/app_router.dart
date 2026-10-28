import '../screens/driver/vehicle_assignment_screen.dart';
import '../screens/auth/role_onboarding_screen.dart';
import '../screens/fleet/fleet_reports_screen.dart';
import '../screens/fleet/server_driver_detail_screen.dart';
import '../screens/common/notification_preferences_screen.dart';
import '../screens/common/notification_inbox_screen.dart';
import '../screens/common/bank_account_screen.dart';

import 'package:flutter/material.dart';

import '../core/theme.dart';

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
import '../screens/driver/operations_dashboard.dart';
import '../screens/common/operations_screens.dart';

import '../screens/fleet/provider_assets_screen.dart';
import '../screens/fleet/guided_provider_setup.dart';
import '../screens/admin/provider_review_screen.dart';
import '../screens/common/support_tickets_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final session = context.read<DriverSession>(), path = state.uri.path;
    if (session.restoring) {
      return path == '/login' ? null : '/login';
    }
    if (session.restorationNeedsRetry) {
      return path == '/login' ? null : '/login';
    }
    if (session.authenticated && session.roleEnrolment != null) {
      final landing = session.landingPath;
      if (landing == '/driver/active-trip') {
        return path == landing ? null : landing;
      }
      if ((path == '/onboarding' || path == '/verification-status') &&
          {'/role-selection', '/role-onboarding'}.contains(landing)) {
        return landing;
      }
      if (landing == '/role-selection') return path == landing ? null : landing;
      if (landing == '/role-onboarding' &&
          !{
            '/role-onboarding',
            '/driver/assignment',
            '/onboarding/assets',
            '/provider-assets',
            '/profile',
          }.contains(path)) {
        return landing;
      }
      if (path == '/role-onboarding') {
        return landing == '/role-onboarding' ? null : landing;
      }
    }
    if ({'/profile-photo', '/document-upload'}.contains(path)) {
      return session.authenticated ? session.landingPath : '/role-selection';
    }
    if (path == '/personal-details' && !session.authenticated) {
      return '/role-selection';
    }
    if (session.api.isTestOnboarding && session.authenticated) {
      return path == '/onboarding' || path == '/verification-status'
          ? null
          : '/onboarding';
    }
    if (!kReleaseMode && session.isPreview) {
      return null;
    }
    if (path == '/welcome' ||
        path == '/login' ||
        path == '/register' ||
        path == '/role-selection') {
      return session.authenticated ? session.landingPath : null;
    }
    if (path == '/otp') {
      return session.challengeId == null && session.signupId == null
          ? session.landingPath
          : null;
    }
    if (!session.authenticated) return '/login';
    if ({
          '/driver/earnings',
          '/driver/wallet',
          '/provider/payouts',
        }.contains(path) &&
        (!session.api.hasFleetRole ||
            session.api.providerMode != 'fleet_owner')) {
      return session.landingPath;
    }
    if (path == '/driver/assignment' &&
        session.api.hasDriverRole &&
        session.api.providerMode == 'driver') {
      return null;
    }
    if (path.startsWith('/admin')) {
      return session.api.isAdmin ? null : session.landingPath;
    }
    if (session.api.isAdmin) return '/admin/dashboard';
    if ({
      '/personal-details',
      '/support-tickets',
      '/safety',
      '/notifications',
      '/profile',
      '/profile/photo',
      '/profile/driver-details',
      '/provider/payouts',
      '/provider/bank-account',
      '/settings/notifications',
      '/driver/wallet',
      '/driver/earnings',
    }.contains(path)) {
      return null;
    }
    if (path.startsWith('/fleet')) {
      return session.api.hasFleetRole &&
              session.api.providerMode == 'fleet_owner'
          ? null
          : session.landingPath;
    }
    if (path == '/provider-assets' || path == '/onboarding/assets') return null;
    if (!session.api.hasDriverRole || session.api.providerMode != 'driver') {
      return session.landingPath;
    }
    if (path == '/onboarding' || path == '/verification-status') return null;
    return session.dashboardAllowed ? null : session.landingPath;
  },
  routes: [
    GoRoute(
      path: '/driver/active-trip',
      builder: (_, _) => const OperationsDashboard(),
    ),
    GoRoute(
      path: '/driver/assignment',
      builder: (_, _) => const VehicleAssignmentScreen(),
    ),
    GoRoute(
      path: '/profile/photo',
      builder: (_, _) => const RoleOnboardingScreen(editStep: 'profile_photo'),
    ),
    GoRoute(
      path: '/profile/driver-details',
      builder: (_, _) => const RoleOnboardingScreen(editStep: 'licence'),
    ),
    GoRoute(
      path: '/role-onboarding',
      builder: (_, _) => const RoleOnboardingScreen(),
    ),
    GoRoute(
      path: '/provider/bank-account',
      builder: (_, _) => const BankAccountScreen(),
    ),
    GoRoute(
      path: '/settings/notifications',
      builder: (_, _) => const NotificationPreferencesScreen(),
    ),
    GoRoute(
      path: '/fleet/drivers/:id',
      builder: (_, state) =>
          ServerDriverDetailScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/fleet/reports',
      builder: (_, _) => const FleetReportsScreen(),
    ),
    GoRoute(
      path: '/onboarding/assets',
      builder: (_, _) => const GuidedProviderSetup(),
    ),
    GoRoute(path: '/safety', builder: (_, _) => const SafetySettingsScreen()),
    GoRoute(
      path: '/provider/payouts',
      builder: (_, _) => const PayoutHistoryScreen(),
    ),
    GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
    GoRoute(
      path: '/support-tickets',
      builder: (_, _) => const SupportTicketsScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (_, _) =>
          Theme(data: InfurnusTheme.lightTheme, child: const LoginScreen()),
    ),
    GoRoute(
      path: '/register',
      builder: (_, state) => Theme(
        data: InfurnusTheme.lightTheme,
        child: RegistrationScreen(
          initialRole: state.uri.queryParameters['role'],
        ),
      ),
    ),
    GoRoute(path: '/otp', builder: (_, _) => const OtpVerificationScreen()),
    GoRoute(
      path: '/role-selection',
      builder: (_, _) => const RoleSelectionScreen(),
    ),
    GoRoute(
      path: '/personal-details',
      builder: (_, _) => const PersonalInformationScreen(),
    ),
    GoRoute(path: '/profile-photo', redirect: (_, _) => '/role-selection'),
    GoRoute(path: '/document-upload', redirect: (_, _) => '/role-selection'),
    GoRoute(
      path: '/onboarding',
      builder: (_, state) => DriverOnboardingScreen(
        initialTask: state.uri.queryParameters['task'],
      ),
    ),
    GoRoute(
      path: '/verification-status',
      builder: (_, _) => const VerificationStatusScreen(),
    ),
    GoRoute(
      path: '/driver/dashboard',
      builder: (_, _) => const OperationsDashboard(),
    ),
    GoRoute(path: '/driver/trips', builder: (_, _) => const TripsScreen()),
    GoRoute(path: '/driver/earnings', builder: (_, _) => const LedgerScreen()),
    GoRoute(
      path: '/driver/wallet',
      builder: (_, _) => const LedgerScreen(wallet: true),
    ),
    GoRoute(path: '/profile', builder: (_, _) => const AccountScreen()),
    GoRoute(path: '/driver/profile', builder: (_, _) => const AccountScreen()),
    GoRoute(
      path: '/driver/ride-requests',
      builder: (_, _) => const ServerRideRequestsScreen(),
    ),
    GoRoute(
      path: '/driver/navigate-pickup',
      builder: (_, _) => const OperationsDashboard(),
    ),
    GoRoute(
      path: '/driver/on-ride',
      builder: (_, _) => const OperationsDashboard(),
    ),
    GoRoute(
      path: '/driver/trip-completed',
      builder: (_, _) => const TripsScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (_, _) => const ServerNotificationInbox(),
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
