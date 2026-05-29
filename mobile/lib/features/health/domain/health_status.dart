class HealthStatus {
  const HealthStatus({
    required this.status,
    required this.service,
    required this.version,
    required this.timestamp,
  });

  final String status;
  final String service;
  final String version;
  final DateTime timestamp;

  factory HealthStatus.fromJson(Map<String, dynamic> json) {
    return HealthStatus(
      status: json['status'] as String? ?? 'unknown',
      service: json['service'] as String? ?? 'unknown',
      version: json['version'] as String? ?? 'dev',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  String get localizedTimestamp => timestamp.toLocal().toString();
}
