import 'package:flutter_test/flutter_test.dart';
import 'package:saas_uchet_mobile/app/app.dart';
import 'package:saas_uchet_mobile/features/auth/domain/auth_gateway.dart';
import 'package:saas_uchet_mobile/features/auth/domain/auth_session.dart';
import 'package:saas_uchet_mobile/features/auth/domain/user_profile.dart';
import 'package:saas_uchet_mobile/features/health/domain/health_gateway.dart';
import 'package:saas_uchet_mobile/features/health/domain/health_status.dart';

void main() {
  testWidgets('shows auth screen by default', (tester) async {
    await tester.pumpWidget(
      SaasUchetApp(
        authGateway: _FakeAuthGateway(),
        healthGateway: _FakeHealthGateway(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Saas Uchet'), findsOneWidget);
    expect(find.text('Регистрация'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
    expect(find.text('Аккаунт'), findsOneWidget);
  });

  testWidgets('shows profile screen for injected session', (tester) async {
    await tester.pumpWidget(
      SaasUchetApp(
        authGateway: _FakeAuthGateway(),
        healthGateway: _FakeHealthGateway(),
        initialSession: _fakeSession,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Привет'), findsOneWidget);
    expect(find.text('Профиль'), findsWidgets);
    expect(find.text('Новый пароль'), findsOneWidget);
    expect(find.text('Сохранить'), findsOneWidget);
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
    String? password,
  }) async {
    return _fakeSession.user.copyWith(
      fullName: fullName,
      phone: phone,
    );
  }
}

class _FakeHealthGateway extends HealthGateway {
  @override
  Future<HealthStatus> fetchHealth() async {
    return HealthStatus(
      status: 'ok',
      service: 'saas-uchet-api',
      version: 'test',
      timestamp: DateTime.utc(2026, 1, 1),
    );
  }
}

final _fakeSession = AuthSession(
  accessToken: 'token',
  tokenType: 'Bearer',
  expiresAt: DateTime.utc(2026, 1, 2),
  user: UserProfile(
    id: 'usr_1',
    fullName: 'Иван Петров',
    phone: '+77011234567',
    createdAt: DateTime.utc(2026, 1, 1),
  ),
);
