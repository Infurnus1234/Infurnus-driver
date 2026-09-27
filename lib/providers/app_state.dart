import 'package:flutter/foundation.dart';
import '../models/app_models.dart';

class AppState extends ChangeNotifier {
  // Authentication State
  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  UserProfile? _currentUser;
  UserProfile? get currentUser => _currentUser;

  ActiveMode _activeMode = ActiveMode.driverMode;
  ActiveMode get activeMode => _activeMode;

  // Driver Status
  bool _isOnline = false;
  bool get isOnline => _isOnline;

  // Wallet & Revenue
  double _walletBalance = 12450.50;
  double get walletBalance => _walletBalance;

  final List<WalletTransaction> _transactions = [
    WalletTransaction(
      id: 'TXN-9021',
      title: 'Ride Delivery Payout #R-8012',
      amount: 450.00,
      type: 'credit',
      status: 'Completed',
      date: 'Today, 02:15 PM',
    ),
    WalletTransaction(
      id: 'TXN-9020',
      title: 'Weekly Payout Withdrawal',
      amount: 5000.00,
      type: 'debit',
      status: 'Completed',
      date: 'Yesterday, 10:00 AM',
    ),
    WalletTransaction(
      id: 'TXN-9019',
      title: 'Logistics Fleet Commission',
      amount: 1200.00,
      type: 'credit',
      status: 'Completed',
      date: '24 Sep 2026',
    ),
  ];
  List<WalletTransaction> get transactions => _transactions;

  final List<PayoutItem> _payouts = [
    PayoutItem(
      id: 'PO-301',
      amount: 5000.00,
      bankAccount: 'HDFC Bank **** 4891',
      status: 'Settled',
      requestedDate: '23 Sep 2026',
    ),
    PayoutItem(
      id: 'PO-302',
      amount: 2500.00,
      bankAccount: 'HDFC Bank **** 4891',
      status: 'Processing',
      requestedDate: 'Today, 09:30 AM',
    ),
  ];
  List<PayoutItem> get payouts => _payouts;

  // Vehicles
  List<VehicleModel> _vehicles = [
    VehicleModel(
      id: 'VEH-101',
      plateNumber: 'KA 01 EV 8899',
      modelName: 'Tata Ace EV Truck',
      category: 'Truck',
      ownerId: 'USER-1',
      assignedDriverId: 'DRV-501',
      assignedDriverName: 'Rajesh Kumar',
      verificationStatus: 'Approved',
      isActive: true,
      documents: [
        DocumentItem(id: 'DOC-V1', name: 'Vehicle Registration Certificate (RC)', type: 'RC', status: 'Approved'),
        DocumentItem(id: 'DOC-V2', name: 'Vehicle Insurance Policy', type: 'Insurance', status: 'Approved'),
        DocumentItem(id: 'DOC-V3', name: 'Fitness Certificate', type: 'Fitness', status: 'Approved'),
      ],
    ),
    VehicleModel(
      id: 'VEH-102',
      plateNumber: 'KA 05 MX 2040',
      modelName: 'Mahindra Bolero Maxi Truck',
      category: 'Container',
      ownerId: 'USER-1',
      assignedDriverId: null,
      assignedDriverName: null,
      verificationStatus: 'Approved',
      isActive: true,
      documents: [
        DocumentItem(id: 'DOC-V4', name: 'Vehicle RC', type: 'RC', status: 'Approved'),
        DocumentItem(id: 'DOC-V5', name: 'Vehicle Insurance', type: 'Insurance', status: 'Approved'),
      ],
    ),
  ];
  List<VehicleModel> get vehicles => _vehicles;

  // Managed Drivers (For Fleet Owner view)
  List<ManagedDriverModel> _managedDrivers = [
    ManagedDriverModel(
      id: 'DRV-501',
      name: 'Rajesh Kumar',
      phone: '+91 98765 43210',
      email: 'rajesh.kumar@infurnus.com',
      applicationStatus: 'Approved',
      assignedVehicleId: 'VEH-101',
      assignedVehiclePlate: 'KA 01 EV 8899',
    ),
    ManagedDriverModel(
      id: 'DRV-502',
      name: 'Suresh Patil',
      phone: '+91 98123 45678',
      email: 'suresh.patil@infurnus.com',
      applicationStatus: 'Pending Review',
      assignedVehicleId: null,
      assignedVehiclePlate: null,
    ),
    ManagedDriverModel(
      id: 'DRV-503',
      name: 'Amit Singh',
      phone: '+91 99887 76655',
      email: 'amit.singh@infurnus.com',
      applicationStatus: 'Changes Requested',
      assignedVehicleId: null,
      assignedVehiclePlate: null,
      rejectionReason: 'Driving License photo is blurry. Please re-upload a clear front photo.',
    ),
  ];
  List<ManagedDriverModel> get managedDrivers => _managedDrivers;

