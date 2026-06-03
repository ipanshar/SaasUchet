import 'package:flutter_test/flutter_test.dart';
import 'package:saas_uchet_mobile/app/app.dart';
import 'package:saas_uchet_mobile/features/auth/domain/auth_gateway.dart';
import 'package:saas_uchet_mobile/features/auth/domain/auth_session.dart';
import 'package:saas_uchet_mobile/features/auth/domain/company_profile.dart';
import 'package:saas_uchet_mobile/features/auth/domain/user_profile.dart';
import 'package:saas_uchet_mobile/features/business/domain/business_gateway.dart';

void main() {
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
