part of 'business_shell.dart';

/// Отчёт «Акт сверки с контрагентом»: все движения по выбранному контрагенту за
/// период (продажи, закупки, возвраты, оплаты) с дебетом/кредитом и сальдо.
/// Положительное сальдо — контрагент должен нам, отрицательное — мы должны.
/// Экспорт в PDF / Excel.
class _CounterpartyReportScreen extends StatefulWidget {
  const _CounterpartyReportScreen({
    required this.accessToken,
    required this.businessGateway,
    required this.companyName,
    required this.clients,
  });

  final String accessToken;
  final BusinessGateway businessGateway;
  final String companyName;
  final List<_Client> clients;

  @override
  State<_CounterpartyReportScreen> createState() =>
      _CounterpartyReportScreenState();
}

class _CounterpartyReportScreenState extends State<_CounterpartyReportScreen> {
  _Client? _selected;
  late DateTime _from;
  late DateTime _to;
  _CounterpartyStatement? _statement;
  bool _forming = false;
  bool _exporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month, now.day);
    if (widget.clients.isNotEmpty) {
      _selected = widget.clients.first;
    }
  }

  String _apiDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String _humanDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.${date.year}';

  String _balanceMeaning(int balance) {
    if (balance > 0) return 'Контрагент должен нам';
    if (balance < 0) return 'Мы должны контрагенту';
    return 'Взаиморасчёты закрыты';
  }

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
    final client = _selected;
    if (client == null) return;
    setState(() {
      _forming = true;
      _error = null;
    });
    try {
      final payload = await widget.businessGateway.fetchCounterpartyStatement(
        accessToken: widget.accessToken,
        clientId: client.id,
        from: _apiDate(_from),
        to: _apiDate(_to),
      );
      final statement = _counterpartyStatementFromJson(payload);
      if (!mounted) return;
      setState(() {
        _statement = statement;
        _forming = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _forming = false;
      });
    }
  }

  Future<void> _exportPdf() async {
    final statement = _statement;
    if (statement == null) return;
    setState(() => _exporting = true);
    try {
      final bytes = await _buildStatementPdf(
        companyName: widget.companyName,
        from: _humanDate(_from),
        to: _humanDate(_to),
        statement: statement,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _PrintedFormScreen(
            documentNo: 'Акт сверки ${statement.clientName}',
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
      final bytes = _buildStatementExcel(statement: statement);
      final safeName = statement.clientName
          .replaceAll(RegExp(r'[^0-9A-Za-zА-Яа-яЁё-]+'), '_');
      await shareBytesFile(
        bytes,
        'Akt_sverki_$safeName.xlsx',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'Акт сверки ${statement.clientName}',
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
    final statement = _statement;
    final canExport = statement != null && !_exporting;
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7FAF8),
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text('Акт сверки'),
      ),
      body: widget.clients.isEmpty
          ? const _ReportNotice(
              icon: Icons.people_outline_rounded,
              title: 'Нет контрагентов',
              message: 'Добавьте контрагента в разделе CRM.',
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Контрагент',
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
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<_Client>(
                            isExpanded: true,
                            value: _selected,
                            hint: const Text('Выберите контрагента'),
                            items: widget.clients
                                .map(
                                  (client) => DropdownMenuItem(
                                    value: client,
                                    child: Text(
                                      client.name,
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
                          onPressed:
                              _selected == null || _forming ? null : _form,
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
                          label:
                              Text(_forming ? 'Формируем...' : 'Сформировать'),
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
            ),
    );
  }

  Widget _buildBody() {
    final statement = _statement;
    if (statement == null) {
      return const _ReportNotice(
        icon: Icons.handshake_rounded,
        title: 'Отчёт не сформирован',
        message: 'Выберите контрагента и период, затем «Сформировать».',
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
                statement.clientName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _StockReportMetric(
                      label: 'Сальдо на начало',
                      value: formatMoney(statement.openingBalance),
                    ),
                  ),
                  Expanded(
                    child: _StockReportMetric(
                      label: 'Сальдо на конец',
                      value: formatMoney(statement.closingBalance),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _balanceMeaning(statement.closingBalance),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF00A86B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (statement.entries.isEmpty)
          const _ReportNotice(
            icon: Icons.inbox_rounded,
            title: 'Нет движений',
            message: 'За выбранный период по контрагенту нет операций.',
          )
        else
          ...statement.entries.map((entry) => _StatementRow(entry: entry)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Обороты за период',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              'Дт ${formatMoney(statement.totalDebit)} · '
              'Кт ${formatMoney(statement.totalCredit)}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatementRow extends StatelessWidget {
  const _StatementRow({required this.entry});

  final _StatementEntry entry;

  @override
  Widget build(BuildContext context) {
    final parsed = DateTime.tryParse(entry.date);
    final dateLabel = parsed == null
        ? entry.date
        : '${parsed.day.toString().padLeft(2, '0')}.'
            '${parsed.month.toString().padLeft(2, '0')}.${parsed.year}';
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
                  entry.kindLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Text(
                dateLabel,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
          if (entry.documentNo.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              entry.documentNo,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StockReportMetric(
                  label: 'Дебет',
                  value: entry.debit == 0 ? '—' : formatMoney(entry.debit),
                ),
              ),
              Expanded(
                child: _StockReportMetric(
                  label: 'Кредит',
                  value: entry.credit == 0 ? '—' : formatMoney(entry.credit),
                ),
              ),
              Expanded(
                child: _StockReportMetric(
                  label: 'Сальдо',
                  value: formatMoney(entry.balance),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Строит лист Excel (.xlsx) с актом сверки.
List<int> _buildStatementExcel({required _CounterpartyStatement statement}) {
  final excel = xlsx.Excel.createExcel();
  const sheetName = 'Акт сверки';
  final sheet = excel[sheetName];
  excel.setDefaultSheet(sheetName);

  sheet.appendRow([xlsx.TextCellValue('Контрагент'), xlsx.TextCellValue(statement.clientName)]);
  sheet.appendRow([
    xlsx.TextCellValue('Период'),
    xlsx.TextCellValue('${statement.from} — ${statement.to}'),
  ]);
  sheet.appendRow([xlsx.TextCellValue('')]);

  sheet.appendRow([
    xlsx.TextCellValue('Дата'),
    xlsx.TextCellValue('Документ'),
    xlsx.TextCellValue('Операция'),
    xlsx.TextCellValue('Дебет'),
    xlsx.TextCellValue('Кредит'),
    xlsx.TextCellValue('Сальдо'),
  ]);
  sheet.appendRow([
    xlsx.TextCellValue(''),
    xlsx.TextCellValue(''),
    xlsx.TextCellValue('Сальдо на начало'),
    xlsx.TextCellValue(''),
    xlsx.TextCellValue(''),
    xlsx.IntCellValue(statement.openingBalance),
  ]);
  for (final entry in statement.entries) {
    sheet.appendRow([
      xlsx.TextCellValue(entry.date),
      xlsx.TextCellValue(entry.documentNo),
      xlsx.TextCellValue(entry.kindLabel),
      xlsx.IntCellValue(entry.debit),
      xlsx.IntCellValue(entry.credit),
      xlsx.IntCellValue(entry.balance),
    ]);
  }
  sheet.appendRow([
    xlsx.TextCellValue(''),
    xlsx.TextCellValue(''),
    xlsx.TextCellValue('Сальдо на конец'),
    xlsx.IntCellValue(statement.totalDebit),
    xlsx.IntCellValue(statement.totalCredit),
    xlsx.IntCellValue(statement.closingBalance),
  ]);

  if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
    excel.delete('Sheet1');
  }

  return excel.encode() ?? <int>[];
}

/// Строит PDF-форму акта сверки.
Future<Uint8List> _buildStatementPdf({
  required String companyName,
  required String from,
  required String to,
  required _CounterpartyStatement statement,
}) async {
  final regularFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/PTSans-Regular.ttf'),
  );
  final boldFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/PTSans-Bold.ttf'),
  );
  final regularStyle = pw.TextStyle(font: regularFont, fontSize: 9);
  final boldStyle = pw.TextStyle(font: boldFont, fontSize: 9);

  String pdfDate(String isoDate) {
    final parsed = DateTime.tryParse(isoDate);
    if (parsed == null) return isoDate;
    return '${parsed.day.toString().padLeft(2, '0')}.'
        '${parsed.month.toString().padLeft(2, '0')}.${parsed.year}';
  }

  final data = <List<String>>[
    [
      '',
      '',
      'Сальдо на начало',
      '',
      '',
      _formatMoneyForPdf(statement.openingBalance),
    ],
    ...statement.entries.map((entry) => [
          pdfDate(entry.date),
          entry.documentNo.isEmpty ? '—' : entry.documentNo,
          entry.kindLabel,
          entry.debit == 0 ? '' : _formatMoneyForPdf(entry.debit),
          entry.credit == 0 ? '' : _formatMoneyForPdf(entry.credit),
          _formatMoneyForPdf(entry.balance),
        ]),
    [
      '',
      '',
      'Сальдо на конец',
      _formatMoneyForPdf(statement.totalDebit),
      _formatMoneyForPdf(statement.totalCredit),
      _formatMoneyForPdf(statement.closingBalance),
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
          'Акт сверки с контрагентом: ${statement.clientName}',
          style: pw.TextStyle(font: boldFont, fontSize: 13),
        ),
        pw.Text('Период: $from — $to', style: regularStyle),
        pw.SizedBox(height: 4),
        pw.Text(
          'Положительное сальдо — контрагент должен нам, '
          'отрицательное — мы должны контрагенту.',
          style: regularStyle,
        ),
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
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.centerLeft,
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
          },
          headers: const [
            'Дата',
            'Документ',
            'Операция',
            'Дебет',
            'Кредит',
            'Сальдо',
          ],
          data: data,
        ),
      ],
    ),
  );

  return doc.save();
}
