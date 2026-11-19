# nusapeta (Dart)

Thin Dart client for the Nusapeta HTTP APIs. No generated code, no Flutter
dependency, one explicit timeout per client.

```yaml
dependencies:
  nusapeta:
    hosted: https://pub.dev
    version: ^0.1.0
```

Or use a local checkout while developing:

```yaml
dependencies:
  nusapeta:
    path: ../dartid
```

## Usage

```dart
import 'package:nusapeta/nusapeta.dart';

final client = NusapetaClient(
  baseUrl: Uri.parse('https://demo.nusapeta.web.id'),
  timeout: const Duration(seconds: 10),
);

final route = await client.route(
  from: const LatLng(-6.1754, 106.8272),
  to: const LatLng(-6.2444, 106.8006),
);
print('${route.distanceM} m, ${route.durationS}s, ${route.points.length} points');

final places = await client.place.search('monas', limit: 5);
final suggestions = await client.place.suggest('mon', limit: 5);
final matrix = await client.matrix(
  sources: const [LatLng(-6.1754, 106.8272)],
  targets: const [LatLng(-6.2444, 106.8006)],
);
final area = await client.isochrone(
  origin: const LatLng(-6.1754, 106.8272),
  minutes: 15,
);
client.close();
```

| Method | Endpoint | Result |
|---|---|---|
| `route()` | `GET /route` | `RouteResult` |
| `matrix()` | `GET /matrix` | `MatrixResult` |
| `isochrone()` | `GET /isochrone` | `IsochroneResult` |
| `place.search()` | `GET /place/search` | `List<PlaceFeature>` |
| `place.suggest()` | `GET /place/suggest` | `List<PlaceFeature>` |

Every request uses `.timeout(timeout)`. A slow server raises
`NusapetaTimeoutException`; a non-200 response raises `NusapetaApiException`
with the server's stable `reason` (`snap`, `too_far`, `budget`, `no_route`,
`cross_region`, `deadline`). All result objects and their lists are immutable.

`place_id` is deliberately absent from `PlaceFeature`. It is not a stable
external key across builds; use `osm_type` plus `osm_id` until stability has
been tested.

## Run the example and tests

```bash
dart pub get
dart run example/routing.dart
dart format --output=none --set-exit-if-changed .
dart analyze
dart test
```

The example routes two points through the public demo and prints distance,
duration, point count, and region. Pass another base URL as the first argument
to use a local gateway.

`matrix` and `isochrone` follow the contracts in NUSA-7 and NUSA-8. Until those
server endpoints ship on the demo, test them with a local gateway built from
those changes; the client tests use a local HTTP server.

## Data attribution

Routing graphs and place indexes are built from OpenStreetMap data, available
under ODbL 1.0. See <https://www.openstreetmap.org/copyright>.

Code: MIT, see `LICENSE`.
