part of 'business_shell.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Top-level screen widget
// ─────────────────────────────────────────────────────────────────────────────

class _ProductionScreen extends StatefulWidget {
  const _ProductionScreen({
    required this.accessToken,
    required this.products,
    required this.businessGateway,
  });

  final String accessToken;
  final List<_Product> products;
  final BusinessGateway businessGateway;

  @override
  State<_ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<_ProductionScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<_Recipe> _recipes = [];
  List<_ProductionOrder> _orders = [];
  List<_Service> _services = [];
  List<_Warehouse> _warehouses = [];
  List<_Employee> _employees = [];

  bool _isLoading = true;
  String? _loadError;
  bool _isFabExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        widget.businessGateway.fetchRecipes(accessToken: widget.accessToken),
        widget.businessGateway
            .fetchProductionOrders(accessToken: widget.accessToken),
        widget.businessGateway.fetchServices(accessToken: widget.accessToken),
        widget.businessGateway.fetchWarehouses(accessToken: widget.accessToken),
        widget.businessGateway.fetchEmployees(accessToken: widget.accessToken),
      ]);
      if (!mounted) return;
      setState(() {
        _recipes = results[0].map(_recipeFromJson).toList();
        _orders = results[1].map(_productionOrderFromJson).toList();
        _services = results[2].map(_serviceFromJson).toList();
        _warehouses = results[3].map(_warehouseFromJson).toList();
        _employees = results[4].map(_employeeFromJson).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = '$e';
        _isLoading = false;
      });
    }
  }

  void _dismissFab() {
    if (_isFabExpanded) setState(() => _isFabExpanded = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(_loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    final fabActions = _tabController.index == 0
        ? _recipeFabActions
        : _orderFabActions;

    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              _GradientHeader(
                title: 'Производство',
                subtitle: _subtitleForTab(),
                child: TabBar(
                  controller: _tabController,
                  onTap: (_) => _dismissFab(),
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xCCFFFFFF),
                  indicator: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [
                    Tab(text: 'Рецепты'),
                    Tab(text: 'Производство'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _RecipesTab(
                      recipes: _recipes,
                      products: widget.products,
                      services: _services,
                      onChanged: _loadData,
                      accessToken: widget.accessToken,
                      gateway: widget.businessGateway,
                    ),
                    _OrdersTab(
                      orders: _orders,
                      recipes: _recipes,
                      warehouses: _warehouses,
                      onChanged: _loadData,
                      accessToken: widget.accessToken,
                      gateway: widget.businessGateway,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 90,
          child: _FabMenu(
            expanded: _isFabExpanded,
            actions: fabActions,
            onToggle: () => setState(() => _isFabExpanded = !_isFabExpanded),
            onActionSelected: _handleFabAction,
          ),
        ),
      ],
    );
  }

  String _subtitleForTab() {
    if (_tabController.index == 1) {
      return _pluralOrders(_orders.length);
    }
    return _pluralRecipes(_recipes.length);
  }

  static const _recipeFabActions = [
    _FabMenuAction(
      id: 'recipe_add',
      label: 'Новый рецепт',
      icon: Icons.menu_book_rounded,
      color: Color(0xFF7C3AED),
    ),
  ];

  static const _orderFabActions = [
    _FabMenuAction(
      id: 'order_add',
      label: 'Новый заказ',
      icon: Icons.precision_manufacturing_rounded,
      color: Color(0xFF00A86B),
    ),
  ];

  Future<void> _handleFabAction(_FabMenuAction action) async {
    setState(() => _isFabExpanded = false);
    switch (action.id) {
      case 'recipe_add':
        await _showRecipeSheet();
      case 'order_add':
        await _showOrderSheet();
    }
  }

  Future<void> _showRecipeSheet({_Recipe? initialRecipe}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecipeSheet(
        initialRecipe: initialRecipe,
        products: widget.products,
        services: _services,
        accessToken: widget.accessToken,
        gateway: widget.businessGateway,
        onSaved: _loadData,
      ),
    );
  }

  Future<void> _showOrderSheet({_ProductionOrder? initialOrder}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderSheet(
        initialOrder: initialOrder,
        recipes: _recipes,
        warehouses: _warehouses,
        employees: _employees,
        accessToken: widget.accessToken,
        gateway: widget.businessGateway,
        onSaved: _loadData,
      ),
    );
  }

  static String _pluralRecipes(int n) {
    if (n % 100 >= 11 && n % 100 <= 19) return '$n рецептов';
    switch (n % 10) {
      case 1:
        return '$n рецепт';
      case 2:
      case 3:
      case 4:
        return '$n рецепта';
      default:
        return '$n рецептов';
    }
  }

  static String _pluralOrders(int n) {
    if (n % 100 >= 11 && n % 100 <= 19) return '$n заказов';
    switch (n % 10) {
      case 1:
        return '$n заказ';
      case 2:
      case 3:
      case 4:
        return '$n заказа';
      default:
        return '$n заказов';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recipes tab
// ─────────────────────────────────────────────────────────────────────────────

class _RecipesTab extends StatelessWidget {
  const _RecipesTab({
    required this.recipes,
    required this.products,
    required this.services,
    required this.accessToken,
    required this.gateway,
    required this.onChanged,
  });

  final List<_Recipe> recipes;
  final List<_Product> products;
  final List<_Service> services;
  final String accessToken;
  final BusinessGateway gateway;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_outlined, size: 56, color: Color(0xFFCBD5E1)),
            SizedBox(height: 12),
            Text('Рецептов пока нет',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16)),
            SizedBox(height: 4),
            Text('Нажмите + чтобы создать рецепт',
                style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: recipes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => _RecipeTile(
        recipe: recipes[i],
        products: products,
        services: services,
        accessToken: accessToken,
        gateway: gateway,
        onChanged: onChanged,
      ),
    );
  }
}

