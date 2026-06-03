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

  void dispose() {}
}
