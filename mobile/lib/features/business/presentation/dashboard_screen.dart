part of 'business_shell.dart';

class _DashboardScreen extends StatelessWidget {
  const _DashboardScreen({
    required this.session,
    required this.overview,
    required this.companies,
    required this.activeCompanyId,
    required this.onSwitchCompany,
    required this.onSetDefaultCompany,
    required this.onCreateCompany,
    required this.onAddCompanyMember,
    required this.onRefresh,
    required this.onOpenBusinessTab,
  });

  final AuthSession session;
  final _OverviewData overview;
  final List<_Company> companies;
  final String? activeCompanyId;
  final Future<void> Function(String companyId) onSwitchCompany;
  final Future<void> Function(String companyId) onSetDefaultCompany;
  final Future<void> Function(Map<String, dynamic> payload) onCreateCompany;
  final Future<void> Function(String companyId, Map<String, dynamic> payload)
      onAddCompanyMember;
  final Future<void> Function() onRefresh;
  final Future<void> Function(BusinessTab tab) onOpenBusinessTab;

  @override
  Widget build(BuildContext context) {
    final dashboard = overview.dashboard;
    final roleLabel = _dashboardRoleLabel(overview.activeRole);
    final currentCompany = companies.firstWhere(
      (company) => company.id == activeCompanyId,
      orElse: () => companies.isNotEmpty
          ? companies.first
          : _Company(
              id: '',
              name: overview.companyName,
              country: 'KZ',
              iin: '',
              role: overview.activeRole,
              isDefault: false,
            ),
    );

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _GradientHeader(
              title: overview.companyName,
              subtitle: roleLabel,
              onTitleTap: () => _showCompanySwitcher(context),
              trailing: _CompanyAvatar(
                name: currentCompany.name,
                logoUrl: currentCompany.logoUrl,
                accessToken: session.accessToken,
                size: 52,
                foregroundColor: Colors.white,
                backgroundColor: const Color(0x33FFFFFF),
              ),
              child: _DashboardHero(
                label: dashboard.heroLabel,
                value: dashboard.heroValue,
                change: dashboard.heroChange,
                changeTone: dashboard.heroChangeTone,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              child: Column(
                children: [
                  _DashboardKpiGrid(kpis: dashboard.kpis),
                  if (overview.myPayroll.hasEmployee ||
                      overview.activeRole == 'staff') ...[
                    const SizedBox(height: 16),
                    _DashboardMyPayrollCard(
                      payroll: overview.myPayroll,
                      onOpen: () {
                        onOpenBusinessTab(BusinessTab.salary);
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  _DashboardHighlightsGrid(
                    highlights: dashboard.highlights,
                    onSelected: _openHighlight,
                  ),
                  const SizedBox(height: 16),
                  _DashboardCharts(
                    overview: overview,
                    onOpenBusinessTab: onOpenBusinessTab,
                  ),
                  const SizedBox(height: 16),
                  _DashboardRoleSignals(
                    overview: overview,
                    onOpenBusinessTab: onOpenBusinessTab,
                  ),
                  const SizedBox(height: 16),
                  _DashboardActivityCard(
                    activities: overview.recentActivities,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openHighlight(_DashboardHighlight highlight) async {
    final tab = _tabForTarget(highlight.target);
    if (tab == null) {
      return;
    }
    await onOpenBusinessTab(tab);
  }

  BusinessTab? _tabForTarget(String target) {
    switch (target) {
      case 'crm':
        return BusinessTab.crm;
      case 'warehouse':
        return BusinessTab.warehouse;
      case 'finance':
        return BusinessTab.finance;
      case 'catalog':
        return BusinessTab.catalog;
      case 'production':
        return BusinessTab.production;
      case 'sales':
        return BusinessTab.warehouse;
      case 'purchases':
        return BusinessTab.purchases;
      case 'salary':
        return BusinessTab.salary;
      case 'reports':
        return BusinessTab.reports;
      default:
        return null;
    }
  }

  Future<void> _showCompanySwitcher(BuildContext context) async {
    final canManageCompany =
        overview.activeRole == 'owner' || overview.activeRole == 'admin';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF7FAF8),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: SizedBox(width: 48, child: Divider(thickness: 4)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Мои компании',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  if (companies.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Список компаний недоступен',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: companies.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final company = companies[index];
                          final isActive = company.id == activeCompanyId;
                          return _BusinessCard(
                            child: InkWell(
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                onSwitchCompany(company.id);
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    isActive
                                        ? Icons.check_circle_rounded
                                        : Icons.circle_outlined,
                                    color: isActive
                                        ? const Color(0xFF00A86B)
                                        : const Color(0xFFCBD5E1),
                                  ),
                                  const SizedBox(width: 12),
                                  _CompanyAvatar(
                                    name: company.name,
                                    logoUrl: company.logoUrl,
                                    accessToken: session.accessToken,
                                    size: 42,
                                    foregroundColor: const Color(0xFF00A86B),
                                    backgroundColor: const Color(0x1400A86B),
                                    icon: Icons.business_rounded,
                                    useIconFallback: true,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          company.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          company.isDefault
                                              ? '${company.roleLabel} · по умолчанию'
                                              : company.roleLabel,
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Сделать основной',
                                    onPressed: company.isDefault
                                        ? null
                                        : () {
                                            Navigator.of(sheetContext).pop();
                                            onSetDefaultCompany(company.id);
                                          },
                                    icon: Icon(
                                      company.isDefault
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      color: company.isDefault
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (canManageCompany)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                              _showCreateCompanySheet(context);
                            },
                            icon: const Icon(Icons.add_business_rounded),
                            label: const Text('Компания'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                              _showAddMemberSheet(context);
                            },
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: const Text('Сотрудник'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCreateCompanySheet(BuildContext context) async {
    final payload = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CompanyFormSheet(),
    );
    if (payload == null) return;
    try {
      await onCreateCompany(payload);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _showAddMemberSheet(BuildContext context) async {
    final targetId =
        activeCompanyId ?? (companies.isNotEmpty ? companies.first.id : null);
    if (targetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала выберите компанию')),
      );
      return;
    }
    final payload = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddMemberFormSheet(),
    );
    if (payload == null) return;
    try {
      await onAddCompanyMember(targetId, payload);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.label,
    required this.value,
    required this.change,
    required this.changeTone,
  });

  final String label;
  final String value;
  final String change;
  final String changeTone;

  @override
  Widget build(BuildContext context) {
    final tone = toneColor(changeTone);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xCCFFFFFF),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_trendIcon(changeTone), color: tone, size: 17),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  change,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashboardKpiGrid extends StatelessWidget {
  const _DashboardKpiGrid({required this.kpis});

  final List<_KpiData> kpis;

  @override
  Widget build(BuildContext context) {
    if (kpis.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          childAspectRatio: constraints.maxWidth >= 760 ? 1.38 : 1.22,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: kpis
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
        );
      },
    );
  }
}

class _DashboardMyPayrollCard extends StatelessWidget {
  const _DashboardMyPayrollCard({
    required this.payroll,
    required this.onOpen,
  });

  final _MyPayrollOverview payroll;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return _BusinessCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tokens.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  payroll.hasEmployee
                      ? Icons.payments_rounded
                      : Icons.person_search_rounded,
                  color: tokens.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Моя зарплата',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      payroll.hasEmployee
                          ? _dashboardPayrollPeriod(payroll.from, payroll.to)
                          : 'Пользователь не связан с сотрудником',
                      style: TextStyle(
                        color: tokens.mutedForeground,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: tokens.mutedForeground),
            ],
          ),
          const SizedBox(height: 16),
          if (payroll.hasEmployee)
            Row(
              children: [
                Expanded(
                  child: _DashboardMiniStat(
                    label: 'Начислено',
                    value: formatMoney(payroll.totalGross),
                    color: tokens.foreground,
                  ),
                ),
                Expanded(
                  child: _DashboardMiniStat(
                    label: 'К выплате',
                    value: formatMoney(payroll.totalNet),
                    color: tokens.success,
                  ),
                ),
              ],
            )
          else
            Text(
              'Попросите администратора связать ваш профиль с карточкой сотрудника.',
              style: TextStyle(color: tokens.mutedForeground, fontSize: 13),
            ),
        ],
      ),
    );
  }
}

String _dashboardPayrollPeriod(String from, String to) {
  final formattedFrom = _dashboardIsoDate(from);
  final formattedTo = _dashboardIsoDate(to);
  if (formattedFrom.isEmpty && formattedTo.isEmpty) return 'Текущий год';
  if (formattedFrom.isEmpty) return 'по $formattedTo';
  if (formattedTo.isEmpty) return 'с $formattedFrom';
  return '$formattedFrom - $formattedTo';
}

String _dashboardIsoDate(String value) {
  final parts = value.split('-');
  if (parts.length != 3) return value;
  return '${parts[2]}.${parts[1]}.${parts[0]}';
}

class _DashboardHighlightsGrid extends StatelessWidget {
  const _DashboardHighlightsGrid({
    required this.highlights,
    required this.onSelected,
  });

  final List<_DashboardHighlight> highlights;
  final ValueChanged<_DashboardHighlight> onSelected;

  @override
  Widget build(BuildContext context) {
    if (highlights.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          childAspectRatio: constraints.maxWidth >= 760 ? 1.72 : 1.35,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: highlights
              .map(
                (highlight) => _DashboardHighlightCard(
                  highlight: highlight,
                  onTap: highlight.target.isEmpty
                      ? null
                      : () => onSelected(highlight),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _DashboardHighlightCard extends StatelessWidget {
  const _DashboardHighlightCard({
    required this.highlight,
    this.onTap,
  });

  final _DashboardHighlight highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    final accent = toneColor(highlight.tone);
    return _BusinessCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TileIcon(
                icon: iconFor(highlight.icon),
                color: accent,
                tone: tokens.tone(accent),
              ),
              const Spacer(),
              if (onTap != null)
                Icon(
                  Icons.arrow_forward_rounded,
                  color: tokens.mutedForeground,
                  size: 18,
                ),
            ],
          ),
          const Spacer(),
          Text(
            highlight.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.mutedForeground,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              highlight.value,
              style: TextStyle(
                color: tokens.cardForeground,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            highlight.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.mutedForeground,
              fontSize: 11,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardCharts extends StatelessWidget {
  const _DashboardCharts({
    required this.overview,
    required this.onOpenBusinessTab,
  });

  final _OverviewData overview;
  final Future<void> Function(BusinessTab tab) onOpenBusinessTab;

  @override
  Widget build(BuildContext context) {
    final chartCards = <Widget>[
      _BusinessCard(
        onTap: overview.hasPermission('warehouse.read')
            ? () => onOpenBusinessTab(BusinessTab.warehouse)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: overview.dashboard.seriesTitle,
              actionLabel:
                  overview.hasPermission('warehouse.read') ? 'Открыть' : null,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 190,
              child: _SalesChart(points: overview.dashboard.salesSeries),
            ),
          ],
        ),
      ),
    ];

    if (overview.hasPermission('finance.read')) {
      chartCards.add(
        _BusinessCard(
          onTap: () => onOpenBusinessTab(BusinessTab.finance),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                title: 'Структура расходов',
                actionLabel: 'Финансы',
              ),
              const SizedBox(height: 12),
              _ExpensesChart(categories: overview.finance.expenseCategories),
            ],
          ),
        ),
      );
    } else if (overview.hasPermission('warehouse.read') ||
        overview.hasPermission('catalog.read')) {
      chartCards.add(
        _BusinessCard(
          onTap: () => onOpenBusinessTab(BusinessTab.warehouse),
          child: _StockHealthPanel(products: overview.products),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 760 && chartCards.length > 1) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: chartCards[0]),
              const SizedBox(width: 12),
              Expanded(child: chartCards[1]),
            ],
          );
        }
        return Column(
          children: [
            for (var index = 0; index < chartCards.length; index++) ...[
              if (index > 0) const SizedBox(height: 12),
              chartCards[index],
            ],
          ],
        );
      },
    );
  }
}

