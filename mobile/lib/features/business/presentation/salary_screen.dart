part of 'business_shell.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Salary / Зарплата — root screen with Employees + Payroll tabs
// ─────────────────────────────────────────────────────────────────────────────

class _SalaryScreen extends StatefulWidget {
  const _SalaryScreen({
    required this.accessToken,
    required this.businessGateway,
    required this.accounts,
    this.canWrite = true,
  });

  final String accessToken;
  final BusinessGateway businessGateway;
  final List<_BankAccount> accounts;
  final bool canWrite;

  @override
  State<_SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<_SalaryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<_Employee> _employees = [];
  List<_PayrollPeriod> _periods = [];

  bool _isLoading = true;
  String? _loadError;
  bool _isFabExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        widget.businessGateway.fetchEmployees(accessToken: widget.accessToken),
        widget.businessGateway
            .fetchPayrollPeriods(accessToken: widget.accessToken),
      ]);
      if (!mounted) return;
      setState(() {
        _employees = results[0].map(_employeeFromJson).toList();
        _periods = results[1].map(_payrollPeriodFromJson).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = '$e';
        _isLoading = false;
      });
    }
  }

  void _dismissFab() {
    if (_isFabExpanded) setState(() => _isFabExpanded = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(_loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    final fabActions =
        _tabController.index == 0 ? _employeeFabActions : _periodFabActions;

    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              _GradientHeader(
                title: 'Зарплата',
                subtitle: _tabController.index == 0
                    ? _pluralEmployees(_employees.length)
                    : _pluralPeriods(_periods.length),
                trailing: IconButton(
                  icon: const Icon(Icons.settings_rounded, color: Colors.white),
                  tooltip: 'Настройки начислений',
                  onPressed: _openSettings,
                ),
                child: TabBar(
                  controller: _tabController,
                  onTap: (_) => _dismissFab(),
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xCCFFFFFF),
                  indicator: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [
                    Tab(text: 'Сотрудники'),
                    Tab(text: 'Ведомости'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _EmployeesTab(
                      employees: _employees,
                      accessToken: widget.accessToken,
                      gateway: widget.businessGateway,
                      onChanged: _loadData,
                    ),
                    _PayrollPeriodsTab(
                      periods: _periods,
                      employees: _employees,
                      accounts: widget.accounts,
                      accessToken: widget.accessToken,
                      gateway: widget.businessGateway,
                      onChanged: _loadData,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (widget.canWrite)
          Positioned(
            right: 16,
            bottom: 90,
            child: _FabMenu(
              expanded: _isFabExpanded,
              actions: fabActions,
              onToggle: () => setState(() => _isFabExpanded = !_isFabExpanded),
              onActionSelected: _handleFabAction,
            ),
          ),
      ],
    );
  }

  static const _employeeFabActions = [
    _FabMenuAction(
      id: 'employee_add',
      label: 'Новый сотрудник',
      icon: Icons.person_add_alt_1_rounded,
      color: Color(0xFF8B5CF6),
    ),
  ];

  static const _periodFabActions = [
    _FabMenuAction(
      id: 'period_add',
      label: 'Новая ведомость',
      icon: Icons.calculate_rounded,
      color: Color(0xFF00A86B),
    ),
  ];

  Future<void> _handleFabAction(_FabMenuAction action) async {
    setState(() => _isFabExpanded = false);
    switch (action.id) {
      case 'employee_add':
        await _showEmployeeSheet();
      case 'period_add':
        await _showCreatePeriodSheet();
    }
  }

  Future<void> _showEmployeeSheet({_Employee? initial}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EmployeeSheet(
        initial: initial,
        accessToken: widget.accessToken,
        gateway: widget.businessGateway,
        onSaved: _loadData,
      ),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PayrollSettingsScreen(
          accessToken: widget.accessToken,
          gateway: widget.businessGateway,
        ),
      ),
    );
  }

  Future<void> _showCreatePeriodSheet() async {
    if (_employees.where((e) => e.isActive).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала добавьте хотя бы одного активного сотрудника'),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreatePeriodSheet(
        accessToken: widget.accessToken,
        gateway: widget.businessGateway,
        onSaved: _loadData,
      ),
    );
  }

  static String _pluralEmployees(int n) {
    if (n % 100 >= 11 && n % 100 <= 19) return '$n сотрудников';
    switch (n % 10) {
      case 1:
        return '$n сотрудник';
      case 2:
      case 3:
      case 4:
        return '$n сотрудника';
      default:
        return '$n сотрудников';
    }
  }

  static String _pluralPeriods(int n) {
    if (n % 100 >= 11 && n % 100 <= 19) return '$n ведомостей';
    switch (n % 10) {
      case 1:
        return '$n ведомость';
      case 2:
      case 3:
      case 4:
        return '$n ведомости';
      default:
        return '$n ведомостей';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Employees tab
// ─────────────────────────────────────────────────────────────────────────────

class _EmployeesTab extends StatelessWidget {
  const _EmployeesTab({
    required this.employees,
    required this.accessToken,
    required this.gateway,
    required this.onChanged,
  });

  final List<_Employee> employees;
  final String accessToken;
  final BusinessGateway gateway;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (employees.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.badge_outlined, size: 56, color: Color(0xFFCBD5E1)),
            SizedBox(height: 12),
            Text('Сотрудников пока нет',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16)),
            SizedBox(height: 4),
            Text('Нажмите + чтобы добавить сотрудника',
                style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: employees.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => _EmployeeTile(
        employee: employees[i],
        accessToken: accessToken,
        gateway: gateway,
        onChanged: onChanged,
      ),
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  const _EmployeeTile({
    required this.employee,
    required this.accessToken,
    required this.gateway,
    required this.onChanged,
  });

  final _Employee employee;
  final String accessToken;
  final BusinessGateway gateway;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return _BusinessCard(
      onTap: () => _edit(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CircleInitials(
                text: employee.fullName,
                size: 44,
                foregroundColor: const Color(0xFF8B5CF6),
                backgroundColor: const Color(0x1A8B5CF6),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(employee.fullName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    if (employee.position.isNotEmpty)
                      Text(employee.position,
                          style: const TextStyle(
                              color: Color(0xFF64748B), fontSize: 12)),
                  ],
                ),
              ),
              _StatusBadge(
                label: employee.salaryTypeLabel,
                kind: StatusKind.info,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                employee.hasLinkedUser
                    ? Icons.person_rounded
                    : Icons.person_off_outlined,
                size: 16,
                color: employee.hasLinkedUser
                    ? const Color(0xFF00A86B)
                    : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  employee.linkedUserLabel,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: employee.hasLinkedUser
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.payments_outlined,
                  size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(employee.payDescription,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              if (!employee.isActive)
                const _StatusBadge(
                    label: 'Неактивен', kind: StatusKind.neutral),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFEF4444), size: 20),
                onPressed: () => _delete(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _edit(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EmployeeSheet(
        initial: employee,
        accessToken: accessToken,
        gateway: gateway,
        onSaved: onChanged,
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить сотрудника?'),
        content: Text('«${employee.fullName}» будет удалён из справочника.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await gateway.deleteEmployee(
          accessToken: accessToken, employeeId: employee.id);
      onChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Employee bottom sheet (create / edit)
// ─────────────────────────────────────────────────────────────────────────────

class _EmployeeSheet extends StatefulWidget {
  const _EmployeeSheet({
    this.initial,
    required this.accessToken,
    required this.gateway,
    required this.onSaved,
  });

  final _Employee? initial;
  final String accessToken;
  final BusinessGateway gateway;
  final VoidCallback onSaved;

  @override
  State<_EmployeeSheet> createState() => _EmployeeSheetState();
}

class _EmployeeSheetState extends State<_EmployeeSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _positionCtrl;
  late final TextEditingController _iinCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _monthlyCtrl;
  late final TextEditingController _hourlyCtrl;
  late final TextEditingController _salesPercentCtrl;
  late final TextEditingController _standardDaysCtrl;
  late final TextEditingController _notesCtrl;

  String _salaryType = 'monthly';
  String _salesBasis = 'revenue';
  String _selectedUserId = '';
  List<_PayrollUser> _users = const [];
  bool _isActive = true;
  bool _isSubmitting = false;
  bool _loadingUsers = true;
  bool _userSelectedManually = false;
  String? _usersError;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _nameCtrl = TextEditingController(text: e?.fullName ?? '');
    _positionCtrl = TextEditingController(text: e?.position ?? '');
    _iinCtrl = TextEditingController(text: e?.iin ?? '');
    _phoneCtrl = TextEditingController(text: e?.phone ?? '');
    _monthlyCtrl = TextEditingController(
        text: e == null ? '' : e.monthlySalary.toString());
    _hourlyCtrl =
        TextEditingController(text: e == null ? '' : e.hourlyRate.toString());
    _salesPercentCtrl = TextEditingController(
        text: (e == null || e.salesPercent == 0)
            ? ''
            : _formatPercent(e.salesPercent));
    _standardDaysCtrl =
        TextEditingController(text: (e?.standardDays ?? 22).toString());
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _salaryType = e?.salaryType ?? 'monthly';
    _salesBasis = e?.salesBasis ?? 'revenue';
    _selectedUserId = e?.userId ?? '';
    _userSelectedManually = _selectedUserId.isNotEmpty;
    _isActive = e?.isActive ?? true;
    _phoneCtrl.addListener(_autoSelectUserByPhone);
    _loadUsers();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _positionCtrl.dispose();
    _iinCtrl.dispose();
    _phoneCtrl.removeListener(_autoSelectUserByPhone);
    _phoneCtrl.dispose();
    _monthlyCtrl.dispose();
    _hourlyCtrl.dispose();
    _salesPercentCtrl.dispose();
    _standardDaysCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  bool get _showMonthly =>
      _salaryType == 'monthly' || _salaryType == 'combined';
  bool get _showHourly => _salaryType == 'hourly';

  String get _selectedUserValue {
    if (_selectedUserId.isEmpty) return '';
    if (_users.any((user) => user.userId == _selectedUserId)) {
      return _selectedUserId;
    }
    return _selectedFallbackUserLabel.isNotEmpty ? _selectedUserId : '';
  }

  String get _selectedFallbackUserLabel {
    final initial = widget.initial;
    if (_selectedUserId.isEmpty ||
        initial == null ||
        initial.userId != _selectedUserId) {
      return '';
    }
    return initial.linkedUserLabel;
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loadingUsers = true;
      _usersError = null;
    });
    try {
      final payload = await widget.gateway.fetchPayrollUsers(
        accessToken: widget.accessToken,
      );
      final users = payload.map(_payrollUserFromJson).toList(growable: false);
      if (!mounted) return;
      setState(() {
        _users = users;
        if (_selectedUserId.isNotEmpty &&
            !users.any((user) => user.userId == _selectedUserId) &&
            _selectedFallbackUserLabel.isEmpty) {
          _selectedUserId = '';
          _userSelectedManually = false;
        }
        _loadingUsers = false;
      });
      _autoSelectUserByPhone();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _users = const [];
        _loadingUsers = false;
        _usersError = 'Не удалось загрузить пользователей компании';
      });
    }
  }

  void _autoSelectUserByPhone() {
    if (!mounted || _userSelectedManually || _users.isEmpty) return;
    final phone = _normalizePhoneForMatch(_phoneCtrl.text);
    if (phone.isEmpty) {
      if (_selectedUserId.isNotEmpty) {
        setState(() => _selectedUserId = '');
      }
      return;
    }
    final match = _users.where((user) {
      return _normalizePhoneForMatch(user.phone) == phone;
    }).firstOrNull;
    if (match == null) {
      if (_selectedUserId.isNotEmpty) {
        setState(() => _selectedUserId = '');
      }
      return;
    }
    if (match.userId == _selectedUserId) return;
    setState(() => _selectedUserId = match.userId);
  }

  static String _normalizePhoneForMatch(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 11 && digits.startsWith('8')) {
      return '7${digits.substring(1)}';
    }
    return digits;
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Введите ФИО сотрудника')));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final payload = {
        'full_name': _nameCtrl.text.trim(),
        'position': _positionCtrl.text.trim(),
        'iin': _iinCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'user_id': _selectedUserId,
        'disable_user_auto_link':
            _userSelectedManually && _selectedUserId.isEmpty,
        'salary_type': _salaryType,
        'monthly_salary': _showMonthly ? _intOf(_monthlyCtrl.text) : 0,
        'hourly_rate': _showHourly ? _intOf(_hourlyCtrl.text) : 0,
        'piece_rate': 0,
        'piece_rate_source': 'none',
        'sales_percent': _doubleOf(_salesPercentCtrl.text),
        'sales_basis': _salesBasis,
        'standard_days': _intOf(_standardDaysCtrl.text, fallback: 22),
        'status': _isActive ? 'active' : 'inactive',
        'notes': _notesCtrl.text.trim(),
      };
      final initial = widget.initial;
      if (initial == null) {
        await widget.gateway
            .createEmployee(accessToken: widget.accessToken, payload: payload);
      } else {
        await widget.gateway.updateEmployee(
            accessToken: widget.accessToken,
            employeeId: initial.id,
            payload: payload);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  static int _intOf(String value, {int fallback = 0}) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return fallback;
    return int.tryParse(cleaned) ?? fallback;
  }

  static double _doubleOf(String value) =>
      double.tryParse(value.replaceAll(',', '.')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF7FAF8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            _SheetDragHandle(
                title:
                    isEditing ? 'Редактировать сотрудника' : 'Новый сотрудник'),
            Expanded(
              child: ListView(
                controller: controller,
                padding: EdgeInsets.fromLTRB(
                    16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 96),
                children: [
                  const _SectionLabel(label: 'ФИО *'),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: _inputDecoration('Например: Иванов Иван'),
                  ),
                  const SizedBox(height: 12),
                  const _SectionLabel(label: 'Должность'),
                  TextFormField(
                    controller: _positionCtrl,
                    decoration: _inputDecoration('Например: Менеджер'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionLabel(label: 'ИИН'),
                            TextFormField(
                              controller: _iinCtrl,
                              decoration: _inputDecoration('12 цифр'),
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionLabel(label: 'Телефон'),
                            TextFormField(
                              controller: _phoneCtrl,
                              decoration: _inputDecoration('+7...'),
                              keyboardType: TextInputType.phone,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _SectionLabel(label: 'Пользователь'),
                  if (_loadingUsers)
                    Container(
                      height: 54,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Text('Загружаем пользователей...'),
                        ],
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      key: ValueKey(
                          'employee_user_${_users.length}_$_selectedUserId'),
                      initialValue: _selectedUserValue,
                      decoration: _inputDecoration('Пользователь компании'),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Не связан'),
                        ),
                        if (_selectedFallbackUserLabel.isNotEmpty &&
                            !_users
                                .any((user) => user.userId == _selectedUserId))
                          DropdownMenuItem(
                            value: _selectedUserId,
                            child: Text(
                              _selectedFallbackUserLabel,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ..._users.map(
                          (user) => DropdownMenuItem(
                            value: user.userId,
                            child: Text(
                              user.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedUserId = value ?? '';
                          _userSelectedManually = true;
                        });
                      },
                    ),
                  if (_usersError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _usersError!,
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const _SectionLabel(label: 'Тип оплаты *'),
                  DropdownButtonFormField<String>(
                    initialValue: _salaryType,
                    decoration: _inputDecoration('Тип оплаты'),
                    items: const [
                      DropdownMenuItem(value: 'monthly', child: Text('Оклад')),
                      DropdownMenuItem(
                          value: 'hourly', child: Text('Почасовая')),
                      DropdownMenuItem(
                          value: 'piece_rate', child: Text('Сдельная')),
                      DropdownMenuItem(value: 'bonus', child: Text('Бонусная')),
                      DropdownMenuItem(
                          value: 'combined', child: Text('Комбинированная')),
                    ],
                    onChanged: (v) =>
                        setState(() => _salaryType = v ?? 'monthly'),
                  ),
                  if (_showMonthly) ...[
                    const SizedBox(height: 12),
                    const _SectionLabel(label: 'Оклад в месяц, ₸'),
                    TextFormField(
                      controller: _monthlyCtrl,
                      decoration: _inputDecoration('Например: 300000'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    const _SectionLabel(label: 'Норма рабочих дней в месяц'),
                    TextFormField(
                      controller: _standardDaysCtrl,
                      decoration: _inputDecoration('22'),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  if (_showHourly) ...[
                    const SizedBox(height: 12),
                    const _SectionLabel(label: 'Ставка за час, ₸'),
                    TextFormField(
                      controller: _hourlyCtrl,
                      decoration: _inputDecoration('Например: 2000'),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text('Комиссия с продаж',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  const Text(
                    'Начисляется по проведённым продажам, где сотрудник указан продавцом. 0 — без комиссии.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionLabel(label: 'Процент, %'),
                            TextFormField(
                              controller: _salesPercentCtrl,
                              decoration: _inputDecoration('0'),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionLabel(label: 'База'),
                            DropdownButtonFormField<String>(
                              initialValue: _salesBasis,
                              decoration: _inputDecoration('База'),
                              items: const [
                                DropdownMenuItem(
                                    value: 'revenue', child: Text('Выручка')),
                                DropdownMenuItem(
                                    value: 'profit', child: Text('Прибыль')),
                              ],
                              onChanged: (v) =>
                                  setState(() => _salesBasis = v ?? 'revenue'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Оплата за производство начисляется автоматически за участие в производственных заказах; сумму за рецепт задайте в Настройках (шестерёнка вверху).',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ),
                  if (_salaryType == 'bonus')
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Сумма бонуса вводится при расчёте ведомости за период.',
                        style:
                            TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 12),
                  const _SectionLabel(label: 'Примечания'),
                  TextFormField(
                    controller: _notesCtrl,
                    decoration: _inputDecoration('Необязательно'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                    title: const Text('Активный сотрудник',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    activeThumbColor: const Color(0xFF00A86B),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _save,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(isEditing ? 'Сохранить' : 'Добавить сотрудника'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
