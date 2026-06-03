class CompanyProfile {
  const CompanyProfile({
    required this.name,
    required this.country,
    required this.iin,
  });

  final String name;
  final String country;
  final String iin;

  factory CompanyProfile.fromJson(Map<String, dynamic> json) {
    return CompanyProfile(
      name: json['name'] as String? ?? '',
      country: json['country'] as String? ?? '',
      iin: json['iin'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'country': country,
      'iin': iin,
    };
  }

  CompanyProfile copyWith({
    String? name,
    String? country,
    String? iin,
  }) {
    return CompanyProfile(
      name: name ?? this.name,
      country: country ?? this.country,
      iin: iin ?? this.iin,
    );
  }
}