class _StockHealthPanel extends StatelessWidget {
  const _StockHealthPanel({required this.products});

  final List<_Product> products;

  @override
  Widget build(BuildContext context) {
    final total = products.length;
    final low =
        products.where((p) => p.status == ProductStatus.lowStock).length;
    final out =
        products.where((p) => p.status == ProductStatus.outOfStock).length;
    final healthy = math.max(0, total - low - out);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Здоровье склада', actionLabel: 'Склад'),
        const SizedBox(height: 18),
        _StockHealthBar(
          total: total,
          healthy: healthy,
          low: low,
          out: out,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _DashboardMiniStat(
                label: 'В наличии',
                value: '$healthy',
                color: const Color(0xFF16A34A),
              ),
            ),
            Expanded(
              child: _DashboardMiniStat(
                label: 'Низко',
                value: '$low',
                color: const Color(0xFFF59E0B),
              ),
            ),
            Expanded(
              child: _DashboardMiniStat(
                label: 'Нет',
                value: '$out',
                color: const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StockHealthBar extends StatelessWidget {
  const _StockHealthBar({
    required this.total,
    required this.healthy,
    required this.low,
    required this.out,
  });

  final int total;
  final int healthy;
  final int low;
  final int out;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 16,
        child: Row(
          children: [
            _StockBarSegment(
              flex: math.max(1, healthy),
              color: tokens.success,
              visible: healthy > 0 || total == 0,
            ),
            _StockBarSegment(
              flex: math.max(1, low),
              color: tokens.warning,
              visible: low > 0,
            ),
            _StockBarSegment(
              flex: math.max(1, out),
              color: tokens.destructive,
              visible: out > 0,
            ),
          ],
        ),
      ),
    );
  }
}

class _StockBarSegment extends StatelessWidget {
  const _StockBarSegment({
    required this.flex,
    required this.color,
    required this.visible,
  });

