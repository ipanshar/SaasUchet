part of 'business_shell.dart';

class _DashboardScreen extends StatelessWidget {
  const _DashboardScreen({
    required this.session,
    required this.overview,
    required this.companies,
    required this.activeCompanyId,
    required this.onSwitchCompany,
    required this.onSetDefaultCompany,
    required this.onCreateCompany,
    required this.onAddCompanyMember,
  });

  final AuthSession session;
  final _OverviewData overview;
  final List<_Company> companies;
  final String? activeCompanyId;
  final Future<void> Function(String companyId) onSwitchCompany;
  final Future<void> Function(String companyId) onSetDefaultCompany;
  final Future<void> Function(Map<String, dynamic> payload) onCreateCompany;
  final Future<void> Function(String companyId, Map<String, dynamic> payload)
      onAddCompanyMember;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _GradientHeader(
            title: overview.companyName,
            subtitle: 'Добро пожаловать',
            onTitleTap: () => _showCompanySwitcher(context),
            trailing: _CircleInitials(
              text: overview.initials,
              size: 52,
              foregroundColor: Colors.white,
              backgroundColor: const Color(0x33FFFFFF),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Общая выручка за месяц',
                  style: TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  overview.dashboard.monthlyRevenue,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.arrow_upward_rounded,
                      color: Color(0xFF9AE6B4),
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      overview.dashboard.revenueChange,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'vs прошлый месяц',
                      style: TextStyle(color: Color(0xB3FFFFFF)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            child: Column(
              children: [
                Transform.translate(
                  offset: const Offset(0, -18),
                  child: GridView.count(
                    crossAxisCount: 2,
                    childAspectRatio: 1.28,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: overview.dashboard.kpis
                        .map(
                          (kpi) => _KpiCard(
                            title: kpi.title,
                            value: kpi.value,
                            change: kpi.change,
                            changeColor: toneColor(kpi.changeTone),
                            icon: iconFor(kpi.icon),
                            iconBackground: toneColor(kpi.iconTone),
                          ),
                        )
                        .toList(),
                  ),
                ),
                _BusinessCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader(
                        title: 'График продаж',
                        actionLabel: 'Подробнее',
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 190,
                        child:
                            _SalesChart(points: overview.dashboard.salesSeries),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _BusinessCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader(title: 'Последние действия'),
                      const SizedBox(height: 14),
                      ...overview.recentActivities.map(
                        (activity) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _ActivityRow(activity: activity),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCompanySwitcher(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF7FAF8),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: SizedBox(width: 48, child: Divider(thickness: 4)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Мои компании',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  if (companies.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Список компаний недоступен',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: companies.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final company = companies[index];
                          final isActive = company.id == activeCompanyId;
                          return _BusinessCard(
                            child: InkWell(
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                onSwitchCompany(company.id);
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    isActive
                                        ? Icons.check_circle_rounded
                                        : Icons.circle_outlined,
                                    color: isActive
                                        ? const Color(0xFF00A86B)
                                        : const Color(0xFFCBD5E1),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          company.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          company.isDefault
                                              ? '${company.roleLabel} · по умолчанию'
                                              : company.roleLabel,
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Сделать основной',
                                    onPressed: company.isDefault
                                        ? null
                                        : () {
                                            Navigator.of(sheetContext).pop();
                                            onSetDefaultCompany(company.id);
                                          },
                                    icon: Icon(
                                      company.isDefault
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      color: company.isDefault
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _showCreateCompanySheet(context);
                          },
                          icon: const Icon(Icons.add_business_rounded),
                          label: const Text('Компания'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _showAddMemberSheet(context);
                          },
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: const Text('Сотрудник'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCreateCompanySheet(BuildContext context) async {
    final payload = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CompanyFormSheet(),
    );
    if (payload == null) return;
    try {
      await onCreateCompany(payload);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _showAddMemberSheet(BuildContext context) async {
    final targetId = activeCompanyId ??
        (companies.isNotEmpty ? companies.first.id : null);
    if (targetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала выберите компанию')),
      );
      return;
    }
    final payload = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddMemberFormSheet(),
    );
    if (payload == null) return;
    try {
      await onAddCompanyMember(targetId, payload);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }
}

class _CompanyFormSheet extends StatefulWidget {
  const _CompanyFormSheet();

  @override
  State<_CompanyFormSheet> createState() => _CompanyFormSheetState();
}

class _CompanyFormSheetState extends State<_CompanyFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _iinController = TextEditingController();
  String _country = 'KZ';

  @override
  void dispose() {
    _nameController.dispose();
    _iinController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(<String, dynamic>{
      'name': _nameController.text.trim(),
      'country': _country,
      'iin': _iinController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF7FAF8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: SizedBox(width: 48, child: Divider(thickness: 4)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Новая компания',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  _ClientTextField(
                    controller: _nameController,
                    label: 'Название компании',
                    validator: (value) {
                      if (value == null || value.trim().length < 2) {
                        return 'Введите название';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _country,
                    decoration: const InputDecoration(labelText: 'Страна'),
                    items: const [
                      DropdownMenuItem(value: 'KZ', child: Text('Казахстан')),
                      DropdownMenuItem(value: 'RU', child: Text('Россия')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _country = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  _ClientTextField(
                    controller: _iinController,
                    label: _country == 'KZ' ? 'БИН / ИИН' : 'Идентификатор',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final trimmed = value?.trim() ?? '';
                      if (_country == 'KZ') {
                        if (trimmed.length != 12 ||
                            int.tryParse(trimmed) == null) {
                          return 'БИН/ИИН — 12 цифр';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submit,
                      child: const Text('Создать компанию'),
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
}

class _AddMemberFormSheet extends StatefulWidget {
  const _AddMemberFormSheet();

  @override
  State<_AddMemberFormSheet> createState() => _AddMemberFormSheetState();
}

class _AddMemberFormSheetState extends State<_AddMemberFormSheet> {
  static const _roles = <String, String>{
    'staff': 'Сотрудник',
    'manager': 'Менеджер',
    'sales': 'Продажи',
    'warehouse': 'Склад',
    'accountant': 'Бухгалтер',
    'admin': 'Администратор',
  };

  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  String _role = 'staff';

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(<String, dynamic>{
      'phone': _phoneController.text.trim(),
      'role': _role,
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF7FAF8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: SizedBox(width: 48, child: Divider(thickness: 4)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Добавить сотрудника',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Пользователь должен быть уже зарегистрирован в приложении.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  _ClientTextField(
                    controller: _phoneController,
                    label: 'Телефон сотрудника',
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.trim().length < 10) {
                        return 'Введите телефон';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _role,
                    decoration: const InputDecoration(labelText: 'Роль'),
                    items: _roles.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) setState(() => _role = value);
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submit,
                      child: const Text('Добавить'),
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
}
