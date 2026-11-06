class VehicleCategoryPolicy {
  static const _inventorySectors = {
    'passenger',
    'logistics',
    'service',
    'premium',
    'rental',
  };

  static const _allowedPairs = {
    // Logistics
    'logistics:cargo_207_heavy',
    'logistics:207_heavy',
    'logistics:three_wheeler',
    'logistics:three_wheeler_goods',
    'logistics:cargo_407',
    'logistics:mini_truck',
    'logistics:mini_truck_tata_ace',
    'logistics:tata_407',
    'logistics:tata_magic',
    'logistics:tata_207',
    'logistics:piaggio_ape',
    'logistics:pickup_8ft',
    // Service
    'service:ambulance',
    'service:towing',
    'service:jcb',
    // Premium
    'premium:thar',
    'premium:scorpio_n',
    'premium:innova_crysta',
    'premium:force_traveller',
    'premium:mercedes_v_class',
    // Rental
    'rental:thar',
    'rental:hatchback',
    'rental:sedan',
    'rental:innova_crysta',
    'rental:minicab',
  };

  static bool isSelectableSector(String? sector) =>
      _inventorySectors.contains(sector?.toLowerCase().trim());

  static bool allowsCode(String? sector, String? code) {
    if (!isSelectableSector(sector)) return false;
    final s = sector?.toLowerCase().trim() ?? '';
    final c = code?.toLowerCase().trim() ?? '';
    if (c.isEmpty) return false;
    if (s == 'passenger') return true;
    return _allowedPairs.contains('$s:$c');
  }
}