  // Bookings / Rides
  List<BookingModel> _bookings = [
    BookingModel(
      id: 'BK-8001',
      bookingType: 'Logistics',
      pickupLocation: 'Electronic City Phase 1, Bangalore',
      dropoffLocation: 'Whitefield Industrial Area, Bangalore',
      customerName: 'AeroTech Logistics Ltd',
      customerPhone: '+91 91234 56789',
      distanceKm: 28.5,
      fareAmount: 1850.00,
      status: 'Pending',
      goodsDescription: '12 Box Industrial Electrical Components (Weight: 450 kg)',
      routeDetails: 'NH 44 -> Outer Ring Road -> ITPL Main Rd',
      createdAt: '10 mins ago',
    ),
    BookingModel(
      id: 'BK-8002',
      bookingType: 'Ride',
      pickupLocation: 'Koramangala 5th Block',
      dropoffLocation: 'Kempegowda International Airport',
      customerName: 'Ananya Roy',
      customerPhone: '+91 98761 12233',
      distanceKm: 41.2,
      fareAmount: 1200.00,
      status: 'Accepted',
      goodsDescription: '2 Passenger Luggage Bags',
      routeDetails: 'Bellary Road Express Highway',
      createdAt: '25 mins ago',
    ),
    BookingModel(
      id: 'BK-7998',
      bookingType: 'Parcel',
      pickupLocation: 'Indiranagar 100ft Road',
      dropoffLocation: 'MG Road Metro Station',
      customerName: 'TechHub Office Supplies',
      customerPhone: '+91 90000 11111',
      distanceKm: 6.4,
      fareAmount: 320.00,
      status: 'Delivered',
      goodsDescription: 'Document Pack & Hard Drives',
      routeDetails: 'Old Airport Rd -> MG Road',
      createdAt: 'Yesterday',
    ),
  ];
  List<BookingModel> get bookings => _bookings;

  // Notifications
  final List<NotificationItem> _notifications = [
    NotificationItem(
      id: 'NOTIF-1',
      title: 'Driver Application Approved',
      body: 'Your driver partner profile has been approved by Admin. You are now ready to take bookings.',
      timestamp: '2 hours ago',
    ),
    NotificationItem(
      id: 'NOTIF-2',
      title: 'New Logistics Booking Received',
      body: 'A new high-value cargo trip #BK-8001 is available in your vicinity.',
      timestamp: '15 mins ago',
    ),
    NotificationItem(
      id: 'NOTIF-3',
      title: 'Vehicle Verification Successful',
      body: 'Vehicle KA 01 EV 8899 documents have been verified and approved.',
      timestamp: '1 day ago',
    ),
  ];
  List<NotificationItem> get notifications => _notifications;

  // Constructor with initial demo user
  AppState() {
    _currentUser = UserProfile(
      id: 'USER-101',
      fullName: 'Vikram Sharma',
      email: 'vikram.sharma@infurnus.com',
      phone: '+91 98765 00112',
      role: UserRole.driverFleetOwner,
      verificationStatus: VerificationStatus.approved,
      businessName: 'Vikram Fleet & Transport Services',
      businessAddress: 'Plot 42, Transport Nagar, Bangalore',
      assignedVehicleId: 'VEH-101',
      documents: [
        DocumentItem(
          id: 'DOC-1',
          name: 'Commercial Driving License',
          type: 'License',
          status: 'Approved',
          uploadedAt: '20 Sep 2026',
        ),
        DocumentItem(
          id: 'DOC-2',
          name: 'Aadhaar Identity Card',
          type: 'Aadhaar',
          status: 'Approved',
          uploadedAt: '20 Sep 2026',
        ),
        DocumentItem(
          id: 'DOC-3',
          name: 'PAN Card Verification',
          type: 'PAN',
          status: 'Approved',
          uploadedAt: '20 Sep 2026',
        ),
      ],
    );
    _isLoggedIn = true;
  }

  // Auth Methods
  void login(String phoneOrEmail) {
    _isLoggedIn = true;
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
    notifyListeners();
  }

