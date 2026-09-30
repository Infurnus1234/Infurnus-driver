class VehicleCatalogItem {
  final String id;
  final String brand;
  final String modelName;
  final String category; // 'Sedan', 'Truck', 'Van', 'Container', 'Hatchback', 'SUV'
  final String fuelType; // 'Electric', 'Diesel', 'CNG', 'Petrol'
  final String payloadCapacity;

  const VehicleCatalogItem({
    required this.id,
    required this.brand,
    required this.modelName,
    required this.category,
    required this.fuelType,
    required this.payloadCapacity,
  });

  String get fullName => '$brand $modelName';
}
