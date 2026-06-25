part of 'business_shell.dart';

class _ReportsScreen extends StatefulWidget {
  const _ReportsScreen({
    required this.accessToken,
    required this.businessGateway,
    required this.overview,
  });

  final String accessToken;
  final BusinessGateway businessGateway;
  final _OverviewData overview;

  @override
  State<_ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<_ReportsScreen> {
  List<_InventoryDocument> _inventoryDocuments = const [];
  List<_MoneyDocument> _moneyDocuments = const [];
  List<_ProductionOrder> _productionOrders = const [];
  List<_PayrollPeriod> _payrollPeriods = const [];
  String _period = 'month';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ReportsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accessToken != widget.accessToken ||
        oldWidget.businessGateway != widget.businessGateway) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final inventoryPayload =
          await widget.businessGateway.fetchInventoryDocuments(
        accessToken: widget.accessToken,
      );
      final moneyPayload = await widget.businessGateway.fetchMoneyDocuments(
        accessToken: widget.accessToken,
      );

      var productionPayload = const <Map<String, dynamic>>[];
      var payrollPayload = const <Map<String, dynamic>>[];
      try {
        productionPayload = await widget.businessGateway.fetchProductionOrders(
          accessToken: widget.accessToken,
        );
      } catch (_) {}
      try {
        payrollPayload = await widget.businessGateway.fetchPayrollPeriods(
          accessToken: widget.accessToken,
        );
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _inventoryDocuments =
            inventoryPayload.map(_inventoryDocumentFromJson).toList();
        _moneyDocuments = moneyPayload.map(_moneyDocumentFromJson).toList();
        _productionOrders =
            productionPayload.map(_productionOrderFromJson).toList();
        _payrollPeriods = payrollPayload.map(_payrollPeriodFromJson).toList();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  List<_InventoryDocument> get _periodInventoryDocuments => _inventoryDocuments
      .where((document) => _matchesPeriod(document.documentDate))
      .toList(growable: false);

  List<_MoneyDocument> get _periodMoneyDocuments => _moneyDocuments
      .where((document) => _matchesPeriod(document.operationDate))
      .toList(growable: false);

  List<_ProductionOrder> get _periodProductionOrders => _productionOrders
      .where((order) => _matchesPeriod(
            order.plannedDate.isEmpty ? order.createdAt : order.plannedDate,
          ))
      .toList(growable: false);

  List<_PayrollPeriod> get _periodPayrollPeriods => _payrollPeriods
      .where((period) => _matchesPayrollPeriod(period))
      .toList(growable: false);

  bool _matchesPeriod(String rawDate) {
    if (_period == 'all') return true;
    final parsed = DateTime.tryParse(
        rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate);
    if (parsed == null) return false;
    final now = DateTime.now();
    if (_period == 'month') {
      return parsed.year == now.year && parsed.month == now.month;
    }
    final currentQuarter = ((now.month - 1) ~/ 3) + 1;
    final parsedQuarter = ((parsed.month - 1) ~/ 3) + 1;
    return parsed.year == now.year && parsedQuarter == currentQuarter;
  }

  bool _matchesPayrollPeriod(_PayrollPeriod period) {
    if (_period == 'all') return true;
    final now = DateTime.now();
    if (_period == 'month') {
      return period.periodYear == now.year && period.periodMonth == now.month;
    }
    final currentQuarter = ((now.month - 1) ~/ 3) + 1;
    final periodQuarter = ((period.periodMonth - 1) ~/ 3) + 1;
    return period.periodYear == now.year && periodQuarter == currentQuarter;
  }

  int _sumInventory(String type) => _periodInventoryDocuments
      .where((document) => document.documentType == type)
      .fold(0, (sum, document) => sum + document.totalAmount);

  int _sumInventoryQuantity(String type) => _periodInventoryDocuments
      .where((document) => document.documentType == type)
      .fold(0, (sum, document) => sum + document.totalQuantity);

  int _sumMoneyRemaining(String type) => _periodMoneyDocuments
      .where((document) => document.documentType == type)
      .fold(0, (sum, document) => sum + document.remainingAmount);

  int _sumPayrollNet(Iterable<_PayrollPeriod> periods) =>
      periods.fold(0, (sum, period) => sum + period.totalNet);

  String _signedMoney(int value) {
    if (value == 0) return formatMoney(0);
    final sign = value > 0 ? '+' : '-';
    return '$sign${formatMoney(value.abs())}';
  }

  @override
  Widget build(BuildContext context) {
    final inventoryDocuments = _periodInventoryDocuments;
    final productionOrders = _periodProductionOrders;
    final payrollPeriods = _periodPayrollPeriods;
    final completedProduction =
        productionOrders.where((order) => order.status == 'completed').length;
    final activeProduction = productionOrders
        .where(
            (order) => order.status == 'draft' || order.status == 'in_progress')
        .length;
    final lowStock = widget.overview.products
        .where((product) => product.quantity <= product.minQuantity)
        .length;
    final payrollDue = _sumPayrollNet(
      payrollPeriods.where(
        (period) => period.status != 'paid' && period.status != 'cancelled',
      ),
    );
    final payrollPaid = _sumPayrollNet(
      payrollPeriods.where((period) => period.status == 'paid'),
    );
    final netFlow = widget.overview.finance.income -
        widget.overview.finance.expense -
        payrollPaid;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
        children: [
          _ReportsHeader(
            period: _period,
            onPeriodChanged: (value) => setState(() => _period = value),
            onRefresh: _load,
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _ReportNotice(
              icon: Icons.cloud_off_rounded,
              title: 'Не удалось загрузить отчеты',
              message: _error!,
            )
          else ...[
            _ReportLinkCard(
              icon: Icons.inventory_2_rounded,
              title: 'Остатки на складах',
              subtitle: 'Текущие остатки и себестоимость · PDF / Excel',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _StockReportScreen(
                      accessToken: widget.accessToken,
                      businessGateway: widget.businessGateway,
                      companyName: widget.overview.companyName,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _ReportLinkCard(
              icon: Icons.swap_vert_rounded,
              title: 'Оборотная ведомость',
              subtitle: 'Движение товаров за период · PDF / Excel',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _TurnoverReportScreen(
                      accessToken: widget.accessToken,
                      businessGateway: widget.businessGateway,
                      companyName: widget.overview.companyName,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _ReportLinkCard(
              icon: Icons.account_balance_rounded,
              title: 'Финансовая сводка',
              subtitle: 'Деньги, долги, товары, зарплата за период · PDF / Excel',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _FinancialReportScreen(
                      accessToken: widget.accessToken,
                      businessGateway: widget.businessGateway,
                      companyName: widget.overview.companyName,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _ReportLinkCard(
              icon: Icons.handshake_rounded,
              title: 'Акт сверки с контрагентом',
              subtitle: 'Все движения по контрагенту за период · PDF / Excel',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _CounterpartyReportScreen(
                      accessToken: widget.accessToken,
                      businessGateway: widget.businessGateway,
                      companyName: widget.overview.companyName,
                      clients: widget.overview.clients,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            _ReportSection(
              title: 'Торговля',
              children: [
                _ReportMetricCard(
                  title: 'Продажи',
                  value: formatMoney(_sumInventory('sale_issue')),
                  icon: Icons.trending_up_rounded,
                  color: const Color(0xFF16A34A),
                ),
                _ReportMetricCard(
                  title: 'Закупки',
                  value: formatMoney(_sumInventory('purchase_receipt')),
                  icon: Icons.shopping_cart_checkout_rounded,
                  color: const Color(0xFF2563EB),
                ),
                _ReportMetricCard(
                  title: 'Дебиторка',
                  value: formatMoney(_sumMoneyRemaining('sale_receivable')),
                  icon: Icons.call_received_rounded,
                  color: const Color(0xFFF59E0B),
                ),
                _ReportMetricCard(
                  title: 'Кредиторка',
                  value: formatMoney(_sumMoneyRemaining('purchase_payable')),
                  icon: Icons.call_made_rounded,
                  color: const Color(0xFFEF4444),
                ),
              ],
            ),
            _ReportSection(
              title: 'Склад',
              children: [
                _ReportMetricCard(
                  title: 'Товаров',
                  value: '${widget.overview.products.length}',
                  icon: Icons.inventory_2_rounded,
                  color: const Color(0xFF0EA5E9),
                ),
                _ReportMetricCard(
                  title: 'Низкий остаток',
                  value: '$lowStock',
                  icon: Icons.warning_amber_rounded,
                  color: const Color(0xFFF59E0B),
                ),
                _ReportMetricCard(
                  title: 'Документы',
                  value: '${inventoryDocuments.length}',
                  icon: Icons.description_rounded,
                  color: const Color(0xFF64748B),
                ),
                _ReportMetricCard(
                  title: 'Выпуск, шт',
                  value: '${_sumInventoryQuantity('production_in')}',
                  icon: Icons.precision_manufacturing_rounded,
                  color: const Color(0xFF7C3AED),
                ),
              ],
            ),
            _ReportSection(
              title: 'Производство',
              children: [
                _ReportMetricCard(
                  title: 'Завершено',
                  value: '$completedProduction',
                  icon: Icons.task_alt_rounded,
                  color: const Color(0xFF16A34A),
                ),
                _ReportMetricCard(
                  title: 'В работе',
                  value: '$activeProduction',
                  icon: Icons.timelapse_rounded,
                  color: const Color(0xFF2563EB),
                ),
                _ReportMetricCard(
                  title: 'Списано сырья',
                  value: '${_sumInventoryQuantity('production_out')}',
                  icon: Icons.remove_circle_outline_rounded,
                  color: const Color(0xFFEF4444),
                ),
                _ReportMetricCard(
                  title: 'Стоимость выпуска',
                  value: formatMoney(_sumInventory('production_in')),
                  icon: Icons.attach_money_rounded,
                  color: const Color(0xFF7C3AED),
                ),
              ],
            ),
            _ReportSection(
              title: 'Деньги и зарплата',
              children: [
                _ReportMetricCard(
                  title: 'Деньги',
                  value: formatMoney(widget.overview.finance.totalBalance),
                  icon: Icons.account_balance_wallet_rounded,
                  color: const Color(0xFF0F766E),
                ),
                _ReportMetricCard(
                  title: 'Поток',
                  value: _signedMoney(netFlow),
                  icon: Icons.swap_vert_rounded,
                  color: netFlow >= 0
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFEF4444),
                ),
                _ReportMetricCard(
                  title: 'К выплате',
                  value: formatMoney(payrollDue),
                  icon: Icons.payments_rounded,
                  color: const Color(0xFFF59E0B),
                ),
                _ReportMetricCard(
                  title: 'Выплачено',
                  value: formatMoney(payrollPaid),
                  icon: Icons.done_all_rounded,
                  color: const Color(0xFF16A34A),
                ),
              ],
            ),
            if (inventoryDocuments.isEmpty &&
                productionOrders.isEmpty &&
                payrollPeriods.isEmpty)
              const _ReportNotice(
                icon: Icons.insights_rounded,
                title: 'Данных пока нет',
                message:
                    'Создайте продажу, закупку, заказ производства или ведомость.',
              ),
          ],
        ],
      ),
    );
  }
}

class _ReportsHeader extends StatelessWidget {
  const _ReportsHeader({
    required this.period,
    required this.onPeriodChanged,
    required this.onRefresh,
  });

  final String period;
  final ValueChanged<String> onPeriodChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Отчеты',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Сводка MVP',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          initialValue: period,
          onSelected: onPeriodChanged,
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'month', child: Text('Месяц')),
            PopupMenuItem(value: 'quarter', child: Text('Квартал')),
            PopupMenuItem(value: 'all', child: Text('Все время')),
          ],
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
                Text(
                  switch (period) {
                    'quarter' => 'Квартал',
                    'all' => 'Все',
                    _ => 'Месяц',
                  },
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.expand_more_rounded, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 12.0;
              final columns = constraints.maxWidth >= 720 ? 2 : 1;
              final width = columns == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - spacing) / 2;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: children
                    .map((child) => SizedBox(width: width, child: child))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReportMetricCard extends StatelessWidget {
  const _ReportMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 132),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(height: 24),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportNotice extends StatelessWidget {
  const _ReportNotice({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF64748B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
