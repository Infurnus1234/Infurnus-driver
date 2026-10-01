import 'dart:async';
import '../models/location_model.dart';

class LocationCatalogRepository {
  static const List<LocationItem> _locations = [
    LocationItem(
      id: 'LOC-1',
      name: 'Electronic City Phase 1',
      address: 'Hosur Road, Near Wipro Gate 1',
      city: 'Bangalore',
      landmark: 'IT Industrial Park',
      latitude: 12.8452,
      longitude: 77.6602,
    ),
    LocationItem(
      id: 'LOC-2',
      name: 'Electronic City Phase 2',
      address: 'Tech Mahindra SEZ Road',
      city: 'Bangalore',
      landmark: 'TCS Campus',
      latitude: 12.8398,
      longitude: 77.6782,
    ),
    LocationItem(
      id: 'LOC-3',
      name: 'Whitefield Industrial Area',
      address: 'ITPL Main Road, Hoodi',
      city: 'Bangalore',
      landmark: 'Export Promotion Industrial Park',
      latitude: 12.9854,
      longitude: 77.7289,
    ),
    LocationItem(
      id: 'LOC-4',
      name: 'Koramangala 5th Block',
      address: '100ft Intermediate Ring Road',
      city: 'Bangalore',
      landmark: 'Jyoti Nivas College Circle',
      latitude: 12.9348,
      longitude: 77.6200,
    ),
    LocationItem(
      id: 'LOC-5',
      name: 'Kempegowda International Airport (BLR)',
      address: 'KIAL Road, Devanahalli',
      city: 'Bangalore',
      landmark: 'Terminal 1 & 2 Cargo Gate',
      latitude: 13.1986,
      longitude: 77.7066,
    ),
    LocationItem(
      id: 'LOC-6',
      name: 'Indiranagar 100ft Road',
      address: '12th Main Junction, Near Metro',
      city: 'Bangalore',
      landmark: 'Indiranagar Metro Station',
      latitude: 12.9784,
      longitude: 77.6408,
    ),
    LocationItem(
      id: 'LOC-7',
      name: 'M.G. Road Metro Station',
      address: 'Brigade Road Junction',
      city: 'Bangalore',
      landmark: 'Utility Building Circle',
      latitude: 12.9756,
      longitude: 77.6066,
    ),
    LocationItem(
      id: 'LOC-8',
      name: 'Peenya Industrial Estate',
      address: '1st Stage, Tumkur Road',
      city: 'Bangalore',
      landmark: 'Peenya Metro Station Hub',
      latitude: 13.0285,
      longitude: 77.5197,
    ),
    LocationItem(
      id: 'LOC-9',
      name: 'Hebbal Flyover Junction',
      address: 'Bellary Road, Outer Ring Road',
      city: 'Bangalore',
      landmark: 'Manyata Tech Park Gate',
      latitude: 13.0359,
      longitude: 77.5970,
    ),
    LocationItem(
      id: 'LOC-10',
      name: 'Silk Board Junction',
      address: 'Hosur Road & BTM Layout Border',
      city: 'Bangalore',
      landmark: 'Central Silk Board Flyover',
      latitude: 12.9172,
      longitude: 77.6228,
    ),
    LocationItem(
      id: 'LOC-11',
      name: 'Yeshwanthpur Railway Station',
      address: 'Market Road, Yeshwanthpur',
      city: 'Bangalore',
      landmark: 'Platform 1 Cargo Gate',
      latitude: 13.0238,
      longitude: 77.5510,
    ),
    LocationItem(
      id: 'LOC-12',
      name: 'Majestic KSR Bengaluru City Station',
      address: 'Gubbi Thotadappa Road',
      city: 'Bangalore',
      landmark: 'KSRTC Bus Stand',
      latitude: 12.9781,
      longitude: 77.5697,
    ),
  ];

  static List<LocationItem> get allLocations => List.unmodifiable(_locations);

  /// Asynchronous map location search with partial matching & debouncing.
  Future<List<LocationItem>> searchLocations(String query) async {
    final cleanQuery = query.trim().toLowerCase();
    
    // Simulate async map network API query
    await Future.delayed(const Duration(milliseconds: 150));

    if (cleanQuery.isEmpty) {
      return _locations;
    }

    return _locations.where((loc) {
      final nameMatch = loc.name.toLowerCase().contains(cleanQuery);
      final addrMatch = loc.address.toLowerCase().contains(cleanQuery);
      final landmarkMatch = loc.landmark.toLowerCase().contains(cleanQuery);
      final cityMatch = loc.city.toLowerCase().contains(cleanQuery);
      return nameMatch || addrMatch || landmarkMatch || cityMatch;
    }).toList();
  }
}
