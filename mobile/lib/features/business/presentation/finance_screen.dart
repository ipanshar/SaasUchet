part of 'business_shell.dart';

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
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
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
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
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
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
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
