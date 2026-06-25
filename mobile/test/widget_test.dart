import 'package:flutter_test/flutter_test.dart';
import 'package:saas_uchet_mobile/app/app.dart';
import 'package:saas_uchet_mobile/features/auth/domain/auth_gateway.dart';
import 'package:saas_uchet_mobile/features/auth/domain/auth_session.dart';
import 'package:saas_uchet_mobile/features/auth/domain/company_profile.dart';
import 'package:saas_uchet_mobile/features/auth/domain/user_profile.dart';
import 'package:saas_uchet_mobile/features/business/domain/business_gateway.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('shows onboarding screen by default', (tester) async {
    await tester.pumpWidget(
      SaasUchetApp(
        authGateway: _FakeAuthGateway(),
        businessGateway: _FakeBusinessGateway(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Управляйте продажами'), findsOneWidget);
    expect(find.text('Далее'), findsOneWidget);
    expect(find.text('Пропустить'), findsOneWidget);
  });

  testWidgets('shows auth screen after skipping onboarding', (tester) async {
    await tester.pumpWidget(
      SaasUchetApp(
        authGateway: _FakeAuthGateway(),
        businessGateway: _FakeBusinessGateway(),
      ),
    );

    await tester.tap(find.text('Пропустить'));
    await tester.pumpAndSettle();

    expect(find.text('Вход в систему'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
    expect(find.text('Забыли пароль?'), findsOneWidget);
  });

  testWidgets('shows business shell for injected session', (tester) async {
    await tester.pumpWidget(
      SaasUchetApp(
        authGateway: _FakeAuthGateway(),
        businessGateway: _FakeBusinessGateway(),
        initialSession: _fakeSession,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Главная'), findsOneWidget);
    expect(find.text('График продаж'), findsOneWidget);
    expect(find.text('Последние действия'), findsOneWidget);
  });
}

class _FakeAuthGateway extends AuthGateway {
  @override
  Future<void> deleteProfile({required String accessToken}) async {}

  @override
  Future<UserProfile> fetchProfile({required String accessToken}) async {
    return _fakeSession.user;
  }

  @override
  Future<AuthSession> login({
    required String phone,
    required String password,
  }) async {
    return _fakeSession;
  }

  @override
  Future<AuthSession> register({
    required String fullName,
    required String phone,
    required String password,
  }) async {
    return _fakeSession;
  }

  @override
  Future<UserProfile> updateProfile({
    required String accessToken,
    required String fullName,
    required String phone,
    required List<CompanyProfile> companies,
    String? password,
  }) async {
    return _fakeSession.user.copyWith(
      fullName: fullName,
      phone: phone,
      companies: companies,
    );
  }
}

class _FakeBusinessGateway extends BusinessGateway {
  @override
  set activeCompanyId(String? value) {}

  @override
  Future<List<Map<String, dynamic>>> fetchCompanies({
    required String accessToken,
  }) async {
    return [
      {
        'id': 'cmp_1',
        'name': 'ТОО Мой Бизнес',
        'country': 'KZ',
        'iin': '123456789012',
        'role': 'owner',
        'is_default': true,
      },
    ];
  }

  @override
  Future<Map<String, dynamic>> createCompany({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    return {'id': 'cmp_new', ...payload};
  }

  @override
  Future<Map<String, dynamic>> addCompanyMember({
    required String accessToken,
    required String companyId,
    required Map<String, dynamic> payload,
  }) async =>
      {
        'user_id': 'usr_2',
        'full_name': 'Новый участник',
        'phone': payload['phone'] ?? '+77001234567',
        'role': payload['role'] ?? 'manager',
        'role_label': 'Менеджер',
        'is_owner': false,
        'is_current_user': false,
        'joined_at': '2026-06-03T00:00:00Z',
      };

  @override
  Future<List<Map<String, dynamic>>> fetchCompanyMembers({
    required String accessToken,
    required String companyId,
  }) async =>
      [
        {
          'user_id': 'usr_1',
          'full_name': 'Иван Петров',
          'phone': '+77011234567',
          'role': 'owner',
          'role_label': 'Владелец',
          'is_owner': true,
          'is_current_user': true,
          'joined_at': '2026-06-01T00:00:00Z',
        },
      ];

  @override
  Future<Map<String, dynamic>> updateCompanyMemberRole({
    required String accessToken,
    required String companyId,
    required String userId,
    required Map<String, dynamic> payload,
  }) async =>
      {
        'user_id': userId,
        'full_name': 'Иван Петров',
        'phone': '+77011234567',
        'role': payload['role'] ?? 'manager',
        'role_label': 'Менеджер',
        'is_owner': false,
        'is_current_user': false,
        'joined_at': '2026-06-01T00:00:00Z',
      };

  @override
  Future<void> removeCompanyMember({
    required String accessToken,
    required String companyId,
    required String userId,
  }) async {}

  @override
  Future<void> setDefaultCompany({
    required String accessToken,
    required String companyId,
  }) async {}

  @override
  Future<Map<String, dynamic>> fetchCompany({
    required String accessToken,
    required String companyId,
  }) async =>
      {
        'id': companyId,
        'name': 'ТОО Мой Бизнес',
        'country': 'KZ',
        'iin': '',
        'role': 'owner',
        'is_default': true
      };

  @override
  Future<Map<String, dynamic>> updateCompany({
    required String accessToken,
    required String companyId,
    required Map<String, dynamic> payload,
  }) async =>
      {'id': companyId, ...payload};

  @override
  Future<Map<String, dynamic>> fetchOverview({
    required String accessToken,
  }) async {
    return {
      'company_name': 'ТОО Мой Бизнес',
      'initials': 'ТМ',
      'dashboard': {
        'monthly_revenue': '₸ 2,450,000',
        'revenue_change': '+12.5%',
        'kpis': [
          {
            'title': 'Продажи за день',
            'value': '₸ 125,000',
            'change': '+8.2%',
            'change_tone': 'success',
            'icon': 'cart',
            'icon_tone': 'success',
          },
          {
            'title': 'Дебиторка',
            'value': '₸ 456,000',
            'change': '-3.1%',
            'change_tone': 'warning',
            'icon': 'receipt',
            'icon_tone': 'warning',
          },
        ],
        'sales_series': [
          {'label': '1 июн', 'value': 45},
          {'label': '5 июн', 'value': 52},
        ],
      },
      'recent_activities': [
        {
          'title': 'ТОО Астана Трейд',
          'amount': '₸ 125,000',
          'time': '10 минут назад',
          'icon': 'cart',
          'tone': 'success',
        },
      ],
      'clients': [
        {
          'id': 'clt_1',
          'name': 'ТОО Астана Трейд',
          'bin': '123456789012',
          'contact': 'Нурланов Азамат',
          'phone': '+7 (777) 123-45-67',
          'email': 'info@astana-trade.kz',
          'segment': 'VIP',
          'total_sales': 2450000,
          'debt': 125000,
          'interactions': [
            {
              'title': 'Звонок',
              'date': '3 июня 2026',
              'note': 'Обсудили новую поставку',
            },
          ],
        },
      ],
      'products': [
        {
          'id': 'prd_1',
          'name': 'Ноутбук Lenovo ThinkPad',
          'sku': 'TECH-001',
          'category': 'Техника',
          'quantity': 15,
          'min_quantity': 10,
          'price': 350000,
          'cost': 280000,
          'barcode': '8600123456789',
          'status': 'in_stock',
          'movements': [
            {
              'date': '2 июня',
              'document': 'Продажа #1234',
              'quantity': -5,
              'balance': 15,
            },
          ],
        },
      ],
      'finance': {
        'total_balance': 5032000,
        'income': 2145000,
        'expense': 940000,
        'accounts': [
          {
            'id': 'acc_1',
            'name': 'Kaspi Bank',
            'balance': 2450000,
            'color': '#F14635',
            'icon': '🏦',
          },
        ],
        'expense_categories': [
          {
            'name': 'Закупки',
            'value': 1200000,
            'color': '#00A86B',
          },
        ],
        'transactions': [
          {
            'type': 'income',
            'description': 'Оплата',
            'amount': 125000,
            'category': 'Продажи',
            'date': '3 июня',
            'account': 'Kaspi Bank',
          },
        ],
        'cash_flows': [
          {
            'title': 'Операционная деятельность',
            'subtitle': 'Приток',
            'value': '₸ 1,245,000',
            'tone': '#22C55E',
            'value_color': '#22C55E',
            'highlighted': false,
          },
        ],
      },
      'staff': [
        {
          'name': 'Иван Петров',
          'role': 'Администратор',
        },
      ],
      'menu_notifications': 5,
    };
  }

  @override
  Future<Map<String, dynamic>> createClient({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    return payload;
  }

  @override
  Future<Map<String, dynamic>> updateClient({
    required String accessToken,
    required String clientId,
    required Map<String, dynamic> payload,
  }) async {
    return {
      'id': clientId,
      ...payload,
    };
  }

  @override
  Future<void> deleteClient({
    required String accessToken,
    required String clientId,
  }) async {}

  @override
  Future<Map<String, dynamic>> createProduct({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    return {
      'id': 'prd_new',
      ...payload,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchWarehouses({
    required String accessToken,
  }) async {
    return [
      {
        'id': 'wh_1',
        'name': 'Основной склад',
        'code': 'MAIN',
        'is_default': true,
      },
    ];
  }

  @override
  Future<Map<String, dynamic>> createWarehouse({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    return {
      'id': 'wh_new',
      'name': payload['name'] ?? 'Новый склад',
      'code': '',
      'is_default': false,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchWarehouseStock({
    required String accessToken,
    required String warehouseId,
    String? search,
  }) async {
    return [
      {
        'product_id': 'prd_1',
        'product_name': 'Ноутбук Lenovo ThinkPad',
        'sku': 'TECH-001',
        'category': 'Техника',
        'unit_name': 'шт',
        'available': 15,
        'min_quantity': 10,
        'status': 'in_stock',
      },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchWarehouseMovements({
    required String accessToken,
    required String warehouseId,
    String? search,
  }) async {
    return [
      {
        'id': 'mov_1',
        'document_id': 'inv_1',
        'document_no': 'OPEN-TECH-001',
        'document_type': 'opening',
        'movement_type': 'in',
        'product_id': 'prd_1',
        'product_name': 'Ноутбук Lenovo ThinkPad',
        'sku': 'TECH-001',
        'quantity': 15,
        'balance_after': 15,
        'document_date': '2026-06-03',
        'warehouse_name': 'Основной склад',
        'related_warehouse_name': '',
      },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchWarehouseTurnover({
    required String accessToken,
    required String warehouseId,
    required String from,
    required String to,
  }) async {
    return [
      {
        'product_id': 'prd_1',
        'product_name': 'Ноутбук Lenovo ThinkPad',
        'sku': 'TECH-001',
        'barcode': '',
        'unit_name': 'шт',
        'opening': 0,
        'receipts': 15,
        'issues': 0,
        'closing': 15,
      },
    ];
  }

  @override
  Future<Map<String, dynamic>> fetchFinancialSummary({
    required String accessToken,
    required String from,
    required String to,
  }) async {
    return {
      'from': from,
      'to': to,
      'money_opening': 0,
      'money_income': 0,
      'money_expense': 0,
      'money_closing': 0,
      'receivable_opening': 0,
      'receivable_accrued': 0,
      'receivable_paid': 0,
      'receivable_closing': 0,
      'payable_opening': 0,
      'payable_accrued': 0,
      'payable_paid': 0,
      'payable_closing': 0,
      'purchases_total': 0,
      'sales_total': 0,
      'salary_accrued': 0,
      'salary_paid': 0,
    };
  }

  @override
  Future<Map<String, dynamic>> fetchCounterpartyStatement({
    required String accessToken,
    required String clientId,
    required String from,
    required String to,
  }) async {
    return {
      'client_id': clientId,
      'client_name': 'Иван Петров',
      'from': from,
      'to': to,
      'opening_balance': 0,
      'closing_balance': 0,
      'total_debit': 0,
      'total_credit': 0,
      'entries': <Map<String, dynamic>>[],
    };
  }

  @override
  Future<Map<String, dynamic>> createInventoryDocument({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    return {
      'summary': {
        'id': 'inv_new',
        'document_no': 'REC-1',
        'document_type': payload['document_type'] ?? 'purchase_receipt',
        'status': 'posted',
        'document_date': '2026-06-04',
        'warehouse_name': 'Основной склад',
        'product_lines':
            (payload['lines'] as List<dynamic>? ?? const []).length,
        'total_quantity': 1,
      },
      'lines': payload['lines'] ?? const [],
    };
  }

  @override
  Future<Map<String, dynamic>> updateInventoryDocument({
    required String accessToken,
    required String documentId,
    required Map<String, dynamic> payload,
  }) async {
    return {
      'summary': {
        'id': documentId,
        'document_no': 'REC-1',
        'document_type': payload['document_type'] ?? 'purchase_receipt',
        'status': 'draft',
        'document_date': '2026-06-04',
        'warehouse_name': 'Основной склад',
        'product_lines':
            (payload['lines'] as List<dynamic>? ?? const []).length,
        'total_quantity': 1,
      },
      'lines': payload['lines'] ?? const [],
    };
  }

  @override
  Future<Map<String, dynamic>> postInventoryDocument({
    required String accessToken,
    required String documentId,
  }) async {
    return {
      'summary': {
        'id': documentId,
        'document_no': 'REC-1',
        'document_type': 'purchase_receipt',
        'status': 'posted',
        'document_date': '2026-06-04',
        'warehouse_name': 'Основной склад',
        'product_lines': 1,
        'total_quantity': 1,
      },
      'lines': const [],
    };
  }

  @override
  Future<void> deleteInventoryDocument({
    required String accessToken,
    required String documentId,
  }) async {}

  @override
  Future<Map<String, dynamic>> uploadCompanyLogo({
    required String accessToken,
    required String companyId,
    required List<int> bytes,
    required String filename,
  }) async {
    return {
      'id': companyId,
      'name': 'ТОО Мой Бизнес',
      'country': 'KZ',
      'iin': '',
      'role': 'owner',
      'is_default': true,
    };
  }

  @override
  Future<Map<String, dynamic>> updateProduct({
    required String accessToken,
    required String productId,
    required Map<String, dynamic> payload,
  }) async {
    return {
      'id': productId,
      ...payload,
    };
  }

  @override
  Future<void> deleteProduct({
    required String accessToken,
    required String productId,
  }) async {}

  @override
  Future<Map<String, dynamic>> createCashAccount({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    return {
      'id': 'acc_new',
      ...payload,
    };
  }

  @override
  Future<void> createMoneyOperation({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> fetchInventoryDocuments({
    required String accessToken,
    String? type,
    String? search,
  }) async {
    return [
      {
        'id': 'inv_1',
        'document_no': 'OPEN-TECH-001',
        'document_type': 'opening',
        'status': 'posted',
        'document_date': '2026-06-03',
        'warehouse_name': 'Основной склад',
        'product_lines': 1,
        'total_quantity': 15,
        'note': 'Начальный остаток',
      },
    ];
  }

  @override
  Future<Map<String, dynamic>> fetchInventoryDocumentDetail({
    required String accessToken,
    required String documentId,
  }) async {
    return {
      'summary': {
        'id': documentId,
        'document_no': 'OPEN-TECH-001',
        'document_type': 'opening',
        'status': 'posted',
        'document_date': '2026-06-03',
        'warehouse_name': 'Основной склад',
        'product_lines': 1,
        'total_quantity': 15,
      },
      'lines': [
        {
          'product_name': 'Ноутбук Lenovo ThinkPad',
          'sku': 'TECH-001',
          'quantity': 15,
          'unit_price': 350000,
          'unit_cost': 280000,
          'line_total': 5250000,
        },
      ],
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMoneyDocuments({
    required String accessToken,
    String? type,
    String? search,
  }) async {
    return [
      {
        'id': 'mny_1',
        'document_no': 'RCP-1',
        'document_type': 'receipt',
        'status': 'posted',
        'operation_date': '2026-06-03',
        'description': 'Оплата',
        'primary_account': 'Kaspi Bank',
        'amount': 125000,
      },
    ];
  }

  @override
  Future<Map<String, dynamic>> fetchMoneyDocumentDetail({
    required String accessToken,
    required String documentId,
  }) async {
    return {
      'summary': {
        'id': documentId,
        'document_no': 'RCP-1',
        'document_type': 'receipt',
        'status': 'posted',
        'operation_date': '2026-06-03',
        'description': 'Оплата',
        'primary_account': 'Kaspi Bank',
        'amount': 125000,
      },
      'lines': [
        {
          'category': 'Продажи',
          'amount': 125000,
          'note': 'Оплата клиента',
        },
      ],
    };
  }

  @override
  Future<void> settleMoneyDocument({
    required String accessToken,
    required String documentId,
    required Map<String, dynamic> payload,
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> fetchServices({
    required String accessToken,
  }) async {
    return [];
  }

  @override
  Future<Map<String, dynamic>> createService({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    return {'id': 'svc_new', ...payload};
  }

  @override
  Future<Map<String, dynamic>> updateService({
    required String accessToken,
    required String serviceId,
    required Map<String, dynamic> payload,
  }) async {
    return {'id': serviceId, ...payload};
  }

  @override
  Future<void> deleteService({
    required String accessToken,
    required String serviceId,
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> fetchRecipes({
    required String accessToken,
  }) async =>
      [];

  @override
  Future<Map<String, dynamic>> createRecipe({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async =>
      {'id': 'r1', ...payload};

  @override
  Future<Map<String, dynamic>> updateRecipe({
    required String accessToken,
    required String recipeId,
    required Map<String, dynamic> payload,
  }) async =>
      {'id': recipeId, ...payload};

  @override
  Future<void> deleteRecipe({
    required String accessToken,
    required String recipeId,
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> fetchProductionOrders({
    required String accessToken,
  }) async =>
      [];

  @override
  Future<Map<String, dynamic>> createProductionOrder({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async =>
      {'id': 'o1', ...payload};

  @override
  Future<Map<String, dynamic>> updateProductionOrderStatus({
    required String accessToken,
    required String orderId,
    required String status,
  }) async =>
      {'id': orderId, 'status': status};

  @override
  Future<List<Map<String, dynamic>>> fetchEmployees({
    required String accessToken,
  }) async =>
      [];

  @override
  Future<Map<String, dynamic>> createEmployee({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async =>
      {'id': 'emp_new', ...payload};

  @override
  Future<Map<String, dynamic>> updateEmployee({
    required String accessToken,
    required String employeeId,
    required Map<String, dynamic> payload,
  }) async =>
      {'id': employeeId, ...payload};

  @override
  Future<void> deleteEmployee({
    required String accessToken,
    required String employeeId,
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> fetchPayrollPeriods({
    required String accessToken,
  }) async =>
      [];

  @override
  Future<Map<String, dynamic>> createPayrollPeriod({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async =>
      {'id': 'pp_new', ...payload};

  @override
  Future<Map<String, dynamic>> fetchPayrollPeriodDetail({
    required String accessToken,
    required String periodId,
  }) async =>
      {
        'period': {'id': periodId, 'status': 'draft'},
        'entries': [],
      };

  @override
  Future<void> deletePayrollPeriod({
    required String accessToken,
    required String periodId,
  }) async {}

  @override
  Future<Map<String, dynamic>> calculatePayroll({
    required String accessToken,
    required String periodId,
  }) async =>
      {
        'period': {'id': periodId, 'status': 'calculated'},
        'entries': [],
      };

  @override
  Future<Map<String, dynamic>> updatePayrollEntry({
    required String accessToken,
    required String periodId,
    required String entryId,
    required Map<String, dynamic> payload,
  }) async =>
      {
        'period': {'id': periodId, 'status': 'calculated'},
        'entries': [],
      };

  @override
  Future<Map<String, dynamic>> payPayrollPeriod({
    required String accessToken,
    required String periodId,
    required Map<String, dynamic> payload,
  }) async =>
      {
        'period': {'id': periodId, 'status': 'paid'},
        'entries': [],
      };

  @override
  Future<void> setRecipePayrollAmount({
    required String accessToken,
    required String recipeId,
    required int amount,
  }) async {}
}

final _fakeSession = AuthSession(
  accessToken: 'token',
  tokenType: 'Bearer',
  expiresAt: DateTime.utc(2026, 1, 2),
  user: UserProfile(
    id: 'usr_1',
    fullName: 'Иван Петров',
    phone: '+77011234567',
    companies: const [
      CompanyProfile(
        name: 'ТОО Мой Бизнес',
        country: 'KZ',
        iin: '123456789012',
      ),
    ],
    createdAt: DateTime.utc(2026, 1, 1),
  ),
);
