class VehicleCategoryPolicy {
  static const Map<String, Set<String>> vehicleTypesBySector = {
    'logistics': {
      '3-Wheeler (Goods)',
      'Mini Truck (Tata Ace)',
      'Pickup 8ft',
      'Tata 407',
    },
  };

  static bool isSelectableSector(String? sector) =>
      sector == null || sector.toLowerCase() != 'passenger';

  static bool allowsType(String? sector, String? typeName) {
    if (!isSelectableSector(sector)) return false;
    final approvedTypes = vehicleTypesBySector[sector?.toLowerCase()];
    return approvedTypes == null || approvedTypes.contains(typeName);
  }
}
