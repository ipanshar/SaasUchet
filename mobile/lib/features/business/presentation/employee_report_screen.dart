part of 'business_shell.dart';

/// Отчёт «Зарплатная карточка сотрудника»: по одному сотруднику за период все
/// начисления (оклад/сдельно), премии, переработки, отпускные, удержания и суммы
/// к выплате по месяцам. Экспорт в PDF / Excel.
class _EmployeeReportScreen extends StatefulWidget {
  const _EmployeeReportScreen({
    required this.accessToken,
    required this.businessGateway,
    required this.companyName,
    this.currentUserOnly = false,
    this.embedded = false,
  });

  final String accessToken;
  final BusinessGateway businessGateway;
  final String companyName;
  final bool currentUserOnly;
  final bool embedded;

  @override
  State<_EmployeeReportScreen> createState() => _EmployeeReportScreenState();
}

class _EmployeeReportScreenState extends State<_EmployeeReportScreen> {
  List<_Employee> _employees = const [];
  _Employee? _selected;
  late DateTime _from;
  late DateTime _to;
  _EmployeeStatement? _statement;
  bool _loadingEmployees = true;
  bool _forming = false;
  bool _exporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, 1, 1);
    _to = DateTime(now.year, now.month, now.day);
    if (widget.currentUserOnly) {
      _loadingEmployees = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _form();
      });
    } else {
      _loadEmployees();
    }
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _loadingEmployees = true;
      _error = null;
    });
    try {
      final payload = await widget.businessGateway.fetchEmployees(
        accessToken: widget.accessToken,
      );
      final employees = payload.map(_employeeFromJson).toList();
      if (!mounted) return;
      setState(() {
        _employees = employees;
        _selected = employees.isEmpty ? null : employees.first;
        _loadingEmployees = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loadingEmployees = false;
      });
    }
  }

  String _apiDate(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String _humanDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.${date.year}';

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _from : _to;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: isFrom ? 'Дата начала' : 'Дата окончания',
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
        if (_to.isBefore(_from)) _from = _to;
      }
      _statement = null;
    });
  }

  Future<void> _form() async {
    final employee = _selected;
    if (!widget.currentUserOnly && employee == null) return;
    setState(() {
      _forming = true;
      _error = null;
    });
    try {
      final payload = widget.currentUserOnly
          ? await widget.businessGateway.fetchCurrentEmployeeStatement(
              accessToken: widget.accessToken,
              from: _apiDate(_from),
              to: _apiDate(_to),
            )
          : await widget.businessGateway.fetchEmployeeStatement(
              accessToken: widget.accessToken,
              employeeId: employee!.id,
              from: _apiDate(_from),
              to: _apiDate(_to),
            );
      final statement = _employeeStatementFromJson(payload);
      if (!mounted) return;
      setState(() {
        _statement = statement;
        _forming = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = widget.currentUserOnly
            ? 'Пользователь не связан с сотрудником компании.'
            : error.toString();
        _forming = false;
      });
    }
  }

  Future<void> _exportPdf() async {
    final statement = _statement;
    if (statement == null) return;
    setState(() => _exporting = true);
    try {
      final bytes = await _buildEmployeePdf(
        companyName: widget.companyName,
        from: _humanDate(_from),
        to: _humanDate(_to),
        statement: statement,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _PrintedFormScreen(
            documentNo: 'Зарплата ${statement.employeeName}',
            bytes: bytes,
          ),
        ),
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportExcel() async {
    final statement = _statement;
    if (statement == null) return;
    setState(() => _exporting = true);
    try {
      final bytes = _buildEmployeeExcel(statement: statement);
      final safeName = statement.employeeName
          .replaceAll(RegExp(r'[^0-9A-Za-zА-Яа-яЁё-]+'), '_');
      await shareBytesFile(
        bytes,
        'Zarplata_$safeName.xlsx',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'Зарплатная карточка ${statement.employeeName}',
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Не удалось экспортировать: $error')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);
    if (widget.embedded) return content;
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7FAF8),
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text(
            widget.currentUserOnly ? 'Моя зарплата' : 'Зарплатная карточка'),
      ),
      body: content,
    );
  }

  Widget _buildContent(BuildContext context) {
    final statement = _statement;
    final canExport = statement != null && !_exporting;
    return _loadingEmployees
        ? const Center(child: CircularProgressIndicator())
        : !widget.currentUserOnly && _employees.isEmpty
            ? const _ReportNotice(
                icon: Icons.people_outline_rounded,
                title: 'Нет сотрудников',
                message: 'Добавьте сотрудника в разделе «Зарплата».',
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.currentUserOnly) ...[
                          const Text(
                            'Моя зарплата',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Карточка формируется только по сотруднику, связанному с вашим пользователем.',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ] else ...[
                          const Text(
                            'Сотрудник',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<_Employee>(
                                isExpanded: true,
                                value: _selected,
                                hint: const Text('Выберите сотрудника'),
                                items: _employees
                                    .map(
                                      (employee) => DropdownMenuItem(
                                        value: employee,
                                        child: Text(
                                          employee.position.isEmpty
                                              ? employee.fullName
                                              : '${employee.fullName} · ${employee.position}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selected = value;
                                    _statement = null;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: _DateField(
                                label: 'Дата начала',
                                value: _humanDate(_from),
                                onTap: () => _pickDate(isFrom: true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _DateField(
                                label: 'Дата окончания',
                                value: _humanDate(_to),
                                onTap: () => _pickDate(isFrom: false),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _forming ||
                                    (!widget.currentUserOnly &&
                                        _selected == null)
                                ? null
                                : _form,
                            icon: _forming
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.assessment_rounded),
                            label: Text(
                                _forming ? 'Формируем...' : 'Сформировать'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFEF4444)),
                      ),
                    ),
                  Expanded(child: _buildBody()),
                  if (statement != null)
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: canExport ? _exportPdf : null,
                                icon: const Icon(Icons.picture_as_pdf_rounded),
                                label: const Text('PDF'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: canExport ? _exportExcel : null,
                                icon: const Icon(Icons.table_chart_rounded),
                                label: const Text('Excel'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
  }

  Widget _buildBody() {
    final statement = _statement;
    if (statement == null) {
      return _ReportNotice(
        icon: widget.currentUserOnly
            ? Icons.person_search_rounded
            : Icons.badge_rounded,
        title: widget.currentUserOnly
            ? 'Сотрудник не связан'
            : 'Отчёт не сформирован',
        message: widget.currentUserOnly
            ? 'Попросите администратора связать ваш профиль с карточкой сотрудника.'
            : 'Выберите сотрудника и период, затем «Сформировать».',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF00A86B).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF00A86B)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                statement.employeeName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (statement.position.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  statement.position,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _StockReportMetric(
                      label: 'Начислено',
                      value: formatMoney(statement.totalGross),
                    ),
                  ),
                  Expanded(
                    child: _StockReportMetric(
                      label: 'Премии',
                      value: formatMoney(statement.totalBonus),
                    ),
                  ),
                  Expanded(
                    child: _StockReportMetric(
                      label: 'Удержания',
                      value: formatMoney(statement.totalDeductions),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _StockReportMetric(
                      label: 'К выплате',
                      value: formatMoney(statement.totalNet),
                    ),
                  ),
                  Expanded(
                    child: _StockReportMetric(
                      label: 'Выплачено',
                      value: formatMoney(statement.totalPaid),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (statement.entries.isEmpty)
          const _ReportNotice(
            icon: Icons.inbox_rounded,
            title: 'Нет начислений',
            message: 'За выбранный период по сотруднику нет ведомостей.',
          )
        else
          ...statement.entries
              .map((entry) => _EmployeeStatementRow(entry: entry)),
      ],
    );
  }
}

String _payrollStatusLabel(_EmployeeStatementEntry entry) {
  if (entry.isPaid) return 'Выплачено';
  switch (entry.status) {
    case 'paid':
      return 'Выплачено';
    case 'calculated':
      return 'Рассчитано';
    case 'cancelled':
      return 'Отменено';
    default:
      return 'Черновик';
  }
}

class _EmployeeStatementRow extends StatelessWidget {
  const _EmployeeStatementRow({required this.entry});

  final _EmployeeStatementEntry entry;

  @override
  Widget build(BuildContext context) {
    final breakdown = <String>[
      if (entry.baseAmount > 0) 'Оклад/часы ${formatMoney(entry.baseAmount)}',
      if (entry.pieceAmount > 0) 'Сдельно ${formatMoney(entry.pieceAmount)}',
      if (entry.overtimeAmount > 0)
        'Переработка ${formatMoney(entry.overtimeAmount)}',
      if (entry.vacationAmount > 0)
        'Отпуск ${formatMoney(entry.vacationAmount)}',
    ].join('   ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.periodLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Text(
                _payrollStatusLabel(entry),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: entry.isPaid
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          if (breakdown.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              breakdown,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StockReportMetric(
                  label: 'Начислено',
                  value: formatMoney(entry.grossAmount),
                ),
              ),
              Expanded(
                child: _StockReportMetric(
                  label: 'Премия',
                  value: entry.bonusAmount == 0
                      ? '—'
                      : formatMoney(entry.bonusAmount),
                ),
              ),
              Expanded(
                child: _StockReportMetric(
                  label: 'Удержания',
                  value: entry.deductions == 0
                      ? '—'
                      : formatMoney(entry.deductions),
                ),
              ),
              Expanded(
                child: _StockReportMetric(
                  label: 'К выплате',
                  value: formatMoney(entry.netAmount),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Строит лист Excel (.xlsx) с зарплатной карточкой сотрудника.
List<int> _buildEmployeeExcel({required _EmployeeStatement statement}) {
  final excel = xlsx.Excel.createExcel();
  const sheetName = 'Зарплата';
  final sheet = excel[sheetName];
  excel.setDefaultSheet(sheetName);

  sheet.appendRow([
    xlsx.TextCellValue('Сотрудник'),
    xlsx.TextCellValue(statement.employeeName),
  ]);
  if (statement.position.isNotEmpty) {
    sheet.appendRow([
      xlsx.TextCellValue('Должность'),
      xlsx.TextCellValue(statement.position),
    ]);
  }
  sheet.appendRow([
    xlsx.TextCellValue('Период'),
    xlsx.TextCellValue('${statement.from} — ${statement.to}'),
  ]);
  sheet.appendRow([xlsx.TextCellValue('')]);

  sheet.appendRow([
    xlsx.TextCellValue('Период'),
    xlsx.TextCellValue('Оклад/часы'),
    xlsx.TextCellValue('Сдельно'),
    xlsx.TextCellValue('Премия'),
    xlsx.TextCellValue('Переработка'),
    xlsx.TextCellValue('Отпуск'),
    xlsx.TextCellValue('Удержания'),
    xlsx.TextCellValue('Начислено'),
    xlsx.TextCellValue('К выплате'),
    xlsx.TextCellValue('Статус'),
  ]);
  for (final entry in statement.entries) {
    sheet.appendRow([
      xlsx.TextCellValue(entry.periodLabel),
      xlsx.IntCellValue(entry.baseAmount),
      xlsx.IntCellValue(entry.pieceAmount),
      xlsx.IntCellValue(entry.bonusAmount),
      xlsx.IntCellValue(entry.overtimeAmount),
      xlsx.IntCellValue(entry.vacationAmount),
      xlsx.IntCellValue(entry.deductions),
      xlsx.IntCellValue(entry.grossAmount),
      xlsx.IntCellValue(entry.netAmount),
      xlsx.TextCellValue(_payrollStatusLabel(entry)),
    ]);
  }
  sheet.appendRow([
    xlsx.TextCellValue('Итого'),
    xlsx.IntCellValue(statement.totalBase),
    xlsx.IntCellValue(statement.totalPiece),
    xlsx.IntCellValue(statement.totalBonus),
    xlsx.IntCellValue(statement.totalOvertime),
    xlsx.IntCellValue(statement.totalVacation),
    xlsx.IntCellValue(statement.totalDeductions),
    xlsx.IntCellValue(statement.totalGross),
    xlsx.IntCellValue(statement.totalNet),
    xlsx.TextCellValue(''),
  ]);

  if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
    excel.delete('Sheet1');
  }

  return excel.encode() ?? <int>[];
}

/// Строит PDF-форму зарплатной карточки сотрудника.
Future<Uint8List> _buildEmployeePdf({
  required String companyName,
  required String from,
  required String to,
  required _EmployeeStatement statement,
}) async {
  final regularFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/PTSans-Regular.ttf'),
  );
  final boldFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/PTSans-Bold.ttf'),
  );
  final regularStyle = pw.TextStyle(font: regularFont, fontSize: 9);
  final boldStyle = pw.TextStyle(font: boldFont, fontSize: 9);

  final data = <List<String>>[
    ...statement.entries.map((entry) => [
          entry.periodLabel,
          _formatMoneyForPdf(entry.baseAmount + entry.pieceAmount),
          entry.bonusAmount == 0 ? '' : _formatMoneyForPdf(entry.bonusAmount),
          entry.deductions == 0 ? '' : _formatMoneyForPdf(entry.deductions),
          _formatMoneyForPdf(entry.grossAmount),
          _formatMoneyForPdf(entry.netAmount),
          _payrollStatusLabel(entry),
        ]),
    [
      'Итого',
      _formatMoneyForPdf(statement.totalBase + statement.totalPiece),
      _formatMoneyForPdf(statement.totalBonus),
      _formatMoneyForPdf(statement.totalDeductions),
      _formatMoneyForPdf(statement.totalGross),
      _formatMoneyForPdf(statement.totalNet),
      '',
    ],
  ];

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (context) => [
        pw.Text(companyName, style: pw.TextStyle(font: boldFont, fontSize: 14)),
        pw.SizedBox(height: 4),
        pw.Text(
          'Зарплатная карточка: ${statement.employeeName}'
          '${statement.position.isEmpty ? '' : ' (${statement.position})'}',
          style: pw.TextStyle(font: boldFont, fontSize: 13),
        ),
        pw.Text('Период: $from — $to', style: regularStyle),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          context: context,
          cellStyle: regularStyle,
          headerStyle: boldStyle,
          headerDecoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFF7FAF8),
          ),
          cellAlignments: const {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
            6: pw.Alignment.centerLeft,
          },
          headers: const [
            'Период',
            'Начисление',
            'Премия',
            'Удержания',
            'Начислено',
            'К выплате',
            'Статус',
          ],
          data: data,
        ),
      ],
    ),
  );

  return doc.save();
}
