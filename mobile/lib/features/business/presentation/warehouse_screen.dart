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

class _WarehouseScreenState extends State<_WarehouseScreen>
    with SingleTickerProviderStateMixin {
  String _stockQuery = '';
  String _movementQuery = '';
  late final TabController _tabController;
  List<_Warehouse> _warehouses = const [];
  _Warehouse? _selectedWarehouse;
  List<_WarehouseStockItem> _stockItems = const [];
  List<_WarehouseMovement> _movements = const [];
  bool _isLoadingWarehouseData = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadWarehouses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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

  Future<void> openCreateWarehouse() async {
    if (_isSubmitting) {
      return;
    }
    await _showCreateWarehouseSheet();
  }

  Future<void> _loadWarehouses() async {
    setState(() {
      _isLoadingWarehouseData = true;
    });

    try {
      final payload = await widget.businessGateway.fetchWarehouses(
        accessToken: widget.accessToken,
      );
      final warehouses = payload
          .map(_warehouseFromJson)
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
      final selected = warehouses.firstWhere(
        (item) => item.id == _selectedWarehouse?.id,
        orElse: () => warehouses.isNotEmpty
            ? warehouses.first
            : const _Warehouse(id: '', name: '', code: '', isDefault: false),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _warehouses = warehouses;
        _selectedWarehouse = selected.id.isEmpty ? null : selected;
      });
      await _reloadWarehouseSection();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingWarehouseData = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _reloadWarehouseSection() async {
    final warehouse = _selectedWarehouse;
    if (warehouse == null) {
      if (mounted) {
        setState(() {
          _stockItems = const [];
          _movements = const [];
          _isLoadingWarehouseData = false;
        });
      }
      return;
    }

    setState(() {
      _isLoadingWarehouseData = true;
    });

    try {
      final stockPayload = await widget.businessGateway.fetchWarehouseStock(
        accessToken: widget.accessToken,
        warehouseId: warehouse.id,
        search: _stockQuery,
      );
      final movementPayload =
          await widget.businessGateway.fetchWarehouseMovements(
        accessToken: widget.accessToken,
        warehouseId: warehouse.id,
        search: _movementQuery,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _stockItems = stockPayload
            .map(_warehouseStockItemFromJson)
            .toList(growable: false);
        _movements = movementPayload
            .map(_warehouseMovementFromJson)
            .toList(growable: false);
        _isLoadingWarehouseData = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingWarehouseData = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _GradientHeader(
            title: 'Склад',
            subtitle: '${_warehouses.length} '
                '${_warehouses.length == 1 ? 'склад' : _warehouses.length < 5 ? 'склада' : 'складов'}',
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xCCFFFFFF),
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
              tabs: const [
                Tab(text: 'Остатки'),
                Tab(text: 'Движения'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    title: 'Позиций',
                    value: '${_stockItems.length}',
                    tone: const Color(0x14F59E0B),
                    accent: const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    title: 'Движений',
                    value: '${_movements.length}',
                    tone: const Color(0x14EF4444),
                    accent: const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: DropdownButtonFormField<String>(
              key: ValueKey(_selectedWarehouse?.id ?? 'none'),
              initialValue: _selectedWarehouse?.id,
              decoration: const InputDecoration(
                labelText: 'Выбрать склад',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
              items: _warehouses
                  .map(
                    (w) => DropdownMenuItem<String>(
                      value: w.id,
                      child: Text(w.name),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) async {
                final warehouse =
                    _warehouses.where((w) => w.id == value).firstOrNull;
                if (warehouse == null) return;
                setState(() => _selectedWarehouse = warehouse);
                await _reloadWarehouseSection();
              },
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildWarehouseStockSection(),
                _buildWarehouseMovementsSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarehouseStockSection() {
    if (_isLoadingWarehouseData) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        _SearchField(
          hintText: 'Поиск товара по названию или SKU...',
          icon: Icons.search_rounded,
          onChanged: (value) {
            _stockQuery = value;
            _reloadWarehouseSection();
          },
        ),
        const SizedBox(height: 12),
        if (_stockItems.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'В этом складе пока нет остатков',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
          )
        else
          ..._stockItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0x1400A86B),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.inventory_2_rounded,
                        color: Color(0xFF00A86B),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'SKU: ${item.sku}${item.category.isEmpty ? '' : ' · ${item.category}'}',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${item.available} ${item.unitName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        _StatusBadge(
                          label: item.statusLabel,
                          kind: item.status == ProductStatus.outOfStock
                              ? StatusKind.error
                              : item.status == ProductStatus.lowStock
                                  ? StatusKind.warning
                                  : StatusKind.success,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWarehouseMovementsSection() {
    if (_isLoadingWarehouseData) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        _SearchField(
          hintText: 'Поиск по документу, товару или SKU...',
          icon: Icons.search_rounded,
          onChanged: (value) {
            _movementQuery = value;
            _reloadWarehouseSection();
          },
        ),
        const SizedBox(height: 12),
        if (_movements.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Движений по этому складу пока нет',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
          )
        else
          ..._movements.map(
            (movement) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => _openDocumentById(movement.documentId),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: movement.isIncome
                          ? const Color(0x3322C55E)
                          : const Color(0x33EF4444),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: movement.isIncome
                              ? const Color(0x1422C55E)
                              : const Color(0x14EF4444),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          movement.isIncome
                              ? Icons.south_west_rounded
                              : Icons.north_east_rounded,
                          color: movement.isIncome
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              movement.productName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${movement.documentNo} · ${movement.documentDate}',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
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
                            '${movement.quantity > 0 ? '+' : ''}${movement.quantity}',
                            style: TextStyle(
                              color: movement.isIncome
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFDC2626),
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ост: ${movement.balanceAfter}',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
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
        'product_type': result.productType,
        'unit_name': result.unitName,
        'allowed_to_sell': result.allowedToSell,
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
      await _reloadWarehouseSection();
      if (!mounted) {
        return;
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
    final result = await showModalBottomSheet<_CreateInventoryDocumentFormData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateInventoryDocumentSheet(
        accessToken: widget.accessToken,
        businessGateway: widget.businessGateway,
        products: widget.products,
        clients: widget.clients,
        initialWarehouseName: _selectedWarehouse?.name ?? 'Основной склад',
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
                  'service_id': line.serviceId,
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
      await _reloadWarehouseSection();
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

  Future<void> _showCreateWarehouseSheet() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final created = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child:
                            SizedBox(width: 48, child: Divider(thickness: 4)),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Новый склад',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ClientTextField(
                        controller: controller,
                        label: 'Название склада',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Введите название';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            if (!formKey.currentState!.validate()) {
                              return;
                            }
                            Navigator.of(context).pop(controller.text.trim());
                          },
                          child: const Text('Сохранить'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    controller.dispose();

    if (created == null || created.isEmpty) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });
    try {
      await widget.businessGateway.createWarehouse(
        accessToken: widget.accessToken,
        payload: {'name': created},
      );
      await _loadWarehouses();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Склад добавлен')),
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

  Future<void> _openDocumentById(String documentId) async {
    try {
      final payload = await widget.businessGateway.fetchInventoryDocumentDetail(
        accessToken: widget.accessToken,
        documentId: documentId,
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

class _CreateProductFormData {
  const _CreateProductFormData({
    required this.name,
    required this.sku,
    required this.category,
    required this.productType,
    required this.unitName,
    required this.allowedToSell,
    required this.initialQuantity,
    required this.minQuantity,
    required this.price,
    required this.cost,
    required this.barcode,
  });

  final String name;
  final String sku;
  final String category;
  final String productType;
  final String unitName;
  final bool allowedToSell;
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
  static const _productTypes = [
    ('consumer_goods', 'ТНП — товары народного потребления'),
    ('raw_material', 'Сырье'),
    ('finished_product', 'ГП — готовый продукт'),
  ];

  static const _unitOptions = [
    'шт',
    'кг',
    'г',
    'л',
    'мл',
    'м',
    'м²',
    'упак',
    'т',
    'ящ',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _categoryController = TextEditingController();
  final _unitNameController = TextEditingController();
  final _initialQuantityController = TextEditingController();
  final _minQuantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _barcodeController = TextEditingController();

  String _productType = 'consumer_goods';
  bool _allowedToSell = true;

  @override
  void initState() {
    super.initState();
    final product = widget.initialProduct;
    if (product == null) {
      _unitNameController.text = 'шт';
      return;
    }

    _nameController.text = product.name;
    _skuController.text = product.sku;
    _categoryController.text = product.category;
    _unitNameController.text =
        product.unitName.isEmpty ? 'шт' : product.unitName;
    _initialQuantityController.text = '${product.quantity}';
    _minQuantityController.text = '${product.minQuantity}';
    _priceController.text = '${product.price}';
    _costController.text = '${product.cost}';
    _barcodeController.text = product.barcode;
    _productType =
        product.productType.isEmpty ? 'consumer_goods' : product.productType;
    _allowedToSell = product.allowedToSell;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _categoryController.dispose();
    _unitNameController.dispose();
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
                    DropdownButtonFormField<String>(
                      initialValue: _productType,
                      decoration: InputDecoration(
                        labelText: 'Тип товара',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: _productTypes
                          .map(
                            (t) => DropdownMenuItem(
                              value: t.$1,
                              child: Text(t.$2),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _productType = v ?? 'consumer_goods'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ClientTextField(
                            controller: _unitNameController,
                            label: 'Ед. измерения *',
                            validator: _requiredValidator,
                          ),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          icon:
                              const Icon(Icons.arrow_drop_down_circle_outlined),
                          tooltip: 'Выбрать',
                          onSelected: (v) => setState(
                            () => _unitNameController.text = v,
                          ),
                          itemBuilder: (_) => _unitOptions
                              .map(
                                (u) => PopupMenuItem(value: u, child: Text(u)),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile.adaptive(
                      value: _allowedToSell,
                      onChanged: (v) => setState(() => _allowedToSell = v),
                      title: const Text(
                        'Разрешено к продаже',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      activeThumbColor: const Color(0xFF00A86B),
                      activeTrackColor: const Color(0x4400A86B),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 4),
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
        productType: _productType,
        unitName: _unitNameController.text.trim().isEmpty
            ? 'шт'
            : _unitNameController.text.trim(),
        allowedToSell: _allowedToSell,
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
    required this.serviceId,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
    required this.note,
  });

  final String productId;
  final String serviceId;
  final int quantity;
  final int unitPrice;
  final int unitCost;
  final String note;
}

class _CreateInventoryDocumentSheet extends StatefulWidget {
  const _CreateInventoryDocumentSheet({
    required this.accessToken,
    required this.businessGateway,
    required this.products,
    required this.clients,
    this.initialDocumentType = 'purchase_receipt',
    this.initialClientId,
    this.initialWarehouseName = 'Основной склад',
  });

  final String accessToken;
  final BusinessGateway businessGateway;
  final List<_Product> products;
  final List<_Client> clients;
  final String initialDocumentType;
  final String? initialClientId;
  final String initialWarehouseName;

  @override
  State<_CreateInventoryDocumentSheet> createState() =>
      _CreateInventoryDocumentSheetState();
}

class _CreateInventoryDocumentSheetState
    extends State<_CreateInventoryDocumentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _warehouseController;
  final _relatedWarehouseController = TextEditingController();
  final _noteController = TextEditingController();
  late final List<_InventoryDocumentDraftLine> _lines;
  late String _documentType;
  String? _clientId;
  List<_Service> _services = [];

  @override
  void initState() {
    super.initState();
    _warehouseController =
        TextEditingController(text: widget.initialWarehouseName);
    _documentType = widget.initialDocumentType;
    _clientId = widget.initialClientId;
    _lines = [
      widget.products.isNotEmpty
          ? _InventoryDocumentDraftLine.fromProduct(widget.products.first)
          : _InventoryDocumentDraftLine.empty(),
    ];
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      final raw = await widget.businessGateway.fetchServices(
        accessToken: widget.accessToken,
      );
      if (!mounted) return;
      setState(() {
        _services = raw.map(_serviceFromJson).toList(growable: false);
      });
    } catch (_) {}
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
      final isService = line.lineType == 'service';
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
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'product', label: Text('Товар')),
                  ButtonSegment(value: 'service', label: Text('Услуга')),
                ],
                selected: {line.lineType},
                onSelectionChanged: (selection) {
                  setState(() {
                    line.lineType = selection.first;
                    line.productId = '';
                    line.serviceId = '';
                    line.unitPriceController.text = '0';
                    line.unitCostController.text = '0';
                  });
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(height: 8),
              if (!isService)
                DropdownButtonFormField<String>(
                  key: ValueKey('product_${line.productId}_$index'),
                  initialValue: line.productId.isEmpty ? null : line.productId,
                  items: widget.products
                      .map(
                        (product) => DropdownMenuItem(
                          value: product.id,
                          child: Text('${product.name} (${product.sku})'),
                        ),
                      )
                      .toList(growable: false),
                  decoration: const InputDecoration(labelText: 'Товар'),
                  validator: (value) {
                    if (!isService && (value == null || value.isEmpty)) {
                      return 'Выберите товар';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    if (value == null) return;
                    final product = widget.products.firstWhere(
                      (item) => item.id == value,
                    );
                    setState(() {
                      line.productId = value;
                      line.unitPriceController.text = '${product.price}';
                      line.unitCostController.text = '${product.cost}';
                    });
                  },
                )
              else
                DropdownButtonFormField<String>(
                  key: ValueKey('service_${line.serviceId}_$index'),
                  initialValue: line.serviceId.isEmpty ? null : line.serviceId,
                  items: _services
                      .map(
                        (svc) => DropdownMenuItem(
                          value: svc.id,
                          child: Text(svc.name),
                        ),
                      )
                      .toList(growable: false),
                  decoration: const InputDecoration(labelText: 'Услуга'),
                  validator: (value) {
                    if (isService && (value == null || value.isEmpty)) {
                      return 'Выберите услугу';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    if (value == null) return;
                    final svc = _services.firstWhere((s) => s.id == value);
                    setState(() {
                      line.serviceId = value;
                      line.unitPriceController.text =
                          '${svc.price.truncate()}';
                      line.unitCostController.text = '0';
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
      _lines.add(
        widget.products.isNotEmpty
            ? _InventoryDocumentDraftLine.fromProduct(widget.products.first)
            : _InventoryDocumentDraftLine.empty(),
      );
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
                productId: line.lineType == 'product' ? line.productId : '',
                serviceId: line.lineType == 'service' ? line.serviceId : '',
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
    required this.lineType,
    required this.productId,
    required this.serviceId,
    required this.quantityController,
    required this.unitPriceController,
    required this.unitCostController,
    required this.noteController,
  });

  factory _InventoryDocumentDraftLine.fromProduct(_Product product) {
    return _InventoryDocumentDraftLine(
      lineType: 'product',
      productId: product.id,
      serviceId: '',
      quantityController: TextEditingController(text: '1'),
      unitPriceController: TextEditingController(text: '${product.price}'),
      unitCostController: TextEditingController(text: '${product.cost}'),
      noteController: TextEditingController(),
    );
  }

  factory _InventoryDocumentDraftLine.empty() {
    return _InventoryDocumentDraftLine(
      lineType: 'product',
      productId: '',
      serviceId: '',
      quantityController: TextEditingController(text: '1'),
      unitPriceController: TextEditingController(text: '0'),
      unitCostController: TextEditingController(text: '0'),
      noteController: TextEditingController(),
    );
  }

  String lineType;
  String productId;
  String serviceId;
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
