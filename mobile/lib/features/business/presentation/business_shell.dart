import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:saas_uchet_mobile/features/auth/domain/auth_gateway.dart';
import 'package:saas_uchet_mobile/features/auth/domain/auth_session.dart';
import 'package:saas_uchet_mobile/features/auth/domain/company_profile.dart';
import 'package:saas_uchet_mobile/features/auth/domain/user_profile.dart';
import 'package:saas_uchet_mobile/features/business/domain/business_gateway.dart';
import 'package:saas_uchet_mobile/features/business/presentation/profile_editor_screen.dart';

class BusinessShell extends StatefulWidget {
  const BusinessShell({
    super.key,
    required this.authGateway,
    required this.businessGateway,
    required this.session,
    required this.onLogout,
    required this.onSessionChanged,
    required this.onAccountDeleted,
  });

  final AuthGateway authGateway;
  final BusinessGateway businessGateway;
  final AuthSession session;
  final VoidCallback onLogout;
  final ValueChanged<AuthSession> onSessionChanged;
  final VoidCallback onAccountDeleted;
  @override
  State<BusinessShell> createState() => _BusinessShellState();
}

class _BusinessShellState extends State<BusinessShell> {
  BusinessTab _activeTab = BusinessTab.dashboard;
  bool _isFabExpanded = false;
  late AuthSession _session;
  _OverviewData? _overview;
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _loadOverview();
  }

  @override
  void didUpdateWidget(covariant BusinessShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      _session = widget.session;
      _loadOverview();
    }
  }

  void _handleSessionChanged(AuthSession session) {
    setState(() {
      _session = session;
    });
    widget.onSessionChanged(session);
  }

  Future<void> _loadOverview() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final payload = await widget.businessGateway.fetchOverview(
        accessToken: _session.accessToken,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _overview = _OverviewData.fromJson(payload, _session.user);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openProfileEditor() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProfileEditorScreen(
          authGateway: widget.authGateway,
          session: _session,
          onLogout: widget.onLogout,
          onSessionChanged: _handleSessionChanged,
          onAccountDeleted: widget.onAccountDeleted,
        ),
      ),
    );
    _loadOverview();
  }

  @override
  Widget build(BuildContext context) {
    final showFab = _activeTab != BusinessTab.more;
    final overview = _overview;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_loadError != null || overview == null)
            Center(
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
                    const Text(
                      'Не удалось загрузить бизнес-данные',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _loadError ?? 'Попробуйте обновить позже.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _loadOverview,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            )
          else
            IndexedStack(
              index: _activeTab.index,
              children: [
                _DashboardScreen(session: _session, overview: overview),
                _CrmScreen(clients: overview.clients),
                _WarehouseScreen(products: overview.products),
                _FinanceScreen(finance: overview.finance),
                _MoreScreen(
                  session: _session,
                  overview: overview,
                  onLogout: widget.onLogout,
                  onOpenProfile: _openProfileEditor,
                ),
              ],
            ),
          if (showFab)
            Positioned(
              right: 16,
              bottom: 90,
              child: _FabMenu(
                expanded: _isFabExpanded,
                onToggle: () {
                  setState(() {
                    _isFabExpanded = !_isFabExpanded;
                  });
                },
                onActionSelected: (action) {
                  setState(() {
                    _isFabExpanded = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Действие "$action" пока в разработке'),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      bottomNavigationBar: _BottomNavBar(
        activeTab: _activeTab,
        onTabSelected: (tab) {
          setState(() {
            _activeTab = tab;
            _isFabExpanded = false;
          });
        },
      ),
    );
  }
}

class OnboardingFlowScreen extends StatefulWidget {
  const OnboardingFlowScreen({
    super.key,
    required this.onComplete,
  });

  final VoidCallback onComplete;

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  int _currentIndex = 0;

  final List<_OnboardingSlide> _slides = const [
    _OnboardingSlide(
      icon: Icons.trending_up_rounded,
      title: 'Управляйте продажами',
      description:
          'Полный контроль над продажами, заказами и складом в одном приложении.',
      color: Color(0xFF00A86B),
    ),
    _OnboardingSlide(
      icon: Icons.groups_rounded,
      title: 'CRM и клиенты',
      description:
          'Управляйте клиентами, сделками и задачами. Увеличивайте продажи.',
      color: Color(0xFF3B82F6),
    ),
    _OnboardingSlide(
      icon: Icons.bar_chart_rounded,
      title: 'Аналитика в реальном времени',
      description:
          'Следите за показателями бизнеса и принимайте решения на основе данных.',
      color: Color(0xFF22C55E),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentIndex];
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF3FBF7),
              Color(0xFFF5FAFF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: slide.color,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x2200A86B),
                              blurRadius: 28,
                              offset: Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Icon(
                          slide.icon,
                          size: 88,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        slide.title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF102A23),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        slide.description,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF52606D),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _slides.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 8,
                            width: index == _currentIndex ? 28 : 8,
                            decoration: BoxDecoration(
                              color: index == _currentIndex
                                  ? const Color(0xFF00A86B)
                                  : const Color(0xFFD9E2EC),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_currentIndex < _slides.length - 1) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _currentIndex += 1;
                        });
                      },
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Далее'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: widget.onComplete,
                      child: const Text('Пропустить'),
                    ),
                  ),
                ] else
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: widget.onComplete,
                      child: const Text('Начать работу'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardScreen extends StatelessWidget {
  const _DashboardScreen({
    required this.session,
    required this.overview,
  });

  final AuthSession session;
  final _OverviewData overview;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _GradientHeader(
            title: overview.companyName,
            subtitle: 'Добро пожаловать',
            trailing: _CircleInitials(
              text: overview.initials,
              size: 52,
              foregroundColor: Colors.white,
              backgroundColor: const Color(0x33FFFFFF),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Общая выручка за месяц',
                  style: TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  overview.dashboard.monthlyRevenue,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.arrow_upward_rounded,
                      color: Color(0xFF9AE6B4),
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      overview.dashboard.revenueChange,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'vs прошлый месяц',
                      style: TextStyle(color: Color(0xB3FFFFFF)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            child: Column(
              children: [
                Transform.translate(
                  offset: const Offset(0, -18),
                  child: GridView.count(
                    crossAxisCount: 2,
                    childAspectRatio: 1.28,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: overview.dashboard.kpis
                        .map(
                          (kpi) => _KpiCard(
                            title: kpi.title,
                            value: kpi.value,
                            change: kpi.change,
                            changeColor: toneColor(kpi.changeTone),
                            icon: iconFor(kpi.icon),
                            iconBackground: toneColor(kpi.iconTone),
                          ),
                        )
                        .toList(),
                  ),
                ),
                _BusinessCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader(
                        title: 'График продаж',
                        actionLabel: 'Подробнее',
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 190,
                        child:
                            _SalesChart(points: overview.dashboard.salesSeries),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _BusinessCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader(title: 'Последние действия'),
                      const SizedBox(height: 14),
                      ...overview.recentActivities.map(
                        (activity) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _ActivityRow(activity: activity),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CrmScreen extends StatefulWidget {
  const _CrmScreen({required this.clients});

  final List<_Client> clients;

  @override
  State<_CrmScreen> createState() => _CrmScreenState();
}

class _CrmScreenState extends State<_CrmScreen> {
  String _query = '';
  _Client? _selectedClient;

  @override
  Widget build(BuildContext context) {
    final clients = widget.clients.where((client) {
      final query = _query.toLowerCase();
      return client.name.toLowerCase().contains(query) ||
          client.contact.toLowerCase().contains(query);
    }).toList();

    final vipCount =
        widget.clients.where((client) => client.segment == 'VIP').length;
    final debtorCount =
        widget.clients.where((client) => client.debt > 0).length;

    if (_selectedClient != null) {
      final client = _selectedClient!;
      return SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _selectedClient = null),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Назад'),
            ),
            const SizedBox(height: 8),
            _BusinessCard(
              background: const LinearGradient(
                colors: [Color(0xFF00A86B), Color(0xFF008F5B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
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
                              client.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              client.binOrIinLabel,
                              style: const TextStyle(color: Color(0xCCFFFFFF)),
                            ),
                          ],
                        ),
                      ),
                      _StatusBadge(
                        label: client.segment,
                        kind: client.segment == 'VIP'
                            ? StatusKind.warning
                            : StatusKind.neutral,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _HeroStat(
                        label: 'Общие продажи',
                        value: formatMoney(client.totalSales),
                      ),
                      const SizedBox(width: 16),
                      _HeroStat(
                        label: 'Задолженность',
                        value: formatMoney(client.debt),
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
                    'Контактная информация',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  _InfoTile(
                    icon: Icons.person_rounded,
                    label: 'Контактное лицо',
                    value: client.contact,
                  ),
                  _InfoTile(
                    icon: Icons.phone_rounded,
                    label: 'Телефон',
                    value: client.phone,
                  ),
                  _InfoTile(
                    icon: Icons.mail_rounded,
                    label: 'Email',
                    value: client.email,
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
                    'История взаимодействий',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  ...client.interactions.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(top: 6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF00A86B),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
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
                                const SizedBox(height: 2),
                                Text(
                                  item.note,
                                  style: const TextStyle(
                                    color: Color(0xFF7B8794),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
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
                    onPressed: () {},
                    child: const Text('Создать сделку'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Text('Позвонить'),
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
            'CRM',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SearchField(
                  hintText: 'Поиск клиентов...',
                  icon: Icons.search_rounded,
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              const SizedBox(width: 10),
              _SquareIconButton(icon: Icons.tune_rounded, onPressed: () {}),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Всего клиентов',
                  value: '${widget.clients.length}',
                  tone: const Color(0x1400A86B),
                  accent: const Color(0xFF00A86B),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  title: 'VIP клиенты',
                  value: '$vipCount',
                  tone: const Color(0x1422C55E),
                  accent: const Color(0xFF22C55E),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  title: 'Должники',
                  value: '$debtorCount',
                  tone: const Color(0x14F59E0B),
                  accent: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...clients.map(
            (client) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _BusinessCard(
                onTap: () => setState(() => _selectedClient = client),
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
                                client.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                client.contact,
                                style: const TextStyle(
                                  color: Color(0xFF7B8794),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _StatusBadge(
                          label: client.segment,
                          kind: client.debt > 0
                              ? StatusKind.warning
                              : StatusKind.success,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_rounded,
                          size: 14,
                          color: Color(0xFF7B8794),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          client.phone,
                          style: const TextStyle(
                            color: Color(0xFF7B8794),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _LabelValue(
                            label: 'Продажи',
                            value: formatMoney(client.totalSales),
                          ),
                        ),
                        if (client.debt > 0)
                          _LabelValue(
                            label: 'Долг',
                            value: formatMoney(client.debt),
                            valueColor: const Color(0xFFD97706),
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

class _FinanceScreen extends StatefulWidget {
  const _FinanceScreen({required this.finance});

  final _FinanceOverview finance;

  @override
  State<_FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<_FinanceScreen> {
  FinancePeriod _period = FinancePeriod.month;

  @override
  Widget build(BuildContext context) {
    final totalBalance = widget.finance.totalBalance;
    final income = widget.finance.income;
    final expense = widget.finance.expense;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _GradientHeader(
            title: 'Финансы',
            subtitle: null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Общий баланс',
                  style: TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  formatMoney(totalBalance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _FinanceHeroMetric(
                      icon: Icons.arrow_upward_rounded,
                      iconColor: const Color(0xFF9AE6B4),
                      label: 'Доходы',
                      value: formatMoney(income),
                    ),
                    const SizedBox(width: 18),
                    _FinanceHeroMetric(
                      icon: Icons.arrow_downward_rounded,
                      iconColor: const Color(0xFFFCA5A5),
                      label: 'Расходы',
                      value: formatMoney(expense),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: FinancePeriod.values.map((period) {
                      final active = period == _period;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => setState(() => _period = period),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: active
                                  ? Colors.white
                                  : const Color(0x33FFFFFF),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              period.label,
                              style: TextStyle(
                                color: active
                                    ? const Color(0xFF00A86B)
                                    : Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            child: Transform.translate(
              offset: const Offset(0, -18),
              child: Column(
                children: [
                  _BusinessCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Счета',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 14),
                        ...widget.finance.accounts.map(
                          (account) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: account.color,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      account.icon,
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          account.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const Text(
                                          '₸',
                                          style: TextStyle(
                                            color: Color(0xFF7B8794),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    formatMoney(account.balance),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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
                          'Расходы по категориям',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 220,
                          child: _ExpensesChart(
                            categories: widget.finance.expenseCategories,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _BusinessCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionHeader(
                          title: 'Последние операции',
                          actionLabel: 'Все',
                        ),
                        const SizedBox(height: 14),
                        ...widget.finance.transactions.map(
                          (transaction) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _TransactionRow(transaction: transaction),
                          ),
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
                          'Движение денежных средств (ДДС)',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 14),
                        ...widget.finance.cashFlows.expand(
                          (flow) => [
                            _CashFlowTile(
                              title: flow.title,
                              subtitle: flow.subtitle,
                              value: flow.value,
                              tone: hexColor(flow.tone).withValues(alpha: 0.08),
                              valueColor: hexColor(flow.valueColor),
                              highlighted: flow.highlighted,
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ],
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
}

class _MoreScreen extends StatefulWidget {
  const _MoreScreen({
    required this.session,
    required this.overview,
    required this.onLogout,
    required this.onOpenProfile,
  });

  final AuthSession session;
  final _OverviewData overview;
  final VoidCallback onLogout;
  final Future<void> Function() onOpenProfile;

  @override
  State<_MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<_MoreScreen> {
  bool _showProfile = false;
  bool _darkMode = false;

  @override
  Widget build(BuildContext context) {
    final company = widget.session.user.companies.isNotEmpty
        ? widget.session.user.companies.first
        : CompanyProfile(
            name: widget.overview.companyName,
            country: 'KZ',
            iin: '',
          );

    if (_showProfile) {
      return SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _showProfile = false),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Назад'),
            ),
            const SizedBox(height: 8),
            _BusinessCard(
              background: const LinearGradient(
                colors: [Color(0xFF00A86B), Color(0xFF008F5B)],
              ),
              child: Row(
                children: [
                  _CircleInitials(
                    text: company.name,
                    size: 80,
                    foregroundColor: Colors.white,
                    backgroundColor: const Color(0x33FFFFFF),
                    icon: Icons.business_rounded,
                    useIcon: true,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          company.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Торговая компания',
                          style: TextStyle(color: Color(0xCCFFFFFF)),
                        ),
                      ],
                    ),
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
                    'Реквизиты компании',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  _InfoTile(
                    icon: Icons.badge_rounded,
                    label:
                        company.country == 'KZ' ? 'ИИН / БИН' : 'Идентификатор',
                    value: company.iin.isEmpty ? 'Не указан' : company.iin,
                  ),
                  const _InfoTile(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'ИИК',
                    value: 'KZ12 3456 7890 1234 5678',
                  ),
                  const _InfoTile(
                    icon: Icons.account_balance_rounded,
                    label: 'БИК',
                    value: 'CASPKZKA',
                  ),
                  const _InfoTile(
                    icon: Icons.check_circle_rounded,
                    label: 'НДС плательщик',
                    value: 'Да',
                    valueColor: Color(0xFF16A34A),
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
                    'Контактная информация',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  const _InfoTile(
                    icon: Icons.location_on_rounded,
                    label: 'Адрес',
                    value: 'г. Алматы, ул. Абая 150',
                  ),
                  _InfoTile(
                    icon: Icons.phone_rounded,
                    label: 'Телефон',
                    value: widget.session.user.phone,
                  ),
                  const _InfoTile(
                    icon: Icons.mail_rounded,
                    label: 'Email',
                    value: 'info@mybusiness.kz',
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
                    'Пользователи',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  ...widget.overview.staff.map(
                    (member) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            _CircleInitials(
                              text: member.name,
                              size: 44,
                              foregroundColor: const Color(0xFF00A86B),
                              backgroundColor: const Color(0x1400A86B),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    member.role,
                                    style: const TextStyle(
                                      color: Color(0xFF7B8794),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFF9AA5B1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: widget.onOpenProfile,
              child: const Text('Редактировать профиль'),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _GradientHeader(
            title: 'Меню',
            subtitle: null,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => setState(() => _showProfile = true),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0x1AFFFFFF),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0x33FFFFFF)),
                ),
                child: Row(
                  children: [
                    _CircleInitials(
                      text: company.name,
                      size: 64,
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0x33FFFFFF),
                      icon: Icons.business_rounded,
                      useIcon: true,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            company.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ИИН: ${company.iin.isEmpty ? 'не указан' : company.iin}',
                            style: const TextStyle(color: Color(0xCCFFFFFF)),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            child: Transform.translate(
              offset: const Offset(0, -18),
              child: Column(
                children: [
                  const _BusinessCard(
                    child: Column(
                      children: [
                        _MenuTile(
                          icon: Icons.shopping_bag_rounded,
                          iconColor: Color(0xFF00A86B),
                          iconTone: Color(0x1400A86B),
                          title: 'Продажи',
                          subtitle: 'Заказы, счета, накладные',
                        ),
                        Divider(height: 24),
                        _MenuTile(
                          icon: Icons.inventory_rounded,
                          iconColor: Color(0xFF3B82F6),
                          iconTone: Color(0x143B82F6),
                          title: 'Закупки',
                          subtitle: 'Поставщики, заказы',
                        ),
                        Divider(height: 24),
                        _MenuTile(
                          icon: Icons.bar_chart_rounded,
                          iconColor: Color(0xFF22C55E),
                          iconTone: Color(0x1422C55E),
                          title: 'Аналитика',
                          subtitle: 'Отчеты, графики, ABC анализ',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _BusinessCard(
                    child: Column(
                      children: [
                        _MenuTile(
                          icon: Icons.notifications_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          iconTone: const Color(0x14F59E0B),
                          title: 'Уведомления',
                          subtitle: 'Напоминания и события',
                          badge: '${widget.overview.menuNotifications}',
                        ),
                        const Divider(height: 24),
                        const _MenuTile(
                          icon: Icons.description_rounded,
                          iconColor: Color(0xFF64748B),
                          iconTone: Color(0xFFF1F5F9),
                          title: 'Документы',
                          subtitle: 'Шаблоны и архив',
                        ),
                        const Divider(height: 24),
                        const _MenuTile(
                          icon: Icons.groups_rounded,
                          iconColor: Color(0xFF64748B),
                          iconTone: Color(0xFFF1F5F9),
                          title: 'Сотрудники',
                          subtitle: 'Управление пользователями',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _BusinessCard(
                    child: Column(
                      children: [
                        _SwitchTile(
                          icon: _darkMode
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          title: 'Темная тема',
                          value: _darkMode,
                          onChanged: (value) =>
                              setState(() => _darkMode = value),
                        ),
                        const Divider(height: 24),
                        const _MenuTile(
                          icon: Icons.settings_rounded,
                          iconColor: Color(0xFF64748B),
                          iconTone: Color(0xFFF1F5F9),
                          title: 'Настройки',
                          subtitle: 'Параметры приложения',
                        ),
                        const Divider(height: 24),
                        const _MenuTile(
                          icon: Icons.help_rounded,
                          iconColor: Color(0xFF64748B),
                          iconTone: Color(0xFFF1F5F9),
                          title: 'Помощь',
                          subtitle: 'FAQ и поддержка',
                        ),
                        const Divider(height: 24),
                        InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: widget.onLogout,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                _TileIcon(
                                  icon: Icons.logout_rounded,
                                  color: Color(0xFFEF4444),
                                  tone: Color(0x14EF4444),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Выйти',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFEF4444),
                                    ),
                                  ),
                                ),
                              ],
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
        ],
      ),
    );
  }
}

enum BusinessTab { dashboard, crm, warehouse, finance, more }

enum StatusKind { success, warning, error, info, neutral }

enum WarehouseFilter { all, low, out }

enum ProductStatus { inStock, lowStock, outOfStock }

enum FinancePeriod { day, week, month, year }

extension on FinancePeriod {
  String get label {
    switch (this) {
      case FinancePeriod.day:
        return 'День';
      case FinancePeriod.week:
        return 'Неделя';
      case FinancePeriod.month:
        return 'Месяц';
      case FinancePeriod.year:
        return 'Год';
    }
  }
}

enum TransactionType { income, expense }

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.activeTab,
    required this.onTabSelected,
  });

  final BusinessTab activeTab;
  final ValueChanged<BusinessTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    const tabs = [
      (BusinessTab.dashboard, Icons.home_rounded, 'Главная'),
      (BusinessTab.crm, Icons.group_rounded, 'CRM'),
      (BusinessTab.warehouse, Icons.inventory_2_rounded, 'Склад'),
      (BusinessTab.finance, Icons.account_balance_wallet_rounded, 'Финансы'),
      (BusinessTab.more, Icons.more_horiz_rounded, 'Еще'),
    ];

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: tabs.map((tab) {
              final isActive = tab.$1 == activeTab;
              return Expanded(
                child: InkWell(
                  onTap: () => onTabSelected(tab.$1),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tab.$2,
                        color: isActive
                            ? const Color(0xFF00A86B)
                            : const Color(0xFF7B8794),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tab.$3,
                        style: TextStyle(
                          color: isActive
                              ? const Color(0xFF00A86B)
                              : const Color(0xFF7B8794),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _FabMenu extends StatelessWidget {
  const _FabMenu({
    required this.expanded,
    required this.onToggle,
    required this.onActionSelected,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String> onActionSelected;

  @override
  Widget build(BuildContext context) {
    const actions = [
      ('Продажа', Color(0xFF00A86B)),
      ('Закупка', Color(0xFF3B82F6)),
      ('Клиент', Color(0xFF22C55E)),
      ('Счет', Color(0xFFF59E0B)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (expanded)
          ...actions.map(
            (action) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: action.$2,
                borderRadius: BorderRadius.circular(16),
                elevation: 6,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onActionSelected(action.$1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Text(
                      action.$1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        FloatingActionButton(
          onPressed: onToggle,
          backgroundColor: const Color(0xFF00A86B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: AnimatedRotation(
            turns: expanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 220),
            child: const Icon(Icons.add_rounded, size: 30),
          ),
        ),
      ],
    );
  }
}

class _GradientHeader extends StatelessWidget {
  const _GradientHeader({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 34),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF00A86B), Color(0xFF008F5B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitle != null || trailing != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              color: Color(0xCCFFFFFF),
                              fontSize: 13,
                            ),
                          ),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0x1AFFFFFF),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0x33FFFFFF)),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  const _BusinessCard({
    required this.child,
    this.onTap,
    this.background,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Gradient? background;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: BoxDecoration(
        color: background == null ? Colors.white : null,
        gradient: background,
        borderRadius: BorderRadius.circular(24),
        border: background == null
            ? Border.all(color: const Color(0xFFE2E8F0))
            : null,
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: child,
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: content,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.actionLabel,
  });

  final String title;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        if (actionLabel != null)
          Text(
            actionLabel!,
            style: const TextStyle(
              color: Color(0xFF00A86B),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.change,
    required this.changeColor,
    required this.icon,
    required this.iconBackground,
  });

  final String title;
  final String value;
  final String change;
  final Color changeColor;
  final IconData icon;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    return _BusinessCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF7B8794),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  change,
                  style: TextStyle(
                    color: changeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _SalesChart extends StatelessWidget {
  const _SalesChart({required this.points});

  final List<_ChartPoint> points;

  @override
  Widget build(BuildContext context) {
    final values = points.map((point) => point.value).toList(growable: false);

    return Column(
      children: [
        Expanded(
          child: CustomPaint(
            painter: _LineChartPainter(values: values),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: points
              .map(
                (point) => Text(
                  point.label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF7B8794),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    const gridColor = Color(0xFFE2E8F0);
    const lineColor = Color(0xFF00A86B);
    final paintGrid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }

    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final valueRange = math.max(1, maxValue - minValue);

    Offset pointFor(int index) {
      final x = size.width * index / (values.length - 1);
      final normalized = (values[index] - minValue) / valueRange;
      final y = size.height - (normalized * (size.height - 12)) - 6;
      return Offset(x, y);
    }

    final linePath = Path()..moveTo(pointFor(0).dx, pointFor(0).dy);
    for (var i = 1; i < values.length; i++) {
      final previous = pointFor(i - 1);
      final current = pointFor(i);
      final midX = (previous.dx + current.dx) / 2;
      linePath.cubicTo(
          midX, previous.dy, midX, current.dy, current.dx, current.dy);
    }

    final fillPath = Path.from(linePath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final gradientPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x5500A86B), Color(0x0000A86B)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, gradientPaint);

    final strokePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawPath(linePath, strokePaint);

    final dotPaint = Paint()..color = lineColor;
    final dotBorderPaint = Paint()..color = Colors.white;
    for (var i = 0; i < values.length; i++) {
      final point = pointFor(i);
      canvas.drawCircle(point, 4.5, dotBorderPaint);
      canvas.drawCircle(point, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});

  final _Activity activity;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: activity.tone,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(activity.icon, color: activity.color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                activity.time,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF7B8794),
                ),
              ),
            ],
          ),
        ),
        Text(
          activity.amount,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.tone,
    required this.accent,
  });

  final String title;
  final String value;
  final Color tone;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF7B8794),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.kind,
  });

  final String label;
  final StatusKind kind;

  @override
  Widget build(BuildContext context) {
    late final Color background;
    late final Color foreground;
    late final Color borderColor;

    switch (kind) {
      case StatusKind.success:
        background = const Color(0x1422C55E);
        foreground = const Color(0xFF16A34A);
        borderColor = const Color(0x3322C55E);
        break;
      case StatusKind.warning:
        background = const Color(0x14F59E0B);
        foreground = const Color(0xFFD97706);
        borderColor = const Color(0x33F59E0B);
        break;
      case StatusKind.error:
        background = const Color(0x14EF4444);
        foreground = const Color(0xFFDC2626);
        borderColor = const Color(0x33EF4444);
        break;
      case StatusKind.info:
        background = const Color(0x143B82F6);
        foreground = const Color(0xFF2563EB);
        borderColor = const Color(0x333B82F6);
        break;
      case StatusKind.neutral:
        background = const Color(0xFFF1F5F9);
        foreground = const Color(0xFF64748B);
        borderColor = const Color(0xFFE2E8F0);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          _TileIcon(
            icon: icon,
            color: const Color(0xFF64748B),
            tone: const Color(0xFFF1F5F9),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF7B8794),
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon({
    required this.icon,
    required this.color,
    required this.tone,
  });

  final IconData icon;
  final Color color;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.hintText,
    required this.icon,
    required this.onChanged,
  });

  final String hintText;
  final IconData icon;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onPressed,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Icon(icon),
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onPressed,
  });

  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? activeColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF334155),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelValue extends StatelessWidget {
  const _LabelValue({
    required this.label,
    required this.value,
    this.valueColor,
    this.textAlign = TextAlign.left,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: textAlign == TextAlign.right
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF7B8794),
            fontSize: 12,
          ),
          textAlign: textAlign,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
          textAlign: textAlign,
        ),
      ],
    );
  }
}

class _CircleInitials extends StatelessWidget {
  const _CircleInitials({
    required this.text,
    required this.size,
    required this.foregroundColor,
    required this.backgroundColor,
    this.icon,
    this.useIcon = false,
  });

  final String text;
  final double size;
  final Color foregroundColor;
  final Color backgroundColor;
  final IconData? icon;
  final bool useIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: useIcon
          ? Icon(icon, color: foregroundColor, size: size * 0.48)
          : Text(
              initialsOf(text),
              style: TextStyle(
                color: foregroundColor,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.32,
              ),
            ),
    );
  }
}

class _FinanceHeroMetric extends StatelessWidget {
  const _FinanceHeroMetric({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xCCFFFFFF),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpensesChart extends StatelessWidget {
  const _ExpensesChart({required this.categories});

  final List<_ExpenseCategory> categories;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 180,
            child: CustomPaint(
              painter: _DonutChartPainter(categories: categories),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: categories
                .map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: category.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category.name,
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                formatMoney(category.value),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF7B8794),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  const _DonutChartPainter({required this.categories});

  final List<_ExpenseCategory> categories;

  @override
  void paint(Canvas canvas, Size size) {
    final total = categories.fold<double>(0, (sum, item) => sum + item.value);
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: math.min(size.width, size.height) / 2.5,
    );
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 30
      ..strokeCap = StrokeCap.round;

    var startAngle = -math.pi / 2;
    for (final category in categories) {
      final sweep = (category.value / total) * (math.pi * 2);
      strokePaint.color = category.color;
      canvas.drawArc(rect, startAngle, sweep, false, strokePaint);
      startAngle += sweep + 0.05;
    }

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Расходы',
        style: TextStyle(
          color: Color(0xFF0F172A),
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        size.width / 2 - textPainter.width / 2,
        size.height / 2 - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.categories != categories;
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction});

  final _Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final income = transaction.type == TransactionType.income;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: income ? const Color(0x1422C55E) : const Color(0x14EF4444),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            income ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: income ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transaction.description,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '${transaction.category} • ${transaction.account}',
                style: const TextStyle(
                  color: Color(0xFF7B8794),
                  fontSize: 12,
                ),
              ),
              Text(
                transaction.date,
                style: const TextStyle(
                  color: Color(0xFF7B8794),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Text(
          '${income ? '+' : '-'}${formatMoney(transaction.amount.abs())}',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: income ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
          ),
        ),
      ],
    );
  }
}

class _CashFlowTile extends StatelessWidget {
  const _CashFlowTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.tone,
    required this.valueColor,
    this.highlighted = false,
  });

  final String title;
  final String subtitle;
  final String value;
  final Color tone;
  final Color valueColor;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(18),
        border: highlighted
            ? Border.all(color: const Color(0x3300A86B), width: 2)
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF7B8794),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.iconColor,
    required this.iconTone,
    required this.title,
    required this.subtitle,
    this.badge,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconTone;
  final String title;
  final String subtitle;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TileIcon(icon: icon, color: iconColor, tone: iconTone),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF7B8794),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              badge!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        const SizedBox(width: 6),
        const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFF9AA5B1),
        ),
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TileIcon(
          icon: icon,
          color: const Color(0xFF64748B),
          tone: const Color(0xFFF1F5F9),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
}

class _Activity {
  const _Activity({
    required this.title,
    required this.amount,
    required this.time,
    required this.icon,
    required this.color,
    required this.tone,
  });

  final String title;
  final String amount;
  final String time;
  final IconData icon;
  final Color color;
  final Color tone;
}

class _Client {
  const _Client({
    required this.name,
    required this.contact,
    required this.phone,
    required this.email,
    required this.segment,
    required this.totalSales,
    required this.debt,
    required this.interactions,
    this.bin,
    this.iin,
  });

  final String name;
  final String? bin;
  final String? iin;
  final String contact;
  final String phone;
  final String email;
  final String segment;
  final int totalSales;
  final int debt;
  final List<_Interaction> interactions;

  String get binOrIinLabel => bin != null ? 'БИН: $bin' : 'ИИН: $iin';
}

class _Interaction {
  const _Interaction({
    required this.title,
    required this.date,
    required this.note,
  });

  final String title;
  final String date;
  final String note;
}

class _Product {
  const _Product({
    required this.name,
    required this.sku,
    required this.category,
    required this.quantity,
    required this.minQuantity,
    required this.price,
    required this.cost,
    required this.barcode,
    required this.status,
    required this.movements,
  });

  final String name;
  final String sku;
  final String category;
  final int quantity;
  final int minQuantity;
  final int price;
  final int cost;
  final String barcode;
  final ProductStatus status;
  final List<_StockMovement> movements;

  String get statusLabel {
    switch (status) {
      case ProductStatus.inStock:
        return 'В наличии';
      case ProductStatus.lowStock:
        return 'Заканчивается';
      case ProductStatus.outOfStock:
        return 'Нет в наличии';
    }
  }
}

class _StockMovement {
  const _StockMovement({
    required this.date,
    required this.document,
    required this.quantity,
    required this.balance,
  });

  final String date;
  final String document;
  final int quantity;
  final int balance;
}

class _BankAccount {
  const _BankAccount({
    required this.name,
    required this.balance,
    required this.color,
    required this.icon,
  });

  final String name;
  final int balance;
  final Color color;
  final String icon;
}

class _Transaction {
  const _Transaction({
    required this.type,
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
    required this.account,
  });

  final TransactionType type;
  final String description;
  final int amount;
  final String category;
  final String date;
  final String account;
}

class _ExpenseCategory {
  const _ExpenseCategory({
    required this.name,
    required this.value,
    required this.color,
  });

  final String name;
  final int value;
  final Color color;
}

class _StaffMember {
  const _StaffMember({
    required this.name,
    required this.role,
  });

  final String name;
  final String role;
}

class _OverviewData {
  const _OverviewData({
    required this.companyName,
    required this.initials,
    required this.dashboard,
    required this.recentActivities,
    required this.clients,
    required this.products,
    required this.finance,
    required this.staff,
    required this.menuNotifications,
  });

  factory _OverviewData.fromJson(
    Map<String, dynamic> json,
    UserProfile fallbackUser,
  ) {
    return _OverviewData(
      companyName: json['company_name'] as String? ??
          (fallbackUser.companies.isNotEmpty
              ? fallbackUser.companies.first.name
              : 'ТОО "Мой Бизнес"'),
      initials:
          json['initials'] as String? ?? initialsOf(fallbackUser.fullName),
      dashboard: _DashboardData.fromJson(
        json['dashboard'] as Map<String, dynamic>? ?? const {},
      ),
      recentActivities:
          (json['recent_activities'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(_activityFromJson)
              .toList(growable: false),
      clients: (json['clients'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_clientFromJson)
          .toList(growable: false),
      products: (json['products'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_productFromJson)
          .toList(growable: false),
      finance: _FinanceOverview.fromJson(
        json['finance'] as Map<String, dynamic>? ?? const {},
      ),
      staff: (json['staff'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_staffFromJson)
          .toList(growable: false),
      menuNotifications: json['menu_notifications'] as int? ?? 0,
    );
  }

  final String companyName;
  final String initials;
  final _DashboardData dashboard;
  final List<_Activity> recentActivities;
  final List<_Client> clients;
  final List<_Product> products;
  final _FinanceOverview finance;
  final List<_StaffMember> staff;
  final int menuNotifications;
}

class _DashboardData {
  const _DashboardData({
    required this.monthlyRevenue,
    required this.revenueChange,
    required this.kpis,
    required this.salesSeries,
  });

  factory _DashboardData.fromJson(Map<String, dynamic> json) {
    return _DashboardData(
      monthlyRevenue: json['monthly_revenue'] as String? ?? '₸ 0',
      revenueChange: json['revenue_change'] as String? ?? '+0%',
      kpis: (json['kpis'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_kpiFromJson)
          .toList(growable: false),
      salesSeries: (json['sales_series'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_chartPointFromJson)
          .toList(growable: false),
    );
  }

  final String monthlyRevenue;
  final String revenueChange;
  final List<_KpiData> kpis;
  final List<_ChartPoint> salesSeries;
}

class _KpiData {
  const _KpiData({
    required this.title,
    required this.value,
    required this.change,
    required this.changeTone,
    required this.icon,
    required this.iconTone,
  });

  final String title;
  final String value;
  final String change;
  final String changeTone;
  final String icon;
  final String iconTone;
}

class _ChartPoint {
  const _ChartPoint({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;
}

class _FinanceOverview {
  const _FinanceOverview({
    required this.totalBalance,
    required this.income,
    required this.expense,
    required this.accounts,
    required this.expenseCategories,
    required this.transactions,
    required this.cashFlows,
  });

  factory _FinanceOverview.fromJson(Map<String, dynamic> json) {
    return _FinanceOverview(
      totalBalance: json['total_balance'] as int? ?? 0,
      income: json['income'] as int? ?? 0,
      expense: json['expense'] as int? ?? 0,
      accounts: (json['accounts'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_bankAccountFromJson)
          .toList(growable: false),
      expenseCategories:
          (json['expense_categories'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(_expenseCategoryFromJson)
              .toList(growable: false),
      transactions: (json['transactions'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_transactionFromJson)
          .toList(growable: false),
      cashFlows: (json['cash_flows'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_cashFlowFromJson)
          .toList(growable: false),
    );
  }

  final int totalBalance;
  final int income;
  final int expense;
  final List<_BankAccount> accounts;
  final List<_ExpenseCategory> expenseCategories;
  final List<_Transaction> transactions;
  final List<_CashFlowData> cashFlows;
}

class _CashFlowData {
  const _CashFlowData({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.tone,
    required this.valueColor,
    required this.highlighted,
  });

  final String title;
  final String subtitle;
  final String value;
  final String tone;
  final String valueColor;
  final bool highlighted;
}

_KpiData _kpiFromJson(Map<String, dynamic> json) => _KpiData(
      title: json['title'] as String? ?? '',
      value: json['value'] as String? ?? '',
      change: json['change'] as String? ?? '',
      changeTone: json['change_tone'] as String? ?? 'neutral',
      icon: json['icon'] as String? ?? 'inventory',
      iconTone: json['icon_tone'] as String? ?? 'primary',
    );

_ChartPoint _chartPointFromJson(Map<String, dynamic> json) => _ChartPoint(
      label: json['label'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0,
    );

_Activity _activityFromJson(Map<String, dynamic> json) {
  final tone = json['tone'] as String? ?? 'neutral';
  return _Activity(
    title: json['title'] as String? ?? '',
    amount: json['amount'] as String? ?? '',
    time: json['time'] as String? ?? '',
    icon: iconFor(json['icon'] as String? ?? ''),
    color: toneColor(tone),
    tone: toneColor(tone).withValues(alpha: 0.1),
  );
}

_Client _clientFromJson(Map<String, dynamic> json) => _Client(
      name: json['name'] as String? ?? '',
      bin: json['bin'] as String?,
      iin: json['iin'] as String?,
      contact: json['contact'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      segment: json['segment'] as String? ?? 'Regular',
      totalSales: json['total_sales'] as int? ?? 0,
      debt: json['debt'] as int? ?? 0,
      interactions: (json['interactions'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_interactionFromJson)
          .toList(growable: false),
    );

_Interaction _interactionFromJson(Map<String, dynamic> json) => _Interaction(
      title: json['title'] as String? ?? '',
      date: json['date'] as String? ?? '',
      note: json['note'] as String? ?? '',
    );

_Product _productFromJson(Map<String, dynamic> json) => _Product(
      name: json['name'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      category: json['category'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 0,
      minQuantity: json['min_quantity'] as int? ?? 0,
      price: json['price'] as int? ?? 0,
      cost: json['cost'] as int? ?? 0,
      barcode: json['barcode'] as String? ?? '',
      status: switch (json['status'] as String? ?? '') {
        'low_stock' => ProductStatus.lowStock,
        'out_of_stock' => ProductStatus.outOfStock,
        _ => ProductStatus.inStock,
      },
      movements: (json['movements'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_stockMovementFromJson)
          .toList(growable: false),
    );

_StockMovement _stockMovementFromJson(Map<String, dynamic> json) =>
    _StockMovement(
      date: json['date'] as String? ?? '',
      document: json['document'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 0,
      balance: json['balance'] as int? ?? 0,
    );

_BankAccount _bankAccountFromJson(Map<String, dynamic> json) => _BankAccount(
      name: json['name'] as String? ?? '',
      balance: json['balance'] as int? ?? 0,
      color: hexColor(json['color'] as String? ?? '#00A86B'),
      icon: json['icon'] as String? ?? '🏦',
    );

_ExpenseCategory _expenseCategoryFromJson(Map<String, dynamic> json) =>
    _ExpenseCategory(
      name: json['name'] as String? ?? '',
      value: json['value'] as int? ?? 0,
      color: hexColor(json['color'] as String? ?? '#00A86B'),
    );

_Transaction _transactionFromJson(Map<String, dynamic> json) => _Transaction(
      type: (json['type'] as String? ?? 'expense') == 'income'
          ? TransactionType.income
          : TransactionType.expense,
      description: json['description'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
      category: json['category'] as String? ?? '',
      date: json['date'] as String? ?? '',
      account: json['account'] as String? ?? '',
    );

_CashFlowData _cashFlowFromJson(Map<String, dynamic> json) => _CashFlowData(
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      value: json['value'] as String? ?? '',
      tone: json['tone'] as String? ?? '#00A86B',
      valueColor: json['value_color'] as String? ?? '#00A86B',
      highlighted: json['highlighted'] as bool? ?? false,
    );

_StaffMember _staffFromJson(Map<String, dynamic> json) => _StaffMember(
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? '',
    );

Color toneColor(String tone) {
  switch (tone) {
    case 'success':
      return const Color(0xFF16A34A);
    case 'warning':
      return const Color(0xFFF59E0B);
    case 'info':
      return const Color(0xFF3B82F6);
    case 'primary':
      return const Color(0xFF00A86B);
    case 'error':
      return const Color(0xFFEF4444);
    default:
      return const Color(0xFF64748B);
  }
}

IconData iconFor(String icon) {
  switch (icon) {
    case 'cart':
      return Icons.shopping_cart_rounded;
    case 'receipt':
      return Icons.receipt_long_rounded;
    case 'group':
      return Icons.group_rounded;
    case 'inventory':
      return Icons.inventory_2_rounded;
    case 'payments':
      return Icons.payments_rounded;
    case 'description':
      return Icons.description_rounded;
    default:
      return Icons.circle_rounded;
  }
}

Color hexColor(String hex) {
  final normalized = hex.replaceFirst('#', '');
  final withAlpha = normalized.length == 6 ? 'FF$normalized' : normalized;
  return Color(int.parse(withAlpha, radix: 16));
}

String formatMoney(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final reverseIndex = digits.length - i;
    buffer.write(digits[i]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write(',');
    }
  }
  return '₸ ${buffer.toString()}';
}

String initialsOf(String value) {
  final words = value
      .replaceAll('"', '')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(2)
      .toList();
  if (words.isEmpty) {
    return 'MB';
  }
  return words.map((word) => word.characters.first.toUpperCase()).join();
}
