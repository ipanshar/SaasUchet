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
  static Uri get businessProductsUri =>
      Uri.parse('$baseUrl/api/v1/business/products');
  static Uri get businessWarehousesUri =>
      Uri.parse('$baseUrl/api/v1/business/warehouses');
  static Uri get businessInventoryDocumentsUri =>
      Uri.parse('$baseUrl/api/v1/business/inventory-documents');
  static Uri get businessAccountsUri =>
      Uri.parse('$baseUrl/api/v1/business/accounts');
  static Uri get businessMoneyOperationsUri =>
      Uri.parse('$baseUrl/api/v1/business/money-operations');
  static Uri get businessMoneyDocumentsUri =>
      Uri.parse('$baseUrl/api/v1/business/money-documents');

  static Uri businessInventoryDocumentUri(String documentId) =>
      Uri.parse('$baseUrl/api/v1/business/inventory-documents/$documentId');

  static Uri businessInventoryDocumentPostUri(String documentId) => Uri.parse(
        '$baseUrl/api/v1/business/inventory-documents/$documentId/post',
      );

  static Uri businessWarehouseStockUri(String warehouseId) =>
      Uri.parse('$baseUrl/api/v1/business/warehouses/$warehouseId/stock');

  static Uri businessWarehouseMovementsUri(String warehouseId) =>
      Uri.parse('$baseUrl/api/v1/business/warehouses/$warehouseId/movements');

  static Uri businessWarehouseTurnoverUri(String warehouseId) =>
      Uri.parse('$baseUrl/api/v1/business/warehouses/$warehouseId/turnover');

  static Uri get businessFinancialSummaryUri =>
      Uri.parse('$baseUrl/api/v1/business/financial-summary');

  static Uri businessClientStatementUri(String clientId) =>
      Uri.parse('$baseUrl/api/v1/business/clients/$clientId/statement');

  static Uri payrollEmployeeStatementUri(String employeeId) =>
      Uri.parse('$baseUrl/api/v1/payroll/employees/$employeeId/statement');

  static Uri get payrollMeStatementUri =>
      Uri.parse('$baseUrl/api/v1/payroll/me/statement');

  static Uri businessMoneyDocumentUri(String documentId) =>
      Uri.parse('$baseUrl/api/v1/business/money-documents/$documentId');

  static Uri businessMoneyDocumentSettleUri(String documentId) => Uri.parse(
        '$baseUrl/api/v1/business/money-documents/$documentId/settle',
      );

  static Uri get catalogServicesUri =>
      Uri.parse('$baseUrl/api/v1/catalog/services');

  static Uri catalogServiceUri(String serviceId) =>
      Uri.parse('$baseUrl/api/v1/catalog/services/$serviceId');

  static Uri get productionRecipesUri =>
      Uri.parse('$baseUrl/api/v1/production/recipes');

  static Uri productionRecipeUri(String recipeId) =>
      Uri.parse('$baseUrl/api/v1/production/recipes/$recipeId');

  static Uri get productionOrdersUri =>
      Uri.parse('$baseUrl/api/v1/production/orders');

  static Uri productionOrderUri(String orderId) =>
      Uri.parse('$baseUrl/api/v1/production/orders/$orderId');

  static Uri get payrollEmployeesUri =>
      Uri.parse('$baseUrl/api/v1/payroll/employees');

  static Uri get payrollUsersUri => Uri.parse('$baseUrl/api/v1/payroll/users');

  static Uri payrollEmployeeUri(String employeeId) =>
      Uri.parse('$baseUrl/api/v1/payroll/employees/$employeeId');

  static Uri get payrollPeriodsUri =>
      Uri.parse('$baseUrl/api/v1/payroll/periods');

  static Uri payrollPeriodUri(String periodId) =>
      Uri.parse('$baseUrl/api/v1/payroll/periods/$periodId');

  static Uri payrollPeriodCalculateUri(String periodId) =>
      Uri.parse('$baseUrl/api/v1/payroll/periods/$periodId/calculate');

  static Uri payrollPeriodPayUri(String periodId) =>
      Uri.parse('$baseUrl/api/v1/payroll/periods/$periodId/pay');

  static Uri payrollEntryUri(String periodId, String entryId) =>
      Uri.parse('$baseUrl/api/v1/payroll/periods/$periodId/entries/$entryId');

  static Uri payrollRecipeRateUri(String recipeId) =>
      Uri.parse('$baseUrl/api/v1/payroll/recipe-rates/$recipeId');

  static Uri get companiesUri => Uri.parse('$baseUrl/api/v1/companies');

  static Uri companyMembersUri(String companyId) =>
      Uri.parse('$baseUrl/api/v1/companies/$companyId/members');

  static Uri companyMemberByIdUri(String companyId, String userId) =>
      Uri.parse('$baseUrl/api/v1/companies/$companyId/members/$userId');

  static Uri companyDefaultUri(String companyId) =>
      Uri.parse('$baseUrl/api/v1/companies/$companyId/default');

  static Uri companyByIdUri(String companyId) =>
      Uri.parse('$baseUrl/api/v1/companies/$companyId');

  static Uri companyLogoUri(String companyId) =>
      Uri.parse('$baseUrl/api/v1/companies/$companyId/logo');
}
