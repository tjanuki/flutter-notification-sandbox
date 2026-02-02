import 'dart:io';

class ReverbConfig {
  static String get host {
    // Android emulator uses 10.0.2.2 to access host machine's localhost
    // iOS simulator uses localhost
    if (Platform.isAndroid) {
      return '10.0.2.2';
    } else {
      return 'localhost';
    }
  }

  static const int port = 8080;

  // This should match REVERB_APP_KEY in Laravel .env
  static const String appKey = 'laravel-reverb-key';

  // Cluster (not used for Reverb, but required by Pusher client)
  static const String cluster = 'mt1';

  // Use encrypted connection
  static const bool useTLS = false;

  // Activity timeout in milliseconds
  static const int activityTimeout = 120000;

  // Pong timeout in milliseconds
  static const int pongTimeout = 30000;
}
