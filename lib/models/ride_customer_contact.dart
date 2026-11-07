class RideCustomerContact {
  final String rideId;
  final String name;
  final String? phone;
  final String? callingNumber;
  const RideCustomerContact({
    required this.rideId,
    required this.name,
    this.phone,
    this.callingNumber,
  });

  factory RideCustomerContact.fromJson(Map data, String expectedRideId) {
    if (data['rideId'] != expectedRideId || data['name'] is! String) {
      throw const FormatException('Invalid ride contact response');
    }
    // Never retain a peer phone returned by an outdated backend.
    final callingNumber = data['callingNumber'];
    if (callingNumber != null && (callingNumber is! String || !RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(callingNumber))) {
      throw const FormatException('Invalid calling configuration');
    }
    return RideCustomerContact(
      rideId: expectedRideId,
      name: (data['name'] as String).trim(),
      phone: null,
      callingNumber: callingNumber as String?,
    );
  }
}
