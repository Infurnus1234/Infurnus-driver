import 'dart:async';

import '../models/vehicle_catalog_model.dart';

class VehicleCatalogRepository {
  // Comprehensive Vehicle Catalog Database updated with Auto Rickshaw, E-Rickshaw, Passenger, Trip, Logistic, and Premium vehicles
  static const List<VehicleCatalogItem> _catalog = [
    // Auto Rickshaw & 3-Wheeler / E-Rickshaw
    VehicleCatalogItem(
      id: 'CAT-AUTO-1',
      brand: 'Bajaj',
      modelName: 'Compact Auto (CNG)',
      category: 'Auto Rickshaw',
      fuelType: 'CNG',
      payloadCapacity: '350 kg',
    ),
    VehicleCatalogItem(
      id: 'CAT-AUTO-2',
      brand: 'Mahindra',
      modelName: 'Treo Electric Auto',
      category: 'Auto Rickshaw',
      fuelType: 'Electric',
      payloadCapacity: '400 kg',
    ),
    VehicleCatalogItem(
      id: 'CAT-AUTO-3',
      brand: 'Piaggio',
      modelName: 'Ape City (LPG/CNG)',
      category: 'Auto Rickshaw',
      fuelType: 'LPG/CNG',
      payloadCapacity: '380 kg',
    ),
    VehicleCatalogItem(
      id: 'CAT-AUTO-4',
      brand: 'TVS',
      modelName: 'King Deluxe',
      category: 'Auto Rickshaw',
      fuelType: 'Petrol/CNG',
      payloadCapacity: '350 kg',
    ),
    VehicleCatalogItem(
      id: 'CAT-P1',
      brand: 'Electric',
      modelName: 'E-Rickshaw',
      category: 'Passenger',
      fuelType: 'Electric',
      payloadCapacity: '400 kg',
    ),

    // Trip Vehicle
    VehicleCatalogItem(
      id: 'CAT-T1',
      brand: 'Force',
      modelName: 'Force Traveller',
      category: 'Trip Vehicle',
      fuelType: 'Diesel',
      payloadCapacity: '1500 kg',
    ),
    VehicleCatalogItem(
      id: 'CAT-T2',
      brand: 'Tata',
      modelName: 'Winger',
      category: 'Trip Vehicle',
      fuelType: 'Diesel',
      payloadCapacity: '1200 kg',
    ),

    // Logistic & Cargo
    VehicleCatalogItem(
      id: 'CAT-L1',
      brand: 'Piaggio',
      modelName: 'Piaggio Ape Cargo',
      category: 'Logistic',
      fuelType: 'CNG/Diesel',
      payloadCapacity: '500 kg',
    ),
    VehicleCatalogItem(
      id: 'CAT-L2',
      brand: 'Tata',
      modelName: 'Tata Ace EV',
      category: 'Logistic',
      fuelType: 'Electric',
      payloadCapacity: '750 kg',
    ),
    VehicleCatalogItem(
      id: 'CAT-L3',
      brand: 'Tata',
      modelName: '207',
      category: 'Logistic',
      fuelType: 'Diesel',
      payloadCapacity: '1100 kg',
    ),
    VehicleCatalogItem(
      id: 'CAT-L4',
      brand: 'Tata',
      modelName: '407',
      category: 'Logistic',
      fuelType: 'Diesel',
      payloadCapacity: '2200 kg',
    ),

    // Premium Vehicle
    VehicleCatalogItem(
      id: 'CAT-PR1',
      brand: 'Mahindra',
      modelName: 'Scorpio N',
      category: 'Premium Vehicle',
      fuelType: 'Diesel/Petrol',
      payloadCapacity: '600 kg',
    ),

    // Additional popular models
    VehicleCatalogItem(
      id: 'CAT-1',
      brand: 'Maruti Suzuki',
      modelName: 'Alto',
      category: 'Hatchback',
      fuelType: 'Petrol',
      payloadCapacity: '350 kg',
    ),
    VehicleCatalogItem(
      id: 'CAT-2',
      brand: 'Maruti Suzuki',
      modelName: 'Alto K10',
      category: 'Hatchback',
      fuelType: 'Petrol/CNG',
      payloadCapacity: '380 kg',
    ),
    VehicleCatalogItem(
      id: 'CAT-4',
      brand: 'Toyota',
      modelName: 'Fortuner',
      category: 'SUV',
      fuelType: 'Diesel',
      payloadCapacity: '650 kg',
    ),
    VehicleCatalogItem(
      id: 'CAT-5',
      brand: 'Ford',
      modelName: 'EcoSport',
      category: 'SUV',
      fuelType: 'Petrol',
      payloadCapacity: '450 kg',
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
      return [];
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
