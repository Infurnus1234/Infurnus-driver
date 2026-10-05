enum UserRole {
  driver,
  fleetOwner,
  driverFleetOwner,
  vendor,
  admin,
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.driver:
        return 'Driver';
      case UserRole.fleetOwner:
        return 'Fleet Owner';
      case UserRole.driverFleetOwner:
        return 'Driver + Fleet Owner';
      case UserRole.vendor:
        return 'Business Vendor';
      case UserRole.admin:
        return 'Admin / Super Admin';
    }
  }
}

enum ActiveMode {
  driverMode,
  fleetOwnerMode,
}

enum VerificationStatus {
  draft,
  documentsSubmitted,
  underReview,
  approved,
  rejected,
  changesRequired,
}

extension VerificationStatusExtension on VerificationStatus {
  String get label {
    switch (this) {
      case VerificationStatus.draft:
        return 'Draft';
      case VerificationStatus.documentsSubmitted:
        return 'Submitted';
      case VerificationStatus.underReview:
        return 'Under Review';
      case VerificationStatus.approved:
        return 'Approved';
      case VerificationStatus.rejected:
        return 'Rejected';
      case VerificationStatus.changesRequired:
        return 'Changes Required';
    }
  }
}

class DocumentItem {
  final String id;
  final String name;
  final String type;
  final String? fileUrl;
  final String status; // 'Pending', 'Approved', 'Rejected'
  final String? rejectionReason;
  final String? uploadedAt;

  DocumentItem({
    required this.id,
    required this.name,
    required this.type,
    this.fileUrl,
    this.status = 'Pending',
    this.rejectionReason,
    this.uploadedAt,
  });

  DocumentItem copyWith({
    String? id,
    String? name,
    String? type,
    String? fileUrl,
    String? status,
    String? rejectionReason,
    String? uploadedAt,
  }) {
    return DocumentItem(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      fileUrl: fileUrl ?? this.fileUrl,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      uploadedAt: uploadedAt ?? this.uploadedAt,
    );
  }
}

class UserProfile {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String? dob;
  final String? address;
  final String? photoUrl;
  final UserRole role;
  final VerificationStatus verificationStatus;
  final String? businessName;
  final String? businessAddress;
  final String? vehicleInformation;
  final String? vehicleNumber;
  final String? vehicleType;
  final String? rejectionReason;
  final List<DocumentItem> documents;
  final String? assignedVehicleId;
  final List<String> verificationTimestamps;
  final List<String> verificationHistory;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    this.dob,
    this.address,
    this.photoUrl,
    required this.role,
    this.verificationStatus = VerificationStatus.draft,
    this.businessName,
    this.businessAddress,
    this.vehicleInformation,
    this.vehicleNumber,
    this.vehicleType,
    this.rejectionReason,
    this.documents = const [],
    this.assignedVehicleId,
    this.verificationTimestamps = const [],
    this.verificationHistory = const ['Draft created on 01 Oct 2026'],
  });

  UserProfile copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    String? dob,
    String? address,
    String? photoUrl,
    UserRole? role,
    VerificationStatus? verificationStatus,
    String? businessName,
    String? businessAddress,
    String? vehicleInformation,
    String? vehicleNumber,
    String? vehicleType,
    String? rejectionReason,
    List<DocumentItem>? documents,
    String? assignedVehicleId,
    List<String>? verificationTimestamps,
    List<String>? verificationHistory,
  }) {
    return UserProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      dob: dob ?? this.dob,
      address: address ?? this.address,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      businessName: businessName ?? this.businessName,
      businessAddress: businessAddress ?? this.businessAddress,
      vehicleInformation: vehicleInformation ?? this.vehicleInformation,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      documents: documents ?? this.documents,
      assignedVehicleId: assignedVehicleId ?? this.assignedVehicleId,
      verificationTimestamps: verificationTimestamps ?? this.verificationTimestamps,
      verificationHistory: verificationHistory ?? this.verificationHistory,
    );
  }
}

class VehicleModel {
  final String id;
  final String plateNumber;
  final String modelName;
  final String category; // 'Sedan', 'Truck', 'Van', 'Container'
  final String ownerId;
  final String? assignedDriverId;
  final String? assignedDriverName;
  final String verificationStatus; // 'Under Review', 'Approved', 'Rejected'
  final bool isActive;
  final List<DocumentItem> documents;

