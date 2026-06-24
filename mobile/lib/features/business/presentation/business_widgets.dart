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
  salary,
  reports,
  taxes,
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
    case BusinessTab.salary:
      return 'Зарплата';
    case BusinessTab.reports:
      return 'Отчеты';
    case BusinessTab.taxes:
      return 'Налоги';
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
    case BusinessTab.salary:
      return Icons.payments_rounded;
    case BusinessTab.reports:
      return Icons.bar_chart_rounded;
    case BusinessTab.taxes:
      return Icons.receipt_long_rounded;
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
    final tokens = context.appThemeTokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.navBackground,
        border: Border(top: BorderSide(color: tokens.border)),
        boxShadow: [
          BoxShadow(
            color: tokens.shadow,
            blurRadius: 20,
            offset: const Offset(0, -6),
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
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onTabSelected(tab),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: isActive ? 28 : 4,
                        height: 3,
                        decoration: BoxDecoration(
                          color: isActive ? tokens.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Icon(
                        tabIcon(tab),
                        color:
                            isActive ? tokens.primary : tokens.mutedForeground,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tabLabel(tab),
                        style: TextStyle(
                          color: isActive
                              ? tokens.primary
                              : tokens.mutedForeground,
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
    final tokens = context.appThemeTokens;

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
          backgroundColor: tokens.primary,
          foregroundColor: tokens.onPrimary,
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
    final tokens = context.appThemeTokens;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 20, 16, child != null ? 34 : 20),
      decoration: BoxDecoration(
        gradient: tokens.heroGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
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
                            style: TextStyle(
                              color: tokens.onPrimary.withValues(alpha: 0.8),
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
                                    style: TextStyle(
                                      color: tokens.onPrimary,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.expand_more_rounded,
                                  color: tokens.onPrimary,
                                  size: 26,
                                ),
                              ],
                            ),
                          )
                        else
                          Text(
                            title,
                            style: TextStyle(
                              color: tokens.onPrimary,
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
                style: TextStyle(
                  color: tokens.onPrimary,
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
                color: tokens.onPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: tokens.onPrimary.withValues(alpha: 0.2),
                ),
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
    final tokens = context.appThemeTokens;
    final content = Container(
      decoration: BoxDecoration(
        color: background == null ? tokens.card : null,
        gradient: background,
        borderRadius: BorderRadius.circular(18),
        border: background == null ? Border.all(color: tokens.border) : null,
        boxShadow: [
          BoxShadow(
            color: tokens.shadow,
            blurRadius: 20,
            offset: const Offset(0, 10),
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
        borderRadius: BorderRadius.circular(18),
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
    final tokens = context.appThemeTokens;

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 18,
                ),
          ),
        ),
        if (actionLabel != null)
          Text(
            actionLabel!,
            style: TextStyle(
              color: tokens.primary,
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
    final tokens = context.appThemeTokens;

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
                  style: TextStyle(
                    color: tokens.mutedForeground,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: tokens.cardForeground,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
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
    final tokens = context.appThemeTokens;
    final values = points.map((point) => point.value).toList(growable: false);
    if (points.isEmpty) {
      return Center(
        child: Text(
          'Нет данных для графика',
          style: TextStyle(
            color: tokens.mutedForeground,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: CustomPaint(
            painter: _LineChartPainter(
              values: values,
              gridColor: tokens.border,
              lineColor: tokens.chart1,
              dotBorderColor: tokens.card,
            ),
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
                  style: TextStyle(
                    fontSize: 11,
                    color: tokens.mutedForeground,
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
  const _LineChartPainter({
    required this.values,
    required this.gridColor,
    required this.lineColor,
    required this.dotBorderColor,
  });

  final List<double> values;
  final Color gridColor;
  final Color lineColor;
  final Color dotBorderColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) {
      return;
    }
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
      final x = values.length == 1
          ? size.width / 2
          : size.width * index / (values.length - 1);
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
      ..shader = LinearGradient(
        colors: [
          lineColor.withValues(alpha: 0.32),
          lineColor.withValues(alpha: 0),
        ],
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
    final dotBorderPaint = Paint()..color = dotBorderColor;
    for (var i = 0; i < values.length; i++) {
      final point = pointFor(i);
      canvas.drawCircle(point, 4.5, dotBorderPaint);
      canvas.drawCircle(point, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.dotBorderColor != dotBorderColor;
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});

  final _Activity activity;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;

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
                style: TextStyle(
                  color: tokens.cardForeground,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                activity.time,
                style: TextStyle(
                  fontSize: 12,
                  color: tokens.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        Text(
          activity.amount,
          style: TextStyle(
            color: tokens.cardForeground,
            fontWeight: FontWeight.w800,
          ),
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
    final tokens = context.appThemeTokens;

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
            style: TextStyle(
              fontSize: 11,
              color: tokens.mutedForeground,
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
    final tokens = context.appThemeTokens;
    late final Color background;
    late final Color foreground;
    late final Color borderColor;

    switch (kind) {
      case StatusKind.success:
        background = tokens.tone(tokens.success);
        foreground = tokens.success;
        borderColor = tokens.success.withValues(alpha: 0.2);
        break;
      case StatusKind.warning:
        background = tokens.tone(tokens.warning);
        foreground = tokens.warning;
        borderColor = tokens.warning.withValues(alpha: 0.2);
        break;
      case StatusKind.error:
        background = tokens.tone(tokens.destructive);
        foreground = tokens.destructive;
        borderColor = tokens.destructive.withValues(alpha: 0.2);
        break;
      case StatusKind.info:
        background = tokens.tone(tokens.info);
        foreground = tokens.info;
        borderColor = tokens.info.withValues(alpha: 0.2);
        break;
      case StatusKind.neutral:
        background = tokens.secondary;
        foreground = tokens.mutedForeground;
        borderColor = tokens.border;
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
    final tokens = context.appThemeTokens;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          _TileIcon(
            icon: icon,
            color: tokens.mutedForeground,
            tone: tokens.secondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: tokens.mutedForeground,
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
    final tokens = context.appThemeTokens;
    final effectiveTone =
        tokens.brightness == Brightness.dark && tone.computeLuminance() > 0.75
            ? tokens.muted
            : tone;

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: effectiveTone,
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
    final tokens = context.appThemeTokens;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? activeColor : tokens.secondary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? activeColor.withValues(alpha: 0.4) : tokens.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : tokens.secondaryForeground,
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
    final tokens = context.appThemeTokens;

    return Column(
      crossAxisAlignment: textAlign == TextAlign.right
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: tokens.mutedForeground,
            fontSize: 12,
          ),
          textAlign: textAlign,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: valueColor ?? tokens.cardForeground,
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

class _CompanyAvatar extends StatelessWidget {
  const _CompanyAvatar({
    required this.name,
    required this.accessToken,
    required this.size,
    required this.foregroundColor,
    required this.backgroundColor,
    this.logoUrl,
    this.icon,
    this.useIconFallback = false,
  });

  final String name;
  final String accessToken;
  final double size;
  final Color foregroundColor;
  final Color backgroundColor;
  final String? logoUrl;
  final IconData? icon;
  final bool useIconFallback;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = _resolvedApiUrl(logoUrl);
    if (resolvedUrl == null) {
      return _CircleInitials(
        text: name,
        size: size,
        foregroundColor: foregroundColor,
        backgroundColor: backgroundColor,
        icon: icon,
        useIcon: useIconFallback,
      );
    }

    return ClipOval(
      child: Image.network(
        resolvedUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        headers: {'Authorization': 'Bearer $accessToken'},
        errorBuilder: (_, __, ___) => _CircleInitials(
          text: name,
          size: size,
          foregroundColor: foregroundColor,
          backgroundColor: backgroundColor,
          icon: icon,
          useIcon: useIconFallback,
        ),
      ),
    );
  }
}

String? _resolvedApiUrl(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  return '${ApiConfig.baseUrl}$trimmed';
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
    final tokens = context.appThemeTokens;
    if (categories.isEmpty ||
        categories.every((category) => category.value <= 0)) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'Нет расходов за период',
            style: TextStyle(
              color: tokens.mutedForeground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 180,
            child: CustomPaint(
              painter: _DonutChartPainter(
                categories: categories,
                labelColor: tokens.cardForeground,
              ),
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
                                style: TextStyle(
                                  color: tokens.cardForeground,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                formatMoney(category.value),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: tokens.mutedForeground,
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
  const _DonutChartPainter({
    required this.categories,
    required this.labelColor,
  });

  final List<_ExpenseCategory> categories;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final total = categories.fold<double>(0, (sum, item) => sum + item.value);
    if (total <= 0) {
      return;
    }
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
      text: TextSpan(
        text: 'Расходы',
        style: TextStyle(
          color: labelColor,
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
    return oldDelegate.categories != categories ||
        oldDelegate.labelColor != labelColor;
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction});

  final _Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    final income = transaction.type == TransactionType.income;
    final valueColor = income ? tokens.success : tokens.destructive;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: tokens.tone(valueColor),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            income ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: valueColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transaction.description,
                style: TextStyle(
                  color: tokens.cardForeground,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${transaction.category} • ${transaction.account}',
                style: TextStyle(
                  color: tokens.mutedForeground,
                  fontSize: 12,
                ),
              ),
              Text(
                transaction.date,
                style: TextStyle(
                  color: tokens.mutedForeground,
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
            color: valueColor,
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
    final tokens = context.appThemeTokens;
    final effectiveTone =
        tokens.brightness == Brightness.dark && tone.computeLuminance() > 0.75
            ? tokens.secondary
            : tone;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: effectiveTone,
        borderRadius: BorderRadius.circular(18),
        border: highlighted
            ? Border.all(color: tokens.primary.withValues(alpha: 0.2), width: 2)
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
                  style: TextStyle(
                    color: tokens.mutedForeground,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: tokens.cardForeground,
                    fontWeight: FontWeight.w700,
                  ),
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
    final tokens = context.appThemeTokens;

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
                style: TextStyle(
                  color: tokens.cardForeground,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: tokens.mutedForeground,
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
              color: tokens.warning,
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
        Icon(
          Icons.chevron_right_rounded,
          color: tokens.mutedForeground,
        ),
      ],
    );
  }
}

class _ThemePresetTile extends StatelessWidget {
  const _ThemePresetTile({
    required this.preset,
    required this.currentPreset,
    required this.onTap,
  });

  final AppThemePreset preset;
  final AppThemePreset currentPreset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    final presetTokens = preset.tokens;
    final selected = preset == currentPreset;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? tokens.primary.withValues(alpha: 0.08)
                : tokens.secondary,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? tokens.primary : tokens.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              _TileIcon(
                icon: preset.icon,
                color: presetTokens.primary,
                tone: presetTokens.primary.withValues(alpha: 0.12),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset.label,
                      style: TextStyle(
                        color: tokens.cardForeground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      preset.description,
                      style: TextStyle(
                        color: tokens.mutedForeground,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _ThemeSwatch(color: presetTokens.primary),
                        _ThemeSwatch(color: presetTokens.background),
                        _ThemeSwatch(color: presetTokens.card),
                        _ThemeSwatch(color: presetTokens.info),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? tokens.primary : tokens.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;

    return Container(
      width: 22,
      height: 22,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: tokens.border),
      ),
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
    final tokens = context.appThemeTokens;

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
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: tokens.foreground,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Раздел в разработке',
                style: TextStyle(
                  fontSize: 15,
                  color: tokens.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
