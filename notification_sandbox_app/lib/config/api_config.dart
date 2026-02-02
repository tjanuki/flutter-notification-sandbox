import 'dart:io';

class ApiConfig {
  static String get baseUrl {
    // Android emulator uses 10.0.2.2 to access host machine's localhost
    // iOS simulator and physical devices use the actual host IP or localhost
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api';
    } else {
      return 'http://localhost:8000/api';
    }
  }

  static String get broadcastingAuthUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/broadcasting/auth';
    } else {
      return 'http://localhost:8000/broadcasting/auth';
    }
  }

  // Timeout settings
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
