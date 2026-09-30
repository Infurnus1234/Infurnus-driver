import 'dart:async';
import '../models/vehicle_catalog_model.dart';

class VehicleCatalogRepository {
  // Comprehensive Vehicle Catalog Database
  static const List<VehicleCatalogItem> _catalog = [
    VehicleCatalogItem(id: 'CAT-1', brand: 'Maruti Suzuki', modelName: 'Alto', category: 'Hatchback', fuelType: 'Petrol', payloadCapacity: '350 kg'),
    VehicleCatalogItem(id: 'CAT-2', brand: 'Maruti Suzuki', modelName: 'Alto K10', category: 'Hatchback', fuelType: 'Petrol/CNG', payloadCapacity: '380 kg'),
    VehicleCatalogItem(id: 'CAT-3', brand: 'Maruti Suzuki', modelName: 'Alto 800', category: 'Hatchback', fuelType: 'CNG', payloadCapacity: '350 kg'),
    VehicleCatalogItem(id: 'CAT-4', brand: 'Toyota', modelName: 'Fortuner', category: 'SUV', fuelType: 'Diesel', payloadCapacity: '650 kg'),
    VehicleCatalogItem(id: 'CAT-5', brand: 'Ford', modelName: 'EcoSport', category: 'SUV', fuelType: 'Petrol', payloadCapacity: '450 kg'),
    VehicleCatalogItem(id: 'CAT-6', brand: 'Ford', modelName: 'Endeavour', category: 'SUV', fuelType: 'Diesel', payloadCapacity: '700 kg'),
    VehicleCatalogItem(id: 'CAT-7', brand: 'Ford', modelName: 'Transit Van', category: 'Van', fuelType: 'Diesel', payloadCapacity: '1200 kg'),
    VehicleCatalogItem(id: 'CAT-8', brand: 'Tata Motors', modelName: 'Tata Ace EV Truck', category: 'Truck', fuelType: 'Electric', payloadCapacity: '600 kg'),
    VehicleCatalogItem(id: 'CAT-9', brand: 'Tata Motors', modelName: 'Tata Ace Gold', category: 'Truck', fuelType: 'Diesel', payloadCapacity: '750 kg'),
    VehicleCatalogItem(id: 'CAT-10', brand: 'Tata Motors', modelName: 'Tata Intra V30', category: 'Truck', fuelType: 'Diesel', payloadCapacity: '1300 kg'),
    VehicleCatalogItem(id: 'CAT-11', brand: 'Mahindra', modelName: 'Bolero Maxi Truck', category: 'Container', fuelType: 'Diesel', payloadCapacity: '1500 kg'),
    VehicleCatalogItem(id: 'CAT-12', brand: 'Mahindra', modelName: 'Supro Profit Truck', category: 'Truck', fuelType: 'CNG', payloadCapacity: '900 kg'),
    VehicleCatalogItem(id: 'CAT-13', brand: 'Mahindra', modelName: 'Zor Grand Cargo', category: 'Truck', fuelType: 'Electric', payloadCapacity: '500 kg'),
    VehicleCatalogItem(id: 'CAT-14', brand: 'Ashok Leyland', modelName: 'Bada Dost i3', category: 'Truck', fuelType: 'Diesel', payloadCapacity: '1400 kg'),
    VehicleCatalogItem(id: 'CAT-15', brand: 'Ashok Leyland', modelName: 'Dost LiTE', category: 'Truck', fuelType: 'Diesel', payloadCapacity: '1250 kg'),
    VehicleCatalogItem(id: 'CAT-16', brand: 'Hyundai', modelName: 'Grand i10 Nios', category: 'Hatchback', fuelType: 'Petrol/CNG', payloadCapacity: '390 kg'),
    VehicleCatalogItem(id: 'CAT-17', brand: 'Hyundai', modelName: 'i20', category: 'Hatchback', fuelType: 'Petrol', payloadCapacity: '400 kg'),
    VehicleCatalogItem(id: 'CAT-18', brand: 'Hyundai', modelName: 'Creta', category: 'SUV', fuelType: 'Diesel', payloadCapacity: '550 kg'),
    VehicleCatalogItem(id: 'CAT-19', brand: 'Maruti Suzuki', modelName: 'WagonR', category: 'Hatchback', fuelType: 'CNG', payloadCapacity: '400 kg'),
    VehicleCatalogItem(id: 'CAT-20', brand: 'Maruti Suzuki', modelName: 'Swift Dzire Tour', category: 'Sedan', fuelType: 'CNG', payloadCapacity: '450 kg'),
    VehicleCatalogItem(id: 'CAT-21', brand: 'Maruti Suzuki', modelName: 'Ertiga Commercial', category: 'Van', fuelType: 'CNG', payloadCapacity: '600 kg'),
    VehicleCatalogItem(id: 'CAT-22', brand: 'Eicher', modelName: 'Pro 2049 Light Truck', category: 'Container', fuelType: 'Diesel', payloadCapacity: '2500 kg'),
  ];

  static List<VehicleCatalogItem> get allVehicles => List.unmodifiable(_catalog);

  /// Asynchronous search with simulated network latency & debouncing support.
  /// Matches brand name, model name, or category case-insensitively.
  Future<List<VehicleCatalogItem>> searchVehicles(String query) async {
    final cleanQuery = query.trim().toLowerCase();
    
    // Simulate slight async lookup delay
    await Future.delayed(const Duration(milliseconds: 150));

    if (cleanQuery.isEmpty) {
      return _catalog;
    }

    return _catalog.where((item) {
      final brandMatch = item.brand.toLowerCase().contains(cleanQuery);
      final modelMatch = item.modelName.toLowerCase().contains(cleanQuery);
      final fullNameMatch = item.fullName.toLowerCase().contains(cleanQuery);
      final categoryMatch = item.category.toLowerCase().contains(cleanQuery);
      return brandMatch || modelMatch || fullNameMatch || categoryMatch;
    }).toList();
  }
}
