import 'dart:async';

import '../models/vehicle_catalog_model.dart';

class VehicleCatalogRepository {
  // Catalog for the legacy searchable vehicle-entry flow.
  static const List<VehicleCatalogItem> _catalog = [
    // Passenger Rides
    VehicleCatalogItem(
      id: 'CAT-PASS-1',
      brand: 'Maruti Suzuki',
      modelName: 'WagonR (Mini Cab)',
      category: 'Passenger',
      fuelType: 'Petrol/CNG',
      payloadCapacity: '350 kg',
    ),
    VehicleCatalogItem(
      id: 'CAT-PASS-2',
      brand: 'Toyota',
      modelName: 'Etios (Sedan)',
      category: 'Passenger',
      fuelType: 'Diesel',
      payloadCapacity: '450 kg',
    ),
    VehicleCatalogItem(
      id: 'CAT-PASS-3',
      brand: 'Toyota',
      modelName: 'Fortuner (SUV)',
      category: 'Passenger',
      fuelType: 'Diesel',
      payloadCapacity: '650 kg',
    ),
    // Trip Vehicle
    VehicleCatalogItem(
      id: 'CAT-LOG-1',
      brand: 'Tata',
      modelName: '207 Heavy',
      category: 'Logistics',
      fuelType: 'Diesel',
      payloadCapacity: '1100 kg',
    ),
    VehicleCatalogItem(
      id: 'CAT-LOG-2',
      brand: 'Piaggio',
      modelName: '3-Wheeler (Goods)',
      category: 'Logistics',
      fuelType: 'CNG/Electric',
      payloadCapacity: '500 kg',
    ),
    VehicleCatalogItem(
      id: 'CAT-LOG-3',
      brand: 'Tata',
      modelName: '407 Cargo',
      category: 'Logistics',
      fuelType: 'Diesel',
      payloadCapacity: '2200 kg',
    ),
    VehicleCatalogItem(
      id: 'CAT-LOG-4',
      brand: 'Tata',
      modelName: 'Mini Truck (Tata Ace)',
      category: 'Logistics',
      fuelType: 'Diesel/Electric',
      payloadCapacity: '750 kg',
    ),
    VehicleCatalogItem(
      id: 'CAT-LOG-5',
      brand: 'Tata',
      modelName: 'Tata 407',
      category: 'Logistics',
      fuelType: 'Diesel',
      payloadCapacity: '2500 kg',
    ),

    // Service Vehicles
    VehicleCatalogItem(
      id: 'CAT-SERV-1',
      brand: 'Force',
      modelName: 'Ambulance',
      category: 'Service',
      fuelType: 'Diesel',
      payloadCapacity: '1000 kg',
    ),

    // Premium & Rentals
    VehicleCatalogItem(
      id: 'CAT-PREM-1',
      brand: 'Mahindra',
      modelName: 'Mahindra Thar',
      category: 'Premium',
      fuelType: 'Diesel/Petrol',
      payloadCapacity: '500 kg',
    ),
  ];

  static List<VehicleCatalogItem> get allVehicles =>
      List.unmodifiable(_catalog);

  /// Asynchronous search with simulated network latency & debouncing support.
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
