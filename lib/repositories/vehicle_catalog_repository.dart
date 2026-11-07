import '../models/vehicle_catalog_model.dart';
import '../services/api_service.dart';

class VehicleCatalogRepository {
  final ApiService api;
  VehicleCatalogRepository({required this.api});

  /// Each Add Vehicle opening fetches the authoritative backend selection catalog.
  /// Old servers without this contract fail closed rather than resurfacing legacy lists.
  Future<Map<String, dynamic>> loadCatalog() async {
    final raw = await api.request('GET', '/provider/vehicle-catalog');
    if (raw is! Map ||
        raw['selectionCatalogVersion'] != 2 ||
        raw['types'] is! List ||
        raw['sectors'] is! List) {
      throw const FormatException(
        'The vehicle selection catalog requires a backend update.',
      );
    }
    final types = (raw['types'] as List)
        .cast<Map>()
        .where(
          (type) =>
              type['catalogVisible'] == true &&
              type['registrationActive'] == true,
        )
        .toList();
    return {...Map<String, dynamic>.from(raw), 'types': types};
  }

  Future<List<VehicleCatalogItem>> searchVehicles(String query) async {
    final data = await loadCatalog();
    final term = query.trim().toLowerCase();
    final seen = <String>{};
    return (data['types'] as List)
        .cast<Map>()
        .where((type) => type['catalogVisible'] == true)
        .where((type) => seen.add('${type['sector']}:${type['code']}'))
        .where(
          (type) => '${type['name']} ${type['sector']} ${type['code']}'
              .toLowerCase()
              .contains(term),
        )
        .map(
          (type) => VehicleCatalogItem(
            id: type['id'].toString(),
            brand: '',
            modelName: type['name'].toString(),
            category: type['sector'].toString(),
            fuelType: '',
            payloadCapacity: '',
          ),
        )
        .toList();
  }
}
