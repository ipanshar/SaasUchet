import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:saas_uchet_mobile/core/config/api_config.dart';
import 'package:saas_uchet_mobile/core/network/api_exception.dart';
import 'package:saas_uchet_mobile/features/business/domain/business_gateway.dart';

class BusinessApiClient extends BusinessGateway {
  BusinessApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _activeCompanyId;

  @override
  set activeCompanyId(String? value) {
    _activeCompanyId = (value != null && value.isNotEmpty) ? value : null;
  }

  Map<String, String> _headers(String accessToken, {bool json = true}) {
    return {
      if (json) 'Content-Type': 'application/json; charset=utf-8',
      'Authorization': 'Bearer $accessToken',
      if (_activeCompanyId != null) 'X-Company-Id': _activeCompanyId!,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCompanies({
    required String accessToken,
  }) async {
    final response = await _client
        .get(
          ApiConfig.companiesUri,
          headers: _headers(accessToken),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw _buildApiException(response);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException(
        message: 'API returned an unexpected response.',
        statusCode: 500,
      );
    }
    return (decoded['companies'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> createCompany({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client
        .post(
          ApiConfig.companiesUri,
          headers: _headers(accessToken),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 201) {
      throw _buildApiException(response);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException(
        message: 'API returned an unexpected response.',
        statusCode: 500,
      );
    }
    return decoded;
  }

  @override
  Future<Map<String, dynamic>> addCompanyMember({
    required String accessToken,
    required String companyId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client
        .post(
          ApiConfig.companyMembersUri(companyId),
          headers: _headers(accessToken),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 201) {
      throw _buildApiException(response);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException(
        message: 'API returned an unexpected response.',
        statusCode: 500,
      );
    }
    return decoded;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCompanyMembers({
    required String accessToken,
    required String companyId,
  }) async {
    final response = await _client
        .get(
          ApiConfig.companyMembersUri(companyId),
          headers: _headers(accessToken),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw _buildApiException(response);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException(
        message: 'API returned an unexpected response.',
        statusCode: 500,
      );
    }
    return (decoded['members'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> updateCompanyMemberRole({
    required String accessToken,
    required String companyId,
    required String userId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client
        .put(
          ApiConfig.companyMemberByIdUri(companyId, userId),
          headers: _headers(accessToken),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw _buildApiException(response);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException(
        message: 'API returned an unexpected response.',
        statusCode: 500,
      );
    }
    return decoded;
  }

  @override
  Future<void> removeCompanyMember({
    required String accessToken,
    required String companyId,
    required String userId,
  }) async {
    final response = await _client
        .delete(
          ApiConfig.companyMemberByIdUri(companyId, userId),
          headers: _headers(accessToken),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 204) {
      throw _buildApiException(response);
    }
  }

  @override
  Future<void> setDefaultCompany({
    required String accessToken,
    required String companyId,
  }) async {
    final response = await _client
        .put(
          ApiConfig.companyDefaultUri(companyId),
          headers: _headers(accessToken),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw _buildApiException(response);
    }
  }

  @override
  Future<Map<String, dynamic>> fetchCompany({
    required String accessToken,
    required String companyId,
  }) async {
    final response = await _client
        .get(
          ApiConfig.companyByIdUri(companyId),
          headers: _headers(accessToken),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) throw _buildApiException(response);

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException(
          message: 'Unexpected response.', statusCode: 500);
    }
    return decoded;
  }

  @override
  Future<Map<String, dynamic>> updateCompany({
    required String accessToken,
    required String companyId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client
        .put(
          ApiConfig.companyByIdUri(companyId),
          headers: _headers(accessToken),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) throw _buildApiException(response);

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException(
          message: 'Unexpected response.', statusCode: 500);
    }
    return decoded;
  }

  @override
  Future<Map<String, dynamic>> uploadCompanyLogo({
    required String accessToken,
    required String companyId,
    required List<int> bytes,
    required String filename,
  }) async {
    final request = http.MultipartRequest(
      'PUT',
      ApiConfig.companyLogoUri(companyId),
    )
      ..headers.addAll(_headers(accessToken, json: false))
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ),
      );

    final streamed = await request.send().timeout(const Duration(seconds: 8));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw _buildApiException(response);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException(
        message: 'Unexpected response.',
        statusCode: 500,
      );
    }
    return decoded;
  }

  @override
  Future<Map<String, dynamic>> fetchOverview({
    required String accessToken,
  }) async {
    final response = await _client
        .get(
          ApiConfig.businessOverviewUri,
          headers: _headers(accessToken),
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
  Future<Map<String, dynamic>> createClient({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client
        .post(
          ApiConfig.businessClientsUri,
          headers: _headers(accessToken),
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
          headers: _headers(accessToken),
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
    final response = await _client
        .delete(
          Uri.parse('${ApiConfig.businessClientsUri}/$clientId'),
          headers: _headers(accessToken),
        )
        .timeout(const Duration(seconds: 8));

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
          headers: _headers(accessToken),
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
  Future<List<Map<String, dynamic>>> fetchWarehouses({
    required String accessToken,
  }) async {
    final response = await _client
        .get(
          ApiConfig.businessWarehousesUri,
          headers: _headers(accessToken),
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

    return (decodedBody['warehouses'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> createWarehouse({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client
        .post(
          ApiConfig.businessWarehousesUri,
          headers: _headers(accessToken),
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
  Future<List<Map<String, dynamic>>> fetchWarehouseStock({
    required String accessToken,
    required String warehouseId,
    String? search,
  }) async {
    final uri = ApiConfig.businessWarehouseStockUri(warehouseId).replace(
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final response = await _client
        .get(
          uri,
          headers: _headers(accessToken),
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

    return (decodedBody['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> fetchFinancialSummary({
    required String accessToken,
    required String from,
    required String to,
  }) async {
    final uri = ApiConfig.businessFinancialSummaryUri.replace(
      queryParameters: {
        'from': from,
        'to': to,
      },
    );
    final response = await _client
        .get(
          uri,
          headers: _headers(accessToken),
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
  Future<Map<String, dynamic>> fetchCounterpartyStatement({
    required String accessToken,
    required String clientId,
    required String from,
    required String to,
  }) async {
    final uri = ApiConfig.businessClientStatementUri(clientId).replace(
      queryParameters: {
        'from': from,
        'to': to,
      },
    );
    final response = await _client
        .get(
          uri,
          headers: _headers(accessToken),
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
  Future<List<Map<String, dynamic>>> fetchWarehouseMovements({
    required String accessToken,
    required String warehouseId,
    String? search,
  }) async {
    final uri = ApiConfig.businessWarehouseMovementsUri(warehouseId).replace(
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final response = await _client
        .get(
          uri,
          headers: _headers(accessToken),
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

    return (decodedBody['movements'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchWarehouseTurnover({
    required String accessToken,
    required String warehouseId,
    required String from,
    required String to,
  }) async {
    final uri = ApiConfig.businessWarehouseTurnoverUri(warehouseId).replace(
      queryParameters: {
        'from': from,
        'to': to,
      },
    );
    final response = await _client
        .get(
          uri,
          headers: _headers(accessToken),
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

    return (decodedBody['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> createInventoryDocument({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client
        .post(
          ApiConfig.businessInventoryDocumentsUri,
          headers: _headers(accessToken),
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
  Future<Map<String, dynamic>> updateInventoryDocument({
    required String accessToken,
    required String documentId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client
        .put(
          ApiConfig.businessInventoryDocumentUri(documentId),
          headers: _headers(accessToken),
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
  Future<Map<String, dynamic>> postInventoryDocument({
    required String accessToken,
    required String documentId,
  }) async {
    final response = await _client
        .post(
          ApiConfig.businessInventoryDocumentPostUri(documentId),
          headers: _headers(accessToken),
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
  Future<void> deleteInventoryDocument({
    required String accessToken,
    required String documentId,
  }) async {
    final response = await _client
        .delete(
          ApiConfig.businessInventoryDocumentUri(documentId),
          headers: _headers(accessToken),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 204) {
      throw _buildApiException(response);
    }
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
          headers: _headers(accessToken),
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
    final response = await _client
        .delete(
          Uri.parse('${ApiConfig.businessProductsUri}/$productId'),
          headers: _headers(accessToken),
        )
        .timeout(const Duration(seconds: 8));

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
          headers: _headers(accessToken),
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
          headers: _headers(accessToken),
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
    final response = await _client
        .get(
          uri,
          headers: _headers(accessToken),
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

    return (decodedBody['documents'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> fetchInventoryDocumentDetail({
    required String accessToken,
    required String documentId,
  }) async {
    final response = await _client
        .get(
          ApiConfig.businessInventoryDocumentUri(documentId),
          headers: _headers(accessToken),
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
    final response = await _client
        .get(
          uri,
          headers: _headers(accessToken),
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

    return (decodedBody['documents'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> fetchMoneyDocumentDetail({
    required String accessToken,
    required String documentId,
  }) async {
    final response = await _client
        .get(
          ApiConfig.businessMoneyDocumentUri(documentId),
          headers: _headers(accessToken),
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
  Future<void> settleMoneyDocument({
    required String accessToken,
    required String documentId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client
        .post(
          ApiConfig.businessMoneyDocumentSettleUri(documentId),
          headers: _headers(accessToken),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 201) {
      throw _buildApiException(response);
    }
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
  Future<List<Map<String, dynamic>>> fetchServices({
    required String accessToken,
  }) async {
    final response = await _client
        .get(
          ApiConfig.catalogServicesUri,
          headers: _headers(accessToken),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) throw _buildApiException(response);

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException(
          message: 'Unexpected response.', statusCode: 500);
    }
    return (decoded['services'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  @override
  Future<Map<String, dynamic>> createService({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client
        .post(
          ApiConfig.catalogServicesUri,
          headers: _headers(accessToken),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 201) throw _buildApiException(response);

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException(
          message: 'Unexpected response.', statusCode: 500);
    }
    return decoded;
  }

  @override
  Future<Map<String, dynamic>> updateService({
    required String accessToken,
    required String serviceId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client
        .put(
          ApiConfig.catalogServiceUri(serviceId),
          headers: _headers(accessToken),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) throw _buildApiException(response);

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException(
          message: 'Unexpected response.', statusCode: 500);
    }
    return decoded;
  }

  @override
  Future<void> deleteService({
    required String accessToken,
    required String serviceId,
  }) async {
    final response = await _client
        .delete(
          ApiConfig.catalogServiceUri(serviceId),
          headers: _headers(accessToken),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 204) throw _buildApiException(response);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRecipes({
    required String accessToken,
  }) async {
    final response = await _client
        .get(
          ApiConfig.productionRecipesUri,
          headers: _headers(accessToken, json: false),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) throw _buildApiException(response);
    final decoded = jsonDecode(response.body);
    return List<Map<String, dynamic>>.from(decoded['recipes'] ?? []);
  }

  @override
  Future<Map<String, dynamic>> createRecipe({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client
        .post(
          ApiConfig.productionRecipesUri,
          headers: _headers(accessToken),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 201) throw _buildApiException(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> updateRecipe({
    required String accessToken,
    required String recipeId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client
        .put(
          ApiConfig.productionRecipeUri(recipeId),
          headers: _headers(accessToken),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) throw _buildApiException(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  Future<void> deleteRecipe({
    required String accessToken,
    required String recipeId,
  }) async {
    final response = await _client
        .delete(
          ApiConfig.productionRecipeUri(recipeId),
          headers: _headers(accessToken, json: false),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 204) throw _buildApiException(response);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchProductionOrders({
    required String accessToken,
  }) async {
    final response = await _client
        .get(
          ApiConfig.productionOrdersUri,
          headers: _headers(accessToken, json: false),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) throw _buildApiException(response);
    final decoded = jsonDecode(response.body);
    return List<Map<String, dynamic>>.from(decoded['orders'] ?? []);
  }

  @override
  Future<Map<String, dynamic>> createProductionOrder({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client
        .post(
          ApiConfig.productionOrdersUri,
          headers: _headers(accessToken),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 201) throw _buildApiException(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> updateProductionOrderStatus({
    required String accessToken,
    required String orderId,
    required String status,
  }) async {
    final response = await _client
        .patch(
          ApiConfig.productionOrderUri(orderId),
          headers: _headers(accessToken),
          body: jsonEncode({'status': status}),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) throw _buildApiException(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchEmployees({
    required String accessToken,
  }) async {
    final response = await _client
        .get(
          ApiConfig.payrollEmployeesUri,
          headers: _headers(accessToken, json: false),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) throw _buildApiException(response);
    final decoded = jsonDecode(response.body);
    return List<Map<String, dynamic>>.from(decoded['employees'] ?? []);
  }

  @override
  Future<Map<String, dynamic>> createEmployee({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client
        .post(
          ApiConfig.payrollEmployeesUri,
          headers: _headers(accessToken),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 201) throw _buildApiException(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> updateEmployee({
    required String accessToken,
    required String employeeId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client
        .put(
          ApiConfig.payrollEmployeeUri(employeeId),
          headers: _headers(accessToken),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) throw _buildApiException(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  Future<void> deleteEmployee({
    required String accessToken,
    required String employeeId,
  }) async {
    final response = await _client
        .delete(
          ApiConfig.payrollEmployeeUri(employeeId),
          headers: _headers(accessToken, json: false),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 204) throw _buildApiException(response);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPayrollPeriods({
    required String accessToken,
  }) async {
    final response = await _client
        .get(
          ApiConfig.payrollPeriodsUri,
          headers: _headers(accessToken, json: false),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) throw _buildApiException(response);
    final decoded = jsonDecode(response.body);
    return List<Map<String, dynamic>>.from(decoded['periods'] ?? []);
  }

  @override
  Future<Map<String, dynamic>> createPayrollPeriod({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client
        .post(
          ApiConfig.payrollPeriodsUri,
          headers: _headers(accessToken),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 201) throw _buildApiException(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> fetchPayrollPeriodDetail({
    required String accessToken,
    required String periodId,
  }) async {
    final response = await _client
        .get(
          ApiConfig.payrollPeriodUri(periodId),
          headers: _headers(accessToken, json: false),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) throw _buildApiException(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  Future<void> deletePayrollPeriod({
    required String accessToken,
    required String periodId,
  }) async {
    final response = await _client
        .delete(
          ApiConfig.payrollPeriodUri(periodId),
          headers: _headers(accessToken, json: false),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 204) throw _buildApiException(response);
  }

  @override
  Future<Map<String, dynamic>> calculatePayroll({
    required String accessToken,
    required String periodId,
  }) async {
    final response = await _client
        .post(
          ApiConfig.payrollPeriodCalculateUri(periodId),
          headers: _headers(accessToken),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) throw _buildApiException(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> updatePayrollEntry({
    required String accessToken,
    required String periodId,
    required String entryId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client
        .put(
          ApiConfig.payrollEntryUri(periodId, entryId),
          headers: _headers(accessToken),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) throw _buildApiException(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> payPayrollPeriod({
    required String accessToken,
    required String periodId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client
        .post(
          ApiConfig.payrollPeriodPayUri(periodId),
          headers: _headers(accessToken),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) throw _buildApiException(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  Future<void> setRecipePayrollAmount({
    required String accessToken,
    required String recipeId,
    required int amount,
  }) async {
    final response = await _client
        .put(
          ApiConfig.payrollRecipeRateUri(recipeId),
          headers: _headers(accessToken),
          body: jsonEncode({'amount': amount}),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) throw _buildApiException(response);
  }

  @override
  void dispose() {
    _client.close();
  }
}
