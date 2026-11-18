import 'dart:io';

import 'package:nusapeta/nusapeta.dart';

Future<void> main(List<String> args) async {
  final baseUrl = Uri.parse(
    args.isEmpty ? 'https://demo.nusapeta.web.id' : args.first,
  );
  final client = NusapetaClient(
    baseUrl: baseUrl,
    timeout: const Duration(seconds: 20),
  );
  try {
    final route = await client.route(
      from: const LatLng(-6.1754, 106.8272),
      to: const LatLng(-6.2444, 106.8006),
    );
    stdout.writeln(
      '${route.from} -> ${route.to}: ${route.distanceM} m, '
      '${route.durationS.toStringAsFixed(1)} s, ${route.points.length} points, '
      'region ${route.region}',
    );
  } on NusapetaApiException catch (e) {
    stderr.writeln('API error ${e.statusCode} ${e.reason}: ${e.message}');
    exitCode = 1;
  } on NusapetaTimeoutException catch (e) {
    stderr.writeln('Timeout after ${e.timeout.inSeconds}s: ${e.uri}');
    exitCode = 1;
  } finally {
    client.close();
  }
}
