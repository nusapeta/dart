double _double(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int _int(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

List<LatLng> _points(Object? value, {bool swap = false}) {
  if (value is! List) return const [];
  final result = <LatLng>[];
  for (final item in value) {
    if (item is! List || item.length < 2) continue;
    final a = _double(item[0]);
    final b = _double(item[1]);
    result.add(swap ? LatLng(b, a) : LatLng(a, b));
  }
  return List.unmodifiable(result);
}

class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);

  @override
  bool operator ==(Object other) =>
      other is LatLng &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'LatLng($latitude, $longitude)';
}

class RouteResult {
  final LatLng from;
  final LatLng to;
  final int distanceM;
  final double durationS;
  final String region;
  final List<LatLng> points;
  final int pointsN;
  final double? snapFromM;
  final double? snapToM;
  final int? ferryM;
  final bool hasFerry;
  final List<List<int>> ferrySpans;

  const RouteResult({
    required this.from,
    required this.to,
    required this.distanceM,
    required this.durationS,
    required this.region,
    required this.points,
    required this.pointsN,
    this.snapFromM,
    this.snapToM,
    this.ferryM,
    this.hasFerry = false,
    this.ferrySpans = const [],
  });

  factory RouteResult.fromJson(Map<String, dynamic> json) {
    final from = json['from'];
    final to = json['to'];
    final points = _points(json['points']);
    final spans = <List<int>>[];
    final rawSpans = json['ferry_spans'];
    if (rawSpans is List) {
      for (final span in rawSpans) {
        if (span is List && span.length >= 2) {
          spans.add(List<int>.unmodifiable([
            _int(span[0]),
            _int(span[1]),
          ]));
        }
      }
    }
    return RouteResult(
      from: from is List && from.length >= 2
          ? LatLng(_double(from[0]), _double(from[1]))
          : const LatLng(0, 0),
      to: to is List && to.length >= 2
          ? LatLng(_double(to[0]), _double(to[1]))
          : const LatLng(0, 0),
      distanceM: _int(json['distance_m']),
      durationS: _double(json['duration_s']),
      region: json['region'] is String ? json['region'] as String : '',
      points: points,
      pointsN: _int(json['points_n'], points.length),
      snapFromM:
          json['snap_from_m'] == null ? null : _double(json['snap_from_m']),
      snapToM: json['snap_to_m'] == null ? null : _double(json['snap_to_m']),
      ferryM: json['ferry_m'] == null ? null : _int(json['ferry_m']),
      hasFerry: json['has_ferry'] == true || json['ferry_m'] != null,
      ferrySpans: List.unmodifiable(spans),
    );
  }
}

class MatrixCell {
  final String state;
  final double? durationS;
  final int? distanceM;

  const MatrixCell(this.state, {this.durationS, this.distanceM});

  bool get ok => state == 'ok';

  factory MatrixCell.fromJson(Map<String, dynamic> json) {
    final state = json['state'];
    return MatrixCell(
      state is String ? state : 'unknown',
      durationS:
          json['duration_s'] == null ? null : _double(json['duration_s']),
      distanceM: json['distance_m'] == null ? null : _int(json['distance_m']),
    );
  }
}

class MatrixResult {
  final List<LatLng> sources;
  final List<LatLng> targets;
  final List<List<MatrixCell>> cells;

  const MatrixResult({
    required this.sources,
    required this.targets,
    required this.cells,
  });

  factory MatrixResult.fromJson(Map<String, dynamic> json) {
    final rows = <List<MatrixCell>>[];
    final rawCells = json['cells'];
    if (rawCells is List) {
      for (final row in rawCells) {
        if (row is! List) continue;
        rows.add(List<MatrixCell>.unmodifiable(
          row.whereType<Map>().map((c) => MatrixCell.fromJson(_map(c))),
        ));
      }
    }
    return MatrixResult(
      sources: _points(json['sources']),
      targets: _points(json['targets']),
      cells: List.unmodifiable(rows),
    );
  }
}

class IsochroneResult {
  final LatLng origin;
  final int minutes;
  final int gridM;
  final List<List<LatLng>> rings;

  const IsochroneResult({
    required this.origin,
    required this.minutes,
    required this.gridM,
    required this.rings,
  });

  factory IsochroneResult.fromJson(Map<String, dynamic> json) {
    final origin = json['origin'];
    final meta = _map(json['meta']);
    final raw = json['rings'] ?? _map(json['geometry'])['coordinates'];
    final swap = raw != json['rings'];
    final rings = <List<LatLng>>[];
    if (raw is List) {
      for (final ring in raw) {
        if (ring is! List) continue;
        final first = ring.firstOrNull;
        final nested = first is List && first.isNotEmpty && first.first is List;
        final coords = nested ? first : ring;
        final points = _points(coords, swap: swap);
        if (points.isNotEmpty) rings.add(points);
      }
    }
    return IsochroneResult(
      origin: origin is List && origin.length >= 2
          ? LatLng(_double(origin[0]), _double(origin[1]))
          : const LatLng(0, 0),
      minutes: _int(json['minutes'] ?? meta['minutes']),
      gridM: _int(json['grid_m'] ?? meta['grid_m']),
      rings: List.unmodifiable(rings),
    );
  }
}

class PlaceAddress {
  final String road;
  final String city;
  final String state;
  final String country;
  final String countryCode;

  const PlaceAddress({
    this.road = '',
    this.city = '',
    this.state = '',
    this.country = '',
    this.countryCode = '',
  });

  factory PlaceAddress.fromJson(Map<String, dynamic> json) => PlaceAddress(
        road: json['road'] is String ? json['road'] as String : '',
        city: json['city'] is String ? json['city'] as String : '',
        state: json['state'] is String ? json['state'] as String : '',
        country: json['country'] is String ? json['country'] as String : '',
        countryCode: json['country_code'] is String
            ? json['country_code'] as String
            : '',
      );
}

class PlaceFeature {
  final String osmType;
  final int? osmId;
  final double latitude;
  final double longitude;
  final String name;
  final String displayName;
  final String category;
  final PlaceAddress address;
  final String licence;
  final String match;
  final double? score;

  const PlaceFeature({
    required this.osmType,
    this.osmId,
    required this.latitude,
    required this.longitude,
    required this.name,
    required this.displayName,
    required this.category,
    this.address = const PlaceAddress(),
    this.licence = '',
    this.match = '',
    this.score,
  });

  factory PlaceFeature.fromJson(Map<String, dynamic> json) => PlaceFeature(
        osmType: json['osm_type'] is String ? json['osm_type'] as String : '',
        osmId: json['osm_id'] == null ? null : _int(json['osm_id']),
        latitude: _double(json['lat']),
        longitude: _double(json['lon']),
        name: json['name'] is String ? json['name'] as String : '',
        displayName: json['display_name'] is String
            ? json['display_name'] as String
            : '',
        category: [json['class'], json['type']].whereType<String>().join('/'),
        address: PlaceAddress.fromJson(_map(json['address'])),
        licence: json['licence'] is String ? json['licence'] as String : '',
        match: json['match'] is String ? json['match'] as String : '',
        score: json['score'] == null ? null : _double(json['score']),
      );
}
