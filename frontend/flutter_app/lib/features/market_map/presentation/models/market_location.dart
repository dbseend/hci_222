class MarketLocation {
  final String name;
  final double lat;
  final double lon;
  final String desc;

  const MarketLocation({
    required this.name,
    required this.lat,
    required this.lon,
    required this.desc,
  });
}

const kDefaultMarketLocations = [
  MarketLocation(
    name: 'Khan el-Khalili',
    lat: 30.0478,
    lon: 31.2625,
    desc: "Cairo's largest traditional market & souq",
  ),
  MarketLocation(
    name: 'Ataba Market',
    lat: 30.0565,
    lon: 31.2457,
    desc: 'Specializes in fruit, vegetables & spices',
  ),
  MarketLocation(
    name: 'Imbaba Market',
    lat: 30.0720,
    lon: 31.2130,
    desc: 'Focused on fresh fruit & vegetables',
  ),
];