  final int flex;
  final Color color;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }
    return Expanded(
      flex: math.max(1, flex),
      child: DecoratedBox(
        decoration: BoxDecoration(color: color),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _DashboardMiniStat extends StatelessWidget {
  const _DashboardMiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: tokens.mutedForeground,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ],
    );
  }
}

class _DashboardRoleSignals extends StatelessWidget {
  const _DashboardRoleSignals({
    required this.overview,
    required this.onOpenBusinessTab,
  });

  final _OverviewData overview;
  final Future<void> Function(BusinessTab tab) onOpenBusinessTab;

  @override
  Widget build(BuildContext context) {
    final signals = _signalsForOverview();
    return _BusinessCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Фокус по роли'),
          const SizedBox(height: 14),
          ...signals.map(
            (signal) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DashboardSignalTile(
                signal: signal,
                onTap: signal.tab == null
                    ? null
                    : () => onOpenBusinessTab(signal.tab!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_DashboardSignal> _signalsForOverview() {
    final receivable = overview.clients.fold<int>(
      0,
      (sum, client) => sum + client.receivable,
    );
    final lowStock = overview.products
        .where((product) => product.status == ProductStatus.lowStock)
        .length;
    final outStock = overview.products
        .where((product) => product.status == ProductStatus.outOfStock)
        .length;
    final netFlow = overview.finance.income - overview.finance.expense;
    final role = overview.activeRole;

    if (role == 'warehouse') {
      return [
        _DashboardSignal(
          title: 'Проверить остатки',
          subtitle: '$lowStock низкий остаток, $outStock нет в наличии',
          icon: Icons.inventory_2_rounded,
          color: toneColor(lowStock + outStock > 0 ? 'warning' : 'success'),
          tab: BusinessTab.warehouse,
        ),
        _DashboardSignal(
          title: 'Каталог товаров',
          subtitle: '${overview.products.length} позиций доступно',
          icon: Icons.menu_book_rounded,
          color: toneColor('primary'),
          tab: BusinessTab.catalog,
        ),
      ];
    }
    if (role == 'sales') {
      return [
        _DashboardSignal(
          title: 'Клиенты в работе',
          subtitle: '${overview.clients.length} карточек CRM',
          icon: Icons.group_rounded,
          color: toneColor('info'),
          tab: BusinessTab.crm,
        ),
        _DashboardSignal(
          title: 'Дебиторка клиентов',
          subtitle: formatMoney(receivable),
          icon: Icons.receipt_long_rounded,
          color: toneColor(receivable > 0 ? 'warning' : 'success'),
          tab: BusinessTab.crm,
        ),
      ];
    }
    if (role == 'accountant') {
      return [
        _DashboardSignal(
          title: 'Денежный поток',
          subtitle: _signedMoney(netFlow),
          icon: Icons.swap_vert_rounded,
          color: toneColor(netFlow >= 0 ? 'success' : 'error'),
          tab: BusinessTab.finance,
        ),
        _DashboardSignal(
          title: 'Зарплатные периоды',
          subtitle: 'Открыть начисления и выплаты',
          icon: Icons.badge_rounded,
          color: toneColor('warning'),
          tab: BusinessTab.salary,
        ),
      ];
    }
    if (overview.permissions.isEmpty) {
      return [
        _DashboardSignal(
          title: 'Доступ ограничен',
          subtitle: 'Администратор компании может выдать права',
          icon: Icons.lock_outline_rounded,
          color: toneColor('neutral'),
        ),
      ];
    }
    return [
      if (overview.hasPermission('finance.read'))
        _DashboardSignal(
          title: 'Деньги и поток',
          subtitle: '${formatMoney(overview.finance.totalBalance)} на счетах',
          icon: Icons.account_balance_wallet_rounded,
          color: toneColor(netFlow >= 0 ? 'success' : 'error'),
          tab: BusinessTab.finance,
        ),
      if (overview.hasPermission('warehouse.read'))
        _DashboardSignal(
          title: 'Складские риски',
          subtitle: '$lowStock низкий остаток, $outStock нет в наличии',
          icon: Icons.warning_amber_rounded,
          color: toneColor(lowStock + outStock > 0 ? 'warning' : 'success'),
          tab: BusinessTab.warehouse,
        ),
      if (overview.hasPermission('crm.read'))
        _DashboardSignal(
          title: 'Клиенты и задолженность',
          subtitle:
              '${overview.clients.length} клиентов · ${formatMoney(receivable)}',
          icon: Icons.group_rounded,
          color: toneColor('info'),
          tab: BusinessTab.crm,
        ),
    ];
  }

  String _signedMoney(int value) {
    if (value == 0) return formatMoney(0);
    final sign = value > 0 ? '+' : '';
    return '$sign${formatMoney(value)}';
  }
}

class _DashboardSignal {
  const _DashboardSignal({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.tab,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final BusinessTab? tab;
}

class _DashboardSignalTile extends StatelessWidget {
  const _DashboardSignalTile({
    required this.signal,
    this.onTap,
  });

  final _DashboardSignal signal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              _TileIcon(
                icon: signal.icon,
                color: signal.color,
                tone: tokens.tone(signal.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      signal.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.cardForeground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      signal.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.mutedForeground,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: tokens.mutedForeground,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardActivityCard extends StatelessWidget {
  const _DashboardActivityCard({required this.activities});

  final List<_Activity> activities;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return _BusinessCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Последние операции'),
          const SizedBox(height: 14),
          if (activities.isEmpty)
            Text(
              'Операций пока нет',
              style: TextStyle(
                color: tokens.mutedForeground,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            ...activities.map(
              (activity) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _ActivityRow(activity: activity),
              ),
            ),
        ],
      ),
    );
  }
}

String _dashboardRoleLabel(String role) {
  switch (role) {
    case 'owner':
      return 'Владелец · полный обзор';
    case 'admin':
      return 'Администратор · полный обзор';
    case 'manager':
      return 'Менеджер · операционный обзор';
    case 'accountant':
      return 'Бухгалтер · финансы и зарплата';
    case 'warehouse':
      return 'Кладовщик · складская витрина';
    case 'sales':
      return 'Продажи · CRM и отгрузки';
    default:
      return 'Сотрудник · ограниченный доступ';
  }
}

IconData _trendIcon(String tone) {
  switch (tone) {
    case 'success':
      return Icons.arrow_upward_rounded;
    case 'error':
    case 'danger':
      return Icons.arrow_downward_rounded;
    case 'warning':
      return Icons.priority_high_rounded;
    default:
      return Icons.insights_rounded;
  }
}

class _CompanyFormSheet extends StatefulWidget {
  const _CompanyFormSheet();

  @override
  State<_CompanyFormSheet> createState() => _CompanyFormSheetState();
}

class _CompanyFormSheetState extends State<_CompanyFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _iinController = TextEditingController();
  String _country = 'KZ';

  @override
  void dispose() {
    _nameController.dispose();
    _iinController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(<String, dynamic>{
      'name': _nameController.text.trim(),
      'country': _country,
      'iin': _iinController.text.trim(),
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: SizedBox(width: 48, child: Divider(thickness: 4)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Новая компания',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  _ClientTextField(
                    controller: _nameController,
                    label: 'Название компании',
                    validator: (value) {
                      if (value == null || value.trim().length < 2) {
                        return 'Введите название';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _country,
                    decoration: const InputDecoration(labelText: 'Страна'),
                    items: const [
                      DropdownMenuItem(value: 'KZ', child: Text('Казахстан')),
                      DropdownMenuItem(value: 'RU', child: Text('Россия')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _country = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  _ClientTextField(
                    controller: _iinController,
                    label: _country == 'KZ' ? 'БИН / ИИН' : 'Идентификатор',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final trimmed = value?.trim() ?? '';
                      if (_country == 'KZ') {
                        if (trimmed.length != 12 ||
                            int.tryParse(trimmed) == null) {
                          return 'БИН/ИИН — 12 цифр';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submit,
                      child: const Text('Создать компанию'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddMemberFormSheet extends StatefulWidget {
  const _AddMemberFormSheet();

  @override
  State<_AddMemberFormSheet> createState() => _AddMemberFormSheetState();
}

class _AddMemberFormSheetState extends State<_AddMemberFormSheet> {
  static const _roles = <String, String>{
    'staff': 'Сотрудник',
    'manager': 'Менеджер',
    'sales': 'Продажи',
    'warehouse': 'Склад',
    'accountant': 'Бухгалтер',
    'admin': 'Администратор',
  };

  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  String _role = 'staff';

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(<String, dynamic>{
      'phone': _phoneController.text.trim(),
      'role': _role,
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: SizedBox(width: 48, child: Divider(thickness: 4)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Добавить сотрудника',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Пользователь должен быть уже зарегистрирован в приложении.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  _ClientTextField(
                    controller: _phoneController,
                    label: 'Телефон сотрудника',
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.trim().length < 10) {
                        return 'Введите телефон';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _role,
                    decoration: const InputDecoration(labelText: 'Роль'),
                    items: _roles.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) setState(() => _role = value);
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submit,
                      child: const Text('Добавить'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
