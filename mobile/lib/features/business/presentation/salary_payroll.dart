part of 'business_shell.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Payroll periods (ведомости) tab
// ─────────────────────────────────────────────────────────────────────────────

class _PayrollPeriodsTab extends StatelessWidget {
  const _PayrollPeriodsTab({
    required this.periods,
    required this.employees,
    required this.accounts,
    required this.accessToken,
    required this.gateway,
    required this.onChanged,
  });

  final List<_PayrollPeriod> periods;
  final List<_Employee> employees;
  final List<_BankAccount> accounts;
  final String accessToken;
  final BusinessGateway gateway;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (periods.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calculate_outlined, size: 56, color: Color(0xFFCBD5E1)),
            SizedBox(height: 12),
            Text('Ведомостей пока нет',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16)),
            SizedBox(height: 4),
            Text('Нажмите + чтобы создать ведомость за месяц',
                style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: periods.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => _PayrollPeriodTile(
        period: periods[i],
        employees: employees,
        accounts: accounts,
        accessToken: accessToken,
        gateway: gateway,
        onChanged: onChanged,
      ),
    );
  }
}

class _PayrollPeriodTile extends StatelessWidget {
  const _PayrollPeriodTile({
    required this.period,
    required this.employees,
    required this.accounts,
    required this.accessToken,
    required this.gateway,
    required this.onChanged,
  });

  final _PayrollPeriod period;
  final List<_Employee> employees;
  final List<_BankAccount> accounts;
  final String accessToken;
  final BusinessGateway gateway;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return _BusinessCard(
      onTap: () => _open(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0x1A8B5CF6),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.calculate_rounded,
                    color: Color(0xFF8B5CF6), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(period.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    Text('${period.employeeCount} чел.',
                        style: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 12)),
                  ],
                ),
              ),
              _StatusBadge(label: period.statusLabel, kind: period.statusKind),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _LabelValue(
                  label: 'К выплате',
                  value: formatMoney(period.totalNet),
                ),
              ),
              Expanded(
                child: _LabelValue(
                  label: 'Выплачено',
                  value: '${period.paidCount} из ${period.employeeCount}',
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PayrollPeriodDetailScreen(
          periodId: period.id,
          accounts: accounts,
          accessToken: accessToken,
          gateway: gateway,
        ),
      ),
    );
    onChanged();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Create payroll period sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CreatePeriodSheet extends StatefulWidget {
  const _CreatePeriodSheet({
    required this.accessToken,
    required this.gateway,
    required this.onSaved,
  });

  final String accessToken;
  final BusinessGateway gateway;
  final VoidCallback onSaved;

  @override
  State<_CreatePeriodSheet> createState() => _CreatePeriodSheetState();
}

class _CreatePeriodSheetState extends State<_CreatePeriodSheet> {
  late int _year;
  late int _month;
  bool _isSubmitting = false;