class _RecipeTile extends StatelessWidget {
  const _RecipeTile({
    required this.recipe,
    required this.products,
    required this.services,
    required this.accessToken,
    required this.gateway,
    required this.onChanged,
  });

  final _Recipe recipe;
  final List<_Product> products;
  final List<_Service> services;
  final String accessToken;
  final BusinessGateway gateway;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return _BusinessCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0x1A7C3AED),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.menu_book_rounded,
                    color: Color(0xFF7C3AED), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recipe.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    if (recipe.description.isNotEmpty)
                      Text(recipe.description,
                          style: const TextStyle(
                              color: Color(0xFF64748B), fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: Color(0xFF3B82F6), size: 20),
                onPressed: () => _edit(context),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFEF4444), size: 20),
                onPressed: () => _delete(context),
              ),
            ],
          ),
          if (recipe.ingredients.isNotEmpty || recipe.services.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            const Text('Компоненты',
                style:
                    TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            const SizedBox(height: 6),
            ...recipe.ingredients.map(
              (ing) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined,
                        size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(ing.productName,
                            style: const TextStyle(fontSize: 13))),
                    Text(
                        '${_formatQty(ing.quantity)} ${ing.unitName}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151))),
                  ],
                ),
              ),
            ),
            ...recipe.services.map(
              (svc) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.build_circle_outlined,
                        size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(svc.serviceName,
                            style: const TextStyle(fontSize: 13))),
                    Text('×${_formatQty(svc.quantity)}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151))),
                  ],
                ),
              ),
            ),
          ],
          if (recipe.outputs.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            const Text('Выход продукции',
                style:
                    TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            const SizedBox(height: 6),
            ...recipe.outputs.map(
              (out) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded,
                        size: 14, color: Color(0xFF00A86B)),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(out.productName,
                            style: const TextStyle(fontSize: 13))),
                    Text(
                        '${_formatQty(out.quantity)} ${out.unitName}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF00A86B))),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _edit(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecipeSheet(
        initialRecipe: recipe,
        products: products,
        services: services,
        accessToken: accessToken,
        gateway: gateway,
        onSaved: onChanged,
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить рецепт?'),
        content: Text('«${recipe.name}» будет удалён без возможности восстановления.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await gateway.deleteRecipe(
          accessToken: accessToken, recipeId: recipe.id);
      onChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Orders tab
// ─────────────────────────────────────────────────────────────────────────────

class _OrdersTab extends StatelessWidget {
  const _OrdersTab({
    required this.orders,
    required this.recipes,
    required this.warehouses,
    required this.accessToken,
    required this.gateway,
    required this.onChanged,
  });

  final List<_ProductionOrder> orders;
  final List<_Recipe> recipes;
  final List<_Warehouse> warehouses;
  final String accessToken;
  final BusinessGateway gateway;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.precision_manufacturing_outlined,
                size: 56, color: Color(0xFFCBD5E1)),
            SizedBox(height: 12),
            Text('Производственных заказов пока нет',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16)),
            SizedBox(height: 4),
            Text('Нажмите + чтобы создать заказ',
                style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => _OrderTile(
        order: orders[i],
        recipes: recipes,
        warehouses: warehouses,
        accessToken: accessToken,
        gateway: gateway,
        onChanged: onChanged,
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({
    required this.order,
    required this.recipes,
    required this.warehouses,
    required this.accessToken,
    required this.gateway,
    required this.onChanged,
  });

  final _ProductionOrder order;
  final List<_Recipe> recipes;
  final List<_Warehouse> warehouses;
  final String accessToken;
  final BusinessGateway gateway;
  final VoidCallback onChanged;

  static const _statusColors = {
    'draft': Color(0xFF64748B),
    'in_progress': Color(0xFF3B82F6),
    'completed': Color(0xFF00A86B),
    'cancelled': Color(0xFFEF4444),
  };

  Color get _statusColor =>
      _statusColors[order.status] ?? const Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return _BusinessCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.precision_manufacturing_rounded,
                    color: _statusColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.documentNo,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    if (order.recipeName.isNotEmpty)
                      Text(order.recipeName,
                          style: const TextStyle(
                              color: Color(0xFF64748B), fontSize: 12)),
                  ],
                ),
              ),
              _StatusBadge(label: order.statusLabel, kind: order.statusKind),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _LabelValue(
                  label: 'Сырьё со склада',
                  value: order.sourceWarehouseName.isEmpty
                      ? '—'
                      : order.sourceWarehouseName,
                ),
              ),
              Expanded(
                child: _LabelValue(
                  label: 'Выход на склад',
                  value: order.outputWarehouseName.isEmpty
                      ? '—'
                      : order.outputWarehouseName,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (order.batchNumber.isNotEmpty)
                Expanded(
                  child: _LabelValue(
                      label: 'Партия', value: order.batchNumber),
                ),
              if (order.responsibleEmployee.isNotEmpty)
                Expanded(
                  child: _LabelValue(
                    label: 'Сотрудник',
                    value: order.responsibleEmployee,
                    textAlign: order.batchNumber.isNotEmpty
                        ? TextAlign.right
                        : TextAlign.start,
                  ),
                ),
            ],
          ),
          if (order.status != 'completed' && order.status != 'cancelled') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (order.status == 'draft')
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          _changeStatus(context, 'in_progress'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF3B82F6)),
                      child: const Text('В работу'),
                    ),
                  ),
                if (order.status == 'in_progress') ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _changeStatus(context, 'cancelled'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444)),
                      child: const Text('Отменить'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _changeStatus(context, 'completed'),
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF00A86B)),
                      child: const Text('Завершить'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _changeStatus(BuildContext context, String newStatus) async {
    try {
      await gateway.updateProductionOrderStatus(
        accessToken: accessToken,
        orderId: order.id,
        status: newStatus,
      );
      onChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recipe bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _RecipeSheet extends StatefulWidget {
  const _RecipeSheet({
    this.initialRecipe,
    required this.products,
    required this.services,
    required this.accessToken,
    required this.gateway,
    required this.onSaved,
  });

  final _Recipe? initialRecipe;
  final List<_Product> products;
  final List<_Service> services;
  final String accessToken;
  final BusinessGateway gateway;
  final VoidCallback onSaved;

  @override
  State<_RecipeSheet> createState() => _RecipeSheetState();
}

class _RecipeSheetState extends State<_RecipeSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;

  final List<_MutableIngredient> _ingredients = [];
  final List<_MutableRecipeService> _svcLines = [];
  final List<_MutableOutput> _outputs = [];

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final r = widget.initialRecipe;
    _nameCtrl = TextEditingController(text: r?.name ?? '');
    _descCtrl = TextEditingController(text: r?.description ?? '');
    if (r != null) {
      _ingredients.addAll(r.ingredients.map((i) => _MutableIngredient(
            productId: i.productId,
            productName: i.productName,
            qty: i.quantity,
            unit: i.unitName,
          )));
      _svcLines.addAll(r.services.map((s) => _MutableRecipeService(
            serviceId: s.serviceId,
            serviceName: s.serviceName,
            qty: s.quantity,
          )));
      _outputs.addAll(r.outputs.map((o) => _MutableOutput(
            productId: o.productId,
            productName: o.productName,
            qty: o.quantity,
            unit: o.unitName,
          )));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Введите название рецепта')));
      return;
    }
    if (_outputs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Добавьте хотя бы один выход продукции')));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final payload = {
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'ingredients': _ingredients
            .map((i) => {
                  'product_id': i.productId,
                  'quantity': i.qty,
                  'unit_name': i.unit,
                })
            .toList(),
        'services': _svcLines
            .map((s) => {'service_id': s.serviceId, 'quantity': s.qty})
            .toList(),
        'outputs': _outputs
            .map((o) => {
                  'product_id': o.productId,
                  'quantity': o.qty,
                  'unit_name': o.unit,
                })
            .toList(),
      };
      final recipe = widget.initialRecipe;
      if (recipe == null) {
        await widget.gateway
            .createRecipe(accessToken: widget.accessToken, payload: payload);
      } else {
        await widget.gateway.updateRecipe(
            accessToken: widget.accessToken,
            recipeId: recipe.id,
            payload: payload);
      }
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
    final isEditing = widget.initialRecipe != null;
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
            _SheetDragHandle(
                title: isEditing ? 'Редактировать рецепт' : 'Новый рецепт'),
            Expanded(
              child: ListView(
                controller: controller,
                padding: EdgeInsets.fromLTRB(
                    16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 96),
                children: [
                  const _SectionLabel(label: 'Название'),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: _inputDecoration('Название рецепта'),
                  ),
                  const SizedBox(height: 12),
                  const _SectionLabel(label: 'Описание'),
                  TextFormField(
                    controller: _descCtrl,
                    decoration: _inputDecoration('Необязательное описание'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                  const _SectionLabel(label: 'Входящие товары'),
                  ..._ingredients.asMap().entries.map(
                    (e) => _IngredientRow(
                      item: e.value,
                      products: widget.products,
                      onChanged: () => setState(() {}),
                      onRemove: () =>
                          setState(() => _ingredients.removeAt(e.key)),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(
                        () => _ingredients.add(_MutableIngredient())),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Добавить товар'),
                  ),
                  if (widget.services.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const _SectionLabel(label: 'Входящие услуги'),
                    ..._svcLines.asMap().entries.map(
                      (e) => _ServiceRow(
                        item: e.value,
                        services: widget.services,
                        onChanged: () => setState(() {}),
                        onRemove: () =>
                            setState(() => _svcLines.removeAt(e.key)),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(
                          () => _svcLines.add(_MutableRecipeService())),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Добавить услугу'),
                    ),
                  ],
                  const SizedBox(height: 8),
                  const _SectionLabel(label: 'Выход готовой продукции *'),
                  ..._outputs.asMap().entries.map(
                    (e) => _OutputRow(
                      item: e.value,
                      products: widget.products,
                      onChanged: () => setState(() {}),
                      onRemove: () =>
                          setState(() => _outputs.removeAt(e.key)),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _outputs.add(_MutableOutput())),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Добавить продукт'),
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
                      : Text(isEditing ? 'Сохранить' : 'Создать рецепт'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Order bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _OrderSheet extends StatefulWidget {
  const _OrderSheet({
    this.initialOrder,
    required this.recipes,
    required this.warehouses,
    required this.employees,
    required this.accessToken,
    required this.gateway,
    required this.onSaved,
  });

  final _ProductionOrder? initialOrder;
  final List<_Recipe> recipes;
  final List<_Warehouse> warehouses;
  final List<_Employee> employees;
  final String accessToken;
  final BusinessGateway gateway;
  final VoidCallback onSaved;

  @override
  State<_OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends State<_OrderSheet> {
  late final TextEditingController _docNoCtrl;
  late final TextEditingController _batchCtrl;
  late final TextEditingController _employeeCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _dateCtrl;

  String? _selectedRecipeId;
  String? _selectedSourceWarehouseId;
  String? _selectedOutputWarehouseId;
  final List<_MutableParticipant> _participants = [];

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final o = widget.initialOrder;
    _docNoCtrl = TextEditingController(text: o?.documentNo ?? '');
    _batchCtrl = TextEditingController(text: o?.batchNumber ?? '');
    _employeeCtrl =
        TextEditingController(text: o?.responsibleEmployee ?? '');
    _notesCtrl = TextEditingController(text: o?.notes ?? '');
    _qtyCtrl = TextEditingController(
        text: o == null ? '1' : _formatQty(o.plannedQuantity));
    _dateCtrl = TextEditingController(text: o?.plannedDate ?? '');
    _selectedRecipeId = o?.recipeId.isEmpty == true ? null : o?.recipeId;
    _selectedSourceWarehouseId =
        o?.sourceWarehouseId.isEmpty == true ? null : o?.sourceWarehouseId;
    _selectedOutputWarehouseId =
        o?.outputWarehouseId.isEmpty == true ? null : o?.outputWarehouseId;
    if (o != null) {
      _participants.addAll(o.participants.map((p) => _MutableParticipant(
            employeeId: p.employeeId,
            share: p.sharePercent,
          )));
    }
  }

  double get _totalShare =>
      _participants.fold(0.0, (sum, p) => sum + p.share);

  @override
  void dispose() {
    _docNoCtrl.dispose();
    _batchCtrl.dispose();
    _employeeCtrl.dispose();
    _notesCtrl.dispose();
    _qtyCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedRecipeId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Выберите рецепт')));
      return;
    }
    if (_selectedSourceWarehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Выберите склад сырья')));
      return;
    }
    if (_selectedOutputWarehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Выберите склад выхода продукции')));
      return;
    }
    final filledParticipants =
        _participants.where((p) => p.employeeId.isNotEmpty).toList();
    if (filledParticipants.isNotEmpty &&
        (_totalShare - 100).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Доли участников должны давать 100%')));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final qty = double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ?? 1.0;
      final payload = {
        'document_no': _docNoCtrl.text.trim(),
        'recipe_id': _selectedRecipeId,
        'source_warehouse_id': _selectedSourceWarehouseId,
        'output_warehouse_id': _selectedOutputWarehouseId,
        'batch_number': _batchCtrl.text.trim(),
        'responsible_employee': _employeeCtrl.text.trim(),
        'planned_quantity': qty,
        'planned_date': _dateCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
        'participants': filledParticipants
            .map((p) => {
                  'employee_id': p.employeeId,
                  'share_percent': p.share,
                })
            .toList(),
      };
      await widget.gateway.createProductionOrder(
          accessToken: widget.accessToken, payload: payload);
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
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF7FAF8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const _SheetDragHandle(title: 'Новый производственный заказ'),
            Expanded(
              child: ListView(
                controller: controller,
                padding: EdgeInsets.fromLTRB(
                    16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 96),
                children: [
                  const _SectionLabel(label: 'Рецепт *'),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_selectedRecipeId),
                    initialValue: _selectedRecipeId,
                    decoration: _inputDecoration('Выберите рецепт'),
                    items: widget.recipes
                        .map((r) => DropdownMenuItem(
                              value: r.id,
                              child: Text(r.name),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedRecipeId = v),
                  ),
                  const SizedBox(height: 12),
                  const _SectionLabel(label: 'Склад сырья *'),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_selectedSourceWarehouseId),
                    initialValue: _selectedSourceWarehouseId,
                    decoration: _inputDecoration('Откуда брать материалы'),
                    items: widget.warehouses
                        .map((w) => DropdownMenuItem(
                              value: w.id,
                              child: Text(w.name),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedSourceWarehouseId = v),
                  ),
                  const SizedBox(height: 12),
                  const _SectionLabel(label: 'Склад готовой продукции *'),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_selectedOutputWarehouseId),
                    initialValue: _selectedOutputWarehouseId,
                    decoration: _inputDecoration('Куда помещать продукцию'),
                    items: widget.warehouses
                        .map((w) => DropdownMenuItem(
                              value: w.id,
                              child: Text(w.name),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedOutputWarehouseId = v),
                  ),
                  const SizedBox(height: 12),
                  const _SectionLabel(label: 'Количество партий'),
                  TextFormField(
                    controller: _qtyCtrl,
                    decoration: _inputDecoration('1'),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                  ),
                  const SizedBox(height: 12),
                  const _SectionLabel(label: 'Номер партии'),
                  TextFormField(
                    controller: _batchCtrl,
                    decoration: _inputDecoration('Например: BATCH-001'),
                  ),
                  const SizedBox(height: 12),
                  const _SectionLabel(label: 'Ответственный сотрудник'),
                  TextFormField(
                    controller: _employeeCtrl,
                    decoration: _inputDecoration('ФИО'),
                  ),
                  const SizedBox(height: 12),
                  const _SectionLabel(label: 'Плановая дата'),
                  TextFormField(
                    controller: _dateCtrl,
                    decoration: _inputDecoration('ГГГГ-ММ-ДД'),
                    keyboardType: TextInputType.datetime,
                  ),
                  const SizedBox(height: 12),
                  const _SectionLabel(label: 'Номер документа'),
                  TextFormField(
                    controller: _docNoCtrl,
                    decoration: _inputDecoration(
                        'Оставьте пустым для автогенерации'),
                  ),
                  const SizedBox(height: 12),
                  const _SectionLabel(label: 'Примечания'),
                  TextFormField(
                    controller: _notesCtrl,
                    decoration: _inputDecoration('Необязательно'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Участники производства',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                      if (_participants.isNotEmpty)
                        Text('Σ ${_formatQty(_totalShare)}%',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: (_totalShare - 100).abs() < 0.01
                                    ? const Color(0xFF00A86B)
                                    : const Color(0xFFEF4444))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Сумма за рецепт делится между участниками по долям (в сумме 100%). Долю получает каждый из списка.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  if (widget.employees.isEmpty)
                    const Text('Сначала добавьте сотрудников в разделе «Зарплата».',
                        style:
                            TextStyle(color: Color(0xFFEF4444), fontSize: 12))
                  else ...[
                    ..._participants.asMap().entries.map(
                          (e) => _ParticipantRow(
                            item: e.value,
                            employees: widget.employees,
                            onChanged: () => setState(() {}),
                            onRemove: () =>
                                setState(() => _participants.removeAt(e.key)),
                          ),
                        ),
                    TextButton.icon(
                      onPressed: () => setState(
                          () => _participants.add(_MutableParticipant())),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Добавить участника'),
                    ),
                  ],
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
                      : const Text('Создать заказ'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mutable helpers for recipe sheet rows
// ─────────────────────────────────────────────────────────────────────────────

class _MutableIngredient {
  _MutableIngredient({
    this.productId = '',
    this.productName = '',
    this.qty = 1.0,
    this.unit = 'шт',
  });
  String productId;
  String productName;
  double qty;
  String unit;
}

class _MutableRecipeService {
  _MutableRecipeService({
    this.serviceId = '',
    this.serviceName = '',
    this.qty = 1.0,
  });
  String serviceId;
  String serviceName;
  double qty;
}

class _MutableOutput {
  _MutableOutput({
    this.productId = '',
    this.productName = '',
    this.qty = 1.0,
    this.unit = 'шт',
  });
  String productId;
  String productName;
  double qty;
  String unit;
}

class _MutableParticipant {
  _MutableParticipant({
    this.employeeId = '',
    this.share = 0.0,
  });
  String employeeId;
  double share;
}

// ─────────────────────────────────────────────────────────────────────────────
// Row widgets for recipe sheet
// ─────────────────────────────────────────────────────────────────────────────

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.item,
    required this.products,
    required this.onChanged,
    required this.onRemove,
  });

  final _MutableIngredient item;
  final List<_Product> products;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              key: ValueKey(item.productId),
              initialValue: item.productId.isEmpty ? null : item.productId,
              decoration: _inputDecoration('Товар'),
              items: products
                  .map((p) =>
                      DropdownMenuItem(value: p.id, child: Text(p.name)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                final p = products.firstWhere((p) => p.id == v);
                item.productId = v;
                item.productName = p.name;
                item.unit = p.unitName;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: TextFormField(
              initialValue: _formatQty(item.qty),
              decoration: _inputDecoration('Кол-во'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) {
                item.qty = double.tryParse(v.replaceAll(',', '.')) ?? 1.0;
              },
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded,
                color: Color(0xFFEF4444), size: 20),
          ),
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.item,
    required this.services,
    required this.onChanged,
    required this.onRemove,
  });

  final _MutableRecipeService item;
  final List<_Service> services;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              key: ValueKey(item.serviceId),
              initialValue: item.serviceId.isEmpty ? null : item.serviceId,
              decoration: _inputDecoration('Услуга'),
              items: services
                  .map((s) =>
                      DropdownMenuItem(value: s.id, child: Text(s.name)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                final s = services.firstWhere((s) => s.id == v);
                item.serviceId = v;
                item.serviceName = s.name;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: TextFormField(
              initialValue: _formatQty(item.qty),
              decoration: _inputDecoration('Кол-во'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) {
                item.qty = double.tryParse(v.replaceAll(',', '.')) ?? 1.0;
              },
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded,
                color: Color(0xFFEF4444), size: 20),
          ),
        ],
      ),
    );
  }
}

class _OutputRow extends StatelessWidget {
  const _OutputRow({
    required this.item,
    required this.products,
    required this.onChanged,
    required this.onRemove,
  });

  final _MutableOutput item;
  final List<_Product> products;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              key: ValueKey(item.productId),
              initialValue: item.productId.isEmpty ? null : item.productId,
              decoration: _inputDecoration('Готовый продукт'),
              items: products
                  .map((p) =>
                      DropdownMenuItem(value: p.id, child: Text(p.name)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                final p = products.firstWhere((p) => p.id == v);
                item.productId = v;
                item.productName = p.name;
                item.unit = p.unitName;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: TextFormField(
              initialValue: _formatQty(item.qty),
              decoration: _inputDecoration('Кол-во'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) {
                item.qty = double.tryParse(v.replaceAll(',', '.')) ?? 1.0;
              },
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded,
                color: Color(0xFFEF4444), size: 20),
          ),
        ],
      ),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.item,
    required this.employees,
    required this.onChanged,
    required this.onRemove,
  });

  final _MutableParticipant item;
  final List<_Employee> employees;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              key: ValueKey(item.employeeId),
              initialValue: item.employeeId.isEmpty ? null : item.employeeId,
              decoration: _inputDecoration('Сотрудник'),
              isExpanded: true,
              items: employees
                  .map((e) => DropdownMenuItem(
                        value: e.id,
                        child: Text(e.fullName,
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                item.employeeId = v;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: TextFormField(
              initialValue: item.share == 0 ? '' : _formatQty(item.share),
              decoration: _inputDecoration('%'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) {
                item.share = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                onChanged();
              },
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded,
                color: Color(0xFFEF4444), size: 20),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(label,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B))),
    );
  }
}

InputDecoration _inputDecoration(String hint) => InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF00A86B), width: 1.5),
      ),
    );

String _formatQty(double v) =>
    v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
