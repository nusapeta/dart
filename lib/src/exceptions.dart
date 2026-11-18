class NusapetaApiException implements Exception {
  final int statusCode;
  final String reason;
  final String message;
  final Uri uri;

  const NusapetaApiException({
    required this.statusCode,
    required this.reason,
    required this.message,
    required this.uri,
  });

  @override
  String toString() =>
      'NusapetaApiException($statusCode, $reason, $uri): $message';
}

class NusapetaTimeoutException implements Exception {
  final Duration timeout;
  final Uri uri;

  const NusapetaTimeoutException(this.uri, this.timeout);

  @override
  String toString() =>
      'NusapetaTimeoutException(${timeout.inMilliseconds}ms, $uri)';
}
