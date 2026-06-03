part of 'business_shell.dart';

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
}

class _Activity {
  const _Activity({
    required this.title,
    required this.amount,
    required this.time,
    required this.icon,
    required this.color,
    required this.tone,
  });

  final String title;
  final String amount;
  final String time;
  final IconData icon;
  final Color color;
  final Color tone;
}

class _Client {
  const _Client({
    required this.id,
    required this.name,
    required this.contact,
    required this.phone,
    required this.email,
    required this.segment,
    required this.totalSales,
    required this.debt,
    required this.interactions,
    this.bin,
    this.iin,
  });

  final String id;
  final String name;
  final String? bin;
  final String? iin;
  final String contact;
  final String phone;
  final String email;
  final String segment;
  final int totalSales;
  final int debt;
  final List<_Interaction> interactions;

  String get binOrIinLabel => bin != null ? 'БИН: $bin' : 'ИИН: $iin';
}

class _Interaction {
  const _Interaction({
    required this.title,
    required this.date,
    required this.note,
  });

  final String title;
  final String date;
  final String note;
}

class _Product {
  const _Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.quantity,
    required this.minQuantity,
    required this.price,
    required this.cost,
    required this.barcode,
    required this.status,
    required this.movements,
  });

  final String id;
  final String name;
  final String sku;
  final String category;
  final int quantity;
  final int minQuantity;
  final int price;
  final int cost;
  final String barcode;
  final ProductStatus status;
  final List<_StockMovement> movements;

  String get statusLabel {
    switch (status) {
      case ProductStatus.inStock:
        return 'В наличии';
      case ProductStatus.lowStock:
        return 'Заканчивается';
      case ProductStatus.outOfStock:
        return 'Нет в наличии';
    }
  }
}

class _StockMovement {
  const _StockMovement({
    required this.date,
    required this.document,
    required this.quantity,
    required this.balance,
  });

  final String date;
  final String document;
  final int quantity;
  final int balance;
}

class _BankAccount {
  const _BankAccount({
    required this.id,
    required this.name,
    required this.balance,
    required this.color,
    required this.icon,
  });

  final String id;
  final String name;
  final int balance;
  final Color color;
  final String icon;
}

class _InventoryDocument {
  const _InventoryDocument({
    required this.id,
    required this.documentNo,
    required this.documentType,
    required this.status,
    required this.documentDate,
    required this.warehouseName,
    required this.relatedWarehouseName,
    required this.productLines,
    required this.totalQuantity,
    required this.note,
  });

  final String id;
  final String documentNo;
  final String documentType;
  final String status;
  final String documentDate;
  final String warehouseName;
  final String relatedWarehouseName;
  final int productLines;
  final int totalQuantity;
  final String note;
}

class _MoneyDocument {
  const _MoneyDocument({
    required this.id,
    required this.documentNo,
    required this.documentType,
    required this.status,
    required this.operationDate,
    required this.description,
    required this.primaryAccount,
    required this.secondaryAccount,
    required this.amount,
  });

  final String id;
  final String documentNo;
  final String documentType;
  final String status;
  final String operationDate;
  final String description;
  final String primaryAccount;
  final String secondaryAccount;
  final int amount;
}

class _Transaction {
  const _Transaction({
    required this.type,
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
    required this.account,
  });

  final TransactionType type;
  final String description;
  final int amount;
  final String category;
  final String date;
  final String account;
}

class _ExpenseCategory {
  const _ExpenseCategory({
    required this.name,
    required this.value,
    required this.color,
  });

  final String name;
  final int value;
  final Color color;
}

class _StaffMember {
  const _StaffMember({
    required this.name,
    required this.role,
  });

  final String name;
  final String role;
}

class _OverviewData {
  const _OverviewData({
    required this.companyName,
    required this.initials,
    required this.dashboard,
    required this.recentActivities,
    required this.clients,
    required this.products,
    required this.finance,
    required this.staff,
    required this.menuNotifications,
  });

