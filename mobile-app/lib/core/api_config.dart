class ApiConfig {
  // Passed at run time, so no IP address ends up in Git:
  // flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000', // Android emulator only
  );
}