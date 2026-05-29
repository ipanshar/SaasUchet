import 'package:flutter/material.dart';
import 'package:saas_uchet_mobile/core/config/api_config.dart';
import 'package:saas_uchet_mobile/features/health/data/health_api_client.dart';
import 'package:saas_uchet_mobile/features/health/domain/health_gateway.dart';
import 'package:saas_uchet_mobile/features/health/domain/health_status.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key, this.healthGateway});

  final HealthGateway? healthGateway;

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  late final HealthGateway _healthGateway;
  late final bool _ownsGateway;

  bool _isLoading = true;
  String? _errorMessage;
  HealthStatus? _healthStatus;

  @override
  void initState() {
    super.initState();
    _ownsGateway = widget.healthGateway == null;
    _healthGateway = widget.healthGateway ?? HealthApiClient();
    _loadHealth();
  }

  @override
  void dispose() {
    if (_ownsGateway) {
      _healthGateway.dispose();
    }

    super.dispose();
  }

  Future<void> _loadHealth() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final status = await _healthGateway.fetchHealth();

      if (!mounted) {
        return;
      }

      setState(() {
        _healthStatus = status;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _healthStatus = null;
        _errorMessage = 'Не удалось подключиться к API.\n$error';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saas Uchet'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: _isLoading ? null : _loadHealth,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Стартовый мобильный клиент',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Экран проверяет доступность Go API и показывает текущий health-check.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            _InfoCard(
              title: 'Адрес API',
              child: SelectableText(
                ApiConfig.baseUrl,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildStatusCard(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme) {
    if (_isLoading) {
      return const _InfoCard(
        key: ValueKey('loading'),
        title: 'Проверка соединения',
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text('Отправляем запрос к API...'),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return _InfoCard(
        key: const ValueKey('error'),
        title: 'Соединение не установлено',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _errorMessage!,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadHealth,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    final status = _healthStatus!;

    return _InfoCard(
      key: const ValueKey('success'),
      title: 'API отвечает',
      child: Column(
        children: [
          _StatusRow(label: 'Статус', value: status.status),
          _StatusRow(label: 'Сервис', value: status.service),
          _StatusRow(label: 'Версия', value: status.version),
          _StatusRow(label: 'Время', value: status.localizedTimestamp),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
