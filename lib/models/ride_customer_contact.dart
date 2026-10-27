class RideCustomerContact {
  final String rideId;
  final String name;
  final String? phone;
  const RideCustomerContact({
    required this.rideId,
    required this.name,
    this.phone,
  });

  factory RideCustomerContact.fromJson(Map data, String expectedRideId) {
    if (data['rideId'] != expectedRideId || data['name'] is! String) {
      throw const FormatException('Invalid ride contact response');
    }
    final phone = data['phone'];
    if (phone != null &&
        (phone is! String || !RegExp(r'^\+?[1-9]\d{7,14}$').hasMatch(phone))) {
      throw const FormatException('Invalid customer phone number');
    }
    return RideCustomerContact(
      rideId: expectedRideId,
      name: (data['name'] as String).trim(),
      phone: phone as String?,
    );
  }
}
