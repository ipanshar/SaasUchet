part of 'business_shell.dart';

/// Отчёт «Финансовая сводка за период» (упрощённая оборотно-сальдовая): деньги,
/// долги (дебиторка/кредиторка) с оборотами, товары и зарплата за период.
/// Экспорт в PDF / Excel.
class _FinancialReportScreen extends StatefulWidget {
  const _FinancialReportScreen({
    required this.accessToken,
    required this.businessGateway,
    required this.companyName,
  });

  final String accessToken;
  final BusinessGateway businessGateway;
  final String companyName;

  @override
  State<_FinancialReportScreen> createState() => _FinancialReportScreenState();
}

class _FinancialReportScreenState extends State<_FinancialReportScreen> {
  late DateTime _from;
  late DateTime _to;
  _FinancialSummary? _summary;
  bool _forming = false;
  bool _exporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month - 3, 1);
    _to = DateTime(now.year, now.month, now.day);
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
      _summary = null;
    });
  }

  Future<void> _form() async {
    setState(() {
      _forming = true;
      _error = null;
    });
    try {
      final payload = await widget.businessGateway.fetchFinancialSummary(
        accessToken: widget.accessToken,
        from: _apiDate(_from),
        to: _apiDate(_to),
      );
      final summary = _financialSummaryFromJson(payload);
      if (!mounted) return;
      setState(() {
        _summary = summary;
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
    final summary = _summary;
    if (summary == null) return;
    setState(() => _exporting = true);
    try {
      final bytes = await _buildFinancialPdf(
        companyName: widget.companyName,
        from: _humanDate(_from),
        to: _humanDate(_to),
        summary: summary,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _PrintedFormScreen(
            documentNo: 'Финансовая сводка',
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
    final summary = _summary;
    if (summary == null) return;
    setState(() => _exporting = true);
    try {
      final bytes = _buildFinancialExcel(summary: summary);
      await shareBytesFile(
        bytes,
        'Finansovaya_svodka.xlsx',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'Финансовая сводка за период',
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
    final summary = _summary;
    final canExport = summary != null && !_exporting;
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7FAF8),
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text('Финансовая сводка'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    onPressed: _forming ? null : _form,
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
                    label: Text(_forming ? 'Формируем...' : 'Сформировать'),
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
          if (summary != null)
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
    final summary = _summary;
    if (summary == null) {
      return const _ReportNotice(
        icon: Icons.account_balance_rounded,
        title: 'Отчёт не сформирован',
        message: 'Выберите период и нажмите «Сформировать».',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      children: [
        const _FinanceSectionTitle('Оборотно-сальдовая ведомость'),
        _FinanceBalanceCard(
          title: 'Деньги (счета и кассы)',
          opening: summary.moneyOpening,
          debit: summary.moneyIncome,
          credit: summary.moneyExpense,
          closing: summary.moneyClosing,
          debitLabel: 'Поступления',
          creditLabel: 'Списания',
        ),
        const SizedBox(height: 8),
        _FinanceBalanceCard(
          title: 'Дебиторка (нам должны)',
          opening: summary.receivableOpening,
          debit: summary.receivableAccrued,
          credit: summary.receivablePaid,
          closing: summary.receivableClosing,
          debitLabel: 'Возникло',
          creditLabel: 'Погашено',
        ),
        const SizedBox(height: 8),
        _FinanceBalanceCard(
          title: 'Кредиторка (мы должны)',
          opening: summary.payableOpening,
          debit: summary.payableAccrued,
          credit: summary.payablePaid,
          closing: summary.payableClosing,
          debitLabel: 'Возникло',
          creditLabel: 'Погашено',
        ),
        const SizedBox(height: 18),
        const _FinanceSectionTitle('Товары за период'),
        _FinancePairCard(
          leftLabel: 'Закуплено',
          leftValue: summary.purchasesTotal,
          rightLabel: 'Продано',
          rightValue: summary.salesTotal,
        ),
        const SizedBox(height: 18),
        const _FinanceSectionTitle('Зарплата за период'),
        _FinancePairCard(
          leftLabel: 'Начислено',
          leftValue: summary.salaryAccrued,
          rightLabel: 'Выплачено',
          rightValue: summary.salaryPaid,
        ),
      ],
    );
  }
}

class _FinanceSectionTitle extends StatelessWidget {
  const _FinanceSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }
}

class _FinanceBalanceCard extends StatelessWidget {
  const _FinanceBalanceCard({
    required this.title,
    required this.opening,
    required this.debit,
    required this.credit,
    required this.closing,
    required this.debitLabel,
    required this.creditLabel,
  });

  final String title;
  final int opening;
  final int debit;
  final int credit;
  final int closing;
  final String debitLabel;
  final String creditLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StockReportMetric(
                  label: 'На начало',
                  value: formatMoney(opening),
                ),
              ),
              Expanded(
                child: _StockReportMetric(
                  label: debitLabel,
                  value: formatMoney(debit),
                ),
              ),
              Expanded(
                child: _StockReportMetric(
                  label: creditLabel,
                  value: formatMoney(credit),
                ),
              ),
              Expanded(
                child: _StockReportMetric(
                  label: 'На конец',
                  value: formatMoney(closing),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinancePairCard extends StatelessWidget {
  const _FinancePairCard({
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
  });

  final String leftLabel;
  final int leftValue;
  final String rightLabel;
  final int rightValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StockReportMetric(
              label: leftLabel,
              value: formatMoney(leftValue),
            ),
          ),
          Expanded(
            child: _StockReportMetric(
              label: rightLabel,
              value: formatMoney(rightValue),
            ),
          ),
        ],
      ),
    );
  }
}

/// Строит лист Excel (.xlsx) с финансовой сводкой.
List<int> _buildFinancialExcel({required _FinancialSummary summary}) {
  final excel = xlsx.Excel.createExcel();
  const sheetName = 'Сводка';
  final sheet = excel[sheetName];
  excel.setDefaultSheet(sheetName);

  sheet.appendRow([
    xlsx.TextCellValue('Раздел'),
    xlsx.TextCellValue('На начало'),
    xlsx.TextCellValue('Приход'),
    xlsx.TextCellValue('Расход'),
    xlsx.TextCellValue('На конец'),
  ]);
  sheet.appendRow([
    xlsx.TextCellValue('Деньги (счета и кассы)'),
    xlsx.IntCellValue(summary.moneyOpening),
    xlsx.IntCellValue(summary.moneyIncome),
    xlsx.IntCellValue(summary.moneyExpense),
    xlsx.IntCellValue(summary.moneyClosing),
  ]);
  sheet.appendRow([
    xlsx.TextCellValue('Дебиторка (нам должны)'),
    xlsx.IntCellValue(summary.receivableOpening),
    xlsx.IntCellValue(summary.receivableAccrued),
    xlsx.IntCellValue(summary.receivablePaid),
    xlsx.IntCellValue(summary.receivableClosing),
  ]);
  sheet.appendRow([
    xlsx.TextCellValue('Кредиторка (мы должны)'),
    xlsx.IntCellValue(summary.payableOpening),
    xlsx.IntCellValue(summary.payableAccrued),
    xlsx.IntCellValue(summary.payablePaid),
    xlsx.IntCellValue(summary.payableClosing),
  ]);

  sheet.appendRow([xlsx.TextCellValue('')]);
  sheet.appendRow([xlsx.TextCellValue('Товары за период')]);
  sheet.appendRow([
    xlsx.TextCellValue('Закуплено'),
    xlsx.IntCellValue(summary.purchasesTotal),
  ]);
  sheet.appendRow([
    xlsx.TextCellValue('Продано'),
    xlsx.IntCellValue(summary.salesTotal),
  ]);

  sheet.appendRow([xlsx.TextCellValue('')]);
  sheet.appendRow([xlsx.TextCellValue('Зарплата за период')]);
  sheet.appendRow([
    xlsx.TextCellValue('Начислено'),
    xlsx.IntCellValue(summary.salaryAccrued),
  ]);
  sheet.appendRow([
    xlsx.TextCellValue('Выплачено'),
    xlsx.IntCellValue(summary.salaryPaid),
  ]);

  if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
    excel.delete('Sheet1');
  }

  return excel.encode() ?? <int>[];
}

/// Строит PDF-форму финансовой сводки.
Future<Uint8List> _buildFinancialPdf({
  required String companyName,
  required String from,
  required String to,
  required _FinancialSummary summary,
}) async {
  final regularFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/PTSans-Regular.ttf'),
  );
  final boldFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/PTSans-Bold.ttf'),
  );
  final regularStyle = pw.TextStyle(font: regularFont, fontSize: 9);
  final boldStyle = pw.TextStyle(font: boldFont, fontSize: 9);

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
          'Финансовая сводка за период',
          style: pw.TextStyle(font: boldFont, fontSize: 13),
        ),
        pw.Text('Период: $from — $to', style: regularStyle),
        pw.SizedBox(height: 12),
        pw.Text('Оборотно-сальдовая ведомость', style: boldStyle),
        pw.SizedBox(height: 6),
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
          },
          headers: const [
            'Раздел',
            'На начало',
            'Приход',
            'Расход',
            'На конец',
          ],
          data: [
            [
              'Деньги (счета и кассы)',
              _formatMoneyForPdf(summary.moneyOpening),
              _formatMoneyForPdf(summary.moneyIncome),
              _formatMoneyForPdf(summary.moneyExpense),
              _formatMoneyForPdf(summary.moneyClosing),
            ],
            [
              'Дебиторка (нам должны)',
              _formatMoneyForPdf(summary.receivableOpening),
              _formatMoneyForPdf(summary.receivableAccrued),
              _formatMoneyForPdf(summary.receivablePaid),
              _formatMoneyForPdf(summary.receivableClosing),
            ],
            [
              'Кредиторка (мы должны)',
              _formatMoneyForPdf(summary.payableOpening),
              _formatMoneyForPdf(summary.payableAccrued),
              _formatMoneyForPdf(summary.payablePaid),
              _formatMoneyForPdf(summary.payableClosing),
            ],
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Text('Товары за период', style: boldStyle),
        pw.SizedBox(height: 4),
        pw.Text(
          'Закуплено: ${_formatMoneyForPdf(summary.purchasesTotal)}    '
          'Продано: ${_formatMoneyForPdf(summary.salesTotal)}',
          style: regularStyle,
        ),
        pw.SizedBox(height: 12),
        pw.Text('Зарплата за период', style: boldStyle),
        pw.SizedBox(height: 4),
        pw.Text(
          'Начислено: ${_formatMoneyForPdf(summary.salaryAccrued)}    '
          'Выплачено: ${_formatMoneyForPdf(summary.salaryPaid)}',
          style: regularStyle,
        ),
      ],
    ),
  );

  return doc.save();
}
