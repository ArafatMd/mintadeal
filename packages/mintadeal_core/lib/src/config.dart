/// Build-time configuration, set with `--dart-define=API_BASE_URL=https://api.example.com`.
///
/// The Android emulator reaches the host machine at `http://10.0.2.2:8080`.
class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// Map tiles. OpenStreetMap's own servers are fine for light use; for maps shown to every customer, switch to a
  /// tile provider (e.g. MapTiler, Stadia Maps) with `--dart-define=TILE_URL=...` and its credit in TILE_CREDIT.
  static const tileUrl = String.fromEnvironment(
    'TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  static const tileCredit = String.fromEnvironment('TILE_CREDIT', defaultValue: '© OpenStreetMap contributors');
}
