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

class _Company {
  const _Company({
    required this.id,
    required this.name,
    required this.country,
    required this.iin,
    required this.role,
    required this.isDefault,
    this.legalForm,
    this.email,
    this.phone,
    this.addressLine,
    this.city,
    this.region,
    this.bankName,
    this.bankAccount,
    this.bankBik,
  });

  final String id;
  final String name;
  final String country;
  final String iin;
  final String role;
  final bool isDefault;
  final String? legalForm;
  final String? email;
  final String? phone;
  final String? addressLine;
  final String? city;
  final String? region;
  final String? bankName;
  final String? bankAccount;
  final String? bankBik;

  bool get isOwner => role == 'owner';

  String get roleLabel {
    switch (role) {
      case 'owner':
        return 'Владелец';
      case 'admin':
        return 'Администратор';
      case 'manager':
        return 'Менеджер';
      case 'accountant':
        return 'Бухгалтер';
      case 'warehouse':
        return 'Кладовщик';
      case 'sales':
        return 'Продажи';
      default:
        return 'Сотрудник';
    }
  }
}

_Company _companyFromJson(Map<String, dynamic> json) {
  return _Company(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    country: json['country'] as String? ?? '',
    iin: json['iin'] as String? ?? '',
    role: json['role'] as String? ?? 'staff',
    isDefault: json['is_default'] as bool? ?? false,
  );
}

