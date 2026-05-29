import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:saas_uchet_mobile/core/config/api_config.dart';
import 'package:saas_uchet_mobile/features/health/domain/health_gateway.dart';
import 'package:saas_uchet_mobile/features/health/domain/health_status.dart';

class HealthApiClient extends HealthGateway {
  HealthApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<HealthStatus> fetchHealth() async {
    final response = await _client
        .get(ApiConfig.healthUri)
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception('API returned ${response.statusCode}');
    }

    final decodedBody = jsonDecode(response.body);
    if (decodedBody is! Map<String, dynamic>) {
      throw const FormatException('Unexpected response payload.');
    }

    return HealthStatus.fromJson(decodedBody);
  }

  @override
  void dispose() {
    _client.close();
  }
}
