/// Build-time configuration, set with `--dart-define=API_BASE_URL=https://api.example.com`.
///
/// The Android emulator reaches the host machine at `http://10.0.2.2:8080`.
class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
}
