abstract class BusinessGateway {
  /// Sets the active company id sent as the `X-Company-Id` header on every
  /// subsequent request. Null clears it (server falls back to the default).
  set activeCompanyId(String? value) {}

  Future<List<Map<String, dynamic>>> fetchCompanies({
    required String accessToken,
  });

  Future<Map<String, dynamic>> createCompany({
    required String accessToken,
    required Map<String, dynamic> payload,
  });

  Future<Map<String, dynamic>> addCompanyMember({
    required String accessToken,
    required String companyId,
    required Map<String, dynamic> payload,
  });

  Future<List<Map<String, dynamic>>> fetchCompanyMembers({
    required String accessToken,
    required String companyId,
  });

  Future<Map<String, dynamic>> updateCompanyMemberRole({
    required String accessToken,
    required String companyId,
    required String userId,
    required Map<String, dynamic> payload,
  });

  Future<void> removeCompanyMember({
    required String accessToken,
    required String companyId,
    required String userId,
  });

  Future<void> setDefaultCompany({
    required String accessToken,
    required String companyId,
  });

  Future<Map<String, dynamic>> fetchCompany({
    required String accessToken,
    required String companyId,
  });

  Future<Map<String, dynamic>> updateCompany({
    required String accessToken,
    required String companyId,
    required Map<String, dynamic> payload,
  });

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

  Future<List<Map<String, dynamic>>> fetchWarehouses({
    required String accessToken,
  });

  Future<Map<String, dynamic>> createWarehouse({
    required String accessToken,
    required Map<String, dynamic> payload,
  });

  Future<List<Map<String, dynamic>>> fetchWarehouseStock({
    required String accessToken,
    required String warehouseId,
    String? search,
  });

  Future<List<Map<String, dynamic>>> fetchWarehouseMovements({
    required String accessToken,
    required String warehouseId,
    String? search,
  });

  Future<Map<String, dynamic>> createInventoryDocument({
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

  Future<Map<String, dynamic>> fetchInventoryDocumentDetail({
    required String accessToken,
    required String documentId,
  });

  Future<List<Map<String, dynamic>>> fetchMoneyDocuments({
    required String accessToken,
    String? type,
    String? search,
  });

  Future<Map<String, dynamic>> fetchMoneyDocumentDetail({
    required String accessToken,
    required String documentId,
  });

  Future<void> settleMoneyDocument({
    required String accessToken,
    required String documentId,
    required Map<String, dynamic> payload,
  });

  Future<List<Map<String, dynamic>>> fetchServices({
    required String accessToken,
  });

  Future<Map<String, dynamic>> createService({
    required String accessToken,
    required Map<String, dynamic> payload,
  });

  Future<Map<String, dynamic>> updateService({
    required String accessToken,
    required String serviceId,
    required Map<String, dynamic> payload,
  });

  Future<void> deleteService({
    required String accessToken,
    required String serviceId,
  });

  Future<List<Map<String, dynamic>>> fetchRecipes({
    required String accessToken,
  });

  Future<Map<String, dynamic>> createRecipe({
    required String accessToken,
    required Map<String, dynamic> payload,
  });

  Future<Map<String, dynamic>> updateRecipe({
    required String accessToken,
    required String recipeId,
    required Map<String, dynamic> payload,
  });

  Future<void> deleteRecipe({
    required String accessToken,
    required String recipeId,
  });

  Future<List<Map<String, dynamic>>> fetchProductionOrders({
    required String accessToken,
  });

  Future<Map<String, dynamic>> createProductionOrder({
    required String accessToken,
    required Map<String, dynamic> payload,
  });

  Future<Map<String, dynamic>> updateProductionOrderStatus({
    required String accessToken,
    required String orderId,
    required String status,
  });

  void dispose() {}
}
