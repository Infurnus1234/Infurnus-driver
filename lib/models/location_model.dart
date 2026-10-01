class LocationItem {
  final String id;
  final String name;
  final String address;
  final String city;
  final String landmark;
  final double latitude;
  final double longitude;

  const LocationItem({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.landmark,
    required this.latitude,
    required this.longitude,
  });

  String get fullAddress => '$name, $address, $city';
}
