import 'package:flutter/material.dart';
import 'package:saas_uchet_mobile/features/business/domain/business_gateway.dart';

class CompanyEditorScreen extends StatefulWidget {
  const CompanyEditorScreen({
    super.key,
    required this.businessGateway,
    required this.accessToken,
    required this.companyId,
  });

  final BusinessGateway businessGateway;
  final String accessToken;
  final String companyId;

  @override
  State<CompanyEditorScreen> createState() => _CompanyEditorScreenState();
}

class _CompanyEditorScreenState extends State<CompanyEditorScreen> {
  static const _primaryColor = Color(0xFF00A86B);
  static const _bg = Color(0xFFF7FAF8);
  static const _textPrimary = Color(0xFF0F172A);

  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _legalFormCtrl = TextEditingController();
  final _iinCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _bankAccountCtrl = TextEditingController();
  final _bankBikCtrl = TextEditingController();
  String _country = 'KZ';
  String _companyRole = 'owner';

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isMembersLoading = false;
  bool _canViewMembers = false;
  bool _canManageMembers = false;
  String? _error;
  List<_CompanyMemberVm> _members = const [];

  @override
  void initState() {
    super.initState();
    _loadCompany();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _legalFormCtrl.dispose();
    _iinCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _regionCtrl.dispose();
    _postalCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankAccountCtrl.dispose();
    _bankBikCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCompany() async {
    try {
      final data = await widget.businessGateway.fetchCompany(
        accessToken: widget.accessToken,
        companyId: widget.companyId,
      );
      if (!mounted) return;
      setState(() {
        _nameCtrl.text = data['name'] as String? ?? '';
        _legalFormCtrl.text = data['legal_form'] as String? ?? '';
        _iinCtrl.text = data['iin'] as String? ?? '';
        _country = data['country'] as String? ?? 'KZ';
        _emailCtrl.text = data['email'] as String? ?? '';
        _phoneCtrl.text = data['phone'] as String? ?? '';
        _addressCtrl.text = data['address_line'] as String? ?? '';
        _cityCtrl.text = data['city'] as String? ?? '';
        _regionCtrl.text = data['region'] as String? ?? '';
        _postalCtrl.text = data['postal_code'] as String? ?? '';
        _bankNameCtrl.text = data['bank_name'] as String? ?? '';
        _bankAccountCtrl.text = data['bank_account'] as String? ?? '';
        _bankBikCtrl.text = data['bank_bik'] as String? ?? '';
        _companyRole = data['role'] as String? ?? 'staff';
        _canViewMembers = _companyRole == 'owner' || _companyRole == 'admin';
        _canManageMembers = _canViewMembers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await widget.businessGateway.updateCompany(
        accessToken: widget.accessToken,
        companyId: widget.companyId,
        payload: {
          'name': _nameCtrl.text.trim(),
          'legal_form': _legalFormCtrl.text.trim(),
          'country': _country,
          'iin': _iinCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'address_line': _addressCtrl.text.trim(),
          'city': _cityCtrl.text.trim(),
          'region': _regionCtrl.text.trim(),
          'postal_code': _postalCtrl.text.trim(),
          'bank_name': _bankNameCtrl.text.trim(),
          'bank_account': _bankAccountCtrl.text.trim(),
          'bank_bik': _bankBikCtrl.text.trim(),
          'is_vat_payer': false,
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _loadMembers() async {
    setState(() => _isMembersLoading = true);
    try {
      final data = await widget.businessGateway.fetchCompanyMembers(
        accessToken: widget.accessToken,
        companyId: widget.companyId,
      );
      if (!mounted) return;
      setState(() {
        _members = data.map(_CompanyMemberVm.fromJson).toList(growable: false);
        _isMembersLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isMembersLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _showAddMemberDialog() async {
    final phoneCtrl = TextEditingController();
    var selectedRole = 'staff';
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Добавить участника'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Телефон',
                    hintText: '+7 777 123 45 67',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  items: _memberRoles
                      .map(
                        (role) => DropdownMenuItem<String>(
                          value: role,
                          child: Text(_roleLabel(role)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => selectedRole = value);
                  },
                  decoration: const InputDecoration(labelText: 'Роль'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Добавить'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true) return;
      final data = await widget.businessGateway.addCompanyMember(
        accessToken: widget.accessToken,
        companyId: widget.companyId,
        payload: {
          'phone': phoneCtrl.text.trim(),
          'role': selectedRole,
        },
      );
      if (!mounted) return;
      final next = _CompanyMemberVm.fromJson(data);
      setState(() {
        final index = _members.indexWhere((item) => item.userId == next.userId);
        if (index >= 0) {
          _members = [
            ..._members.sublist(0, index),
            next,
            ..._members.sublist(index + 1),
          ];
        } else {
          _members = [..._members, next];
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      phoneCtrl.dispose();
    }
  }

  Future<void> _changeMemberRole(_CompanyMemberVm member) async {
    var selectedRole = member.role;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('Роль: ${member.fullName}'),
            content: DropdownButtonFormField<String>(
              initialValue: selectedRole,
              items: _memberRoles
                  .map(
                    (role) => DropdownMenuItem<String>(
                      value: role,
                      child: Text(_roleLabel(role)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) return;
                setDialogState(() => selectedRole = value);
              },
              decoration: const InputDecoration(labelText: 'Роль'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Сохранить'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true || selectedRole == member.role) return;
      final data = await widget.businessGateway.updateCompanyMemberRole(
        accessToken: widget.accessToken,
        companyId: widget.companyId,
        userId: member.userId,
        payload: {'role': selectedRole},
      );
      if (!mounted) return;
      final updated = _CompanyMemberVm.fromJson(data);
      setState(() {
        _members = _members
            .map((item) => item.userId == updated.userId ? updated : item)
            .toList(growable: false);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _removeMember(_CompanyMemberVm member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить участника?'),
        content:
            Text('Участник ${member.fullName} потеряет доступ к компании.'),
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
    if (confirmed != true) return;
    try {
      await widget.businessGateway.removeCompanyMember(
        accessToken: widget.accessToken,
        companyId: widget.companyId,
        userId: member.userId,
      );
      if (!mounted) return;
      setState(() {
        _members = _members
            .where((item) => item.userId != member.userId)
            .toList(growable: false);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Реквизиты компании',
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        actions: [
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: TextButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _primaryColor),
                      )
                    : const Text(
                        'Сохранить',
                        style: TextStyle(
                          color: _primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryColor))
          : _error != null
              ? _ErrorView(
                  message: _error!,
                  onRetry: () {
                    setState(() {
                      _error = null;
                      _isLoading = true;
                    });
                    _loadCompany();
                  },
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _EditorCard(
                        title: 'Основные данные',
                        children: [
                          _Field(
                            label: 'Название компании',
                            controller: _nameCtrl,
                            required: true,
                          ),
                          _Field(
                            label: 'Организационная форма',
                            hint: 'ТОО, АО, ИП...',
                            controller: _legalFormCtrl,
                          ),
                          _CountryDropdown(
                            value: _country,
                            onChanged: (v) => setState(() => _country = v!),
                          ),
                          _Field(
                            label: 'БИН / ИИН',
                            controller: _iinCtrl,
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _EditorCard(
                        title: 'Контакты',
                        children: [
                          _Field(
                            label: 'Email',
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          _Field(
                            label: 'Телефон',
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _EditorCard(
                        title: 'Адрес',
                        children: [
                          _Field(
                            label: 'Адрес',
                            controller: _addressCtrl,
                          ),
                          _Field(
                            label: 'Город',
                            controller: _cityCtrl,
                          ),
                          _Field(
                            label: 'Область / регион',
                            controller: _regionCtrl,
                          ),
                          _Field(
                            label: 'Почтовый индекс',
                            controller: _postalCtrl,
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _EditorCard(
                        title: 'Банковские реквизиты',
                        children: [
                          _Field(
                            label: 'Название банка',
                            controller: _bankNameCtrl,
                          ),
                          _Field(
                            label: 'ИИК (номер счёта)',
                            controller: _bankAccountCtrl,
                            keyboardType: TextInputType.number,
                          ),
                          _Field(
                            label: 'БИК банка',
                            controller: _bankBikCtrl,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }
}

class _EditorCard extends StatelessWidget {
  const _EditorCard({
    required this.title,
    required this.children,
    this.actions,
  });

  final String title;
  final List<Widget> children;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (actions != null) ...actions!,
              ],
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.required = false,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool required;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF00A86B), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEF4444)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
          ),
          filled: true,
          fillColor: const Color(0xFFF7FAF8),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        validator: required
            ? (v) =>
                (v == null || v.trim().isEmpty) ? 'Обязательное поле' : null
            : null,
      ),
    );
  }
}

class _CountryDropdown extends StatelessWidget {
  const _CountryDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String?> onChanged;

  static const _countries = [
    ('KZ', 'Казахстан'),
    ('RU', 'Россия'),
    ('KG', 'Кыргызстан'),
    ('UZ', 'Узбекистан'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: 'Страна',
          labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF00A86B), width: 1.5),
          ),
          filled: true,
          fillColor: const Color(0xFFF7FAF8),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        items: _countries
            .map(
              (c) => DropdownMenuItem(value: c.$1, child: Text(c.$2)),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A86B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

const _memberRoles = [
  'admin',
  'manager',
  'accountant',
  'warehouse',
  'sales',
  'staff'
];

String _roleLabel(String role) {
  switch (role) {
    case 'admin':
      return 'Администратор';
    case 'manager':
      return 'Менеджер';
    case 'accountant':
      return 'Бухгалтер';
    case 'warehouse':
      return 'Кладовщик';
    case 'sales':
      return 'Продажи';
    case 'owner':
      return 'Владелец';
    default:
      return 'Сотрудник';
  }
}

class _CompanyMemberVm {
  const _CompanyMemberVm({
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.role,
    required this.roleLabel,
    required this.isOwner,
    required this.isCurrentUser,
  });

  factory _CompanyMemberVm.fromJson(Map<String, dynamic> json) {
    return _CompanyMemberVm(
      userId: json['user_id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? 'staff',
      roleLabel: json['role_label'] as String? ??
          _roleLabel(json['role'] as String? ?? 'staff'),
      isOwner: json['is_owner'] as bool? ?? false,
      isCurrentUser: json['is_current_user'] as bool? ?? false,
    );
  }

  final String userId;
  final String fullName;
  final String phone;
  final String role;
  final String roleLabel;
  final bool isOwner;
  final bool isCurrentUser;
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.canManage,
    required this.onEdit,
    required this.onRemove,
  });

  final _CompanyMemberVm member;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFE6F7F0),
        child: Text(
          member.fullName.isEmpty
              ? '?'
              : member.fullName.trim().substring(0, 1).toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF00A86B),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(member.fullName.isEmpty ? member.phone : member.fullName),
      subtitle: Text(
        member.isCurrentUser
            ? '${member.roleLabel} · это вы'
            : '${member.roleLabel} · ${member.phone}',
      ),
      trailing: canManage
          ? PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value == 'remove') {
                  onRemove();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Text('Изменить роль'),
                ),
                PopupMenuItem<String>(
                  value: 'remove',
                  child: Text('Удалить'),
                ),
              ],
            )
          : member.isOwner
              ? const Chip(label: Text('Владелец'))
              : null,
    );
  }
}
