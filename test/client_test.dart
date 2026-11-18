import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nusapeta/nusapeta.dart';
import 'package:test/test.dart';

const routeJson = {
  'from': [-6.1754, 106.8272],
  'to': [-6.2444, 106.8006],
  'distance_m': 10724,
  'duration_s': 680.9,
  'region': 'java',
  'snap_from_m': 4,
  'points': [
    [-6.1754, 106.8272],
    [-6.2444, 106.8006],
  ],
  'points_n': 2,
};

const matrixJson = {
  'sources': [
    [-6.1754, 106.8272],
  ],
  'targets': [
    [-6.2444, 106.8006],
    [-6.3000, 106.8000],
  ],
  'cells': [
    [
      {'state': 'ok', 'duration_s': 680.9, 'distance_m': 10724},
      {'state': 'too_far'},
    ],
  ],
};

const isochroneJson = {
  'origin': [-6.1754, 106.8272],
  'minutes': 15,
  'grid_m': 250,
  'rings': [
    [
      [-6.1754, 106.8272],
      [-6.1800, 106.8300],
      [-6.1754, 106.8272],
    ],
  ],
};

final placeJson = [
  {
    'place_id': 2251801122363396,
    'osm_type': 'node',
    'osm_id': 1308678148,
    'lat': '-6.1754000',
    'lon': '106.8272000',
    'name': 'Monas',
    'display_name': 'Monas, Jakarta, Indonesia',
    'class': 'place',
    'type': 'monument',
    'address': {
      'city': 'Jakarta',
      'country': 'Indonesia',
      'country_code': 'id'
    },
    'licence': 'ODbL 1.0, OpenStreetMap contributors',
    'match': 'prefix',
    'score': 0.9,
  },
];

void respond(HttpRequest req, Object body, {int status = 200}) {
  req.response.statusCode = status;
  req.response.headers.contentType = ContentType.json;
  try {
    req.response.write(jsonEncode(body));
  } catch (_) {
    return;
  }
  unawaited(req.response.close().catchError((Object _) {}));
}

void main() {
  late HttpServer server;
  late Uri base;

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = Uri.parse('http://${server.address.host}:${server.port}');
    server.listen((req) async {
      final q = req.uri.queryParameters;
      switch (req.uri.path) {
        case '/route':
          if (q['to'] == '1.000000,2.000000') {
            respond(
                req,
                {
                  'error': 'too far',
                  'reason': 'too_far',
                },
                status: 422);
          } else if (q['to'] == '9.000000,9.000000') {
            await Future<void>.delayed(const Duration(milliseconds: 500));
            respond(req, routeJson);
          } else {
            respond(req, routeJson);
          }
        case '/matrix':
          respond(req, matrixJson);
        case '/isochrone':
          respond(req, isochroneJson);
        case '/place/search':
        case '/place/suggest':
          respond(req, placeJson);
        default:
          respond(req, {'error': 'not found'}, status: 404);
      }
    });
  });

  tearDownAll(() async {
    await server.close(force: true);
  });

  NusapetaClient client([Duration? timeout]) => NusapetaClient(
        baseUrl: base,
        timeout: timeout ?? const Duration(seconds: 5),
      );

  test('route returns immutable parsed data', () async {
    final c = client();
    addTearDown(c.close);
    final result = await c.route(
      from: const LatLng(-6.1754, 106.8272),
      to: const LatLng(-6.2444, 106.8006),
    );
    expect(result.distanceM, 10724);
    expect(result.durationS, 680.9);
    expect(result.region, 'java');
    expect(result.points.length, 2);
    expect(result.points.first, const LatLng(-6.1754, 106.8272));
    expect(result.snapFromM, 4);
    expect(() => result.points.add(const LatLng(0, 0)), throwsUnsupportedError);
  });

  test('API reason survives error mapping', () async {
    final c = client();
    addTearDown(c.close);
    expect(
      c.route(from: const LatLng(0, 0), to: const LatLng(1, 2)),
      throwsA(
        isA<NusapetaApiException>()
            .having((e) => e.statusCode, 'status', 422)
            .having((e) => e.reason, 'reason', 'too_far'),
      ),
    );
  });

  test('explicit timeout aborts a slow response', () async {
    final c = client(const Duration(milliseconds: 50));
    addTearDown(c.close);
    expect(
      c.route(from: const LatLng(0, 0), to: const LatLng(9, 9)),
      throwsA(isA<NusapetaTimeoutException>()),
    );
  });

  test('matrix keeps cells and states', () async {
    final c = client();
    addTearDown(c.close);
    final result = await c.matrix(
      sources: const [LatLng(-6.1754, 106.8272)],
      targets: const [LatLng(-6.2444, 106.8006), LatLng(-6.3, 106.8)],
    );
    expect(result.cells.length, 1);
    expect(result.cells.first.length, 2);
    expect(result.cells.first.first.ok, isTrue);
    expect(result.cells.first.last.state, 'too_far');
    expect(result.cells.first.first.distanceM, 10724);
  });

  test('isochrone parses rings', () async {
    final c = client();
    addTearDown(c.close);
    final result = await c.isochrone(origin: const LatLng(-6.1754, 106.8272));
    expect(result.gridM, 250);
    expect(result.rings.single.length, 3);
    expect(result.rings.single.first, const LatLng(-6.1754, 106.8272));
  });

  test('place search and suggest use OSM identity, not place_id', () async {
    final c = client();
    addTearDown(c.close);
    final search = await c.place.search('monas', limit: 2);
    final suggest = await c.place.suggest('mon', limit: 2);
    expect(search.single.osmId, 1308678148);
    expect(search.single.address.city, 'Jakarta');
    expect(suggest.single.match, 'prefix');
    expect(suggest.single.score, 0.9);
    expect(search.single.licence, contains('ODbL'));
  });
}