  factory _OverviewData.fromJson(
    Map<String, dynamic> json,
    UserProfile fallbackUser,
  ) {
    return _OverviewData(
      companyName: json['company_name'] as String? ??
          (fallbackUser.companies.isNotEmpty
              ? fallbackUser.companies.first.name
              : 'ТОО "Мой Бизнес"'),
      initials:
          json['initials'] as String? ?? initialsOf(fallbackUser.fullName),
      dashboard: _DashboardData.fromJson(
        json['dashboard'] as Map<String, dynamic>? ?? const {},
      ),
      recentActivities:
          (json['recent_activities'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(_activityFromJson)
              .toList(growable: false),
      clients: (json['clients'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_clientFromJson)
          .toList(growable: false),
      products: (json['products'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_productFromJson)
          .toList(growable: false),
      finance: _FinanceOverview.fromJson(
        json['finance'] as Map<String, dynamic>? ?? const {},
      ),
      staff: (json['staff'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_staffFromJson)
          .toList(growable: false),
      menuNotifications: json['menu_notifications'] as int? ?? 0,
    );
  }

  final String companyName;
  final String initials;
  final _DashboardData dashboard;
  final List<_Activity> recentActivities;
  final List<_Client> clients;
  final List<_Product> products;
  final _FinanceOverview finance;
  final List<_StaffMember> staff;
  final int menuNotifications;
}

class _DashboardData {
  const _DashboardData({
    required this.monthlyRevenue,
    required this.revenueChange,
    required this.kpis,
    required this.salesSeries,
  });

  factory _DashboardData.fromJson(Map<String, dynamic> json) {
    return _DashboardData(
      monthlyRevenue: json['monthly_revenue'] as String? ?? '₸ 0',
      revenueChange: json['revenue_change'] as String? ?? '+0%',
      kpis: (json['kpis'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_kpiFromJson)
          .toList(growable: false),
      salesSeries: (json['sales_series'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_chartPointFromJson)
          .toList(growable: false),
    );
  }

  final String monthlyRevenue;
  final String revenueChange;
  final List<_KpiData> kpis;
  final List<_ChartPoint> salesSeries;
}

class _KpiData {
  const _KpiData({
    required this.title,
    required this.value,
    required this.change,
    required this.changeTone,
    required this.icon,
    required this.iconTone,
  });

  final String title;
  final String value;
  final String change;
  final String changeTone;
  final String icon;
  final String iconTone;
}

class _ChartPoint {
  const _ChartPoint({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;
}

class _FinanceOverview {
  const _FinanceOverview({
    required this.totalBalance,
    required this.income,
    required this.expense,
    required this.accounts,
    required this.expenseCategories,
    required this.transactions,
    required this.cashFlows,
  });

  factory _FinanceOverview.fromJson(Map<String, dynamic> json) {
    return _FinanceOverview(
      totalBalance: json['total_balance'] as int? ?? 0,
      income: json['income'] as int? ?? 0,
      expense: json['expense'] as int? ?? 0,
      accounts: (json['accounts'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_bankAccountFromJson)
          .toList(growable: false),
      expenseCategories:
          (json['expense_categories'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(_expenseCategoryFromJson)
              .toList(growable: false),
      transactions: (json['transactions'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_transactionFromJson)
          .toList(growable: false),
      cashFlows: (json['cash_flows'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_cashFlowFromJson)
          .toList(growable: false),
    );
  }

  final int totalBalance;
  final int income;
  final int expense;
  final List<_BankAccount> accounts;
  final List<_ExpenseCategory> expenseCategories;
  final List<_Transaction> transactions;
  final List<_CashFlowData> cashFlows;
}

class _CashFlowData {
  const _CashFlowData({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.tone,
    required this.valueColor,
    required this.highlighted,
  });

  final String title;
  final String subtitle;
  final String value;
  final String tone;
  final String valueColor;
  final bool highlighted;
}

_KpiData _kpiFromJson(Map<String, dynamic> json) => _KpiData(
      title: json['title'] as String? ?? '',
      value: json['value'] as String? ?? '',
      change: json['change'] as String? ?? '',
      changeTone: json['change_tone'] as String? ?? 'neutral',
      icon: json['icon'] as String? ?? 'inventory',
      iconTone: json['icon_tone'] as String? ?? 'primary',
    );

_ChartPoint _chartPointFromJson(Map<String, dynamic> json) => _ChartPoint(
      label: json['label'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0,
    );

_Activity _activityFromJson(Map<String, dynamic> json) {
  final tone = json['tone'] as String? ?? 'neutral';
  return _Activity(
    title: json['title'] as String? ?? '',
    amount: json['amount'] as String? ?? '',
    time: json['time'] as String? ?? '',
    icon: iconFor(json['icon'] as String? ?? ''),
    color: toneColor(tone),
    tone: toneColor(tone).withValues(alpha: 0.1),
  );
}

_Client _clientFromJson(Map<String, dynamic> json) => _Client(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      bin: json['bin'] as String?,
      iin: json['iin'] as String?,
      contact: json['contact'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      segment: json['segment'] as String? ?? 'Regular',
      totalSales: json['total_sales'] as int? ?? 0,
      debt: json['debt'] as int? ?? 0,
      interactions: (json['interactions'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_interactionFromJson)
          .toList(growable: false),
    );

_Interaction _interactionFromJson(Map<String, dynamic> json) => _Interaction(
      title: json['title'] as String? ?? '',
      date: json['date'] as String? ?? '',
      note: json['note'] as String? ?? '',
    );

_Product _productFromJson(Map<String, dynamic> json) => _Product(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      category: json['category'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 0,
      minQuantity: json['min_quantity'] as int? ?? 0,
      price: json['price'] as int? ?? 0,
      cost: json['cost'] as int? ?? 0,
      barcode: json['barcode'] as String? ?? '',
      status: switch (json['status'] as String? ?? '') {
        'low_stock' => ProductStatus.lowStock,
        'out_of_stock' => ProductStatus.outOfStock,
        _ => ProductStatus.inStock,
      },
      movements: (json['movements'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_stockMovementFromJson)
          .toList(growable: false),
    );

_StockMovement _stockMovementFromJson(Map<String, dynamic> json) =>
    _StockMovement(
      date: json['date'] as String? ?? '',
      document: json['document'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 0,
      balance: json['balance'] as int? ?? 0,
    );

_BankAccount _bankAccountFromJson(Map<String, dynamic> json) => _BankAccount(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      balance: json['balance'] as int? ?? 0,
      color: hexColor(json['color'] as String? ?? '#00A86B'),
      icon: json['icon'] as String? ?? '🏦',
    );

_InventoryDocument _inventoryDocumentFromJson(Map<String, dynamic> json) =>
    _InventoryDocument(
      id: json['id'] as String? ?? '',
      documentNo: json['document_no'] as String? ?? '',
      documentType: json['document_type'] as String? ?? '',
      status: json['status'] as String? ?? '',
      documentDate: json['document_date'] as String? ?? '',
      warehouseName: json['warehouse_name'] as String? ?? '',
      relatedWarehouseName: json['related_warehouse_name'] as String? ?? '',
      productLines: json['product_lines'] as int? ?? 0,
      totalQuantity: json['total_quantity'] as int? ?? 0,
      note: json['note'] as String? ?? '',
    );

_MoneyDocument _moneyDocumentFromJson(Map<String, dynamic> json) =>
    _MoneyDocument(
      id: json['id'] as String? ?? '',
      documentNo: json['document_no'] as String? ?? '',
      documentType: json['document_type'] as String? ?? '',
      status: json['status'] as String? ?? '',
      operationDate: json['operation_date'] as String? ?? '',
      description: json['description'] as String? ?? '',
      primaryAccount: json['primary_account'] as String? ?? '',
      secondaryAccount: json['secondary_account'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
    );

_ExpenseCategory _expenseCategoryFromJson(Map<String, dynamic> json) =>
    _ExpenseCategory(
      name: json['name'] as String? ?? '',
      value: json['value'] as int? ?? 0,
      color: hexColor(json['color'] as String? ?? '#00A86B'),
    );

_Transaction _transactionFromJson(Map<String, dynamic> json) => _Transaction(
      type: (json['type'] as String? ?? 'expense') == 'income'
          ? TransactionType.income
          : TransactionType.expense,
      description: json['description'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
      category: json['category'] as String? ?? '',
      date: json['date'] as String? ?? '',
      account: json['account'] as String? ?? '',
    );

_CashFlowData _cashFlowFromJson(Map<String, dynamic> json) => _CashFlowData(
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      value: json['value'] as String? ?? '',
      tone: json['tone'] as String? ?? '#00A86B',
      valueColor: json['value_color'] as String? ?? '#00A86B',
      highlighted: json['highlighted'] as bool? ?? false,
    );

_StaffMember _staffFromJson(Map<String, dynamic> json) => _StaffMember(
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? '',
    );

Color toneColor(String tone) {
  switch (tone) {
    case 'success':
      return const Color(0xFF16A34A);
    case 'warning':
      return const Color(0xFFF59E0B);
    case 'info':
      return const Color(0xFF3B82F6);
    case 'primary':
      return const Color(0xFF00A86B);
    case 'error':
      return const Color(0xFFEF4444);
    default:
      return const Color(0xFF64748B);
  }
}

IconData iconFor(String icon) {
  switch (icon) {
    case 'cart':
      return Icons.shopping_cart_rounded;
    case 'receipt':
      return Icons.receipt_long_rounded;
    case 'group':
      return Icons.group_rounded;
    case 'inventory':
      return Icons.inventory_2_rounded;
    case 'payments':
      return Icons.payments_rounded;
    case 'description':
      return Icons.description_rounded;
    default:
      return Icons.circle_rounded;
  }
}

Color hexColor(String hex) {
  final normalized = hex.replaceFirst('#', '');
  final withAlpha = normalized.length == 6 ? 'FF$normalized' : normalized;
  return Color(int.parse(withAlpha, radix: 16));
}

String formatMoney(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final reverseIndex = digits.length - i;
    buffer.write(digits[i]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write(',');
    }
  }
  return '₸ ${buffer.toString()}';
}

String initialsOf(String value) {
  final words = value
      .replaceAll('"', '')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(2)
      .toList();
  if (words.isEmpty) {
    return 'MB';
  }
  return words.map((word) => word.characters.first.toUpperCase()).join();
}
