import 'package:flutter/material.dart';
import 'package:saas_uchet_mobile/core/config/api_config.dart';
import 'package:saas_uchet_mobile/core/network/api_exception.dart';
import 'package:saas_uchet_mobile/core/widgets/section_card.dart';
import 'package:saas_uchet_mobile/features/auth/domain/auth_gateway.dart';
import 'package:saas_uchet_mobile/features/auth/domain/auth_session.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.authGateway,
    required this.onAuthenticated,
  });

  final AuthGateway authGateway;
  final ValueChanged<AuthSession> onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _loginPhoneController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _registerFullNameController = TextEditingController();
  final _registerPhoneController = TextEditingController();
  final _registerPasswordController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginPhoneController.dispose();
    _loginPasswordController.dispose();
    _registerFullNameController.dispose();
    _registerPhoneController.dispose();
    _registerPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (!_loginFormKey.currentState!.validate()) {
      return;
    }

    await _runAuthAction(() async {
      final session = await widget.authGateway.login(
        phone: _loginPhoneController.text.trim(),
        password: _loginPasswordController.text,
      );
      widget.onAuthenticated(session);
    });
  }

  Future<void> _submitRegister() async {
    if (!_registerFormKey.currentState!.validate()) {
      return;
    }

    await _runAuthAction(() async {
      final session = await widget.authGateway.register(
        fullName: _registerFullNameController.text.trim(),
        phone: _registerPhoneController.text.trim(),
        password: _registerPasswordController.text,
      );
      widget.onAuthenticated(session);
    });
  }

  Future<void> _runAuthAction(Future<void> Function() action) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await action();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Не удалось выполнить запрос.\n$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFE7F4EF),
              Color(0xFFF6F3E8),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const SizedBox(height: 12),
                  Text(
                    'Saas Uchet',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F4037),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Войди по номеру телефона или создай аккаунт, чтобы управлять профилем и работать с API.',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF355D53),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SectionCard(
                    title: 'Подключение к API',
                    subtitle: 'Текущий адрес backend для мобильного клиента.',
                    child: SelectableText(
                      ApiConfig.baseUrl,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Аккаунт',
                    subtitle:
                        'Регистрация использует ФИО, номер телефона и пароль. Логин выполняется по номеру телефона.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TabBar(
                          controller: _tabController,
                          tabs: const [
                            Tab(text: 'Вход'),
                            Tab(text: 'Регистрация'),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 350,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildLoginForm(),
                              _buildRegisterForm(),
                            ],
                          ),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _loginPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Номер телефона',
              hintText: '+7 701 123 45 67',
            ),
            validator: _validatePhone,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _loginPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Пароль',
            ),
            validator: _validatePassword,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSubmitting ? null : _submitLogin,
              child: Text(_isSubmitting ? 'Входим...' : 'Войти'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _registerFullNameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'ФИО',
              hintText: 'Иван Петров',
            ),
            validator: _validateFullName,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _registerPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Номер телефона',
              hintText: '+7 701 123 45 67',
            ),
            validator: _validatePhone,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _registerPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Пароль',
            ),
            validator: _validatePassword,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSubmitting ? null : _submitRegister,
              child: Text(_isSubmitting ? 'Создаём...' : 'Создать аккаунт'),
            ),
          ),
        ],
      ),
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

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Укажи пароль';
    }
    if (password.length < 8) {
      return 'Минимум 8 символов';
    }
    return null;
  }
}
