part of 'business_shell.dart';

enum BusinessTab {
  dashboard,
  crm,
  warehouse,
  finance,
  more,
  production,
  sales,
  purchases,
  services,
  catalog,
}

String tabLabel(BusinessTab tab) {
  switch (tab) {
    case BusinessTab.dashboard:
      return 'Главная';
    case BusinessTab.crm:
      return 'CRM';
    case BusinessTab.warehouse:
      return 'Склад';
    case BusinessTab.finance:
      return 'Финансы';
    case BusinessTab.more:
      return 'Еще';
    case BusinessTab.production:
      return 'Производство';
    case BusinessTab.sales:
      return 'Продажи';
    case BusinessTab.purchases:
      return 'Закупки';
    case BusinessTab.services:
      return 'Услуги';
    case BusinessTab.catalog:
      return 'Справочник';
  }
}

IconData tabIcon(BusinessTab tab) {
  switch (tab) {
    case BusinessTab.dashboard:
      return Icons.home_rounded;
    case BusinessTab.crm:
      return Icons.group_rounded;
    case BusinessTab.warehouse:
      return Icons.inventory_2_rounded;
    case BusinessTab.finance:
      return Icons.account_balance_wallet_rounded;
    case BusinessTab.more:
      return Icons.more_horiz_rounded;
    case BusinessTab.production:
      return Icons.precision_manufacturing_rounded;
    case BusinessTab.sales:
      return Icons.shopping_bag_rounded;
    case BusinessTab.purchases:
      return Icons.shopping_cart_rounded;
    case BusinessTab.services:
      return Icons.handyman_rounded;
    case BusinessTab.catalog:
      return Icons.menu_book_rounded;
  }
}

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
    required this.tabs,
    required this.onTabSelected,
  });

  final BusinessTab activeTab;
  final List<BusinessTab> tabs;
  final ValueChanged<BusinessTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
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
              final isActive = tab == activeTab;
              return Expanded(
                child: InkWell(
                  onTap: () => onTabSelected(tab),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tabIcon(tab),
                        color: isActive
                            ? const Color(0xFF00A86B)
                            : const Color(0xFF7B8794),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tabLabel(tab),
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

class _FabMenuAction {
  const _FabMenuAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color color;
}

class _FabMenu extends StatelessWidget {
  const _FabMenu({
    required this.expanded,
    required this.actions,
    required this.onToggle,
    required this.onActionSelected,
  });

  final bool expanded;
  final List<_FabMenuAction> actions;
  final VoidCallback onToggle;
  final ValueChanged<_FabMenuAction> onActionSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (expanded)
          ...actions.map(
            (action) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: action.color,
                borderRadius: BorderRadius.circular(16),
                elevation: 6,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onActionSelected(action),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(action.icon, color: Colors.white, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          action.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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
    this.child,
    this.subtitle,
    this.trailing,
    this.onTitleTap,
  });

  final String title;
  final String? subtitle;
  final Widget? child;
  final Widget? trailing;
  final VoidCallback? onTitleTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 20, 16, child != null ? 34 : 20),
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
              padding: EdgeInsets.only(bottom: child != null ? 18 : 0),
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
                        if (onTitleTap != null)
                          GestureDetector(
                            onTap: onTitleTap,
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.expand_more_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ],
                            ),
                          )
                        else
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
              padding: EdgeInsets.only(bottom: child != null ? 18 : 0),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          if (child != null)
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
        midX,
        previous.dy,
        midX,
        current.dy,
        current.dx,
        current.dy,
      );
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

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 44, color: color),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Раздел в разработке',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