  VehicleModel({
    required this.id,
    required this.plateNumber,
    required this.modelName,
    required this.category,
    required this.ownerId,
    this.assignedDriverId,
    this.assignedDriverName,
    this.verificationStatus = 'Under Review',
    this.isActive = true,
    this.documents = const [],
  });

  VehicleModel copyWith({
    String? id,
    String? plateNumber,
    String? modelName,
    String? category,
    String? ownerId,
    String? assignedDriverId,
    String? assignedDriverName,
    String? verificationStatus,
    bool? isActive,
    List<DocumentItem>? documents,
  }) {
    return VehicleModel(
      id: id ?? this.id,
      plateNumber: plateNumber ?? this.plateNumber,
      modelName: modelName ?? this.modelName,
      category: category ?? this.category,
      ownerId: ownerId ?? this.ownerId,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      assignedDriverName: assignedDriverName ?? this.assignedDriverName,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      isActive: isActive ?? this.isActive,
      documents: documents ?? this.documents,
    );
  }
}

class ManagedDriverModel {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String applicationStatus; // 'Pending Review', 'Approved', 'Rejected', 'Changes Requested'
  final String? assignedVehicleId;
  final String? assignedVehiclePlate;
  final String? photoUrl;
  final String? rejectionReason;

  ManagedDriverModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    this.applicationStatus = 'Pending Review',
    this.assignedVehicleId,
    this.assignedVehiclePlate,
    this.photoUrl,
    this.rejectionReason,
  });

  ManagedDriverModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? applicationStatus,
    String? assignedVehicleId,
    String? assignedVehiclePlate,
    String? photoUrl,
    String? rejectionReason,
  }) {
    return ManagedDriverModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      applicationStatus: applicationStatus ?? this.applicationStatus,
      assignedVehicleId: assignedVehicleId ?? this.assignedVehicleId,
      assignedVehiclePlate: assignedVehiclePlate ?? this.assignedVehiclePlate,
      photoUrl: photoUrl ?? this.photoUrl,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}

class BookingModel {
  final String id;
  final String bookingType; // 'Ride', 'Parcel', 'Logistics'
  final String pickupLocation;
  final String dropoffLocation;
  final String customerName;
  final String customerPhone;
  final double distanceKm;
  final double fareAmount;
  final String status; // 'Pending', 'Accepted', 'In Transit', 'Goods Picked Up', 'Delivered', 'Cancelled'
  final String? goodsDescription;
  final String? routeDetails;
  final String createdAt;

  BookingModel({
    required this.id,
    required this.bookingType,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.customerName,
    required this.customerPhone,
    required this.distanceKm,
    required this.fareAmount,
    this.status = 'Pending',
    this.goodsDescription,
    this.routeDetails,
    required this.createdAt,
  });

  // 10% Commission Calculation Helpers (Server-authoritative final fare based)
  double get commissionAmount => fareAmount * 0.10;
  double get driverNetEarning => fareAmount * 0.90;

  int get fareAmountPaise => (fareAmount * 100).round();
  int get commissionPaise => (fareAmountPaise * 0.10).round();
  int get driverNetEarningPaise => fareAmountPaise - commissionPaise;

  BookingModel copyWith({
    String? id,
    String? bookingType,
    String? pickupLocation,
    String? dropoffLocation,
    String? customerName,
    String? customerPhone,
    double? distanceKm,
    double? fareAmount,
    String? status,
    String? goodsDescription,
    String? routeDetails,
    String? createdAt,
  }) {
    return BookingModel(
      id: id ?? this.id,
      bookingType: bookingType ?? this.bookingType,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      distanceKm: distanceKm ?? this.distanceKm,
      fareAmount: fareAmount ?? this.fareAmount,
      status: status ?? this.status,
      goodsDescription: goodsDescription ?? this.goodsDescription,
      routeDetails: routeDetails ?? this.routeDetails,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class WalletTransaction {
  final String id;
  final String title;
  final double amount;
  final String type; // 'credit', 'debit'
  final String status; // 'Completed', 'Pending', 'Failed'
  final String date;

  WalletTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.status,
    required this.date,
  });
}

class PayoutItem {
  final String id;
  final double amount;
  final String bankAccount;
  final String status; // 'Processing', 'Settled', 'Failed'
  final String requestedDate;

  PayoutItem({
    required this.id,
    required this.amount,
    required this.bankAccount,
    required this.status,
    required this.requestedDate,
  });
}

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final String timestamp;
  final bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
  });
}
