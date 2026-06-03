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

  @override
  Future<Map<String, dynamic>> createClient({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client
        .post(
          ApiConfig.businessClientsUri,
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 201) {
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

  @override
  Future<Map<String, dynamic>> updateClient({
    required String accessToken,
    required String clientId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client
        .put(
          Uri.parse('${ApiConfig.businessClientsUri}/$clientId'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));

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

  @override
  Future<void> deleteClient({
    required String accessToken,
    required String clientId,
  }) async {
    final response = await _client.delete(
      Uri.parse('${ApiConfig.businessClientsUri}/$clientId'),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $accessToken',
      },
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode != 204) {
      throw _buildApiException(response);
    }
  }

  @override
  Future<Map<String, dynamic>> createProduct({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client
        .post(
          ApiConfig.businessProductsUri,
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 201) {
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

  @override
  Future<Map<String, dynamic>> updateProduct({
    required String accessToken,
    required String productId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client
        .put(
          Uri.parse('${ApiConfig.businessProductsUri}/$productId'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));

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

  @override
  Future<void> deleteProduct({
    required String accessToken,
    required String productId,
  }) async {
    final response = await _client.delete(
      Uri.parse('${ApiConfig.businessProductsUri}/$productId'),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $accessToken',
      },
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode != 204) {
      throw _buildApiException(response);
    }
  }

  @override
  Future<Map<String, dynamic>> createCashAccount({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client
        .post(
          ApiConfig.businessAccountsUri,
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 201) {
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

  @override
  Future<void> createMoneyOperation({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client
        .post(
          ApiConfig.businessMoneyOperationsUri,
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 201) {
      throw _buildApiException(response);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchInventoryDocuments({
    required String accessToken,
    String? type,
    String? search,
  }) async {
    final uri = ApiConfig.businessInventoryDocumentsUri.replace(
      queryParameters: {
        if (type != null && type.isNotEmpty) 'type': type,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final response = await _client.get(
      uri,
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

    return (decodedBody['documents'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMoneyDocuments({
    required String accessToken,
    String? type,
    String? search,
  }) async {
    final uri = ApiConfig.businessMoneyDocumentsUri.replace(
      queryParameters: {
        if (type != null && type.isNotEmpty) 'type': type,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final response = await _client.get(
      uri,
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

    return (decodedBody['documents'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
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
