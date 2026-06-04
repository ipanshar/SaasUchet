part of 'business_shell.dart';

class _WarehouseScreen extends StatefulWidget {
  const _WarehouseScreen({
    super.key,
    required this.accessToken,
    required this.products,
    required this.clients,
    required this.businessGateway,
    required this.onProductsChanged,
  });

  final String accessToken;
  final List<_Product> products;
  final List<_Client> clients;
  final BusinessGateway businessGateway;
  final Future<void> Function() onProductsChanged;

  @override
  State<_WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<_WarehouseScreen> {
  String _query = '';
  WarehouseFilter _filter = WarehouseFilter.all;
  _Product? _selectedProduct;
  bool _isSubmitting = false;

  Future<void> openInventoryDocuments() async {
    if (_isSubmitting) {
      return;
    }
    await _showInventoryDocuments();
  }

  Future<void> openCreateInventoryDocument() async {
    if (_isSubmitting) {
      return;
    }
    await _showCreateInventoryDocument();
  }

  Future<void> openCreateProduct() async {
    if (_isSubmitting) {
      return;
    }
    await _showProductSheet();
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.products.where((product) {
      final matchesQuery =
          product.name.toLowerCase().contains(_query.toLowerCase()) ||
              product.sku.toLowerCase().contains(_query.toLowerCase());

      switch (_filter) {
        case WarehouseFilter.low:
          return matchesQuery && product.status == ProductStatus.lowStock;
        case WarehouseFilter.out:
          return matchesQuery && product.status == ProductStatus.outOfStock;
        case WarehouseFilter.all:
          return matchesQuery;
      }
    }).toList();

    final lowCount = widget.products
        .where((product) => product.status == ProductStatus.lowStock)
        .length;
    final outCount = widget.products
        .where((product) => product.status == ProductStatus.outOfStock)
        .length;

    if (_selectedProduct != null) {
      final product = _selectedProduct!;
      final markupPercent = product.cost <= 0
          ? 0.0
          : ((product.price - product.cost) / product.cost) * 100;
      return SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _selectedProduct = null),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Назад'),
            ),
            const SizedBox(height: 8),
            _BusinessCard(
              background: const LinearGradient(
                colors: [Color(0xFF00A86B), Color(0xFF008F5B)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'SKU: ${product.sku}',
                    style: const TextStyle(color: Color(0xCCFFFFFF)),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _HeroStat(
                        label: 'Остаток',
                        value: '${product.quantity} шт',
                      ),
                      const SizedBox(width: 16),
                      _HeroStat(
                        label: 'Цена продажи',
                        value: formatMoney(product.price),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _BusinessCard(
                    child: _LabelValue(
                      label: 'Себестоимость',
                      value: formatMoney(product.cost),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BusinessCard(
                    child: _LabelValue(
                      label: 'Наценка',
                      value: '${markupPercent.toStringAsFixed(1)}%',
                      valueColor: const Color(0xFF16A34A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _BusinessCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Штрих-код',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.qr_code_2_rounded, size: 34),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.barcode.isEmpty
                                ? 'Не указан'
                                : product.barcode,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            product.category.isEmpty
                                ? 'Без категории'
                                : product.category,
                            style: const TextStyle(
                              color: Color(0xFF7B8794),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _BusinessCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Движение товара',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  if (product.movements.isEmpty)
                    const Text(
                      'Движений пока нет',
                      style: TextStyle(color: Color(0xFF7B8794)),
                    )
                  else
                    ...product.movements.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: item.quantity > 0
                                    ? const Color(0x1422C55E)
                                    : const Color(0x14F59E0B),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.inventory_2_rounded,
                                color: item.quantity > 0
                                    ? const Color(0xFF22C55E)
                                    : const Color(0xFFF59E0B),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.document,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    item.date,
                                    style: const TextStyle(
                                      color: Color(0xFF7B8794),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${item.quantity > 0 ? '+' : ''}${item.quantity}',
                                  style: TextStyle(
                                    color: item.quantity > 0
                                        ? const Color(0xFF22C55E)
                                        : const Color(0xFFF59E0B),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Ост: ${item.balance}',
                                  style: const TextStyle(
                                    color: Color(0xFF7B8794),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => _showProductSheet(initialProduct: product),
                    child: const Text('Редактировать'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _isSubmitting ? null : () => _deleteProduct(product),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                    ),
                    child: const Text('Удалить'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          const Text(
            'Склад',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SearchField(
                  hintText: 'Поиск товаров...',
                  icon: Icons.search_rounded,
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              const SizedBox(width: 10),
              _SquareIconButton(icon: Icons.tune_rounded, onPressed: () {}),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChipButton(
                  label: 'Все товары',
                  active: _filter == WarehouseFilter.all,
                  activeColor: const Color(0xFF00A86B),
                  onPressed: () =>
                      setState(() => _filter = WarehouseFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChipButton(
                  label: 'Заканчиваются',
                  active: _filter == WarehouseFilter.low,
                  activeColor: const Color(0xFFF59E0B),
                  onPressed: () =>
                      setState(() => _filter = WarehouseFilter.low),
                ),
                const SizedBox(width: 8),
                _FilterChipButton(
                  label: 'Нет в наличии',
                  active: _filter == WarehouseFilter.out,
                  activeColor: const Color(0xFFEF4444),
                  onPressed: () =>
                      setState(() => _filter = WarehouseFilter.out),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Позиций',
                  value: '${widget.products.length}',
                  tone: const Color(0x1400A86B),
                  accent: const Color(0xFF00A86B),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  title: 'Заканчивается',
                  value: '$lowCount',
                  tone: const Color(0x14F59E0B),
                  accent: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  title: 'Нет в наличии',
                  value: '$outCount',
                  tone: const Color(0x14EF4444),
                  accent: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...products.map(
            (product) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _BusinessCard(
                onTap: () => setState(() => _selectedProduct = product),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'SKU: ${product.sku} • ${product.category.isEmpty ? 'Без категории' : product.category}',
                                style: const TextStyle(
                                  color: Color(0xFF7B8794),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _StatusBadge(
                          label: product.statusLabel,
                          kind: product.status == ProductStatus.outOfStock
                              ? StatusKind.error
                              : product.status == ProductStatus.lowStock
                                  ? StatusKind.warning
                                  : StatusKind.success,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _LabelValue(
                            label: 'Цена',
                            value: formatMoney(product.price),
                          ),
                        ),
                        _LabelValue(
                          label: 'Остаток',
                          value: '${product.quantity} шт',
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showProductSheet({_Product? initialProduct}) async {
    final result = await showModalBottomSheet<_CreateProductFormData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateProductSheet(initialProduct: initialProduct),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final payload = {
        'name': result.name,
        'sku': result.sku,
        'category': result.category,
        'initial_quantity': result.initialQuantity,
        'min_quantity': result.minQuantity,
        'price': result.price,
        'cost': result.cost,
        'barcode': result.barcode,
      };
      if (initialProduct == null) {
        await widget.businessGateway.createProduct(
          accessToken: widget.accessToken,
          payload: payload,
        );
      } else {
        await widget.businessGateway.updateProduct(
          accessToken: widget.accessToken,
          productId: initialProduct.id,
          payload: payload,
        );
      }
      await widget.onProductsChanged();
      if (!mounted) {
        return;
      }
      if (initialProduct != null) {
        setState(() {
          _selectedProduct = null;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            initialProduct == null ? 'Товар добавлен' : 'Товар обновлен',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _deleteProduct(_Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить товар?'),
        content: Text('Товар "${product.name}" будет удален со склада.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.businessGateway.deleteProduct(
        accessToken: widget.accessToken,
        productId: product.id,
      );
      await widget.onProductsChanged();
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedProduct = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Товар удален')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _showInventoryDocuments() async {
    try {
      final documents = await widget.businessGateway.fetchInventoryDocuments(
        accessToken: widget.accessToken,
      );
      if (!mounted) {
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _InventoryDocumentsSheet(
          accessToken: widget.accessToken,
          businessGateway: widget.businessGateway,
          documents:
              documents.map(_inventoryDocumentFromJson).toList(growable: false),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _showCreateInventoryDocument() async {
    if (widget.products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала добавьте товары')),
      );
      return;
    }

    final result = await showModalBottomSheet<_CreateInventoryDocumentFormData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateInventoryDocumentSheet(
        products: widget.products,
        clients: widget.clients,
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.businessGateway.createInventoryDocument(
        accessToken: widget.accessToken,
        payload: {
          'document_type': result.documentType,
          'client_id': result.clientId,
          'warehouse_name': result.warehouseName,
          'related_warehouse_name': result.relatedWarehouseName,
          'note': result.note,
          'lines': result.lines
              .map(
                (line) => {
                  'product_id': line.productId,
                  'quantity': line.quantity,
                  'unit_price': line.unitPrice,
                  'unit_cost': line.unitCost,
                  'note': line.note,
                },
              )
              .toList(growable: false),
        },
      );
      await widget.onProductsChanged();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Складской документ создан')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}

class _CreateProductFormData {
  const _CreateProductFormData({
    required this.name,
    required this.sku,
    required this.category,
    required this.initialQuantity,
    required this.minQuantity,
    required this.price,
    required this.cost,
    required this.barcode,
  });

  final String name;
  final String sku;
  final String category;
  final int initialQuantity;
  final int minQuantity;
  final int price;
  final int cost;
  final String barcode;
}

class _CreateProductSheet extends StatefulWidget {
  const _CreateProductSheet({this.initialProduct});

  final _Product? initialProduct;

  @override
  State<_CreateProductSheet> createState() => _CreateProductSheetState();
}

class _CreateProductSheetState extends State<_CreateProductSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _categoryController = TextEditingController();
  final _initialQuantityController = TextEditingController();
  final _minQuantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _barcodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final product = widget.initialProduct;
    if (product == null) {
      return;
    }

    _nameController.text = product.name;
    _skuController.text = product.sku;
    _categoryController.text = product.category;
    _initialQuantityController.text = '${product.quantity}';
    _minQuantityController.text = '${product.minQuantity}';
    _priceController.text = '${product.price}';
    _costController.text = '${product.cost}';
    _barcodeController.text = product.barcode;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _categoryController.dispose();
    _initialQuantityController.dispose();
    _minQuantityController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _barcodeController.dispose();
    super.dispose();
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Center(
                      child: SizedBox(width: 48, child: Divider(thickness: 4)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.initialProduct == null
                          ? 'Новый товар'
                          : 'Редактировать товар',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ClientTextField(
                      controller: _nameController,
                      label: 'Название',
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 12),
                    _ClientTextField(
                      controller: _skuController,
                      label: 'SKU',
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 12),
                    _ClientTextField(
                      controller: _categoryController,
                      label: 'Категория',
                    ),
                    const SizedBox(height: 12),
                    _ClientTextField(
                      controller: _initialQuantityController,
                      label: 'Начальный остаток',
                      keyboardType: TextInputType.number,
                      validator: _numberValidator,
                    ),
                    const SizedBox(height: 12),
                    _ClientTextField(
                      controller: _minQuantityController,
                      label: 'Минимальный остаток',
                      keyboardType: TextInputType.number,
                      validator: _numberValidator,
                    ),
                    const SizedBox(height: 12),
                    _ClientTextField(
                      controller: _priceController,
                      label: 'Цена продажи',
                      keyboardType: TextInputType.number,
                      validator: _numberValidator,
                    ),
                    const SizedBox(height: 12),
                    _ClientTextField(
                      controller: _costController,
                      label: 'Себестоимость',
                      keyboardType: TextInputType.number,
                      validator: _numberValidator,
                    ),
                    const SizedBox(height: 12),
                    _ClientTextField(
                      controller: _barcodeController,
                      label: 'Штрих-код',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submit,
                        child: Text(
                          widget.initialProduct == null
                              ? 'Сохранить'
                              : 'Обновить',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _CreateProductFormData(
        name: _nameController.text.trim(),
        sku: _skuController.text.trim(),
        category: _categoryController.text.trim(),
        initialQuantity: int.parse(_initialQuantityController.text.trim()),
        minQuantity: int.parse(_minQuantityController.text.trim()),
        price: int.parse(_priceController.text.trim()),
        cost: int.parse(_costController.text.trim()),
        barcode: _barcodeController.text.trim(),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Обязательное поле';
    }
    return null;
  }

  String? _numberValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Обязательное поле';
    }
    if (int.tryParse(value.trim()) == null) {
      return 'Введите число';
    }
    return null;
  }
}

class _CreateInventoryDocumentFormData {
  const _CreateInventoryDocumentFormData({
    required this.documentType,
    required this.clientId,
    required this.warehouseName,
    required this.relatedWarehouseName,
    required this.note,
    required this.lines,
  });

  final String documentType;
  final String clientId;
  final String warehouseName;
  final String relatedWarehouseName;
  final String note;
  final List<_CreateInventoryDocumentLineFormData> lines;
}

class _CreateInventoryDocumentLineFormData {
  const _CreateInventoryDocumentLineFormData({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
    required this.note,
  });

  final String productId;
  final int quantity;
  final int unitPrice;
  final int unitCost;
  final String note;
}

class _CreateInventoryDocumentSheet extends StatefulWidget {
  const _CreateInventoryDocumentSheet({
    required this.products,
    required this.clients,
  });

  final List<_Product> products;
  final List<_Client> clients;

  @override
  State<_CreateInventoryDocumentSheet> createState() =>
      _CreateInventoryDocumentSheetState();
}

class _CreateInventoryDocumentSheetState
    extends State<_CreateInventoryDocumentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _warehouseController = TextEditingController(text: 'Основной склад');
  final _relatedWarehouseController = TextEditingController();
  final _noteController = TextEditingController();
  late final List<_InventoryDocumentDraftLine> _lines;
  String _documentType = 'purchase_receipt';
  String? _clientId;

  @override
  void initState() {
    super.initState();
    _lines = [_InventoryDocumentDraftLine.fromProduct(widget.products.first)];
  }

  @override
  void dispose() {
    _warehouseController.dispose();
    _relatedWarehouseController.dispose();
    _noteController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: SizedBox(width: 48, child: Divider(thickness: 4)),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Новый складской документ',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _documentType,
                      items: const [
                        DropdownMenuItem(
                          value: 'purchase_receipt',
                          child: Text('Приход'),
                        ),
                        DropdownMenuItem(
                          value: 'write_off',
                          child: Text('Списание'),
                        ),
                        DropdownMenuItem(
                          value: 'transfer',
                          child: Text('Перемещение'),
                        ),
                        DropdownMenuItem(
                          value: 'sale_issue',
                          child: Text('Продажа'),
                        ),
                        DropdownMenuItem(
                          value: 'adjustment',
                          child: Text('Корректировка'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Тип документа',
                      ),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _documentType = value;
                            if (_documentType != 'sale_issue' &&
                                _documentType != 'purchase_receipt') {
                              _clientId = null;
                            }
                          });
                        }
                      },
                    ),
                    if (_documentType == 'sale_issue' ||
                        _documentType == 'purchase_receipt') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _clientId,
                        items: widget.clients
                            .map(
                              (client) => DropdownMenuItem<String>(
                                value: client.id,
                                child: Text(client.name),
                              ),
                            )
                            .toList(growable: false),
                        decoration: const InputDecoration(
                          labelText: 'Контрагент',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Выберите контрагента';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          setState(() {
                            _clientId = value;
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    _ClientTextField(
                      controller: _warehouseController,
                      label: 'Склад-источник',
                    ),
                    if (_documentType == 'transfer') ...[
                      const SizedBox(height: 12),
                      _ClientTextField(
                        controller: _relatedWarehouseController,
                        label: 'Склад-получатель',
                        validator: _requiredValidator,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _ClientTextField(
                      controller: _noteController,
                      label: 'Примечание',
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Строки документа',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addLine,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Строка'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._buildLineEditors(),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submit,
                        child: const Text('Провести документ'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLineEditors() {
    return List<Widget>.generate(_lines.length, (index) {
      final line = _lines[index];
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _BusinessCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Строка ${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (_lines.length > 1)
                    IconButton(
                      onPressed: () => _removeLine(index),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                ],
              ),
              DropdownButtonFormField<String>(
                initialValue: line.productId,
                items: widget.products
                    .map(
                      (product) => DropdownMenuItem(
                        value: product.id,
                        child: Text('${product.name} (${product.sku})'),
                      ),
                    )
                    .toList(growable: false),
                decoration: const InputDecoration(labelText: 'Товар'),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  final product = widget.products.firstWhere(
                    (item) => item.id == value,
                  );
                  setState(() {
                    line.productId = value;
                    line.unitPriceController.text = '${product.price}';
                    line.unitCostController.text = '${product.cost}';
                  });
                },
              ),
              const SizedBox(height: 12),
              _ClientTextField(
                controller: line.quantityController,
                label: 'Количество',
                keyboardType: TextInputType.number,
                validator: _numberValidator,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ClientTextField(
                      controller: line.unitPriceController,
                      label: 'Цена',
                      keyboardType: TextInputType.number,
                      validator: _numberValidator,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ClientTextField(
                      controller: line.unitCostController,
                      label: 'Себестоимость',
                      keyboardType: TextInputType.number,
                      validator: _numberValidator,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ClientTextField(
                controller: line.noteController,
                label: 'Комментарий к строке',
              ),
            ],
          ),
        ),
      );
    });
  }

  void _addLine() {
    setState(() {
      _lines
          .add(_InventoryDocumentDraftLine.fromProduct(widget.products.first));
    });
  }

  void _removeLine(int index) {
    final line = _lines.removeAt(index);
    line.dispose();
    setState(() {});
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _CreateInventoryDocumentFormData(
        documentType: _documentType,
        clientId: _clientId ?? '',
        warehouseName: _warehouseController.text.trim(),
        relatedWarehouseName: _relatedWarehouseController.text.trim(),
        note: _noteController.text.trim(),
        lines: _lines
            .map(
              (line) => _CreateInventoryDocumentLineFormData(
                productId: line.productId,
                quantity: int.parse(line.quantityController.text.trim()),
                unitPrice: int.parse(line.unitPriceController.text.trim()),
                unitCost: int.parse(line.unitCostController.text.trim()),
                note: line.noteController.text.trim(),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Обязательное поле';
    }
    return null;
  }

  String? _numberValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Обязательное поле';
    }
    if (int.tryParse(value.trim()) == null) {
      return 'Введите число';
    }
    return null;
  }
}

class _InventoryDocumentDraftLine {
  _InventoryDocumentDraftLine({
    required this.productId,
    required this.quantityController,
    required this.unitPriceController,
    required this.unitCostController,
    required this.noteController,
  });

  factory _InventoryDocumentDraftLine.fromProduct(_Product product) {
    return _InventoryDocumentDraftLine(
      productId: product.id,
      quantityController: TextEditingController(text: '1'),
      unitPriceController: TextEditingController(text: '${product.price}'),
      unitCostController: TextEditingController(text: '${product.cost}'),
      noteController: TextEditingController(),
    );
  }

  String productId;
  final TextEditingController quantityController;
  final TextEditingController unitPriceController;
  final TextEditingController unitCostController;
  final TextEditingController noteController;

  void dispose() {
    quantityController.dispose();
    unitPriceController.dispose();
    unitCostController.dispose();
    noteController.dispose();
  }
}

class _InventoryDocumentsSheet extends StatefulWidget {
  const _InventoryDocumentsSheet({
    required this.accessToken,
    required this.businessGateway,
    required this.documents,
  });

  final String accessToken;
  final BusinessGateway businessGateway;
  final List<_InventoryDocument> documents;

  @override
  State<_InventoryDocumentsSheet> createState() =>
      _InventoryDocumentsSheetState();
}

class _InventoryDocumentsSheetState extends State<_InventoryDocumentsSheet> {
  String _query = '';
  String _type = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.documents.where((document) {
      final matchesType = _type.isEmpty || document.documentType == _type;
      final query = _query.toLowerCase();
      final matchesQuery = query.isEmpty ||
          document.documentNo.toLowerCase().contains(query) ||
          document.clientName.toLowerCase().contains(query) ||
          document.warehouseName.toLowerCase().contains(query) ||
          document.note.toLowerCase().contains(query);
      return matchesType && matchesQuery;
    }).toList(growable: false);

    final documentTypes = widget.documents
        .map((item) => item.documentType)
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7FAF8),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            children: [
              const SizedBox(width: 48, child: Divider(thickness: 4)),
              const SizedBox(height: 12),
              const Text(
                'Складские документы',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              _SearchField(
                hintText: 'Поиск по номеру, складу, примечанию...',
                icon: Icons.search_rounded,
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChipButton(
                      label: 'Все',
                      active: _type.isEmpty,
                      activeColor: const Color(0xFF00A86B),
                      onPressed: () => setState(() => _type = ''),
                    ),
                    ...documentTypes.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _FilterChipButton(
                          label: item,
                          active: _type == item,
                          activeColor: const Color(0xFF0F766E),
                          onPressed: () => setState(() => _type = item),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'Документы не найдены',
                          style: TextStyle(color: Color(0xFF7B8794)),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final document = filtered[index];
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
                                      label: document.status,
                                      kind: StatusKind.success,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${document.documentType} • ${document.documentDate}',
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
                                        value: document.warehouseName,
                                      ),
                                    ),
                                    if (document.clientName.isNotEmpty)
                                      Expanded(
                                        child: _LabelValue(
                                          label: 'Контрагент',
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDocumentDetail(_InventoryDocument document) async {
    try {
      final payload = await widget.businessGateway.fetchInventoryDocumentDetail(
        accessToken: widget.accessToken,
        documentId: document.id,
      );
      if (!mounted) {
        return;
      }
      final detail = _inventoryDocumentDetailFromJson(payload);
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _InventoryDocumentDetailSheet(detail: detail),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }
}

class _InventoryDocumentDetailSheet extends StatelessWidget {
  const _InventoryDocumentDetailSheet({required this.detail});

  final _InventoryDocumentDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7FAF8),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 48, child: Divider(thickness: 4)),
              const SizedBox(height: 12),
              Text(
                detail.summary.documentNo,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                '${detail.summary.documentType} • ${detail.summary.documentDate}',
                style: const TextStyle(color: Color(0xFF7B8794)),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _BusinessCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: _LabelValue(
                              label: 'Склад',
                              value: detail.summary.warehouseName,
                            ),
                          ),
                          if (detail.summary.clientName.isNotEmpty)
                            Expanded(
                              child: _LabelValue(
                                label: 'Контрагент',
                                value: detail.summary.clientName,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          _LabelValue(
                            label: 'Сумма',
                            value: formatMoney(detail.summary.totalAmount),
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
                              value: '${detail.summary.productLines}',
                            ),
                          ),
                          _LabelValue(
                            label: 'Количество',
                            value: '${detail.summary.totalQuantity}',
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
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
                              const SizedBox(height: 4),
                              Text(
                                'SKU: ${line.sku}',
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
                                      label: 'Количество',
                                      value: '${line.quantity}',
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
