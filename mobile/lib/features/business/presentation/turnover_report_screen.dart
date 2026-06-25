part of 'business_shell.dart';

/// Отчёт «Оборотная ведомость по товарам»: выбор склада и периода → движение
/// товаров (остаток на начало, приход, расход, остаток на конец) с экспортом в
/// PDF / Excel.
class _TurnoverReportScreen extends StatefulWidget {
  const _TurnoverReportScreen({
    required this.accessToken,
    required this.businessGateway,
    required this.companyName,
  });

  final String accessToken;
  final BusinessGateway businessGateway;
  final String companyName;

  @override
  State<_TurnoverReportScreen> createState() => _TurnoverReportScreenState();
}

class _TurnoverReportScreenState extends State<_TurnoverReportScreen> {
  List<_Warehouse> _warehouses = const [];
  _Warehouse? _selected;
  late DateTime _from;
  late DateTime _to;
  List<_WarehouseTurnoverItem> _items = const [];
  bool _loadingWarehouses = true;
  bool _forming = false;
  bool _formed = false;
  bool _exporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month, now.day);
    _loadWarehouses();
  }

  Future<void> _loadWarehouses() async {
    setState(() {
      _loadingWarehouses = true;
      _error = null;
    });
    try {
      final payload = await widget.businessGateway.fetchWarehouses(
        accessToken: widget.accessToken,
      );
      final warehouses = payload.map(_warehouseFromJson).toList();
      if (!mounted) return;
      setState(() {
        _warehouses = warehouses;
        _selected = warehouses.isEmpty
            ? null
            : warehouses.firstWhere(
                (item) => item.isDefault,
                orElse: () => warehouses.first,
              );
        _loadingWarehouses = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loadingWarehouses = false;
      });
    }
  }

  String _apiDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String _humanDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.'
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
      _formed = false;
      _items = const [];
    });
  }

  Future<void> _form() async {
    final warehouse = _selected;
    if (warehouse == null) return;
    setState(() {
      _forming = true;
      _error = null;
    });
    try {
      final payload = await widget.businessGateway.fetchWarehouseTurnover(
        accessToken: widget.accessToken,
        warehouseId: warehouse.id,
        from: _apiDate(_from),
        to: _apiDate(_to),
      );
      final items =
          payload.map(_warehouseTurnoverItemFromJson).toList(growable: false);
      if (!mounted) return;
      setState(() {
        _items = items;
        _formed = true;
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

  int get _totalReceipts =>
      _items.fold(0, (sum, item) => sum + item.receipts);

  int get _totalIssues => _items.fold(0, (sum, item) => sum + item.issues);

  Future<void> _exportPdf() async {
    final warehouse = _selected;
    if (warehouse == null || _items.isEmpty) return;
    setState(() => _exporting = true);
    try {
      final bytes = await _buildTurnoverPdf(
        companyName: widget.companyName,
        warehouseName: warehouse.name,
        from: _humanDate(_from),
        to: _humanDate(_to),
        items: _items,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _PrintedFormScreen(
            documentNo: 'Ведомость ${warehouse.name}',
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
    final warehouse = _selected;
    if (warehouse == null || _items.isEmpty) return;
    setState(() => _exporting = true);
    try {
      final bytes = _buildTurnoverExcel(items: _items);
      final safeName =
          warehouse.name.replaceAll(RegExp(r'[^0-9A-Za-zА-Яа-яЁё-]+'), '_');
      await shareBytesFile(
        bytes,
        'Vedomost_$safeName.xlsx',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'Оборотная ведомость ${warehouse.name}',
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
    final canExport = _formed && _items.isNotEmpty && !_exporting;
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7FAF8),
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text('Оборотная ведомость'),
      ),
      body: _loadingWarehouses
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Склад',
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
                          child: DropdownButton<_Warehouse>(
                            isExpanded: true,
                            value: _selected,
                            hint: const Text('Выберите склад'),
                            items: _warehouses
                                .map(
                                  (warehouse) => DropdownMenuItem(
                                    value: warehouse,
                                    child: Text(warehouse.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selected = value;
                                _formed = false;
                                _items = const [];
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
                if (_formed && _items.isNotEmpty)
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
    if (!_formed) {
      return const _ReportNotice(
        icon: Icons.swap_vert_rounded,
        title: 'Отчёт не сформирован',
        message: 'Выберите склад и период, затем нажмите «Сформировать».',
      );
    }
    if (_items.isEmpty) {
      return const _ReportNotice(
        icon: Icons.inbox_rounded,
        title: 'Нет движений',
        message: 'За выбранный период по складу нет движений товаров.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      itemCount: _items.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Итого за период',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Приход $_totalReceipts · Расход $_totalIssues',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF00A86B),
                  ),
                ),
              ],
            ),
          );
        }
        return _TurnoverRow(item: _items[index]);
      },
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

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
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_rounded,
                    size: 18, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TurnoverRow extends StatelessWidget {
  const _TurnoverRow({required this.item});

  final _WarehouseTurnoverItem item;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (item.sku.isNotEmpty) 'SKU: ${item.sku}',
      if (item.barcode.isNotEmpty) 'ШК: ${item.barcode}',
    ].join('   ');
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
            item.productName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '$meta   ·   ${item.unitName}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StockReportMetric(
                  label: 'Начало',
                  value: '${item.opening}',
                ),
              ),
              Expanded(
                child: _StockReportMetric(
                  label: 'Приход',
                  value: '+${item.receipts}',
                ),
              ),
              Expanded(
                child: _StockReportMetric(
                  label: 'Расход',
                  value: '-${item.issues}',
                ),
              ),
              Expanded(
                child: _StockReportMetric(
                  label: 'Конец',
                  value: '${item.closing}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Строит лист Excel (.xlsx) с оборотной ведомостью.
List<int> _buildTurnoverExcel({required List<_WarehouseTurnoverItem> items}) {
  final excel = xlsx.Excel.createExcel();
  const sheetName = 'Ведомость';
  final sheet = excel[sheetName];
  excel.setDefaultSheet(sheetName);

  sheet.appendRow([
    xlsx.TextCellValue('Наименование'),
    xlsx.TextCellValue('SKU'),
    xlsx.TextCellValue('Штрихкод'),
    xlsx.TextCellValue('Ед.'),
    xlsx.TextCellValue('Остаток на начало'),
    xlsx.TextCellValue('Приход'),
    xlsx.TextCellValue('Расход'),
    xlsx.TextCellValue('Остаток на конец'),
  ]);

  for (final item in items) {
    sheet.appendRow([
      xlsx.TextCellValue(item.productName),
      xlsx.TextCellValue(item.sku),
      xlsx.TextCellValue(item.barcode),
      xlsx.TextCellValue(item.unitName),
      xlsx.IntCellValue(item.opening),
      xlsx.IntCellValue(item.receipts),
      xlsx.IntCellValue(item.issues),
      xlsx.IntCellValue(item.closing),
    ]);
  }

  if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
    excel.delete('Sheet1');
  }

  return excel.encode() ?? <int>[];
}

/// Строит PDF-форму оборотной ведомости.
Future<Uint8List> _buildTurnoverPdf({
  required String companyName,
  required String warehouseName,
  required String from,
  required String to,
  required List<_WarehouseTurnoverItem> items,
}) async {
  final regularFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/PTSans-Regular.ttf'),
  );
  final boldFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/PTSans-Bold.ttf'),
  );
  final regularStyle = pw.TextStyle(font: regularFont, fontSize: 9);
  final boldStyle = pw.TextStyle(font: boldFont, fontSize: 9);

  var totalReceipts = 0;
  var totalIssues = 0;
  for (final item in items) {
    totalReceipts += item.receipts;
    totalIssues += item.issues;
  }

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
          'Оборотная ведомость: $warehouseName',
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
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.centerLeft,
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
            6: pw.Alignment.centerRight,
          },
          headers: const [
            'Наименование',
            'SKU',
            'Штрихкод',
            'Начало',
            'Приход',
            'Расход',
            'Конец',
          ],
          data: List<List<String>>.generate(items.length, (index) {
            final item = items[index];
            return [
              item.productName,
              item.sku.isEmpty ? '—' : item.sku,
              item.barcode.isEmpty ? '—' : item.barcode,
              '${item.opening}',
              '${item.receipts}',
              '${item.issues}',
              '${item.closing}',
            ];
          }),
        ),
        pw.SizedBox(height: 10),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Итого за период — приход: $totalReceipts, расход: $totalIssues',
            style: pw.TextStyle(font: boldFont, fontSize: 11),
          ),
        ),
      ],
    ),
  );

  return doc.save();
}
