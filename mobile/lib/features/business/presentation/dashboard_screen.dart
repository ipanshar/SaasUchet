part of 'business_shell.dart';

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
