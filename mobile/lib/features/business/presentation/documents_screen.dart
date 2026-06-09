part of 'business_shell.dart';

/// Варианты сортировки списка документов продаж/закупок.
enum _DocumentSort { dateDesc, dateAsc, amountDesc, amountAsc, numberDesc, numberAsc }

String _documentSortLabel(_DocumentSort sort) {
  switch (sort) {
    case _DocumentSort.dateDesc:
      return 'Сначала новые';
    case _DocumentSort.dateAsc:
      return 'Сначала старые';
    case _DocumentSort.amountDesc:
      return 'Сумма ↓';
    case _DocumentSort.amountAsc:
      return 'Сумма ↑';
    case _DocumentSort.numberDesc:
      return 'Номер ↓';
    case _DocumentSort.numberAsc:
      return 'Номер ↑';
  }
}

String _documentStatusLabel(String status) {
  switch (status) {
    case 'draft':
      return 'Черновик';
    case 'posted':
      return 'Проведён';
    case 'cancelled':
      return 'Отменён';
    case 'partial':
      return 'Частично';
    default:
      return status.isEmpty ? '—' : status;
  }
}

StatusKind _documentStatusKind(String status) {
  switch (status) {
    case 'posted':
      return StatusKind.success;
    case 'draft':
      return StatusKind.warning;
    case 'cancelled':
      return StatusKind.error;
    default:
      return StatusKind.neutral;
  }
}

String _documentTypeLabel(String type) {
  switch (type) {
    case 'sale_issue':
      return 'Продажа';
    case 'purchase_receipt':
      return 'Закупка';
    case 'transfer':
      return 'Перемещение';
    case 'write_off':
      return 'Списание';
    case 'adjustment':
      return 'Корректировка';
    case 'opening':
      return 'Начальные остатки';
    case 'return_in':
      return 'Возврат (приход)';
    case 'return_out':
      return 'Возврат (расход)';
    case 'production_in':
      return 'Производство (приход)';
    case 'production_out':
      return 'Производство (расход)';
    default:
      return type.isEmpty ? '—' : type;
  }
}

/// Универсальный экран списка складских документов одного типа
/// (`sale_issue` для продаж, `purchase_receipt` для закупок) с поиском,
/// фильтрами (статус, период, контрагент, склад) и сортировкой.
class _DocumentsListScreen extends StatefulWidget {
  const _DocumentsListScreen({
    required this.accessToken,
    required this.businessGateway,
    required this.documentType,
    required this.title,
    required this.accentColor,
    required this.counterpartyLabel,
  });

  final String accessToken;
  final BusinessGateway businessGateway;
  final String documentType;
  final String title;
  final Color accentColor;
  final String counterpartyLabel;

  @override
  State<_DocumentsListScreen> createState() => _DocumentsListScreenState();
}

class _DocumentsListScreenState extends State<_DocumentsListScreen> {
  bool _isLoading = true;
  String? _loadError;
  List<_InventoryDocument> _documents = const [];

