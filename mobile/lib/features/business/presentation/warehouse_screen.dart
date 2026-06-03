part of 'business_shell.dart';

class _WarehouseScreen extends StatefulWidget {
  const _WarehouseScreen({required this.products});

  final List<_Product> products;

  @override
  State<_WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<_WarehouseScreen> {
  String _query = '';
  WarehouseFilter _filter = WarehouseFilter.all;
  _Product? _selectedProduct;

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
                      value:
                          '${(((product.price - product.cost) / product.cost) * 100).toStringAsFixed(1)}%',
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
                            product.barcode,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const Text(
                            'EAN-13',
                            style: TextStyle(
                              color: Color(0xFF7B8794),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Показать QR-код'),
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
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                    ),
                    onPressed: () {},
                    child: const Text('Приход'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                    ),
                    onPressed: () {},
                    child: const Text('Расход'),
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
                                'SKU: ${product.sku} • ${product.category}',
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
}
