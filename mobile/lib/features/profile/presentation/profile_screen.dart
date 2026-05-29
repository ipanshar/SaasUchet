import 'package:flutter/material.dart';
import 'package:saas_uchet_mobile/core/config/api_config.dart';
import 'package:saas_uchet_mobile/core/network/api_exception.dart';
import 'package:saas_uchet_mobile/core/widgets/section_card.dart';
import 'package:saas_uchet_mobile/features/auth/domain/auth_gateway.dart';
import 'package:saas_uchet_mobile/features/auth/domain/auth_session.dart';
import 'package:saas_uchet_mobile/features/auth/domain/user_profile.dart';
import 'package:saas_uchet_mobile/features/health/data/health_api_client.dart';
import 'package:saas_uchet_mobile/features/health/domain/health_gateway.dart';
import 'package:saas_uchet_mobile/features/health/domain/health_status.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.authGateway,
    required this.session,
    required this.onLogout,
    required this.onSessionChanged,
    required this.onAccountDeleted,
    this.healthGateway,
  });

  final AuthGateway authGateway;
  final AuthSession session;
  final VoidCallback onLogout;
  final ValueChanged<AuthSession> onSessionChanged;
  final VoidCallback onAccountDeleted;
  final HealthGateway? healthGateway;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileFormKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  late final HealthGateway _healthGateway;
  late final bool _ownsHealthGateway;

  late AuthSession _session;
  bool _isSaving = false;
  bool _isRefreshingProfile = true;
  bool _isRefreshingHealth = true;
  String? _profileErrorMessage;
  String? _healthErrorMessage;
  HealthStatus? _healthStatus;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _ownsHealthGateway = widget.healthGateway == null;
    _healthGateway = widget.healthGateway ?? HealthApiClient();
    _syncControllersFromUser(_session.user);
    _refreshProfile();
    _refreshHealth();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    if (_ownsHealthGateway) {
      _healthGateway.dispose();
    }
    super.dispose();
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _isRefreshingProfile = true;
      _profileErrorMessage = null;
    });

    try {
      final user = await widget.authGateway.fetchProfile(
        accessToken: _session.accessToken,
      );
      _updateSessionUser(user);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.isUnauthorized) {
        widget.onLogout();
        return;
      }
      setState(() {
        _profileErrorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _profileErrorMessage = 'Не удалось загрузить профиль.\n$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingProfile = false;
        });
      }
    }
  }

  Future<void> _refreshHealth() async {
    setState(() {
      _isRefreshingHealth = true;
      _healthErrorMessage = null;
    });

    try {
      final status = await _healthGateway.fetchHealth();
      if (!mounted) {
        return;
      }
      setState(() {
        _healthStatus = status;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _healthErrorMessage = 'Не удалось получить health-check.\n$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingHealth = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_profileFormKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _profileErrorMessage = null;
    });

    try {
      final updatedUser = await widget.authGateway.updateProfile(
        accessToken: _session.accessToken,
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text.trim().isEmpty
            ? null
            : _passwordController.text,
      );

      _passwordController.clear();
      _updateSessionUser(updatedUser);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.isUnauthorized) {
        widget.onLogout();
        return;
      }
      setState(() {
        _profileErrorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _profileErrorMessage = 'Не удалось сохранить профиль.\n$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _confirmDeleteProfile() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удалить аккаунт?'),
          content: const Text(
            'Это действие удалит профиль и активные сессии. Отменить его нельзя.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isSaving = true;
      _profileErrorMessage = null;
    });

    try {
      await widget.authGateway.deleteProfile(accessToken: _session.accessToken);
      widget.onAccountDeleted();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.isUnauthorized) {
        widget.onLogout();
        return;
      }
      setState(() {
        _profileErrorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _profileErrorMessage = 'Не удалось удалить профиль.\n$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _updateSessionUser(UserProfile user) {
    if (!mounted) {
      return;
    }

    final session = _session.copyWith(user: user);
    setState(() {
      _session = session;
      _syncControllersFromUser(user);
    });
    widget.onSessionChanged(session);
  }

  void _syncControllersFromUser(UserProfile user) {
    _fullNameController.text = user.fullName;
    _phoneController.text = user.phone;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        actions: [
          IconButton(
            tooltip: 'Обновить профиль',
            onPressed: _isRefreshingProfile ? null : _refreshProfile,
            icon: const Icon(Icons.sync),
          ),
          TextButton(
            onPressed: _isSaving ? null : widget.onLogout,
            child: const Text('Выйти'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Привет, ${_session.user.fullName.split(' ').first}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Здесь можно посмотреть текущий профиль, обновить данные аккаунта и проверить состояние API.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                SectionCard(
                  title: 'Профиль',
                  subtitle:
                      'ФИО и телефон сохраняются в PostgreSQL. Новый пароль указывать необязательно.',
                  child: Form(
                    key: _profileFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _fullNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'ФИО',
                          ),
                          validator: _validateFullName,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Номер телефона',
                          ),
                          validator: _validatePhone,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Новый пароль',
                            helperText:
                                'Оставь пустым, если пароль менять не нужно.',
                          ),
                          validator: _validateOptionalPassword,
                        ),
                        const SizedBox(height: 8),
                        if (_profileErrorMessage != null) ...[
                          Text(
                            _profileErrorMessage!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.icon(
                              onPressed: _isSaving || _isRefreshingProfile
                                  ? null
                                  : _saveProfile,
                              icon: const Icon(Icons.save_outlined),
                              label: Text(
                                  _isSaving ? 'Сохраняем...' : 'Сохранить'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _isSaving ? null : _refreshProfile,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Обновить из API'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _ProfileMeta(session: _session),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Состояние API',
                  subtitle: 'Backend адрес: ${ApiConfig.baseUrl}',
                  child: _buildHealthContent(theme),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Опасная зона',
                  subtitle: 'Полностью удалить аккаунт и активные сессии.',
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: _isSaving ? null : _confirmDeleteProfile,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Удалить аккаунт'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHealthContent(ThemeData theme) {
    if (_isRefreshingHealth) {
      return const Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text('Проверяем соединение с API...'),
          ),
        ],
      );
    }

    if (_healthErrorMessage != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _healthErrorMessage!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _refreshHealth,
            icon: const Icon(Icons.refresh),
            label: const Text('Повторить'),
          ),
        ],
      );
    }

    final healthStatus = _healthStatus!;

    return Column(
      children: [
        _ProfileRow(label: 'Статус', value: healthStatus.status),
        _ProfileRow(label: 'Сервис', value: healthStatus.service),
        _ProfileRow(label: 'Версия', value: healthStatus.version),
        _ProfileRow(label: 'Время', value: healthStatus.localizedTimestamp),
      ],
    );
  }

  String? _validateFullName(String? value) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) {
      return 'Укажи ФИО';
    }
    if (normalized.runes.length < 5) {
      return 'Минимум 5 символов';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) {
      return 'Укажи номер телефона';
    }
    if (normalized.length < 10) {
      return 'Номер выглядит слишком коротким';
    }
    return null;
  }

  String? _validateOptionalPassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return null;
    }
    if (password.length < 8) {
      return 'Минимум 8 символов';
    }
    return null;
  }
}

class _ProfileMeta extends StatelessWidget {
  const _ProfileMeta({required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ProfileRow(label: 'ID', value: session.user.id),
        _ProfileRow(label: 'Телефон', value: session.user.phone),
        _ProfileRow(
          label: 'Создан',
          value: session.user.createdAt.toLocal().toString(),
        ),
        _ProfileRow(
          label: 'Сессия до',
          value: session.expiresAt.toLocal().toString(),
        ),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