  String _query = '';
  String? _statusFilter;
  DateTimeRange? _dateRange;
  String? _counterpartyFilter;
  String? _warehouseFilter;
  _DocumentSort _sort = _DocumentSort.dateDesc;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final documents = await widget.businessGateway.fetchInventoryDocuments(
        accessToken: widget.accessToken,
        type: widget.documentType,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _documents = documents
            .map(_inventoryDocumentFromJson)
            .toList(growable: false);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = '$error';
        _isLoading = false;
      });
    }
  }

  List<String> get _counterpartyOptions {
    final values = _documents
        .map((d) => d.clientName)
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return values;
  }

  List<String> get _warehouseOptions {
    final values = _documents
        .map((d) => d.warehouseName)
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return values;
  }

  List<_InventoryDocument> get _filteredDocuments {
    final query = _query.trim().toLowerCase();
    final range = _dateRange;

    final filtered = _documents.where((document) {
      if (_statusFilter != null && document.status != _statusFilter) {
        return false;
      }
      if (_counterpartyFilter != null &&
          document.clientName != _counterpartyFilter) {
        return false;
      }
      if (_warehouseFilter != null &&
          document.warehouseName != _warehouseFilter) {
        return false;
      }
      if (range != null) {
        final date = DateTime.tryParse(document.documentDate);
        if (date == null) {
          return false;
        }
        final day = DateTime(date.year, date.month, date.day);
        final start = DateTime(
          range.start.year,
          range.start.month,
          range.start.day,
        );
        final end = DateTime(range.end.year, range.end.month, range.end.day);
        if (day.isBefore(start) || day.isAfter(end)) {
          return false;
        }
      }
      if (query.isNotEmpty) {
        final haystack = '${document.documentNo} ${document.clientName} '
                '${document.warehouseName}'
            .toLowerCase();
        if (!haystack.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      switch (_sort) {
        case _DocumentSort.dateDesc:
          return b.documentDate.compareTo(a.documentDate);
        case _DocumentSort.dateAsc:
          return a.documentDate.compareTo(b.documentDate);
        case _DocumentSort.amountDesc:
          return b.totalAmount.compareTo(a.totalAmount);
        case _DocumentSort.amountAsc:
          return a.totalAmount.compareTo(b.totalAmount);
        case _DocumentSort.numberDesc:
          return b.documentNo.compareTo(a.documentNo);
        case _DocumentSort.numberAsc:
          return a.documentNo.compareTo(b.documentNo);
      }
    });

    return filtered;
  }

  bool get _hasActiveFilters =>
      _statusFilter != null ||
      _dateRange != null ||
      _counterpartyFilter != null ||
      _warehouseFilter != null;

  void _resetFilters() {
    setState(() {
      _statusFilter = null;
      _dateRange = null;
      _counterpartyFilter = null;
      _warehouseFilter = null;
    });
  }

  Future<void> _pickSort() async {
    final selected = await _showOptionPicker<_DocumentSort>(
      title: 'Сортировка',
      options: _DocumentSort.values
          .map((s) => MapEntry(_documentSortLabel(s), s))
          .toList(),
      current: _sort,
    );
    if (selected != null) {
      setState(() => _sort = selected);
    }
  }

  Future<void> _pickStatus() async {
    final selected = await _showOptionPicker<String?>(
      title: 'Статус',
      options: const [
        MapEntry('Все статусы', null),
        MapEntry('Черновик', 'draft'),
        MapEntry('Проведён', 'posted'),
        MapEntry('Отменён', 'cancelled'),
      ],
      current: _statusFilter,
    );
    setState(() => _statusFilter = selected);
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  Future<void> _pickCounterparty() async {
    final options = _counterpartyOptions;
    if (options.isEmpty) {
      return;
    }
    final selected = await _showOptionPicker<String?>(
      title: widget.counterpartyLabel,
      options: [
        const MapEntry('Все', null),
        ...options.map((name) => MapEntry(name, name)),
      ],
      current: _counterpartyFilter,
    );
    setState(() => _counterpartyFilter = selected);
  }

  Future<void> _pickWarehouse() async {
    final options = _warehouseOptions;
    if (options.isEmpty) {
      return;
    }
    final selected = await _showOptionPicker<String?>(
      title: 'Склад',
      options: [
        const MapEntry('Все', null),
        ...options.map((name) => MapEntry(name, name)),
      ],
      current: _warehouseFilter,
    );
    setState(() => _warehouseFilter = selected);
  }

  Future<T?> _showOptionPicker<T>({
    required String title,
    required List<MapEntry<String, T>> options,
    required T current,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF7FAF8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              const SizedBox(width: 48, child: Divider(thickness: 4)),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  children: options.map((option) {
                    final isSelected = option.value == current;
                    return ListTile(
                      title: Text(option.key),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_rounded,
                              color: widget.accentColor,
                            )
                          : null,
                      onTap: () => Navigator.of(context).pop(option.value),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _dateRangeLabel {
    final range = _dateRange;
    if (range == null) {
      return 'Период';
    }
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    return '${fmt(range.start)} – ${fmt(range.end)}';
  }

  Future<void> _openDocumentDetail(_InventoryDocument document) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _DocumentDetailScreen(
          accessToken: widget.accessToken,
          businessGateway: widget.businessGateway,
          document: document,
          accentColor: widget.accentColor,
          counterpartyLabel: widget.counterpartyLabel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GradientHeader(title: widget.title),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _SearchField(
            hintText: 'Поиск по номеру, контрагенту, складу...',
            icon: Icons.search_rounded,
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _FilterChipButton(
                label: _documentSortLabel(_sort),
                active: _sort != _DocumentSort.dateDesc,
                activeColor: widget.accentColor,
                onPressed: _pickSort,
              ),
              const SizedBox(width: 8),
              _FilterChipButton(
                label: _statusFilter == null
                    ? 'Статус'
                    : _documentStatusLabel(_statusFilter!),
                active: _statusFilter != null,
                activeColor: widget.accentColor,
                onPressed: _pickStatus,
              ),
              const SizedBox(width: 8),
              _FilterChipButton(
                label: _dateRangeLabel,
                active: _dateRange != null,
                activeColor: widget.accentColor,
                onPressed: _pickDateRange,
              ),
              const SizedBox(width: 8),
              _FilterChipButton(
                label: _counterpartyFilter ?? widget.counterpartyLabel,
                active: _counterpartyFilter != null,
                activeColor: widget.accentColor,
                onPressed: _pickCounterparty,
              ),
              const SizedBox(width: 8),
              _FilterChipButton(
                label: _warehouseFilter ?? 'Склад',
                active: _warehouseFilter != null,
                activeColor: widget.accentColor,
                onPressed: _pickWarehouse,
              ),
              if (_hasActiveFilters) ...[
                const SizedBox(width: 8),
                _FilterChipButton(
                  label: 'Сбросить',
                  active: false,
                  activeColor: widget.accentColor,
                  onPressed: _resetFilters,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 52,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(height: 12),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
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

    final documents = _filteredDocuments;
    if (documents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.inbox_rounded,
                size: 52,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(height: 12),
              Text(
                _documents.isEmpty
                    ? 'Документов пока нет'
                    : 'Ничего не найдено по выбранным фильтрам',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        itemCount: documents.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final document = documents[index];
          return _BusinessCard(
            onTap: () => _openDocumentDetail(document),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        document.documentNo,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    _StatusBadge(
                      label: _documentStatusLabel(document.status),
                      kind: _documentStatusKind(document.status),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  document.documentDate,
                  style: const TextStyle(
                    color: Color(0xFF7B8794),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _LabelValue(
                        label: 'Склад',
                        value: document.warehouseName.isEmpty
                            ? '—'
                            : document.warehouseName,
                      ),
                    ),
                    if (document.clientName.isNotEmpty)
                      Expanded(
                        child: _LabelValue(
                          label: widget.counterpartyLabel,
                          value: document.clientName,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    _LabelValue(
                      label: 'Сумма',
                      value: formatMoney(document.totalAmount),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _LabelValue(
                        label: 'Количество',
                        value: '${document.totalQuantity}',
                      ),
                    ),
                    _LabelValue(
                      label: 'Строк',
                      value: '${document.productLines}',
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
                if (document.note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    document.note,
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Полноэкранные детали складского документа (продажа/закупка).
class _DocumentDetailScreen extends StatefulWidget {
  const _DocumentDetailScreen({
    required this.accessToken,
    required this.businessGateway,
    required this.document,
    required this.accentColor,
    required this.counterpartyLabel,
  });

  final String accessToken;
  final BusinessGateway businessGateway;
  final _InventoryDocument document;
  final Color accentColor;
  final String counterpartyLabel;

  @override
  State<_DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<_DocumentDetailScreen> {
  bool _isLoading = true;
  String? _loadError;
  _InventoryDocumentDetail? _detail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final payload = await widget.businessGateway.fetchInventoryDocumentDetail(
        accessToken: widget.accessToken,
        documentId: widget.document.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _detail = _inventoryDocumentDetailFromJson(payload);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = '$error';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7FAF8),
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text(
          widget.document.documentNo,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null || _detail == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 52,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(height: 12),
              Text(
                _loadError ?? 'Не удалось загрузить документ',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
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

    final detail = _detail!;
    final summary = detail.summary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_documentTypeLabel(summary.documentType)} • ${summary.documentDate}',
                style: const TextStyle(color: Color(0xFF7B8794)),
              ),
            ),
            _StatusBadge(
              label: _documentStatusLabel(summary.status),
              kind: _documentStatusKind(summary.status),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _BusinessCard(
          child: Row(
            children: [
              Expanded(
                child: _LabelValue(
                  label: 'Склад',
                  value:
                      summary.warehouseName.isEmpty ? '—' : summary.warehouseName,
                ),
              ),
              if (summary.clientName.isNotEmpty)
                Expanded(
                  child: _LabelValue(
                    label: widget.counterpartyLabel,
                    value: summary.clientName,
                    textAlign: TextAlign.center,
                  ),
                ),
              _LabelValue(
                label: 'Сумма',
                value: formatMoney(summary.totalAmount),
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _BusinessCard(
          child: Row(
            children: [
              Expanded(
                child: _LabelValue(
                  label: 'Строк',
                  value: '${summary.productLines}',
                ),
              ),
              _LabelValue(
                label: 'Количество',
                value: '${summary.totalQuantity}',
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ),
        if (summary.note.isNotEmpty) ...[
          const SizedBox(height: 12),
          _BusinessCard(
            child: _LabelValue(
              label: 'Примечание',
              value: summary.note,
            ),
          ),
        ],
        const SizedBox(height: 20),
        const Text(
          'Позиции',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        if (detail.lines.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'В документе нет позиций',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
          )
        else
          ...detail.lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _BusinessCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    if (line.sku.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'SKU: ${line.sku}',
                        style: const TextStyle(
                          color: Color(0xFF7B8794),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _LabelValue(
                            label: 'Количество',
                            value: '${line.quantity}',
                          ),
                        ),
                        Expanded(
                          child: _LabelValue(
                            label: 'Цена',
                            value: formatMoney(line.unitPrice),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          child: _LabelValue(
                            label: 'Сумма',
                            value: formatMoney(line.lineTotal),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    if (line.note.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        line.note,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
