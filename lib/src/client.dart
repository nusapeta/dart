import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'exceptions.dart';
import 'models.dart';

String _pair(LatLng point) =>
    '${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}';

Map<String, dynamic> _jsonMap(Object? body) =>
    body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};

class PlaceApi {
  final NusapetaClient _client;

  const PlaceApi(this._client);

  Uri _uri(String path, Map<String, String> query) => _client._uri(path, query);

  Future<List<PlaceFeature>> _features(Uri uri) async {
    final body = await _client._get(uri);
    if (body is! List) return const [];
    return List<PlaceFeature>.unmodifiable(
      body.whereType<Map>().map((f) => PlaceFeature.fromJson(_jsonMap(f))),
    );
  }

  Future<List<PlaceFeature>> search(
    String query, {
    int limit = 5,
    LatLng? bias,
    bool addressDetails = true,
  }) {
    final params = <String, String>{
      'q': query,
      'limit': '$limit',
      'addressdetails': addressDetails ? '1' : '0',
    };
    if (bias != null) {
      params['lat'] = '${bias.latitude}';
      params['lon'] = '${bias.longitude}';
    }
    return _features(_uri('place/search', params));
  }

  Future<List<PlaceFeature>> suggest(
    String query, {
    int limit = 10,
    LatLng? bias,
  }) {
    final params = <String, String>{
      'q': query,
      'limit': '$limit',
    };
    if (bias != null) {
      params['lat'] = '${bias.latitude}';
      params['lon'] = '${bias.longitude}';
    }
    return _features(_uri('place/suggest', params));
  }
}

class NusapetaClient {
  final Uri baseUrl;
  final Duration timeout;
  final http.Client _http;

  late final PlaceApi place;

  NusapetaClient({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 10),
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client() {
    place = PlaceApi(this);
  }

  Uri _uri(String path, Map<String, String> query) {
    final root = baseUrl.toString().replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$root/$path').replace(queryParameters: query);
  }

  Future<Object?> _get(Uri uri) async {
    late final http.Response response;
    try {
      response = await _http.get(uri).timeout(timeout);
    } on TimeoutException {
      throw NusapetaTimeoutException(uri, timeout);
    }
    if (response.statusCode != 200) {
      Map<String, dynamic> body = const {};
      try {
        body = _jsonMap(jsonDecode(response.body));
      } on FormatException {
        // Keep the status code; error text is not a stable contract.
      }
      throw NusapetaApiException(
        statusCode: response.statusCode,
        reason: body['reason'] is String ? body['reason'] as String : '',
        message: body['error'] is String
            ? body['error'] as String
            : response.reasonPhrase ?? 'HTTP ${response.statusCode}',
        uri: uri,
      );
    }
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw NusapetaApiException(
        statusCode: 200,
        reason: 'invalid_json',
        message: 'Response body is not JSON',
        uri: uri,
      );
    }
  }

  Future<Map<String, dynamic>> _object(Uri uri) async {
    final body = await _get(uri);
    if (body is! Map) {
      throw NusapetaApiException(
        statusCode: 200,
        reason: 'invalid_json',
        message: 'Expected a JSON object',
        uri: uri,
      );
    }
    return Map<String, dynamic>.from(body);
  }

  Future<RouteResult> route({
    required LatLng from,
    required LatLng to,
    String? profile,
    int? simplifyM,
    bool restrictions = true,
    bool pin = false,
  }) async {
    final query = <String, String>{
      'from': _pair(from),
      'to': _pair(to),
      'format': 'json',
      'restrictions': restrictions ? '1' : '0',
      'pin': pin ? '1' : '0',
    };
    if (profile != null) query['profile'] = profile;
    if (simplifyM != null) query['simplify'] = '$simplifyM';
    return RouteResult.fromJson(await _object(_uri('route', query)));
  }

  Future<MatrixResult> matrix({
    required List<LatLng> sources,
    required List<LatLng> targets,
    int maxMinutes = 60,
  }) async {
    final query = <String, String>{
      'sources': sources.map(_pair).join('|'),
      'targets': targets.map(_pair).join('|'),
      'max_minutes': '$maxMinutes',
    };
    return MatrixResult.fromJson(await _object(_uri('matrix', query)));
  }

  Future<IsochroneResult> isochrone({
    required LatLng origin,
    int minutes = 15,
    int meters = 10000,
    int gridM = 250,
  }) async {
    final query = <String, String>{
      'lat': '${origin.latitude}',
      'lon': '${origin.longitude}',
      'minutes': '$minutes',
      'meters': '$meters',
      'grid': '$gridM',
    };
    return IsochroneResult.fromJson(await _object(_uri('isochrone', query)));
  }

  void close() => _http.close();
}
