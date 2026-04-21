class ApiConfig {
  /// For iOS Simulator + Chrome on the same laptop, this default works.
  /// If needed, override at runtime:
  /// `--dart-define=API_BASE_URL=http://<LAN-IP>:8080`
  static const String _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  static String _runtimeBaseUrl = _defaultBaseUrl;

  static String get baseUrl => _runtimeBaseUrl;

  static void setRuntimeBaseUrl(String url) {
    final normalized = url.trim();
    if (normalized.isEmpty) return;
    _runtimeBaseUrl = normalized;
  }
}

