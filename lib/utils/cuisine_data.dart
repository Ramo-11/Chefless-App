/// Comprehensive cuisine data organized by region with country flags.
///
/// Used across onboarding, recipe creation, filtering, and the globe screen.

class CuisineItem {
  const CuisineItem(this.name, this.flag);

  final String name;
  final String flag;
}

class CuisineRegion {
  const CuisineRegion(this.name, this.cuisines);

  final String name;
  final List<CuisineItem> cuisines;
}

/// Quick-pick cuisines shown at the top for fast selection.
const quickPickCuisines = [
  CuisineItem('Italian', '🇮🇹'),
  CuisineItem('Mexican', '🇲🇽'),
  CuisineItem('Japanese', '🇯🇵'),
  CuisineItem('Indian', '🇮🇳'),
  CuisineItem('American', '🇺🇸'),
];

/// All cuisines organized by region.
const cuisineRegions = [
  CuisineRegion('Middle East & North Africa', [
    CuisineItem('Lebanese', '🇱🇧'),
    CuisineItem('Palestinian', '🇵🇸'),
    CuisineItem('Syrian', '🇸🇾'),
    CuisineItem('Egyptian', '🇪🇬'),
    CuisineItem('Moroccan', '🇲🇦'),
    CuisineItem('Turkish', '🇹🇷'),
    CuisineItem('Iraqi', '🇮🇶'),
    CuisineItem('Jordanian', '🇯🇴'),
    CuisineItem('Saudi', '🇸🇦'),
    CuisineItem('Yemeni', '🇾🇪'),
    CuisineItem('Emirati', '🇦🇪'),
    CuisineItem('Tunisian', '🇹🇳'),
    CuisineItem('Algerian', '🇩🇿'),
    CuisineItem('Persian', '🇮🇷'),
  ]),
  CuisineRegion('East & Southeast Asia', [
    CuisineItem('Japanese', '🇯🇵'),
    CuisineItem('Chinese', '🇨🇳'),
    CuisineItem('Korean', '🇰🇷'),
    CuisineItem('Thai', '🇹🇭'),
    CuisineItem('Vietnamese', '🇻🇳'),
    CuisineItem('Filipino', '🇵🇭'),
    CuisineItem('Indonesian', '🇮🇩'),
    CuisineItem('Malaysian', '🇲🇾'),
    CuisineItem('Singaporean', '🇸🇬'),
    CuisineItem('Taiwanese', '🇹🇼'),
    CuisineItem('Cambodian', '🇰🇭'),
    CuisineItem('Burmese', '🇲🇲'),
  ]),
  CuisineRegion('South Asia', [
    CuisineItem('Indian', '🇮🇳'),
    CuisineItem('Pakistani', '🇵🇰'),
    CuisineItem('Sri Lankan', '🇱🇰'),
    CuisineItem('Bangladeshi', '🇧🇩'),
    CuisineItem('Nepali', '🇳🇵'),
    CuisineItem('Afghan', '🇦🇫'),
  ]),
  CuisineRegion('Europe', [
    CuisineItem('Italian', '🇮🇹'),
    CuisineItem('French', '🇫🇷'),
    CuisineItem('Spanish', '🇪🇸'),
    CuisineItem('Greek', '🇬🇷'),
    CuisineItem('Portuguese', '🇵🇹'),
    CuisineItem('German', '🇩🇪'),
    CuisineItem('British', '🇬🇧'),
    CuisineItem('Polish', '🇵🇱'),
    CuisineItem('Swedish', '🇸🇪'),
    CuisineItem('Hungarian', '🇭🇺'),
    CuisineItem('Dutch', '🇳🇱'),
    CuisineItem('Swiss', '🇨🇭'),
    CuisineItem('Austrian', '🇦🇹'),
    CuisineItem('Belgian', '🇧🇪'),
    CuisineItem('Russian', '🇷🇺'),
    CuisineItem('Ukrainian', '🇺🇦'),
    CuisineItem('Georgian', '🇬🇪'),
  ]),
  CuisineRegion('Americas', [
    CuisineItem('American', '🇺🇸'),
    CuisineItem('Mexican', '🇲🇽'),
    CuisineItem('Brazilian', '🇧🇷'),
    CuisineItem('Peruvian', '🇵🇪'),
    CuisineItem('Argentine', '🇦🇷'),
    CuisineItem('Colombian', '🇨🇴'),
    CuisineItem('Cuban', '🇨🇺'),
    CuisineItem('Jamaican', '🇯🇲'),
    CuisineItem('Canadian', '🇨🇦'),
    CuisineItem('Chilean', '🇨🇱'),
    CuisineItem('Venezuelan', '🇻🇪'),
    CuisineItem('Puerto Rican', '🇵🇷'),
    CuisineItem('Salvadoran', '🇸🇻'),
    CuisineItem('Haitian', '🇭🇹'),
    CuisineItem('Trinidadian', '🇹🇹'),
  ]),
  CuisineRegion('Africa', [
    CuisineItem('Ethiopian', '🇪🇹'),
    CuisineItem('Nigerian', '🇳🇬'),
    CuisineItem('South African', '🇿🇦'),
    CuisineItem('Ghanaian', '🇬🇭'),
    CuisineItem('Senegalese', '🇸🇳'),
    CuisineItem('Kenyan', '🇰🇪'),
    CuisineItem('Somali', '🇸🇴'),
    CuisineItem('Tanzanian', '🇹🇿'),
    CuisineItem('Sudanese', '🇸🇩'),
  ]),
  CuisineRegion('Oceania & Pacific', [
    CuisineItem('Australian', '🇦🇺'),
    CuisineItem('New Zealand', '🇳🇿'),
    CuisineItem('Hawaiian', '🇺🇸'),
    CuisineItem('Polynesian', '🇼🇸'),
  ]),
];

/// Flat list of all cuisines for search/filter purposes.
final allCuisines = cuisineRegions
    .expand((region) => region.cuisines)
    .toSet()
    .toList()
  ..sort((a, b) => a.name.compareTo(b.name));

/// Get flag for a cuisine name (case-insensitive).
String? flagForCuisine(String name) {
  final lower = name.toLowerCase();
  for (final region in cuisineRegions) {
    for (final c in region.cuisines) {
      if (c.name.toLowerCase() == lower) return c.flag;
    }
  }
  // Legacy mapping for old cuisine names
  return switch (lower) {
    'middle eastern' => '🌍',
    'asian' => '🌏',
    'mediterranean' => '🌊',
    _ => null,
  };
}

/// All unique cuisine names as strings (for compatibility with existing code).
final allCuisineNames =
    allCuisines.map((c) => c.name).toList();
