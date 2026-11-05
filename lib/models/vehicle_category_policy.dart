class VehicleCategoryPolicy {
  static const _inventorySectors = {
    'passenger',
    'logistics',
    'service',
    'premium',
    'rental',
  };

  static bool isSelectableSector(String? sector) =>
      _inventorySectors.contains(sector?.toLowerCase().trim());

  // The catalog endpoint and vehicle write API own the configured code list.
  // In particular, chauffeured Rental uses existing passenger inventory.
  static bool allowsCode(String? sector, String? code) =>
      isSelectableSector(sector) && (code?.trim().isNotEmpty ?? false);
}
