import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:saas_uchet_mobile/core/network/api_exception.dart';
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

class _AuthScreenState extends State<AuthScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _loginPhoneController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _registerFullNameController = TextEditingController();
  final _registerPhoneController = TextEditingController();
  final _registerPasswordController = TextEditingController();

  bool _isLoginMode = true;
  bool _showLoginPassword = false;
  bool _showRegisterPassword = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
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
        phone: _phoneToE164(_loginPhoneController),
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
        phone: _phoneToE164(_registerPhoneController),
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
              Color(0xFFF7FBF8),
              Color(0xFFFFFFFF),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF00A86B),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2200A86B),
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.business_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _isLoginMode ? 'Вход в систему' : 'Регистрация',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _isLoginMode
                    ? 'Войдите для управления вашим бизнесом.'
                    : 'Создайте аккаунт, а компанию сможете добавить в профиле.',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _isLoginMode ? _buildLoginForm() : _buildRegisterForm(),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Text(
                  _errorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          setState(() {
                            _isLoginMode = !_isLoginMode;
                            _errorMessage = null;
                          });
                        },
                  child: Text.rich(
                    TextSpan(
                      text: _isLoginMode
                          ? 'Нет аккаунта? '
                          : 'Уже есть аккаунт? ',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                      ),
                      children: [
                        TextSpan(
                          text: _isLoginMode ? 'Зарегистрироваться' : 'Войти',
                          style: const TextStyle(
                            color: Color(0xFF00A86B),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Продолжая, вы соглашаетесь с условиями использования и политикой конфиденциальности.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        key: const ValueKey('login-form'),
        children: [
          _KzPhoneField(
            controller: _loginPhoneController,
            validator: _validatePhone,
          ),
          const SizedBox(height: 16),
          _AuthField(
            controller: _loginPasswordController,
            label: 'Пароль',
            hintText: '••••••••',
            obscureText: !_showLoginPassword,
            prefixIcon: Icons.lock_rounded,
            trailingIcon: _showLoginPassword
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            onTrailingPressed: () {
              setState(() {
                _showLoginPassword = !_showLoginPassword;
              });
            },
            validator: _validatePassword,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isSubmitting ? null : () {},
              child: const Text('Забыли пароль?'),
            ),
          ),
          const SizedBox(height: 12),
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
        key: const ValueKey('register-form'),
        children: [
          _AuthField(
            controller: _registerFullNameController,
            label: 'ФИО',
            hintText: 'Иван Петров',
            textCapitalization: TextCapitalization.words,
            prefixIcon: Icons.person_rounded,
            validator: _validateFullName,
          ),
          const SizedBox(height: 16),
          _KzPhoneField(
            controller: _registerPhoneController,
            validator: _validatePhone,
          ),
          const SizedBox(height: 16),
          _AuthField(
            controller: _registerPasswordController,
            label: 'Пароль',
            hintText: 'Минимум 8 символов',
            obscureText: !_showRegisterPassword,
            prefixIcon: Icons.lock_rounded,
            trailingIcon: _showRegisterPassword
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            onTrailingPressed: () {
              setState(() {
                _showRegisterPassword = !_showRegisterPassword;
              });
            },
            validator: _validatePassword,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSubmitting ? null : _submitRegister,
              child: Text(
                _isSubmitting ? 'Создаем аккаунт...' : 'Зарегистрироваться',
              ),
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
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return 'Укажи номер телефона';
    }
    if (digits.length != 10) {
      return 'Введите 10 цифр номера';
    }
    if (digits[0] != '7') {
      return 'Это не похоже на номер Казахстана';
    }
    return null;
  }

  String _phoneToE164(TextEditingController controller) {
    final digits = controller.text.replaceAll(RegExp(r'\D'), '');
    return '+7$digits';
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

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.prefixIcon,
    required this.validator,
    this.obscureText = false,
    this.trailingIcon,
    this.onTrailingPressed,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData prefixIcon;
  final String? Function(String?) validator;
  final bool obscureText;
  final IconData? trailingIcon;
  final VoidCallback? onTrailingPressed;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          textCapitalization: textCapitalization,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(prefixIcon),
            suffixIcon: trailingIcon == null
                ? null
                : IconButton(
                    onPressed: onTrailingPressed,
                    icon: Icon(trailingIcon),
                  ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}

class _KzPhoneField extends StatelessWidget {
  const _KzPhoneField({
    required this.controller,
    required this.validator,
  });

  final TextEditingController controller;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Номер телефона',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.phone,
          inputFormatters: [_KzPhoneInputFormatter()],
          decoration: const InputDecoration(
            hintText: '701 123 45 67',
            prefixIcon: Padding(
              padding: EdgeInsets.only(left: 16, right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🇰🇿', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 8),
                  Text(
                    '+7',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
          ),
          validator: validator,
        ),
      ],
    );
  }
}

/// Форматирует ввод казахстанского номера: только цифры (макс 10),
/// сгруппированные как `XXX XXX XX XX`.
class _KzPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }

    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 3 || i == 6 || i == 8) {
        buffer.write(' ');
      }
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
