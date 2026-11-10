enum ProviderStatus {
  pending,
  submitted,
  underReview,
  approved,
  rejected,
  expired,
  changesRequested,
  unknown,
}

ProviderStatus providerStatus(Object? value) =>
    switch (value?.toString().toUpperCase()) {
      'PENDING' => ProviderStatus.pending,
      'SUBMITTED' => ProviderStatus.submitted,
      'UNDER_REVIEW' => ProviderStatus.underReview,
      'APPROVED' || 'VERIFIED' => ProviderStatus.approved,
      'REJECTED' => ProviderStatus.rejected,
      'EXPIRED' => ProviderStatus.expired,
      'CHANGES_REQUESTED' => ProviderStatus.changesRequested,
      _ => ProviderStatus.unknown,
    };

String statusLabel(Object? value) => switch (providerStatus(value)) {
  ProviderStatus.pending => 'Pending review',
  ProviderStatus.submitted => 'Submitted for review',
  ProviderStatus.underReview => 'Under review',
  ProviderStatus.approved => 'Approved',
  ProviderStatus.rejected => 'Rejected',
  ProviderStatus.expired => 'Expired',
  ProviderStatus.changesRequested => 'Changes requested',
  ProviderStatus.unknown => value?.toString() ?? 'Not submitted',
};

String? rejectionReason(Map<String, dynamic> value) {
  final metadata =
      value['metadata'] as Map? ?? value['documentMetadata'] as Map?;
  return (value['rejectionReason'] ??
          value['rejection_reason'] ??
          metadata?['rejectionReason'] ??
          (metadata?['review'] as Map?)?['reason'])
      ?.toString();
}

String verificationRequestLabel(Object? type) {
  final key = type?.toString().toLowerCase().trim() ?? '';
  switch (key) {
    case 'fleet_verification':
      return 'Fleet Verification';
    case 'vehicle_verification':
      return 'Vehicle Verification';
    case 'driver_verification':
      return 'Driver Verification';
    case 'fleet_submission':
      return 'Fleet Submission';
    case 'partner_verification':
      return 'Partner Verification';
    case 'document_verification':
      return 'Document Verification';
    default:
      if (key.isEmpty) return 'Verification Request';
      return key
          .split(RegExp(r'[_-\s]+'))
          .where((s) => s.isNotEmpty)
          .map((s) => '${s[0].toUpperCase()}${s.substring(1)}')
          .join(' ');
  }
}

String verificationRequestDescription(Object? type) {
  final key = type?.toString().toLowerCase().trim() ?? '';
  switch (key) {
    case 'fleet_verification':
      return 'Review of fleet business credentials and organization documents.';
    case 'vehicle_verification':
      return 'Review of vehicle registration, insurance, fitness, and permit documents.';
    case 'driver_verification':
      return 'Review of driver identity, driving license, and background verification.';
    case 'fleet_submission':
      return 'Comprehensive fleet onboarding review submission.';
    case 'partner_verification':
      return 'Review of business partnership and entity verification documents.';
    case 'document_verification':
      return 'Review of supporting compliance and operational documents.';
    default:
      return 'Verification review request submitted for administrative approval.';
  }
}

String ledgerPeriodLabel(Object? period) {
  final key = period?.toString().toLowerCase().trim() ?? '';
  switch (key) {
    case 'daily':
      return 'Daily';
    case 'weekly':
      return 'Weekly';
    case 'monthly':
      return 'Monthly';
    case 'yearly':
      return 'Yearly';
    default:
      if (key.isEmpty) return 'Period';
      return key
          .split(RegExp(r'[_-\s]+'))
          .where((s) => s.isNotEmpty)
          .map((s) => '${s[0].toUpperCase()}${s.substring(1)}')
          .join(' ');
  }
}

String ledgerPeriodDescription(Object? period) {
  final key = period?.toString().toLowerCase().trim() ?? '';
  switch (key) {
    case 'daily':
      return 'Settlement transactions and earnings calculated for today.';
    case 'weekly':
      return 'Settlement transactions and earnings calculated for the current week.';
    case 'monthly':
      return 'Settlement transactions and earnings calculated for the current month.';
    default:
      return 'Settlement transactions and earnings summary for this period.';
  }
}
