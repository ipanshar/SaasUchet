part of 'business_shell.dart';

/// Карточка-ссылка на отдельный отчёт в разделе «Отчёты».
class _ReportLinkCard extends StatelessWidget {
  const _ReportLinkCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF00A86B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF00A86B)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Отчёт «Остатки на складах»: выбор склада → формирование списка товаров с
/// остатком > 0 (наименование, SKU, штрихкод, количество, себестоимость) и
/// экспорт в PDF / Excel.
class _StockReportScreen extends StatefulWidget {
  const _StockReportScreen({
    required this.accessToken,
    required this.businessGateway,
    required this.companyName,
  });

  final String accessToken;
  final BusinessGateway businessGateway;
  final String companyName;

  @override
  State<_StockReportScreen> createState() => _StockReportScreenState();
}

class _StockReportScreenState extends State<_StockReportScreen> {
  List<_Warehouse> _warehouses = const [];
  _Warehouse? _selected;
  List<_WarehouseStockItem> _items = const [];
  bool _loadingWarehouses = true;
  bool _forming = false;
  bool _formed = false;
  bool _exporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
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

  Future<void> _form() async {
    final warehouse = _selected;
    if (warehouse == null) return;
    setState(() {
      _forming = true;
      _error = null;
    });
    try {
      final payload = await widget.businessGateway.fetchWarehouseStock(
        accessToken: widget.accessToken,
        warehouseId: warehouse.id,
      );
      final items = payload
          .map(_warehouseStockItemFromJson)
          .where((item) => item.available > 0)
          .toList()
        ..sort((a, b) => a.productName
            .toLowerCase()
            .compareTo(b.productName.toLowerCase()));
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

  int get _totalCost =>
      _items.fold(0, (sum, item) => sum + item.available * item.cost);

  Future<void> _exportPdf() async {
    final warehouse = _selected;
    if (warehouse == null || _items.isEmpty) return;
    setState(() => _exporting = true);
    try {
      final bytes = await _buildStockReportPdf(
        companyName: widget.companyName,
        warehouseName: warehouse.name,
        items: _items,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _PrintedFormScreen(
            documentNo: 'Остатки ${warehouse.name}',
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
      final bytes = _buildStockReportExcel(items: _items);
      final safeName =
          warehouse.name.replaceAll(RegExp(r'[^0-9A-Za-zА-Яа-яЁё-]+'), '_');
      await shareBytesFile(
        bytes,
        'Ostatki_$safeName.xlsx',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'Остатки на складе ${warehouse.name}',
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
        title: const Text('Остатки на складах'),
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
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _selected == null || _forming
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
        icon: Icons.inventory_2_rounded,
        title: 'Отчёт не сформирован',
        message: 'Выберите склад и нажмите «Сформировать».',
      );
    }
    if (_items.isEmpty) {
      return const _ReportNotice(
        icon: Icons.inbox_rounded,
        title: 'Нет остатков',
        message: 'На выбранном складе нет товаров с остатком больше 0.',
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
                  'Итого себестоимость',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  formatMoney(_totalCost),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF00A86B),
                  ),
                ),
              ],
            ),
          );
        }
        final item = _items[index];
        return _StockReportRow(item: item);
      },
    );
  }
}

class _StockReportRow extends StatelessWidget {
  const _StockReportRow({required this.item});

  final _WarehouseStockItem item;

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
              meta,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StockReportMetric(
                  label: 'Кол-во',
                  value: '${item.available} ${item.unitName}',
                ),
              ),
              Expanded(
                child: _StockReportMetric(
                  label: 'Себестоимость',
                  value: formatMoney(item.cost),
                ),
              ),
              Expanded(
                child: _StockReportMetric(
                  label: 'Сумма',
                  value: formatMoney(item.available * item.cost),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StockReportMetric extends StatelessWidget {
  const _StockReportMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

/// Строит лист Excel (.xlsx) с остатками склада.
List<int> _buildStockReportExcel({required List<_WarehouseStockItem> items}) {
  final excel = xlsx.Excel.createExcel();
  const sheetName = 'Остатки';
  final sheet = excel[sheetName];
  excel.setDefaultSheet(sheetName);

  sheet.appendRow([
    xlsx.TextCellValue('Наименование'),
    xlsx.TextCellValue('SKU'),
    xlsx.TextCellValue('Штрихкод'),
    xlsx.TextCellValue('Количество'),
    xlsx.TextCellValue('Ед.'),
    xlsx.TextCellValue('Себестоимость'),
    xlsx.TextCellValue('Сумма'),
  ]);

  for (final item in items) {
    sheet.appendRow([
      xlsx.TextCellValue(item.productName),
      xlsx.TextCellValue(item.sku),
      xlsx.TextCellValue(item.barcode),
      xlsx.IntCellValue(item.available),
      xlsx.TextCellValue(item.unitName),
      xlsx.IntCellValue(item.cost),
      xlsx.IntCellValue(item.available * item.cost),
    ]);
  }

  // Удаляем автосозданный пустой лист по умолчанию.
  if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
    excel.delete('Sheet1');
  }

  return excel.encode() ?? <int>[];
}

/// Строит PDF-форму отчёта по остаткам склада.
Future<Uint8List> _buildStockReportPdf({
  required String companyName,
  required String warehouseName,
  required List<_WarehouseStockItem> items,
}) async {
  final regularFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/PTSans-Regular.ttf'),
  );
  final boldFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/PTSans-Bold.ttf'),
  );
  final regularStyle = pw.TextStyle(font: regularFont, fontSize: 9);
  final boldStyle = pw.TextStyle(font: boldFont, fontSize: 9);

  final now = DateTime.now();
  final dateLabel = '${now.day.toString().padLeft(2, '0')}.'
      '${now.month.toString().padLeft(2, '0')}.${now.year}';
  final totalCost =
      items.fold<int>(0, (sum, item) => sum + item.available * item.cost);

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
          'Остатки на складе: $warehouseName',
          style: pw.TextStyle(font: boldFont, fontSize: 13),
        ),
        pw.Text('Дата формирования: $dateLabel', style: regularStyle),
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
            'Наименование',
            'SKU',
            'Штрихкод',
            'Кол-во',
            'Себестоимость',
            'Сумма',
          ],
          data: List<List<String>>.generate(items.length, (index) {
            final item = items[index];
            return [
              item.productName,
              item.sku.isEmpty ? '—' : item.sku,
              item.barcode.isEmpty ? '—' : item.barcode,
              '${item.available} ${item.unitName}',
              _formatMoneyForPdf(item.cost),
              _formatMoneyForPdf(item.available * item.cost),
            ];
          }),
        ),
        pw.SizedBox(height: 10),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Итого себестоимость: ${_formatMoneyForPdf(totalCost)}',
            style: pw.TextStyle(font: boldFont, fontSize: 12),
          ),
        ),
      ],
    ),
  );

  return doc.save();
}
