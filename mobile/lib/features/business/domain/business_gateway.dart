abstract class BusinessGateway {
  Future<Map<String, dynamic>> fetchOverview({
    required String accessToken,
  });

  Future<Map<String, dynamic>> createClient({
    required String accessToken,
    required Map<String, dynamic> payload,
  });

  Future<Map<String, dynamic>> updateClient({
    required String accessToken,
    required String clientId,
    required Map<String, dynamic> payload,
  });

  Future<void> deleteClient({
    required String accessToken,
    required String clientId,
  });

  Future<Map<String, dynamic>> createProduct({
    required String accessToken,
    required Map<String, dynamic> payload,
  });

  Future<Map<String, dynamic>> updateProduct({
    required String accessToken,
    required String productId,
    required Map<String, dynamic> payload,
  });

  Future<void> deleteProduct({
    required String accessToken,
    required String productId,
  });

  Future<Map<String, dynamic>> createCashAccount({
    required String accessToken,
    required Map<String, dynamic> payload,
  });

  Future<void> createMoneyOperation({
    required String accessToken,
    required Map<String, dynamic> payload,
  });

  Future<List<Map<String, dynamic>>> fetchInventoryDocuments({
    required String accessToken,
    String? type,
    String? search,
  });

  Future<List<Map<String, dynamic>>> fetchMoneyDocuments({
    required String accessToken,
    String? type,
    String? search,
  });

  void dispose() {}
}
