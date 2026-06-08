import 'package:flutter/material.dart';
import 'package:saas_uchet_mobile/core/network/api_exception.dart';
import 'package:saas_uchet_mobile/features/auth/domain/auth_gateway.dart';
import 'package:saas_uchet_mobile/features/auth/domain/auth_session.dart';
import 'package:saas_uchet_mobile/features/auth/domain/company_profile.dart';
import 'package:saas_uchet_mobile/features/auth/domain/user_profile.dart';
import 'package:saas_uchet_mobile/features/business/domain/business_gateway.dart';

class ProfileEditorScreen extends StatefulWidget {
  const ProfileEditorScreen({
    super.key,
    required this.authGateway,
    required this.businessGateway,
    required this.session,
    required this.onLogout,
    required this.onSessionChanged,
    required this.onAccountDeleted,
  });

  final AuthGateway authGateway;
  final BusinessGateway businessGateway;
  final AuthSession session;
  final VoidCallback onLogout;
  final ValueChanged<AuthSession> onSessionChanged;
  final VoidCallback onAccountDeleted;

  @override
  State<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<ProfileEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final List<_EditableCompany> _companies = [];

  late AuthSession _session;
  bool _isSaving = false;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _syncFromUser(_session.user);
    _refreshProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    for (final company in _companies) {
      company.dispose();
    }
    super.dispose();
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        widget.authGateway.fetchProfile(
          accessToken: _session.accessToken,
        ),
        widget.businessGateway.fetchCompanies(
          accessToken: _session.accessToken,
        ),
      ]);
      final user = results[0] as UserProfile;
      final companies = _ownerCompaniesFromJson(
        results[1] as List<Map<String, dynamic>>,
      );
      _applyUser(user, companies: companies);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.isUnauthorized) {
        widget.onLogout();
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
        _errorMessage = 'Не удалось загрузить профиль.\n$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final updatedUser = await widget.authGateway.updateProfile(
        accessToken: _session.accessToken,
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        companies: _companies.map((item) => item.toProfile()).toList(),
        password: _passwordController.text.trim().isEmpty
            ? null
            : _passwordController.text,
      );
      _passwordController.clear();
      _applyUser(
        updatedUser,
        companies: _companies.map((item) => item.toProfile()).toList(),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.isUnauthorized) {
        widget.onLogout();
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
        _errorMessage = 'Не удалось сохранить профиль.\n$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteProfile() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить аккаунт?'),
        content: const Text(
          'Это действие удалит профиль и активные сессии. Если вы владеете компанией или ваш аккаунт связан с бизнес-записями, удаление будет недоступно.',
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
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
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
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Не удалось удалить профиль.\n$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _applyUser(UserProfile user, {List<CompanyProfile>? companies}) {
    final mergedUser =
        companies != null ? user.copyWith(companies: companies) : user;
    final session = _session.copyWith(user: mergedUser);
    setState(() {
      _session = session;
      _syncFromUser(mergedUser);
    });
    widget.onSessionChanged(session);
  }

  void _syncFromUser(UserProfile user) {
    _fullNameController.text = user.fullName;
    _phoneController.text = user.phone;
    for (final company in _companies) {
      company.dispose();
    }
    _companies
      ..clear()
      ..addAll(user.companies.map(_EditableCompany.fromProfile));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    TextButton.icon(
                      onPressed:
                          _isSaving ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Назад'),
                    ),
                    const SizedBox(height: 8),
                    const _ProfileCard(
                      gradient: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Редактирование профиля',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Настройте данные аккаунта и компании в новом интерфейсе приложения.',
                            style: TextStyle(
                              color: Color(0xCCFFFFFF),
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ProfileCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionTitle('Личные данные'),
                          const SizedBox(height: 14),
                          _ProfileField(
                            controller: _fullNameController,
                            label: 'ФИО',
                            hintText: 'Иван Петров',
                            icon: Icons.person_rounded,
                            validator: _validateFullName,
                          ),
                          const SizedBox(height: 14),
                          _ProfileField(
                            controller: _phoneController,
                            label: 'Номер телефона',
                            hintText: '+7 701 123 45 67',
                            icon: Icons.phone_rounded,
                            keyboardType: TextInputType.phone,
                            validator: _validatePhone,
                          ),
                          const SizedBox(height: 14),
                          _ProfileField(
                            controller: _passwordController,
                            label: 'Новый пароль',
                            hintText: 'Оставьте пустым, если менять не нужно',
                            icon: Icons.lock_rounded,
                            obscureText: true,
                            validator: _validateOptionalPassword,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ProfileCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Expanded(child: _SectionTitle('Компании')),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Здесь показываются компании владельца из основного бизнес-списка. Реквизиты компании редактируются на отдельном экране "Компания".',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (_companies.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Text('Компании пока не добавлены.'),
                            ),
                          for (var index = 0;
                              index < _companies.length;
                              index++) ...[
                            _CompanyEditorCard(
                              index: index,
                              company: _companies[index],
                              enabled: false,
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _isSaving ? null : _saveProfile,
                            icon: const Icon(Icons.save_rounded),
                            label:
                                Text(_isSaving ? 'Сохраняем...' : 'Сохранить'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isSaving ? null : _refreshProfile,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Обновить'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _ProfileCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionTitle('Опасная зона'),
                          const SizedBox(height: 8),
                          const Text(
                            'Полностью удалить аккаунт и активные сессии. Удаление может быть недоступно, если вы владеете компанией или ваш аккаунт уже связан с бизнес-историей.',
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.tonalIcon(
                            onPressed: _isSaving ? null : _deleteProfile,
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('Удалить аккаунт'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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

  List<CompanyProfile> _ownerCompaniesFromJson(
    List<Map<String, dynamic>> companies,
  ) {
    return companies
        .where((company) => (company['role'] as String? ?? '') == 'owner')
        .map(
          (company) => CompanyProfile(
            name: company['name'] as String? ?? '',
            country: company['country'] as String? ?? '',
            iin: company['iin'] as String? ?? '',
          ),
        )
        .toList(growable: false);
  }
}

class _EditableCompany {
  _EditableCompany({
    required this.nameController,
    required this.countryController,
    required this.iinController,
  });

  factory _EditableCompany.fromProfile(CompanyProfile profile) {
    return _EditableCompany(
      nameController: TextEditingController(text: profile.name),
      countryController: TextEditingController(text: profile.country),
      iinController: TextEditingController(text: profile.iin),
    );
  }

  final TextEditingController nameController;
  final TextEditingController countryController;
  final TextEditingController iinController;

  CompanyProfile toProfile() {
    return CompanyProfile(
      name: nameController.text.trim(),
      country: countryController.text.trim().toUpperCase(),
      iin: iinController.text.trim(),
    );
  }

  void dispose() {
    nameController.dispose();
    countryController.dispose();
    iinController.dispose();
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.child,
    this.gradient = false,
  });

  final Widget child;
  final bool gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: gradient ? null : Colors.white,
        gradient: gradient
            ? const LinearGradient(
                colors: [Color(0xFF00A86B), Color(0xFF008F5B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(24),
        border: gradient ? null : Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    required this.validator,
    this.keyboardType,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;
  final bool obscureText;

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
          keyboardType: keyboardType,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(icon),
          ),
          validator: validator,
        ),
      ],
    );
  }
}

class _CompanyEditorCard extends StatelessWidget {
  const _CompanyEditorCard({
    required this.index,
    required this.company,
    required this.enabled,
  });

  final int index;
  final _EditableCompany company;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Компания ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ProfileField(
            controller: company.nameController,
            label: 'Название компании',
            hintText: 'ТОО Мой Бизнес',
            icon: Icons.business_rounded,
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'Укажи название компании';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          _ProfileField(
            controller: company.countryController,
            label: 'Код страны',
            hintText: 'KZ',
            icon: Icons.public_rounded,
            validator: (value) {
              final country = (value ?? '').trim().toUpperCase();
              if (country.isEmpty) {
                return 'Укажи код страны';
              }
              if (country.length != 2) {
                return 'Нужен код из 2 букв';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          _ProfileField(
            controller: company.iinController,
            label: 'ИИН',
            hintText: '12 цифр',
            icon: Icons.badge_rounded,
            keyboardType: TextInputType.number,
            validator: (value) {
              final country =
                  company.countryController.text.trim().toUpperCase();
              final iin = (value ?? '').trim();
              if (country == 'KZ' && iin.isEmpty) {
                return 'Для компаний Казахстана ИИН обязателен';
              }
              if (iin.isNotEmpty && !RegExp(r'^\d{12}$').hasMatch(iin)) {
                return 'ИИН должен содержать 12 цифр';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}