  static const _monthNames = [
    'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
    'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  Future<void> _save() async {
    setState(() => _isSubmitting = true);
    try {
      await widget.gateway.createPayrollPeriod(
        accessToken: widget.accessToken,
        payload: {
          'period_year': _year,
          'period_month': _month,
          'title': '${_monthNames[_month - 1]} $_year',
        },
      );
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

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final years = [now.year - 1, now.year, now.year + 1];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF7FAF8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetDragHandle(title: 'Новая ведомость'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel(label: 'Месяц'),
                  DropdownButtonFormField<int>(
                    initialValue: _month,
                    decoration: _inputDecoration('Месяц'),
                    items: [
                      for (var m = 1; m <= 12; m++)
                        DropdownMenuItem(
                            value: m, child: Text(_monthNames[m - 1])),
                    ],
                    onChanged: (v) => setState(() => _month = v ?? _month),
                  ),
                  const SizedBox(height: 12),
                  const _SectionLabel(label: 'Год'),
                  DropdownButtonFormField<int>(
                    initialValue: _year,
                    decoration: _inputDecoration('Год'),
                    items: [
                      for (final y in years)
                        DropdownMenuItem(value: y, child: Text('$y')),
                    ],
                    onChanged: (v) => setState(() => _year = v ?? _year),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _save,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Создать ведомость'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payroll period detail screen
// ─────────────────────────────────────────────────────────────────────────────

class _PayrollPeriodDetailScreen extends StatefulWidget {
  const _PayrollPeriodDetailScreen({
    required this.periodId,
    required this.accounts,
    required this.accessToken,
    required this.gateway,
  });

  final String periodId;
  final List<_BankAccount> accounts;
  final String accessToken;
  final BusinessGateway gateway;

  @override
  State<_PayrollPeriodDetailScreen> createState() =>
      _PayrollPeriodDetailScreenState();
}

class _PayrollPeriodDetailScreenState
    extends State<_PayrollPeriodDetailScreen> {
  _PayrollPeriodDetail? _detail;
  bool _isLoading = true;
  String? _error;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final json = await widget.gateway.fetchPayrollPeriodDetail(
        accessToken: widget.accessToken,
        periodId: widget.periodId,
      );
      if (!mounted) return;
      setState(() {
        _detail = _payrollPeriodDetailFromJson(json);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _isLoading = false;
      });
    }
  }

  void _applyDetail(Map<String, dynamic> json) {
    if (!mounted) return;
    setState(() => _detail = _payrollPeriodDetailFromJson(json));
  }

  Future<void> _calculate() async {
    setState(() => _isBusy = true);
    try {
      final json = await widget.gateway.calculatePayroll(
        accessToken: widget.accessToken,
        periodId: widget.periodId,
      );
      _applyDetail(json);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _pay() async {
    if (widget.accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет доступных счетов для выплаты')),
      );
      return;
    }
    final accountId = await showDialog<String>(
      context: context,
      builder: (ctx) => _PayAccountDialog(accounts: widget.accounts),
    );
    if (accountId == null || !mounted) return;

    setState(() => _isBusy = true);
    try {
      final json = await widget.gateway.payPayrollPeriod(
        accessToken: widget.accessToken,
        periodId: widget.periodId,
        payload: {'account_id': accountId},
      );
      _applyDetail(json);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Зарплата выплачена и проведена в Финансы')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _editEntry(_PayrollEntry entry) async {
    final json = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PayrollEntrySheet(
        periodId: widget.periodId,
        entry: entry,
        accessToken: widget.accessToken,
        gateway: widget.gateway,
      ),
    );
    if (json != null) {
      _applyDetail(json);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final period = detail?.period;
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      appBar: AppBar(
        title: Text(period?.title ?? 'Ведомость'),
      ),
      body: _buildBody(detail),
      bottomNavigationBar: detail == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isBusy || period!.status == 'paid'
                            ? null
                            : _calculate,
                        icon: const Icon(Icons.calculate_rounded),
                        label: const Text('Рассчитать'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isBusy ||
                                detail.entries.isEmpty ||
                                period!.status == 'paid'
                            ? null
                            : _pay,
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF00A86B)),
                        icon: const Icon(Icons.payments_rounded),
                        label: const Text('Выплатить'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBody(_PayrollPeriodDetail? detail) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 48, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }
    if (detail == null) {
      return const SizedBox.shrink();
    }
    if (detail.entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 56, color: Color(0xFFCBD5E1)),
              SizedBox(height: 12),
              Text('Ведомость ещё не рассчитана',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16)),
              SizedBox(height: 4),
              Text('Нажмите «Рассчитать» внизу экрана',
                  style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        _BusinessCard(
          background: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: Row(
            children: [
              _HeroStat(
                label: 'Всего к выплате',
                value: formatMoney(detail.period.totalNet),
              ),
              _HeroStat(
                label: 'Сотрудников',
                value: '${detail.period.employeeCount}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...detail.entries.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _PayrollEntryTile(
              entry: e,
              onTap: (e.isPaid || detail.period.status == 'paid')
                  ? null
                  : () => _editEntry(e),
            ),
          ),
        ),
      ],
    );
  }
}

class _PayrollEntryTile extends StatelessWidget {
  const _PayrollEntryTile({required this.entry, this.onTap});

  final _PayrollEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _BusinessCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.employeeName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(entry.salaryTypeLabel,
                        style: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 12)),
                  ],
                ),
              ),
              if (entry.isPaid)
                const _StatusBadge(label: 'Выплачено', kind: StatusKind.success)
              else
                Text(formatMoney(entry.netAmount),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (entry.baseAmount > 0)
                _AmountChip(label: 'Оклад/часы', value: entry.baseAmount),
              if (entry.pieceAmount > 0)
                _AmountChip(label: 'Сдельно', value: entry.pieceAmount),
              if (entry.bonusAmount > 0)
                _AmountChip(label: 'Бонус', value: entry.bonusAmount),
              if (entry.overtimeAmount > 0)
                _AmountChip(label: 'Переработка', value: entry.overtimeAmount),
              if (entry.vacationAmount > 0)
                _AmountChip(label: 'Отпускные', value: entry.vacationAmount),
              if (entry.deductions > 0)
                _AmountChip(
                    label: 'Удержания',
                    value: entry.deductions,
                    negative: true),
            ],
          ),
          if (entry.isPaid)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('К выплате: ${formatMoney(entry.netAmount)}',
                  style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

class _AmountChip extends StatelessWidget {
  const _AmountChip({
    required this.label,
    required this.value,
    this.negative = false,
  });

  final String label;
  final int value;
  final bool negative;

  @override
  Widget build(BuildContext context) {
    final color =
        negative ? const Color(0xFFEF4444) : const Color(0xFF334155);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: ${negative ? '−' : ''}${formatMoney(value)}',
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Entry timesheet sheet
// ─────────────────────────────────────────────────────────────────────────────

class _PayrollEntrySheet extends StatefulWidget {
  const _PayrollEntrySheet({
    required this.periodId,
    required this.entry,
    required this.accessToken,
    required this.gateway,
  });

  final String periodId;
  final _PayrollEntry entry;
  final String accessToken;
  final BusinessGateway gateway;

  @override
  State<_PayrollEntrySheet> createState() => _PayrollEntrySheetState();
}

class _PayrollEntrySheetState extends State<_PayrollEntrySheet> {
  late final TextEditingController _daysCtrl;
  late final TextEditingController _hoursCtrl;
  late final TextEditingController _overtimeCtrl;
  late final TextEditingController _vacationCtrl;
  late final TextEditingController _sickCtrl;
  late final TextEditingController _absentCtrl;
  late final TextEditingController _bonusCtrl;
  late final TextEditingController _deductionsCtrl;
  late final TextEditingController _notesCtrl;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _daysCtrl = TextEditingController(text: _formatHours(e.daysWorked));
    _hoursCtrl = TextEditingController(text: _formatHours(e.hoursWorked));
    _overtimeCtrl = TextEditingController(text: _formatHours(e.overtimeHours));
    _vacationCtrl = TextEditingController(text: _formatHours(e.vacationDays));
    _sickCtrl = TextEditingController(text: _formatHours(e.sickDays));
    _absentCtrl = TextEditingController(text: _formatHours(e.absentDays));
    _bonusCtrl = TextEditingController(text: e.bonusAmount.toString());
    _deductionsCtrl = TextEditingController(text: e.deductions.toString());
    _notesCtrl = TextEditingController(text: e.notes);
  }

  @override
  void dispose() {
    _daysCtrl.dispose();
    _hoursCtrl.dispose();
    _overtimeCtrl.dispose();
    _vacationCtrl.dispose();
    _sickCtrl.dispose();
    _absentCtrl.dispose();
    _bonusCtrl.dispose();
    _deductionsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double _doubleOf(String v) => double.tryParse(v.replaceAll(',', '.')) ?? 0;
  int _intOf(String v) {
    final cleaned = v.replaceAll(RegExp(r'[^0-9]'), '');
    return cleaned.isEmpty ? 0 : int.tryParse(cleaned) ?? 0;
  }

  Future<void> _save() async {
    setState(() => _isSubmitting = true);
    try {
      final json = await widget.gateway.updatePayrollEntry(
        accessToken: widget.accessToken,
        periodId: widget.periodId,
        entryId: widget.entry.id,
        payload: {
          'days_worked': _doubleOf(_daysCtrl.text),
          'hours_worked': _doubleOf(_hoursCtrl.text),
          'overtime_hours': _doubleOf(_overtimeCtrl.text),
          'vacation_days': _doubleOf(_vacationCtrl.text),
          'sick_days': _doubleOf(_sickCtrl.text),
          'absent_days': _doubleOf(_absentCtrl.text),
          'bonus_amount': _intOf(_bonusCtrl.text),
          'deductions': _intOf(_deductionsCtrl.text),
          'notes': _notesCtrl.text.trim(),
        },
      );
      if (mounted) Navigator.pop(context, json);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF7FAF8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            _SheetDragHandle(title: widget.entry.employeeName),
            Expanded(
              child: ListView(
                controller: controller,
                padding: EdgeInsets.fromLTRB(
                    16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 96),
                children: [
                  const Text('Табель за период',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _NumField(
                            label: 'Отработано дней', controller: _daysCtrl),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _NumField(
                            label: 'Отработано часов', controller: _hoursCtrl),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _NumField(
                            label: 'Переработка, ч',
                            controller: _overtimeCtrl),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _NumField(
                            label: 'Дней отпуска', controller: _vacationCtrl),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _NumField(
                            label: 'Дней больничного', controller: _sickCtrl),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _NumField(
                            label: 'Дней прогула', controller: _absentCtrl),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Начисления и удержания',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 12),
                  const _SectionLabel(label: 'Бонус / премия, ₸'),
                  TextFormField(
                    controller: _bonusCtrl,
                    decoration: _inputDecoration('0'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  const _SectionLabel(label: 'Удержания, ₸'),
                  TextFormField(
                    controller: _deductionsCtrl,
                    decoration: _inputDecoration('0'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  const _SectionLabel(label: 'Примечания'),
                  TextFormField(
                    controller: _notesCtrl,
                    decoration: _inputDecoration('Необязательно'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 18, color: Color(0xFF6366F1)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Сдельная часть подтягивается автоматически из документов и пересчитывается при сохранении.',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF4338CA)),
                          ),
                        ),
                      ],
                    ),
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
                      : const Text('Сохранить'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  const _NumField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: label),
        TextFormField(
          controller: controller,
          decoration: _inputDecoration('0'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pay account picker dialog
// ─────────────────────────────────────────────────────────────────────────────

class _PayAccountDialog extends StatefulWidget {
  const _PayAccountDialog({required this.accounts});

  final List<_BankAccount> accounts;

  @override
  State<_PayAccountDialog> createState() => _PayAccountDialogState();
}

class _PayAccountDialogState extends State<_PayAccountDialog> {
  late String _accountId;

  @override
  void initState() {
    super.initState();
    _accountId = widget.accounts.first.id;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Выплата зарплаты'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Списать со счёта:',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _accountId,
            decoration: _inputDecoration('Счёт'),
            items: widget.accounts
                .map((a) => DropdownMenuItem(
                      value: a.id,
                      child: Text('${a.name} • ${formatMoney(a.balance)}'),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _accountId = v ?? _accountId),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _accountId),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00A86B)),
          child: const Text('Выплатить'),
        ),
      ],
    );
  }
}
