abstract class BusinessGateway {
  Future<Map<String, dynamic>> fetchOverview({
    required String accessToken,
  });

  void dispose() {}
}
