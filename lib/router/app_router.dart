import 'package:go_router/go_router.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/registration_screen.dart';
import '../screens/auth/otp_verification_screen.dart';
import '../screens/auth/role_selection_screen.dart';
import '../screens/auth/personal_details_screen.dart';
import '../screens/auth/profile_photo_screen.dart';
import '../screens/auth/document_upload_screen.dart';
import '../screens/auth/verification_status_screen.dart';
import '../screens/auth/application_rejected_screen.dart';
import '../screens/driver/driver_dashboard_screen.dart';
import '../screens/driver/ride_requests_screen.dart';
import '../screens/driver/ride_details_screen.dart';
import '../screens/driver/assigned_vehicle_screen.dart';
import '../screens/driver/earnings_screen.dart';
import '../screens/fleet/fleet_dashboard_screen.dart';
import '../screens/fleet/vehicle_management_screen.dart';
import '../screens/fleet/add_vehicle_screen.dart';
import '../screens/fleet/vehicle_details_screen.dart';
import '../screens/fleet/driver_management_screen.dart';
import '../screens/fleet/add_driver_screen.dart';
import '../screens/fleet/driver_details_screen.dart';
import '../screens/fleet/driver_vehicle_assignment_screen.dart';
import '../screens/fleet/fleet_tracking_screen.dart';
import '../screens/fleet/fleet_revenue_screen.dart';
import '../screens/logistics/logistics_operations_screen.dart';
import '../screens/common/provider_profile_screen.dart';
import '../screens/common/notifications_screen.dart';
import '../screens/vendor/vendor_dashboard_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/driver/dashboard',
  routes: [
    // Auth & Onboarding
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/register', builder: (context, state) => const RegistrationScreen()),
    GoRoute(path: '/otp', builder: (context, state) => const OtpVerificationScreen()),
    GoRoute(path: '/role-selection', builder: (context, state) => const RoleSelectionScreen()),
    GoRoute(path: '/personal-details', builder: (context, state) => const PersonalDetailsScreen()),
    GoRoute(path: '/profile-photo', builder: (context, state) => const ProfilePhotoScreen()),
    GoRoute(path: '/document-upload', builder: (context, state) => const DocumentUploadScreen()),
    GoRoute(path: '/verification-status', builder: (context, state) => const VerificationStatusScreen()),
    GoRoute(path: '/application-rejected', builder: (context, state) => const ApplicationRejectedScreen()),

    // Shared & Common
    GoRoute(path: '/profile', builder: (context, state) => const ProviderProfileScreen()),
    GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),

    // Driver Mode
    GoRoute(path: '/driver/dashboard', builder: (context, state) => const DriverDashboardScreen()),
    GoRoute(path: '/driver/rides', builder: (context, state) => const RideRequestsScreen()),
    GoRoute(path: '/driver/ride-details', builder: (context, state) => const RideDetailsScreen()),
    GoRoute(path: '/driver/assigned-vehicle', builder: (context, state) => const AssignedVehicleScreen()),
    GoRoute(path: '/driver/earnings', builder: (context, state) => const EarningsScreen()),

    // Fleet Owner Mode
    GoRoute(path: '/fleet/dashboard', builder: (context, state) => const FleetDashboardScreen()),
    GoRoute(path: '/fleet/vehicles', builder: (context, state) => const VehicleManagementScreen()),
    GoRoute(path: '/fleet/add-vehicle', builder: (context, state) => const AddVehicleScreen()),
    GoRoute(path: '/fleet/vehicle-details', builder: (context, state) => const VehicleDetailsScreen()),
    GoRoute(path: '/fleet/drivers', builder: (context, state) => const DriverManagementScreen()),
    GoRoute(path: '/fleet/add-driver', builder: (context, state) => const AddDriverScreen()),
    GoRoute(path: '/fleet/driver-details', builder: (context, state) => const DriverDetailsScreen()),
    GoRoute(path: '/fleet/assignment', builder: (context, state) => const DriverVehicleAssignmentScreen()),
    GoRoute(path: '/fleet/tracking', builder: (context, state) => const FleetTrackingScreen()),
    GoRoute(path: '/fleet/revenue', builder: (context, state) => const FleetRevenueScreen()),

    // Logistics Operations
    GoRoute(path: '/logistics/bookings', builder: (context, state) => const LogisticsOperationsScreen()),

    // Business Vendor Panel
    GoRoute(path: '/vendor/dashboard', builder: (context, state) => const VendorDashboardScreen()),

    // Admin Panel
    GoRoute(path: '/admin/dashboard', builder: (context, state) => const AdminDashboardScreen()),
  ],
);
