import 'package:saas_uchet_mobile/features/health/domain/health_status.dart';

abstract class HealthGateway {
  Future<HealthStatus> fetchHealth();

  void dispose() {}
}
