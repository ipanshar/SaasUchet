import 'package:saas_uchet_mobile/features/auth/domain/auth_session.dart';
import 'package:saas_uchet_mobile/features/auth/domain/user_profile.dart';

abstract class AuthGateway {
  Future<AuthSession> register({
    required String fullName,
    required String phone,
    required String password,
  });

  Future<AuthSession> login({
    required String phone,
    required String password,
  });

  Future<UserProfile> fetchProfile({
    required String accessToken,
  });

  Future<UserProfile> updateProfile({
    required String accessToken,
    required String fullName,
    required String phone,
    String? password,
  });

  Future<void> deleteProfile({
    required String accessToken,
  });

  void dispose() {}
}
