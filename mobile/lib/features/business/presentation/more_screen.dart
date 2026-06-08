part of 'business_shell.dart';

class _MoreScreen extends StatefulWidget {
  const _MoreScreen({
    required this.session,
    required this.overview,
    required this.onLogout,
    required this.onOpenProfile,
    required this.onNavSettingsOpen,
    required this.businessGateway,
    required this.onOpenCompanyEditor,
    this.activeCompany,
  });

  final AuthSession session;
  final _OverviewData overview;
  final VoidCallback onLogout;
  final Future<void> Function() onOpenProfile;
  final VoidCallback onNavSettingsOpen;
  final BusinessGateway businessGateway;
  final Future<void> Function() onOpenCompanyEditor;
  final _Company? activeCompany;

  @override
  State<_MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<_MoreScreen> {
  bool _showProfile = false;
  bool _darkMode = false;
  bool _loadingDetail = false;
  _Company? _detailCompany;

  Future<void> _loadDetail() async {
    final id = widget.activeCompany?.id;
    if (id == null || id.isEmpty) return;
    setState(() => _loadingDetail = true);
    try {
      final data = await widget.businessGateway.fetchCompany(
        accessToken: widget.session.accessToken,
        companyId: id,
      );
      if (!mounted) return;
      setState(() {
        _detailCompany = _companyDetailFromJson(data);
        _loadingDetail = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final _Company? active = widget.activeCompany;
    final company = CompanyProfile(
      name: active?.name ?? widget.overview.companyName,
      country: active?.country ??
          (widget.session.user.companies.isNotEmpty
              ? widget.session.user.companies.first.country
              : 'KZ'),
      iin: active?.iin ??
          (widget.session.user.companies.isNotEmpty
              ? widget.session.user.companies.first.iin
              : ''),
    );

    if (_showProfile) {
      final detail = _detailCompany;
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
                        if ((detail?.legalForm ?? '').isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            detail!.legalForm!,
                            style: const TextStyle(color: Color(0xCCFFFFFF)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_loadingDetail)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(color: Color(0xFF00A86B)),
                ),
              )
            else ...[
              _BusinessCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Реквизиты компании',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    _InfoTile(
                      icon: Icons.badge_rounded,
                      label: company.country == 'KZ'
                          ? 'ИИН / БИН'
                          : 'Идентификатор',
                      value: company.iin.isEmpty ? 'Не указан' : company.iin,
                    ),
                    _InfoTile(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'ИИК',
                      value: (detail?.bankAccount?.isNotEmpty == true)
                          ? detail!.bankAccount!
                          : 'Не указан',
                    ),
                    _InfoTile(
                      icon: Icons.account_balance_rounded,
                      label: 'БИК',
                      value: (detail?.bankBik?.isNotEmpty == true)
                          ? detail!.bankBik!
                          : 'Не указан',
                    ),
                    if (detail?.bankName?.isNotEmpty == true)
                      _InfoTile(
                        icon: Icons.business_rounded,
                        label: 'Банк',
                        value: detail!.bankName!,
                      ),
                    const _InfoTile(
                      icon: Icons.check_circle_rounded,
                      label: 'НДС плательщик',
                      value: 'Не указано',
                      valueColor: Color(0xFF64748B),
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
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    _InfoTile(
                      icon: Icons.location_on_rounded,
                      label: 'Адрес',
                      value: _buildAddress(detail),
                    ),
                    _InfoTile(
                      icon: Icons.phone_rounded,
                      label: 'Телефон',
                      value: (detail?.phone?.isNotEmpty == true)
                          ? detail!.phone!
                          : widget.session.user.phone,
                    ),
                    _InfoTile(
                      icon: Icons.mail_rounded,
                      label: 'Email',
                      value: (detail?.email?.isNotEmpty == true)
                          ? detail!.email!
                          : 'Не указан',
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
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: active != null &&
                              (active.role == 'owner' || active.role == 'admin')
                          ? widget.onOpenCompanyEditor
                          : null,
                      icon: const Icon(Icons.business_rounded, size: 18),
                      label: const Text('Компания'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF00A86B),
                        side: const BorderSide(color: Color(0xFF00A86B)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onOpenProfile,
                      icon: const Icon(Icons.person_rounded, size: 18),
                      label: const Text('Профиль'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
              onTap: () {
                setState(() => _showProfile = true);
                if (_detailCompany == null) {
                  _loadDetail();
                }
              },
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
                        InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: widget.onNavSettingsOpen,
                          child: const _MenuTile(
                            icon: Icons.tune_rounded,
                            iconColor: Color(0xFF3B82F6),
                            iconTone: Color(0x143B82F6),
                            title: 'Настройка навигации',
                            subtitle: 'Разделы в панели',
                          ),
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

  String _buildAddress(_Company? detail) {
    final parts = <String>[];
    if (detail?.city?.isNotEmpty == true) {
      parts.add(detail!.city!);
    }
    if (detail?.addressLine?.isNotEmpty == true) {
      parts.add(detail!.addressLine!);
    }
    if (detail?.region?.isNotEmpty == true) {
      parts.add(detail!.region!);
    }
    return parts.isEmpty ? 'Не указан' : parts.join(', ');
  }
}
