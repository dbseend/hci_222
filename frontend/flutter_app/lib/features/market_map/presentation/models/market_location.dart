class MarketLocation {
  final String name;
  final double lat;
  final double lon;
  final String desc;
  final double rating;
  final int reviewCount;

  const MarketLocation({
    required this.name,
    required this.lat,
    required this.lon,
    required this.desc,
    required this.rating,
    required this.reviewCount,
  });
}

const kDefaultMarketLocations = [
  MarketLocation(
    name: 'Khan el-Khalili',
    lat: 30.0478,
    lon: 31.2625,
    desc: "Cairo's largest traditional market & souq",
    rating: 4.6,
    reviewCount: 128,
  ),
  MarketLocation(
    name: 'Ataba Market',
    lat: 30.0565,
    lon: 31.2457,
    desc: 'Specializes in fruit, vegetables & spices',
    rating: 4.3,
    reviewCount: 94,
  ),
  MarketLocation(
    name: 'Imbaba Market',
    lat: 30.0720,
    lon: 31.2130,
    desc: 'Focused on fresh fruit & vegetables',
    rating: 4.1,
    reviewCount: 57,
  ),
];
