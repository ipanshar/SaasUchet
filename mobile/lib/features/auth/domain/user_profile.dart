import 'package:saas_uchet_mobile/features/auth/domain/company_profile.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.companies,
    required this.createdAt,
  });

  final String id;
  final String fullName;
  final String phone;
  final List<CompanyProfile> companies;
  final DateTime createdAt;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      companies: (json['companies'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CompanyProfile.fromJson)
          .toList(growable: false),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  UserProfile copyWith({
    String? id,
    String? fullName,
    String? phone,
    List<CompanyProfile>? companies,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      companies: companies ?? this.companies,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
