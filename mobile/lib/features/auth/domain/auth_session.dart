import 'package:saas_uchet_mobile/features/auth/domain/user_profile.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.tokenType,
    required this.expiresAt,
    required this.user,
  });

  final String accessToken;
  final String tokenType;
  final DateTime expiresAt;
  final UserProfile user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['access_token'] as String? ?? '',
      tokenType: json['token_type'] as String? ?? 'Bearer',
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      user: UserProfile.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
    );
  }

  AuthSession copyWith({
    String? accessToken,
    String? tokenType,
    DateTime? expiresAt,
    UserProfile? user,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      tokenType: tokenType ?? this.tokenType,
      expiresAt: expiresAt ?? this.expiresAt,
      user: user ?? this.user,
    );
  }
}
