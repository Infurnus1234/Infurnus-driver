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
