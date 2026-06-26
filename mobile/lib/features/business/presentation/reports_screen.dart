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
  _CompanyBalanceSummary? _balance;
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
      final payload = await widget.businessGateway.fetchCompanyBalance(
        accessToken: widget.accessToken,
      );

      if (!mounted) return;
      setState(() {
        _balance = _companyBalanceSummaryFromJson(payload);
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
        children: [
          _ReportsHeader(onRefresh: _load),
          const SizedBox(height: 16),
          ..._buildReportLinks(context),
          const SizedBox(height: 18),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _ReportNotice(
              icon: Icons.cloud_off_rounded,
              title: 'Не удалось загрузить баланс',
              message:
                  'Разделы отчетов доступны. Попробуйте обновить сводку позже.',
            )
          else if (_balance != null) ...[
            _CompanyBalanceCard(summary: _balance!),
            const SizedBox(height: 14),
            _BalanceHistoryCard(weeks: _balance!.weeks),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildReportLinks(BuildContext context) => [
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
        const SizedBox(height: 10),
        _ReportLinkCard(
          icon: Icons.badge_rounded,
          title: 'Зарплатная карточка сотрудника',
          subtitle: 'Начисления, премии, удержания за период · PDF / Excel',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _EmployeeReportScreen(
                  accessToken: widget.accessToken,
                  businessGateway: widget.businessGateway,
                  companyName: widget.overview.companyName,
                ),
              ),
            );
          },
        ),
      ];
}

class _ReportsHeader extends StatelessWidget {
  const _ReportsHeader({
    required this.onRefresh,
  });

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
      ],
    );
  }
}

class _CompanyBalanceCard extends StatelessWidget {
  const _CompanyBalanceCard({required this.summary});

  final _CompanyBalanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final tone = summary.netBalance >= 0
        ? const Color(0xFF16A34A)
        : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tone.withValues(alpha: 0.12),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                  color: tone.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.account_balance_wallet_rounded,
                    color: tone, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Баланс компании',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Активы - пассивы на текущий момент',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            formatMoney(summary.netBalance),
            style: TextStyle(
              fontSize: 32,
              height: 1,
              fontWeight: FontWeight.w900,
              color: tone,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _BalanceTotalTile(
                  label: 'Активы',
                  value: summary.assetsTotal,
                  color: const Color(0xFF16A34A),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BalanceTotalTile(
                  label: 'Пассивы',
                  value: summary.liabilitiesTotal,
                  color: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _BalanceDetailChip(
                label: 'Деньги',
                value: summary.cash,
                icon: Icons.payments_rounded,
              ),
              _BalanceDetailChip(
                label: 'Склад',
                value: summary.inventory,
                icon: Icons.inventory_2_rounded,
              ),
              _BalanceDetailChip(
                label: 'Дебиторка',
                value: summary.receivable,
                icon: Icons.call_received_rounded,
              ),
              _BalanceDetailChip(
                label: 'Кредиторка',
                value: summary.payable,
                icon: Icons.call_made_rounded,
              ),
              _BalanceDetailChip(
                label: 'Зарплата к выплате',
                value: summary.salaryDue,
                icon: Icons.badge_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceTotalTile extends StatelessWidget {
  const _BalanceTotalTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatMoney(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceDetailChip extends StatelessWidget {
  const _BalanceDetailChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            '$label: ${formatMoney(value)}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceHistoryCard extends StatelessWidget {
  const _BalanceHistoryCard({required this.weeks});

  final List<_CompanyBalanceWeek> weeks;

  @override
  Widget build(BuildContext context) {
    final maxAbs = weeks.fold<int>(
      0,
      (maxValue, week) =>
          week.netBalance.abs() > maxValue ? week.netBalance.abs() : maxValue,
    );
    final hasPositive = weeks.any((week) => week.netBalance > 0);
    final hasNegative = weeks.any((week) => week.netBalance < 0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Баланс за 8 недель',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Чистый баланс на конец каждой недели',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          if (weeks.isEmpty)
            const SizedBox(
              height: 156,
              child: Center(
                child: Text(
                  'История баланса пока недоступна',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
            )
          else
            SizedBox(
              height: 184,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final week in weeks)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          children: [
                            Expanded(
                              child: _BalanceBar(
                                value: week.netBalance,
                                maxAbs: maxAbs,
                                hasPositive: hasPositive,
                                hasNegative: hasNegative,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _balanceWeekLabel(week),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
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
    );
  }
}

class _BalanceBar extends StatelessWidget {
  const _BalanceBar({
    required this.value,
    required this.maxAbs,
    required this.hasPositive,
    required this.hasNegative,
  });

  final int value;
  final int maxAbs;
  final bool hasPositive;
  final bool hasNegative;

  @override
  Widget build(BuildContext context) {
    final color = value == 0
        ? const Color(0xFF94A3B8)
        : value > 0
            ? const Color(0xFF16A34A)
            : const Color(0xFFEF4444);
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final mixed = hasPositive && hasNegative;
        final zeroY = mixed ? height / 2 : (hasNegative ? 0.0 : height);
        final availableHeight = mixed ? (height / 2) - 8 : height - 12;
        final safeAvailableHeight =
            availableHeight < 4.0 ? 4.0 : availableHeight;
        final rawBarHeight =
            maxAbs == 0 ? 4.0 : (value.abs() / maxAbs) * safeAvailableHeight;
        final barHeight = rawBarHeight < 4.0 ? 4.0 : rawBarHeight;
        final negativeSpace = height - zeroY;
        final positiveHeight = barHeight > zeroY ? zeroY : barHeight;
        final negativeHeight =
            barHeight > negativeSpace ? negativeSpace : barHeight;

        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: zeroY.clamp(0.0, height - 1).toDouble(),
              child: Container(
                height: 1,
                color: const Color(0xFFE2E8F0),
              ),
            ),
            if (value >= 0)
              Positioned(
                left: 5,
                right: 5,
                top:
                    zeroY - positiveHeight < 0.0 ? 0.0 : zeroY - positiveHeight,
                height: positiveHeight,
                child: _BalanceBarFill(color: color),
              )
            else
              Positioned(
                left: 5,
                right: 5,
                top: zeroY,
                height: negativeHeight,
                child: _BalanceBarFill(color: color),
              ),
          ],
        );
      },
    );
  }
}

class _BalanceBarFill extends StatelessWidget {
  const _BalanceBarFill({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

String _balanceWeekLabel(_CompanyBalanceWeek week) {
  final parsed = DateTime.tryParse(week.weekEnd);
  if (parsed == null) return week.weekEnd;
  final day = parsed.day.toString().padLeft(2, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  return '$day.$month';
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