_Company _companyDetailFromJson(Map<String, dynamic> json) {
  return _Company(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    country: json['country'] as String? ?? '',
    iin: json['iin'] as String? ?? '',
    role: json['role'] as String? ?? 'staff',
    isDefault: json['is_default'] as bool? ?? false,
    legalForm: json['legal_form'] as String?,
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    addressLine: json['address_line'] as String?,
    city: json['city'] as String?,
    region: json['region'] as String?,
    bankName: json['bank_name'] as String?,
    bankAccount: json['bank_account'] as String?,
    bankBik: json['bank_bik'] as String?,
  );
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
    required this.receivable,
    required this.payable,
    required this.salesCount,
    required this.averageSale,
    required this.paymentsIn,
    required this.paymentsOut,
    required this.overdueAmount,
    required this.interactions,
    required this.openDocuments,
    required this.timeline,
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
  final int receivable;
  final int payable;
  final int salesCount;
  final int averageSale;
  final int paymentsIn;
  final int paymentsOut;
  final int overdueAmount;
  final List<_Interaction> interactions;
  final List<_ClientDebtDocument> openDocuments;
  final List<_ClientTimelineItem> timeline;

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

class _ClientDebtDocument {
  const _ClientDebtDocument({
    required this.documentId,
    required this.documentNo,
    required this.documentType,
    required this.status,
    required this.operationDate,
    required this.amount,
    required this.paidAmount,
    required this.remainingAmount,
  });

  final String documentId;
  final String documentNo;
  final String documentType;
  final String status;
  final String operationDate;
  final int amount;
  final int paidAmount;
  final int remainingAmount;
}

class _ClientTimelineItem {
  const _ClientTimelineItem({
    required this.documentId,
    required this.documentType,
    required this.eventType,
    required this.title,
    required this.subtitle,
    required this.eventDate,
    required this.amount,
    required this.tone,
  });

  final String documentId;
  final String documentType;
  final String eventType;
  final String title;
  final String subtitle;
  final String eventDate;
  final int amount;
  final String tone;
}

class _Product {
  const _Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.productType,
    required this.unitName,
    required this.allowedToSell,
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
  final String productType;
  final String unitName;
  final bool allowedToSell;
  final int quantity;
  final int minQuantity;
  final int price;
  final int cost;
  final String barcode;
  final ProductStatus status;
  final List<_StockMovement> movements;

  String get productTypeLabel {
    switch (productType) {
      case 'raw_material':
        return 'Сырье';
      case 'finished_product':
        return 'ГП';
      default:
        return 'ТНП';
    }
  }

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

class _Warehouse {
  const _Warehouse({
    required this.id,
    required this.name,
    required this.code,
    required this.isDefault,
  });

  final String id;
  final String name;
  final String code;
  final bool isDefault;
}

class _WarehouseStockItem {
  const _WarehouseStockItem({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.category,
    required this.unitName,
    required this.available,
    required this.minQuantity,
    required this.status,
  });

  final String productId;
  final String productName;
  final String sku;
  final String category;
  final String unitName;
  final int available;
  final int minQuantity;
  final ProductStatus status;

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

class _WarehouseMovement {
  const _WarehouseMovement({
    required this.id,
    required this.documentId,
    required this.documentNo,
    required this.documentType,
    required this.movementType,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.quantity,
    required this.balanceAfter,
    required this.documentDate,
    required this.warehouseName,
    required this.relatedWarehouseName,
  });

  final String id;
  final String documentId;
  final String documentNo;
  final String documentType;
  final String movementType;
  final String productId;
  final String productName;
  final String sku;
  final int quantity;
  final int balanceAfter;
  final String documentDate;
  final String warehouseName;
  final String relatedWarehouseName;

  bool get isIncome => quantity > 0;
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
    required this.clientId,
    required this.clientName,
    required this.warehouseName,
    required this.relatedWarehouseName,
    required this.productLines,
    required this.totalQuantity,
    required this.totalAmount,
    required this.note,
  });

  final String id;
  final String documentNo;
  final String documentType;
  final String status;
  final String documentDate;
  final String clientId;
  final String clientName;
  final String warehouseName;
  final String relatedWarehouseName;
  final int productLines;
  final int totalQuantity;
  final int totalAmount;
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
    required this.paidAmount,
    required this.remainingAmount,
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
  final int paidAmount;
  final int remainingAmount;
}

class _InventoryDocumentLine {
  const _InventoryDocumentLine({
    required this.productName,
    required this.sku,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
    required this.lineTotal,
    required this.note,
  });

  final String productName;
  final String sku;
  final int quantity;
  final int unitPrice;
  final int unitCost;
  final int lineTotal;
  final String note;
}

class _InventoryDocumentDetail {
  const _InventoryDocumentDetail({
    required this.summary,
    required this.lines,
  });

  final _InventoryDocument summary;
  final List<_InventoryDocumentLine> lines;
}

class _MoneyDocumentLine {
  const _MoneyDocumentLine({
    required this.category,
    required this.amount,
    required this.note,
  });

  final String category;
  final int amount;
  final String note;
}

class _MoneyDocumentDetail {
  const _MoneyDocumentDetail({
    required this.summary,
    required this.lines,
  });

  final _MoneyDocument summary;
  final List<_MoneyDocumentLine> lines;
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

  String get roleLabel {
    switch (role) {
      case 'owner':
        return 'Владелец';
      case 'admin':
        return 'Администратор';
      case 'manager':
        return 'Менеджер';
      case 'accountant':
        return 'Бухгалтер';
      case 'warehouse':
        return 'Кладовщик';
      case 'sales':
        return 'Продажи';
      default:
        return 'Сотрудник';
    }
  }
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
      receivable: json['receivable'] as int? ?? 0,
      payable: json['payable'] as int? ?? 0,
      salesCount: json['sales_count'] as int? ?? 0,
      averageSale: json['average_sale'] as int? ?? 0,
      paymentsIn: json['payments_in'] as int? ?? 0,
      paymentsOut: json['payments_out'] as int? ?? 0,
      overdueAmount: json['overdue_amount'] as int? ?? 0,
      interactions: (json['interactions'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_interactionFromJson)
          .toList(growable: false),
      openDocuments: (json['open_documents'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_clientDebtDocumentFromJson)
          .toList(growable: false),
      timeline: (json['timeline'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_clientTimelineItemFromJson)
          .toList(growable: false),
    );

_Interaction _interactionFromJson(Map<String, dynamic> json) => _Interaction(
      title: json['title'] as String? ?? '',
      date: json['date'] as String? ?? '',
      note: json['note'] as String? ?? '',
    );

_ClientDebtDocument _clientDebtDocumentFromJson(Map<String, dynamic> json) =>
    _ClientDebtDocument(
      documentId: json['document_id'] as String? ?? '',
      documentNo: json['document_no'] as String? ?? '',
      documentType: json['document_type'] as String? ?? '',
      status: json['status'] as String? ?? '',
      operationDate: json['operation_date'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
      paidAmount: json['paid_amount'] as int? ?? 0,
      remainingAmount: json['remaining_amount'] as int? ?? 0,
    );

_ClientTimelineItem _clientTimelineItemFromJson(Map<String, dynamic> json) =>
    _ClientTimelineItem(
      documentId: json['document_id'] as String? ?? '',
      documentType: json['document_type'] as String? ?? '',
      eventType: json['event_type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      eventDate: json['event_date'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
      tone: json['tone'] as String? ?? 'neutral',
    );

_Product _productFromJson(Map<String, dynamic> json) => _Product(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      category: json['category'] as String? ?? '',
      productType: json['product_type'] as String? ?? 'consumer_goods',
      unitName: json['unit_name'] as String? ?? 'шт',
      allowedToSell: json['allowed_to_sell'] as bool? ?? true,
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

_Warehouse _warehouseFromJson(Map<String, dynamic> json) => _Warehouse(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      isDefault: json['is_default'] as bool? ?? false,
    );

_WarehouseStockItem _warehouseStockItemFromJson(Map<String, dynamic> json) =>
    _WarehouseStockItem(
      productId: json['product_id'] as String? ?? '',
      productName: json['product_name'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      category: json['category'] as String? ?? '',
      unitName: json['unit_name'] as String? ?? 'шт',
      available: json['available'] as int? ?? 0,
      minQuantity: json['min_quantity'] as int? ?? 0,
      status: switch (json['status'] as String? ?? '') {
        'low_stock' => ProductStatus.lowStock,
        'out_of_stock' => ProductStatus.outOfStock,
        _ => ProductStatus.inStock,
      },
    );

_WarehouseMovement _warehouseMovementFromJson(Map<String, dynamic> json) =>
    _WarehouseMovement(
      id: json['id'] as String? ?? '',
      documentId: json['document_id'] as String? ?? '',
      documentNo: json['document_no'] as String? ?? '',
      documentType: json['document_type'] as String? ?? '',
      movementType: json['movement_type'] as String? ?? '',
      productId: json['product_id'] as String? ?? '',
      productName: json['product_name'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 0,
      balanceAfter: json['balance_after'] as int? ?? 0,
      documentDate: json['document_date'] as String? ?? '',
      warehouseName: json['warehouse_name'] as String? ?? '',
      relatedWarehouseName: json['related_warehouse_name'] as String? ?? '',
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
      clientId: json['client_id'] as String? ?? '',
      clientName: json['client_name'] as String? ?? '',
      warehouseName: json['warehouse_name'] as String? ?? '',
      relatedWarehouseName: json['related_warehouse_name'] as String? ?? '',
      productLines: json['product_lines'] as int? ?? 0,
      totalQuantity: json['total_quantity'] as int? ?? 0,
      totalAmount: json['total_amount'] as int? ?? 0,
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
      paidAmount: json['paid_amount'] as int? ?? 0,
      remainingAmount: json['remaining_amount'] as int? ?? 0,
    );

_InventoryDocumentLine _inventoryDocumentLineFromJson(
  Map<String, dynamic> json,
) =>
    _InventoryDocumentLine(
      productName: json['product_name'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 0,
      unitPrice: json['unit_price'] as int? ?? 0,
      unitCost: json['unit_cost'] as int? ?? 0,
      lineTotal: json['line_total'] as int? ?? 0,
      note: json['note'] as String? ?? '',
    );

_InventoryDocumentDetail _inventoryDocumentDetailFromJson(
  Map<String, dynamic> json,
) =>
    _InventoryDocumentDetail(
      summary: _inventoryDocumentFromJson(
        json['summary'] as Map<String, dynamic>? ?? const {},
      ),
      lines: (json['lines'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_inventoryDocumentLineFromJson)
          .toList(growable: false),
    );

_MoneyDocumentLine _moneyDocumentLineFromJson(Map<String, dynamic> json) =>
    _MoneyDocumentLine(
      category: json['category'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
      note: json['note'] as String? ?? '',
    );

_MoneyDocumentDetail _moneyDocumentDetailFromJson(Map<String, dynamic> json) =>
    _MoneyDocumentDetail(
      summary: _moneyDocumentFromJson(
        json['summary'] as Map<String, dynamic>? ?? const {},
      ),
      lines: (json['lines'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_moneyDocumentLineFromJson)
          .toList(growable: false),
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

// ─── Services ────────────────────────────────────────────────────────────────

class _ServiceMaterial {
  const _ServiceMaterial({
    required this.id,
    required this.materialType,
    this.productId = '',
    this.productName = '',
    this.subServiceId = '',
    this.subServiceName = '',
    this.externalServiceName = '',
    required this.quantity,
    required this.cost,
  });

  final String id;
  final String materialType;
  final String productId;
  final String productName;
  final String subServiceId;
  final String subServiceName;
  final String externalServiceName;
  final double quantity;
  final double cost;

  String get displayName {
    if (materialType == 'product') return productName;
    if (materialType == 'sub_service') return subServiceName;
    return externalServiceName;
  }

  String get typeLabel {
    switch (materialType) {
      case 'product':
        return 'Товар';
      case 'sub_service':
        return 'Подуслуга';
      default:
        return 'Внешняя услуга';
    }
  }
}

class _Service {
  const _Service({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.allowedToSell,
    required this.materials,
  });

  final String id;
  final String name;
  final String description;
  final double price;
  final bool allowedToSell;
  final List<_ServiceMaterial> materials;

  double get estimatedCost => materials.fold(
        0.0,
        (sum, m) => sum + m.cost * m.quantity,
      );
}

_ServiceMaterial _serviceMaterialFromJson(Map<String, dynamic> json) =>
    _ServiceMaterial(
      id: json['id'] as String? ?? '',
      materialType: json['material_type'] as String? ?? 'external_service',
      productId: json['product_id'] as String? ?? '',
      productName: json['product_name'] as String? ?? '',
      subServiceId: json['sub_service_id'] as String? ?? '',
      subServiceName: json['sub_service_name'] as String? ?? '',
      externalServiceName: json['external_service_name'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
    );

_Service _serviceFromJson(Map<String, dynamic> json) => _Service(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      allowedToSell: json['allowed_to_sell'] as bool? ?? true,
      materials: (json['materials'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_serviceMaterialFromJson)
          .toList(growable: false),
    );

// ── Production / Recipe models ────────────────────────────────────────────────

class _RecipeIngredient {
  const _RecipeIngredient({
    required this.id,
    required this.productId,
    required this.productName,
    required this.unitName,
    required this.quantity,
  });
  final String id;
  final String productId;
  final String productName;
  final String unitName;
  final double quantity;
}

class _RecipeService {
  const _RecipeService({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.quantity,
  });
  final String id;
  final String serviceId;
  final String serviceName;
  final double quantity;
}

class _RecipeOutput {
  const _RecipeOutput({
    required this.id,
    required this.productId,
    required this.productName,
    required this.unitName,
    required this.quantity,
  });
  final String id;
  final String productId;
  final String productName;
  final String unitName;
  final double quantity;
}

class _Recipe {
  const _Recipe({
    required this.id,
    required this.name,
    required this.description,
    required this.payrollAmount,
    required this.ingredients,
    required this.services,
    required this.outputs,
  });
  final String id;
  final String name;
  final String description;
  final int payrollAmount;
  final List<_RecipeIngredient> ingredients;
  final List<_RecipeService> services;
  final List<_RecipeOutput> outputs;

  int get totalComponents => ingredients.length + services.length;
}

_RecipeIngredient _recipeIngredientFromJson(Map<String, dynamic> j) =>
    _RecipeIngredient(
      id: j['id'] as String? ?? '',
      productId: j['product_id'] as String? ?? '',
      productName: j['product_name'] as String? ?? '',
      unitName: j['unit_name'] as String? ?? 'шт',
      quantity: (j['quantity'] as num?)?.toDouble() ?? 1.0,
    );

_RecipeService _recipeServiceFromJson(Map<String, dynamic> j) =>
    _RecipeService(
      id: j['id'] as String? ?? '',
      serviceId: j['service_id'] as String? ?? '',
      serviceName: j['service_name'] as String? ?? '',
      quantity: (j['quantity'] as num?)?.toDouble() ?? 1.0,
    );

_RecipeOutput _recipeOutputFromJson(Map<String, dynamic> j) => _RecipeOutput(
      id: j['id'] as String? ?? '',
      productId: j['product_id'] as String? ?? '',
      productName: j['product_name'] as String? ?? '',
      unitName: j['unit_name'] as String? ?? 'шт',
      quantity: (j['quantity'] as num?)?.toDouble() ?? 1.0,
    );

_Recipe _recipeFromJson(Map<String, dynamic> j) => _Recipe(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      description: j['description'] as String? ?? '',
      payrollAmount: j['payroll_amount'] as int? ?? 0,
      ingredients: (j['ingredients'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_recipeIngredientFromJson)
          .toList(growable: false),
      services: (j['services'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_recipeServiceFromJson)
          .toList(growable: false),
      outputs: (j['outputs'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_recipeOutputFromJson)
          .toList(growable: false),
    );

// ── ProductionOrder ───────────────────────────────────────────────────────────

class _ProductionOrder {
  const _ProductionOrder({
    required this.id,
    required this.documentNo,
    required this.recipeId,
    required this.recipeName,
    required this.sourceWarehouseId,
    required this.sourceWarehouseName,
    required this.outputWarehouseId,
    required this.outputWarehouseName,
    required this.batchNumber,
    required this.responsibleEmployee,
    required this.plannedQuantity,
    required this.status,
    required this.plannedDate,
    required this.notes,
    required this.createdAt,
    required this.participants,
  });
  final String id;
  final String documentNo;
  final String recipeId;
  final String recipeName;
  final String sourceWarehouseId;
  final String sourceWarehouseName;
  final String outputWarehouseId;
  final String outputWarehouseName;
  final String batchNumber;
  final String responsibleEmployee;
  final double plannedQuantity;
  final String status;
  final String plannedDate;
  final String notes;
  final String createdAt;
  final List<_ProductionParticipant> participants;

  String get statusLabel {
    switch (status) {
      case 'in_progress':
        return 'В работе';
      case 'completed':
        return 'Завершён';
      case 'cancelled':
        return 'Отменён';
      default:
        return 'Черновик';
    }
  }

  StatusKind get statusKind {
    switch (status) {
      case 'in_progress':
        return StatusKind.info;
      case 'completed':
        return StatusKind.success;
      case 'cancelled':
        return StatusKind.error;
      default:
        return StatusKind.neutral;
    }
  }
}

class _ProductionParticipant {
  const _ProductionParticipant({
    required this.employeeId,
    required this.employeeName,
    required this.sharePercent,
  });
  final String employeeId;
  final String employeeName;
  final double sharePercent;
}

_ProductionParticipant _productionParticipantFromJson(Map<String, dynamic> j) =>
    _ProductionParticipant(
      employeeId: j['employee_id'] as String? ?? '',
      employeeName: j['employee_name'] as String? ?? '',
      sharePercent: (j['share_percent'] as num?)?.toDouble() ?? 0,
    );

_ProductionOrder _productionOrderFromJson(Map<String, dynamic> j) =>
    _ProductionOrder(
      id: j['id'] as String? ?? '',
      documentNo: j['document_no'] as String? ?? '',
      recipeId: j['recipe_id'] as String? ?? '',
      recipeName: j['recipe_name'] as String? ?? '',
      sourceWarehouseId: j['source_warehouse_id'] as String? ?? '',
      sourceWarehouseName: j['source_warehouse_name'] as String? ?? '',
      outputWarehouseId: j['output_warehouse_id'] as String? ?? '',
      outputWarehouseName: j['output_warehouse_name'] as String? ?? '',
      batchNumber: j['batch_number'] as String? ?? '',
      responsibleEmployee: j['responsible_employee'] as String? ?? '',
      plannedQuantity: (j['planned_quantity'] as num?)?.toDouble() ?? 1.0,
      status: j['status'] as String? ?? 'draft',
      plannedDate: j['planned_date'] as String? ?? '',
      notes: j['notes'] as String? ?? '',
      createdAt: j['created_at'] as String? ?? '',
      participants: (j['participants'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_productionParticipantFromJson)
          .toList(growable: false),
    );