  void register({
    required String fullName,
    required String email,
    required String phone,
    required UserRole role,
  }) {
    _currentUser = UserProfile(
      id: 'USER-${DateTime.now().millisecondsSinceEpoch}',
      fullName: fullName,
      email: email,
      phone: phone,
      role: role,
      verificationStatus: VerificationStatus.draft,
      documents: [
        DocumentItem(id: 'DOC-L1', name: 'Driving License', type: 'License', status: 'Pending'),
        DocumentItem(id: 'DOC-L2', name: 'Aadhaar Card', type: 'Aadhaar', status: 'Pending'),
        DocumentItem(id: 'DOC-L3', name: 'PAN Card', type: 'PAN', status: 'Pending'),
      ],
    );
    _isLoggedIn = true;
    notifyListeners();
  }

  void setRole(UserRole role) {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(role: role);
      if (role == UserRole.driverFleetOwner) {
        _activeMode = ActiveMode.driverMode;
      }
      notifyListeners();
    }
  }

  void updateProfile({
    String? fullName,
    String? email,
    String? phone,
    String? photoUrl,
    String? businessName,
    String? businessAddress,
  }) {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        fullName: fullName ?? _currentUser!.fullName,
        email: email ?? _currentUser!.email,
        phone: phone ?? _currentUser!.phone,
        photoUrl: photoUrl ?? _currentUser!.photoUrl,
        businessName: businessName ?? _currentUser!.businessName,
        businessAddress: businessAddress ?? _currentUser!.businessAddress,
      );
      notifyListeners();
    }
  }

  // Verification & Document Methods
  void submitDocument(String docId, String fileUrl) {
    if (_currentUser == null) return;
    final updatedDocs = _currentUser!.documents.map((doc) {
      if (doc.id == docId) {
        return doc.copyWith(
          fileUrl: fileUrl,
          status: 'Pending',
          rejectionReason: null,
          uploadedAt: 'Just Now',
        );
      }
      return doc;
    }).toList();

    _currentUser = _currentUser!.copyWith(
      documents: updatedDocs,
      verificationStatus: VerificationStatus.documentsSubmitted,
    );
    notifyListeners();
  }

  void submitForReview() {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        verificationStatus: VerificationStatus.underReview,
      );
      notifyListeners();
    }
  }

  // Admin Verification Control (Simulated Admin Action)
  void adminApproveUser() {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        verificationStatus: VerificationStatus.approved,
      );
      notifyListeners();
    }
  }

  void adminRejectUser(String reason) {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        verificationStatus: VerificationStatus.rejected,
      );
      notifyListeners();
    }
  }

  void adminRequestChanges(String reason) {
    if (_currentUser != null) {
      final updatedDocs = _currentUser!.documents.map((doc) {
        return doc.copyWith(status: 'Rejected', rejectionReason: reason);
      }).toList();
      _currentUser = _currentUser!.copyWith(
        documents: updatedDocs,
        verificationStatus: VerificationStatus.changesRequired,
      );
      notifyListeners();
    }
  }

  // Mode Switcher Engine
  void switchMode(ActiveMode mode) {
    _activeMode = mode;
    notifyListeners();
  }

  void toggleActiveMode() {
    if (_activeMode == ActiveMode.driverMode) {
      _activeMode = ActiveMode.fleetOwnerMode;
    } else {
      _activeMode = ActiveMode.driverMode;
    }
    notifyListeners();
  }

  // Driver Availability
  void toggleOnlineStatus() {
    _isOnline = !_isOnline;
    notifyListeners();
  }

  // Vehicle Management (Fleet Owner)
  void addVehicle({
    required String plateNumber,
    required String modelName,
    required String category,
  }) {
    final newVehicle = VehicleModel(
      id: 'VEH-${DateTime.now().millisecondsSinceEpoch % 10000}',
      plateNumber: plateNumber,
      modelName: modelName,
      category: category,
      ownerId: _currentUser?.id ?? 'USER-1',
      verificationStatus: 'Under Review',
      isActive: true,
      documents: [
        DocumentItem(id: 'DOC-V-NEW1', name: 'Vehicle RC', type: 'RC', status: 'Pending'),
        DocumentItem(id: 'DOC-V-NEW2', name: 'Vehicle Insurance', type: 'Insurance', status: 'Pending'),
      ],
    );
    _vehicles.add(newVehicle);
    notifyListeners();
  }

  void toggleVehicleActiveStatus(String vehicleId) {
    final index = _vehicles.indexWhere((v) => v.id == vehicleId);
    if (index != -1) {
      _vehicles[index] = _vehicles[index].copyWith(
        isActive: !_vehicles[index].isActive,
      );
      notifyListeners();
    }
  }

  // Driver Management (Fleet Owner)
  void addDriver({
    required String name,
    required String phone,
    required String email,
  }) {
    final newDriver = ManagedDriverModel(
      id: 'DRV-${DateTime.now().millisecondsSinceEpoch % 10000}',
      name: name,
      phone: phone,
      email: email,
      applicationStatus: 'Pending Review',
    );
    _managedDrivers.add(newDriver);
    notifyListeners();
  }

  // Admin Driver Approval Simulation (Admin Action)
  void adminApproveManagedDriver(String driverId) {
    final index = _managedDrivers.indexWhere((d) => d.id == driverId);
    if (index != -1) {
      _managedDrivers[index] = _managedDrivers[index].copyWith(
        applicationStatus: 'Approved',
      );
      notifyListeners();
    }
  }

  void adminRejectManagedDriver(String driverId, String reason) {
    final index = _managedDrivers.indexWhere((d) => d.id == driverId);
    if (index != -1) {
      _managedDrivers[index] = _managedDrivers[index].copyWith(
        applicationStatus: 'Rejected',
        rejectionReason: reason,
      );
      notifyListeners();
    }
  }

  // Driver ↔ Vehicle Assignment
  void assignDriverToVehicle(String driverId, String vehicleId) {
    final vehicleIndex = _vehicles.indexWhere((v) => v.id == vehicleId);
    final driverIndex = _managedDrivers.indexWhere((d) => d.id == driverId);

    if (vehicleIndex != -1 && driverIndex != -1) {
      final driver = _managedDrivers[driverIndex];
      final vehicle = _vehicles[vehicleIndex];

      _vehicles[vehicleIndex] = vehicle.copyWith(
        assignedDriverId: driver.id,
        assignedDriverName: driver.name,
      );

      _managedDrivers[driverIndex] = driver.copyWith(
        assignedVehicleId: vehicle.id,
        assignedVehiclePlate: vehicle.plateNumber,
      );

      notifyListeners();
    }
  }

  void unassignDriver(String driverId) {
    final driverIndex = _managedDrivers.indexWhere((d) => d.id == driverId);
    if (driverIndex != -1) {
      final driver = _managedDrivers[driverIndex];
      final vehicleId = driver.assignedVehicleId;

      if (vehicleId != null) {
        final vehicleIndex = _vehicles.indexWhere((v) => v.id == vehicleId);
        if (vehicleIndex != -1) {
          _vehicles[vehicleIndex] = _vehicles[vehicleIndex].copyWith(
            assignedDriverId: null,
            assignedDriverName: null,
          );
        }
      }

      _managedDrivers[driverIndex] = driver.copyWith(
        assignedVehicleId: null,
        assignedVehiclePlate: null,
      );

      notifyListeners();
    }
  }

  // Booking / Logistics Lifecycle Actions
  void acceptBooking(String bookingId) {
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      _bookings[index] = _bookings[index].copyWith(status: 'Accepted');
      notifyListeners();
    }
  }

  void updateBookingStatus(String bookingId, String newStatus) {
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      _bookings[index] = _bookings[index].copyWith(status: newStatus);
      notifyListeners();
    }
  }

  // Revenue & Wallet Actions
  void requestPayout(double amount, String account) {
    if (_walletBalance >= amount) {
      _walletBalance -= amount;
      final newPayout = PayoutItem(
        id: 'PO-${DateTime.now().millisecondsSinceEpoch % 1000}',
        amount: amount,
        bankAccount: account,
        status: 'Processing',
        requestedDate: 'Just Now',
      );
      _payouts.insert(0, newPayout);
      _transactions.insert(
        0,
        WalletTransaction(
          id: 'TXN-${DateTime.now().millisecondsSinceEpoch % 10000}',
          title: 'Payout Request ($account)',
          amount: amount,
          type: 'debit',
          status: 'Pending',
          date: 'Just Now',
        ),
      );
      notifyListeners();
    }
  }

  void markNotificationRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index] = NotificationItem(
        id: _notifications[index].id,
        title: _notifications[index].title,
        body: _notifications[index].body,
        timestamp: _notifications[index].timestamp,
        isRead: true,
      );
      notifyListeners();
    }
  }
}
