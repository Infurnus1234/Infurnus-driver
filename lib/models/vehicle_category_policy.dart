class VehicleCategoryPolicy {
  static const Map<String, Set<String>> vehicleCodesBySector = {
    'logistics': {
      'cargo_207_heavy',
      'three_wheeler',
      'cargo_407',
      'mini_truck',
      'tata_407',
    },
    'service': {'ambulance'},
    'premium': {'thar'},
    'rental': {'thar'},
  };

  static bool isSelectableSector(String? sector) =>
      sector != null &&
      !['passenger', 'passengers'].contains(sector.toLowerCase().trim());

  static bool allowsCode(String? sector, String? code) {
    if (!isSelectableSector(sector) || sector == null || code == null) {
      return false;
    }
    final sec = sector.toLowerCase().trim();
    final c = code.toLowerCase().trim();
    final approvedCodes = vehicleCodesBySector[sec];
    return approvedCodes != null && approvedCodes.contains(c);
  }
}
