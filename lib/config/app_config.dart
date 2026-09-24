/// App-wide connection settings.
///
/// Android emulator: keep the default `10.0.2.2` host.
/// Physical phone: change this one value to the computer's LAN URL while both
/// devices are on the same trusted Wi-Fi. For a deployed backend, use HTTPS.
class AppConfig {
  AppConfig._();

  static const String backendBaseUrl = 'http://10.0.2.2:3000';
  static const Duration connectTimeout = Duration(seconds: 12);
  static const Duration speechTimeout = Duration(seconds: 120);
  static const Duration translationTimeout = Duration(seconds: 60);
}
