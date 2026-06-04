part of 'business_shell.dart';

class _CatalogScreen extends StatefulWidget {
  const _CatalogScreen({
    required this.accessToken,
    required this.products,
    required this.businessGateway,
    required this.onProductsChanged,
  });

  final String accessToken;
  final List<_Product> products;
  final BusinessGateway businessGateway;
  final Future<void> Function() onProductsChanged;

  @override
  State<_CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<_CatalogScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _GradientHeader(
            title: 'Справочник',
            subtitle: null,
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
                Tab(text: 'Товары'),
                Tab(text: 'Услуги'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _CatalogProductsTab(
                  accessToken: widget.accessToken,
                  products: widget.products,
                  businessGateway: widget.businessGateway,
                  onProductsChanged: widget.onProductsChanged,
                ),
                _CatalogServicesTab(
                  accessToken: widget.accessToken,
                  products: widget.products,
                  businessGateway: widget.businessGateway,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Products Tab ─────────────────────────────────────────────────────────────

class _CatalogProductsTab extends StatelessWidget {
  const _CatalogProductsTab({
    required this.accessToken,
    required this.products,
    required this.businessGateway,
    required this.onProductsChanged,
  });

  final String accessToken;
  final List<_Product> products;
  final BusinessGateway businessGateway;
  final Future<void> Function() onProductsChanged;

  Map<String, dynamic> _toPayload(_CreateProductFormData r) => {
        'name': r.name,
        'sku': r.sku,
        'category': r.category,
        'product_type': r.productType,
        'unit_name': r.unitName,
        'allowed_to_sell': r.allowedToSell,
        'initial_quantity': r.initialQuantity,
        'min_quantity': r.minQuantity,
        'price': r.price,
        'cost': r.cost,
        'barcode': r.barcode,
      };

  Future<void> _openCreateProduct(BuildContext context) async {
    final result = await showModalBottomSheet<_CreateProductFormData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateProductSheet(),
    );
    if (result == null) return;
    try {
      await businessGateway.createProduct(
        accessToken: accessToken,
        payload: _toPayload(result),
      );
      await onProductsChanged();
    } catch (_) {}
  }

  Future<void> _openEditProduct(BuildContext context, _Product product) async {
    final result = await showModalBottomSheet<_CreateProductFormData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateProductSheet(initialProduct: product),
    );
    if (result == null) return;
    try {
      await businessGateway.updateProduct(
        accessToken: accessToken,
        productId: product.id,
        payload: _toPayload(result),
      );
      await onProductsChanged();
    } catch (_) {}
  }

  Future<void> _deleteProduct(BuildContext context, _Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить товар?'),
        content: Text('«${product.name}» будет архивирован.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await businessGateway.deleteProduct(
        accessToken: accessToken,
        productId: product.id,
      );
      await onProductsChanged();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        products.isEmpty
            ? const Center(
                child: Text(
                  'Нет товаров в справочнике',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _CatalogProductTile(
                  product: products[i],
                  onEdit: () => _openEditProduct(context, products[i]),
                  onDelete: () => _deleteProduct(context, products[i]),
                ),
              ),
        Positioned(
          right: 16,
          bottom: 90,
          child: FloatingActionButton(
            heroTag: 'catalog_product_fab',
            backgroundColor: const Color(0xFF00A86B),
            onPressed: () => _openCreateProduct(context),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _CatalogProductTile extends StatelessWidget {
  const _CatalogProductTile({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  final _Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
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
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _CatalogBadge(
                      label: product.productTypeLabel,
                      color: const Color(0xFF3B82F6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      product.unitName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    if (!product.allowedToSell) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.block_rounded,
                        size: 12,
                        color: Color(0xFFEF4444),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatMoney(product.price),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF00A86B),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: const Color(0xFF3B82F6),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    color: const Color(0xFFEF4444),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Services Tab ─────────────────────────────────────────────────────────────

class _CatalogServicesTab extends StatefulWidget {
  const _CatalogServicesTab({
    required this.accessToken,
    required this.products,
    required this.businessGateway,
  });

  final String accessToken;
  final List<_Product> products;
  final BusinessGateway businessGateway;

  @override
  State<_CatalogServicesTab> createState() => _CatalogServicesTabState();
}

class _CatalogServicesTabState extends State<_CatalogServicesTab> {
  List<_Service> _services = [];
  bool _isLoading = true;
  String? _error;

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
      final raw = await widget.businessGateway.fetchServices(
        accessToken: widget.accessToken,
      );
      if (!mounted) return;
      setState(() {
        _services = raw.map(_serviceFromJson).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openCreateService() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateServiceSheet(products: widget.products),
    );
    if (result == null) return;
    try {
      await widget.businessGateway.createService(
        accessToken: widget.accessToken,
        payload: result,
      );
      await _load();
    } catch (_) {}
  }

  Future<void> _openEditService(_Service service) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateServiceSheet(
        products: widget.products,
        initialService: service,
      ),
    );
    if (result == null) return;
    try {
      await widget.businessGateway.updateService(
        accessToken: widget.accessToken,
        serviceId: service.id,
        payload: result,
      );
      await _load();
    } catch (_) {}
  }

  Future<void> _deleteService(_Service service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить услугу?'),
        content: Text('«${service.name}» будет архивирована.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.businessGateway.deleteService(
        accessToken: widget.accessToken,
        serviceId: service.id,
      );
      await _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        _services.isEmpty
            ? const Center(
                child: Text(
                  'Нет услуг в справочнике',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: _services.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _ServiceTile(
                  service: _services[i],
                  onEdit: () => _openEditService(_services[i]),
                  onDelete: () => _deleteService(_services[i]),
                ),
              ),
        Positioned(
          right: 16,
          bottom: 90,
          child: FloatingActionButton(
            heroTag: 'catalog_service_fab',
            backgroundColor: const Color(0xFF00A86B),
            onPressed: _openCreateService,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.service,
    required this.onEdit,
    required this.onDelete,
  });

  final _Service service;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0x14F59E0B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.handyman_rounded,
                  color: Color(0xFFF59E0B),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (service.description.isNotEmpty)
                      Text(
                        service.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₸ ${service.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF00A86B),
                    ),
                  ),
                  if (service.estimatedCost > 0)
                    Text(
                      'с/с ₸ ${service.estimatedCost.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: const Color(0xFF3B82F6),
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: const Color(0xFFEF4444),
                onPressed: onDelete,
              ),
            ],
          ),
          if (service.materials.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Text(
              'Состав (${service.materials.length}):',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 4),
            ...service.materials.take(3).map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        _CatalogBadge(
                          label: m.typeLabel,
                          color: const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            m.displayName,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '×${m.quantity % 1 == 0 ? m.quantity.toInt() : m.quantity}  ₸${m.cost.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            if (service.materials.length > 3)
              Text(
                '+ ещё ${service.materials.length - 3}...',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
          ],
        ],
      ),
    );
  }
}

// ─── Create Service Sheet ─────────────────────────────────────────────────────

class _CreateServiceSheet extends StatefulWidget {
  const _CreateServiceSheet({required this.products, this.initialService});

  final List<_Product> products;
  final _Service? initialService;

  @override
  State<_CreateServiceSheet> createState() => _CreateServiceSheetState();
}

class _CreateServiceSheetState extends State<_CreateServiceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController(text: '0');
  bool _allowedToSell = true;
  final List<_ServiceMaterialDraft> _materials = [];

  @override
  void initState() {
    super.initState();
    final svc = widget.initialService;
    if (svc == null) return;
    _nameController.text = svc.name;
    _descController.text = svc.description;
    _priceController.text = svc.price.toStringAsFixed(0);
    _allowedToSell = svc.allowedToSell;
    for (final m in svc.materials) {
      final draft = _ServiceMaterialDraft()
        ..materialType = m.materialType
        ..productId = m.productId
        ..productName = m.productName
        ..externalName = m.externalServiceName
        ..quantity = m.quantity
        ..cost = m.cost;
      _materials.add(draft);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _addMaterial() {
    setState(() {
      _materials.add(_ServiceMaterialDraft());
    });
  }

  void _removeMaterial(int index) {
    setState(() => _materials.removeAt(index));
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final matPayload = _materials.map((m) => m.toJson()).toList();
    Navigator.of(context).pop({
      'name': _nameController.text.trim(),
      'description': _descController.text.trim(),
      'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
      'allowed_to_sell': _allowedToSell,
      'materials': matPayload,
    });
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
                      widget.initialService == null
                          ? 'Новая услуга'
                          : 'Редактировать услугу',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ClientTextField(
                      controller: _nameController,
                      label: 'Название *',
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Обязательное поле'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _ClientTextField(
                      controller: _descController,
                      label: 'Описание',
                    ),
                    const SizedBox(height: 12),
                    _ClientTextField(
                      controller: _priceController,
                      label: 'Цена услуги',
                      keyboardType: TextInputType.number,
                    ),
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          'Компоненты',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _addMaterial,
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          label: const Text('Добавить'),
                        ),
                      ],
                    ),
                    if (_materials.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ..._materials.asMap().entries.map(
                            (entry) => _MaterialRow(
                              key: ValueKey(entry.key),
                              draft: entry.value,
                              products: widget.products,
                              onRemove: () => _removeMaterial(entry.key),
                              onChanged: () => setState(() {}),
                            ),
                          ),
                    ],
                    const SizedBox(height: 20),
                    if (_materials.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Себестоимость:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              '₸ ${_materials.fold(0.0, (s, m) => s + m.cost * m.quantity).toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submit,
                        child: const Text('Сохранить'),
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
}

class _ServiceMaterialDraft {
  String materialType = 'external_service';
  String productId = '';
  String productName = '';
  String externalName = '';
  double quantity = 1.0;
  double cost = 0.0;

  Map<String, dynamic> toJson() => {
        'material_type': materialType,
        if (materialType == 'product') 'product_id': productId,
        if (materialType == 'external_service')
          'external_service_name': externalName,
        'quantity': quantity,
        'cost': cost,
      };
}

class _MaterialRow extends StatefulWidget {
  const _MaterialRow({
    super.key,
    required this.draft,
    required this.products,
    required this.onRemove,
    required this.onChanged,
  });

  final _ServiceMaterialDraft draft;
  final List<_Product> products;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  State<_MaterialRow> createState() => _MaterialRowState();
}

class _MaterialRowState extends State<_MaterialRow> {
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _costController = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.draft.externalName;
    _qtyController.text = widget.draft.quantity.toStringAsFixed(
      widget.draft.quantity % 1 == 0 ? 0 : 2,
    );
    _costController.text = widget.draft.cost.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: widget.draft.materialType,
                  decoration: InputDecoration(
                    labelText: 'Тип',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'product',
                      child: Text('Товар'),
                    ),
                    DropdownMenuItem(
                      value: 'external_service',
                      child: Text('Внешняя услуга'),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() {
                      widget.draft.materialType = v ?? 'external_service';
                    });
                    widget.onChanged();
                  },
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.remove_circle_outline_rounded,
                  color: Color(0xFFEF4444),
                ),
                onPressed: widget.onRemove,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.draft.materialType == 'product')
            DropdownButtonFormField<String>(
              initialValue: widget.draft.productId.isEmpty
                  ? null
                  : widget.draft.productId,
              hint: const Text('Выберите товар'),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
              items: widget.products
                  .map(
                    (p) => DropdownMenuItem(
                      value: p.id,
                      child: Text(p.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                final p = widget.products.firstWhere(
                  (x) => x.id == v,
                  orElse: () => widget.products.first,
                );
                setState(() {
                  widget.draft.productId = v ?? '';
                  widget.draft.productName = p.name;
                  widget.draft.cost = p.cost.toDouble();
                  _costController.text = '${p.cost}';
                });
                widget.onChanged();
              },
            )
          else
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Название услуги/работы',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
              onChanged: (v) {
                widget.draft.externalName = v;
                widget.onChanged();
              },
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qtyController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Кол-во',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    widget.draft.quantity = double.tryParse(v) ?? 1.0;
                    widget.onChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _costController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Стоимость (₸)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    widget.draft.cost = double.tryParse(v) ?? 0.0;
                    widget.onChanged();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Badge helper ─────────────────────────────────────────────────────────────

class _CatalogBadge extends StatelessWidget {
  const _CatalogBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
