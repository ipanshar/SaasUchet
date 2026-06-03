import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:saas_uchet_mobile/core/config/api_config.dart';
import 'package:saas_uchet_mobile/core/network/api_exception.dart';
import 'package:saas_uchet_mobile/features/business/domain/business_gateway.dart';

class BusinessApiClient extends BusinessGateway {
  BusinessApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<Map<String, dynamic>> fetchOverview({
    required String accessToken,
  }) async {
    final response = await _client.get(
      ApiConfig.businessOverviewUri,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $accessToken',
      },
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw _buildApiException(response);
    }

    final decodedBody = jsonDecode(response.body);
    if (decodedBody is! Map<String, dynamic>) {
      throw const ApiException(
        message: 'API returned an unexpected response.',
        statusCode: 500,
      );
    }

    return decodedBody;
  }

  ApiException _buildApiException(http.Response response) {
    try {
      final decodedBody = jsonDecode(response.body);
      if (decodedBody is Map<String, dynamic>) {
        return ApiException(
          message: decodedBody['error'] as String? ??
              'API request failed with ${response.statusCode}.',
          statusCode: response.statusCode,
        );
      }
    } catch (_) {}

    return ApiException(
      message: 'API request failed with ${response.statusCode}.',
      statusCode: response.statusCode,
    );
  }

  @override
  void dispose() {
    _client.close();
  }
}
