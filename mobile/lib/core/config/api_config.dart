import 'package:flutter/foundation.dart';

class ApiConfig {
  const ApiConfig._();

  static const String _baseUrlOverride = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_baseUrlOverride.isNotEmpty) {
      return _baseUrlOverride;
    }

    if (kIsWeb) {
      return 'http://localhost:8080';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8080';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
      case TargetPlatform.fuchsia:
        return 'http://localhost:8080';
    }
  }

  static Uri get healthUri => Uri.parse('$baseUrl/api/v1/health');
  static Uri get authRegisterUri => Uri.parse('$baseUrl/api/v1/auth/register');
  static Uri get authLoginUri => Uri.parse('$baseUrl/api/v1/auth/login');
  static Uri get profileUri => Uri.parse('$baseUrl/api/v1/profile');
  static Uri get businessOverviewUri =>
      Uri.parse('$baseUrl/api/v1/business/overview');
  static Uri get businessClientsUri =>
      Uri.parse('$baseUrl/api/v1/business/clients');
}
