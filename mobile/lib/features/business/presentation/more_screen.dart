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
    required this.hiddenTabs,
    required this.onOpenHiddenTab,
    required this.onOpenBusinessTab,
    required this.themePreset,
    required this.onThemeChanged,
    required this.startTab,
    required this.onStartTabChanged,
    required this.bottomNavTabs,
    this.activeCompany,
  });

  final AuthSession session;
  final _OverviewData overview;
  final VoidCallback onLogout;
  final Future<void> Function() onOpenProfile;
  final VoidCallback onNavSettingsOpen;
  final BusinessGateway businessGateway;
  final Future<void> Function() onOpenCompanyEditor;
  final List<BusinessTab> hiddenTabs;
  final Future<void> Function(BusinessTab tab) onOpenHiddenTab;
  final Future<void> Function(BusinessTab tab) onOpenBusinessTab;
  final AppThemePreset themePreset;
  final ValueChanged<AppThemePreset> onThemeChanged;
  final BusinessTab startTab;
  final Future<void> Function(BusinessTab tab) onStartTabChanged;
  final List<BusinessTab> bottomNavTabs;
  final _Company? activeCompany;

  @override
  State<_MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<_MoreScreen> {
  _MoreSection _section = _MoreSection.menu;
  bool _loadingDetail = false;
  bool _isUsersLoading = false;
  bool _isNotificationsLoading = false;
  bool _isDocumentsLoading = false;
  _Company? _detailCompany;
  List<_MoreCompanyMemberVm> _members = const [];
  List<_MoneyDocument> _notificationMoneyDocuments = const [];
  Set<String> _seenNotificationIds = <String>{};
  List<_InventoryDocument> _inventoryDocuments = const [];
  List<_MoneyDocument> _moneyDocuments = const [];
  _MoreDocumentsView _documentsView = _MoreDocumentsView.inventory;
  String _documentsType = '';
  final TextEditingController _documentsSearchController =
      TextEditingController();
  final Set<String> _expandedFaqIds = <String>{};

  @override
  void initState() {
    super.initState();
    _restoreSeenNotifications();
    _loadNotifications(showLoading: false);
  }

  @override
  void didUpdateWidget(covariant _MoreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final companyChanged =
        oldWidget.activeCompany?.id != widget.activeCompany?.id;
    final userChanged = oldWidget.session.user.id != widget.session.user.id;
    if (companyChanged || userChanged) {
      _seenNotificationIds = <String>{};
      _notificationMoneyDocuments = const [];
      _restoreSeenNotifications();
      _loadNotifications(showLoading: false);
      return;
    }
    if (oldWidget.overview.products != widget.overview.products) {
      _syncSeenNotifications();
    }
  }

  String get _notificationSeenPrefKey =>
      'more_seen_notifications_${widget.session.user.id}_${widget.activeCompany?.id ?? widget.overview.companyName}';

  List<_Product> get _lowStockProducts => widget.overview.products
      .where(
          (item) => item.minQuantity > 0 && item.quantity <= item.minQuantity)
      .toList(growable: false);

  int get _unreadNotificationsCount => _currentNotificationIds()
      .where((id) => !_seenNotificationIds.contains(id))
      .length;

  String _lowStockNotificationId(_Product product) => 'low_stock:${product.id}';

  String _moneyDocumentNotificationId(_MoneyDocument document) =>
      'money_due:${document.id}';

  Set<String> _currentNotificationIds({
    List<_MoneyDocument>? moneyDocuments,
  }) =>
      {
        for (final product in _lowStockProducts)
          _lowStockNotificationId(product),
        for (final document in moneyDocuments ?? _notificationMoneyDocuments)
          _moneyDocumentNotificationId(document),
      };

  Future<void> _restoreSeenNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_notificationSeenPrefKey) ?? const [];
      if (!mounted) {
        return;
      }
      setState(() {
        _seenNotificationIds = stored.toSet();
      });
    } catch (_) {
      // Keep unread state in memory only if preferences are unavailable.
    }
  }

  Future<void> _persistSeenNotifications(Set<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _notificationSeenPrefKey,
        ids.toList(growable: false),
      );
    } catch (_) {
      // Non-fatal: unread markers will persist only for the current session.
    }
  }

  Future<void> _syncSeenNotifications({
    List<_MoneyDocument>? moneyDocuments,
  }) async {
    final activeIds = _currentNotificationIds(moneyDocuments: moneyDocuments);
    final nextSeen = _seenNotificationIds.where(activeIds.contains).toSet();
    if (_sameStringSet(nextSeen, _seenNotificationIds)) {
      return;
    }
    if (mounted) {
      setState(() {
        _seenNotificationIds = nextSeen;
      });
    }
    await _persistSeenNotifications(nextSeen);
  }

  Future<void> _markNotificationsViewed() async {
    final nextSeen = {
      ..._seenNotificationIds,
      ..._currentNotificationIds(),
    };
    if (_sameStringSet(nextSeen, _seenNotificationIds)) {
      return;
    }
    if (mounted) {
      setState(() {
        _seenNotificationIds = nextSeen;
      });
    }
    await _persistSeenNotifications(nextSeen);
  }

  bool _sameStringSet(Set<String> left, Set<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (final value in left) {
      if (!right.contains(value)) {
        return false;
      }
    }
    return true;
  }

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

  Future<void> _loadUsers() async {
    final companyId = widget.activeCompany?.id;
    if (companyId == null || companyId.isEmpty) return;
    setState(() => _isUsersLoading = true);
    try {
      final data = await widget.businessGateway.fetchCompanyMembers(
        accessToken: widget.session.accessToken,
        companyId: companyId,
      );
      if (!mounted) return;
      setState(() {
        _members =
            data.map(_MoreCompanyMemberVm.fromJson).toList(growable: false);
        _isUsersLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUsersLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _openUsers() async {
    setState(() => _section = _MoreSection.users);
    await _loadUsers();
  }

  Future<void> _openCompany() async {
    setState(() => _section = _MoreSection.company);
    if (_detailCompany == null) {
      await _loadDetail();
    }
  }

  Future<void> _openNotifications() async {
    setState(() => _section = _MoreSection.notifications);
    await _loadNotifications();
    await _markNotificationsViewed();
  }

  Future<void> _loadNotifications({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _isNotificationsLoading = true);
    }
    try {
      final payload = await widget.businessGateway.fetchMoneyDocuments(
        accessToken: widget.session.accessToken,
      );
      final documents = payload
          .map(_moneyDocumentFromJson)
          .where((item) => item.remainingAmount > 0)
          .toList(growable: false);
      final nextSeen = _seenNotificationIds
          .where(_currentNotificationIds(moneyDocuments: documents).contains)
          .toSet();
      if (!mounted) {
        return;
      }
      setState(() {
        _notificationMoneyDocuments = documents;
        _seenNotificationIds = nextSeen;
        _isNotificationsLoading = false;
      });
      await _persistSeenNotifications(nextSeen);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _isNotificationsLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _openDocuments({
    _MoreDocumentsView view = _MoreDocumentsView.inventory,
  }) async {
    setState(() {
      _section = _MoreSection.documents;
      _documentsView = view;
      _documentsType = '';
    });
    _documentsSearchController.clear();
    await _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isDocumentsLoading = true);
    try {
      if (_documentsView == _MoreDocumentsView.inventory) {
        final payload = await widget.businessGateway.fetchInventoryDocuments(
          accessToken: widget.session.accessToken,
          type: _documentsType.isEmpty ? null : _documentsType,
          search: _documentsSearchController.text.trim().isEmpty
              ? null
              : _documentsSearchController.text.trim(),
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _inventoryDocuments =
              payload.map(_inventoryDocumentFromJson).toList(growable: false);
          _isDocumentsLoading = false;
        });
        return;
      }

      final payload = await widget.businessGateway.fetchMoneyDocuments(
        accessToken: widget.session.accessToken,
        type: _documentsType.isEmpty ? null : _documentsType,
        search: _documentsSearchController.text.trim().isEmpty
            ? null
            : _documentsSearchController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _moneyDocuments =
            payload.map(_moneyDocumentFromJson).toList(growable: false);
        _isDocumentsLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _isDocumentsLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _openSettings() {
    setState(() => _section = _MoreSection.settings);
  }

  void _openHelp() {
    setState(() => _section = _MoreSection.help);
  }

  void _closeSection() {
    setState(() => _section = _MoreSection.menu);
  }

  @override
  void dispose() {
    _documentsSearchController.dispose();
    super.dispose();
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

    if (_section == _MoreSection.users) {
      final canManageUsers =
          active != null && (active.role == 'owner' || active.role == 'admin');
      return SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            TextButton.icon(
              onPressed: _closeSection,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Назад'),
            ),
            const SizedBox(height: 8),
            _BusinessCard(
              background: const LinearGradient(
                colors: [Color(0xFF64748B), Color(0xFF475569)],
              ),
              child: Row(
                children: [
                  const _CircleInitials(
                    text: 'Пользователи',
                    size: 80,
                    foregroundColor: Colors.white,
                    backgroundColor: Color(0x33FFFFFF),
                    icon: Icons.groups_rounded,
                    useIcon: true,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Пользователи',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_members.length} в компании',
                          style: const TextStyle(color: Color(0xCCFFFFFF)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildUsersCard(canManageUsers: canManageUsers),
          ],
        ),
      );
    }

    if (_section == _MoreSection.notifications) {
      return _buildNotificationsPage();
    }

    if (_section == _MoreSection.documents) {
      return _buildDocumentsPage();
    }

    if (_section == _MoreSection.settings) {
      return _buildSettingsPage();
    }

    if (_section == _MoreSection.help) {
      return _buildHelpPage();
    }

    if (_section == _MoreSection.company) {
      final detail = _detailCompany;
      return SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            TextButton.icon(
              onPressed: _closeSection,
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
                  _CompanyAvatar(
                    name: company.name,
                    logoUrl: detail?.logoUrl ?? active?.logoUrl,
                    accessToken: widget.session.accessToken,
                    size: 80,
                    foregroundColor: Colors.white,
                    backgroundColor: const Color(0x33FFFFFF),
                    icon: Icons.business_rounded,
                    useIconFallback: true,
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
              onTap: () => _openCompany(),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0x1AFFFFFF),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0x33FFFFFF)),
                ),
                child: Row(
                  children: [
                    _CompanyAvatar(
                      name: company.name,
                      logoUrl: active?.logoUrl,
                      accessToken: widget.session.accessToken,
                      size: 64,
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0x33FFFFFF),
                      icon: Icons.business_rounded,
                      useIconFallback: true,
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
                  _buildHiddenTabsCard(),
                  const SizedBox(height: 16),
                  _BusinessCard(
                    child: Column(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _openNotifications(),
                          child: _MenuTile(
                            icon: Icons.notifications_rounded,
                            iconColor: const Color(0xFFF59E0B),
                            iconTone: const Color(0x14F59E0B),
                            title: 'Уведомления',
                            subtitle: 'Напоминания и события',
                            badge: _unreadNotificationsCount > 0
                                ? '$_unreadNotificationsCount'
                                : null,
                          ),
                        ),
                        const Divider(height: 24),
                        InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _openDocuments(),
                          child: const _MenuTile(
                            icon: Icons.description_rounded,
                            iconColor: Color(0xFF64748B),
                            iconTone: Color(0xFFF1F5F9),
                            title: 'Документы',
                            subtitle: 'Поиск и просмотр',
                          ),
                        ),
                        const Divider(height: 24),
                        InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _openUsers(),
                          child: const _MenuTile(
                            icon: Icons.groups_rounded,
                            iconColor: Color(0xFF64748B),
                            iconTone: Color(0xFFF1F5F9),
                            title: 'Пользователи',
                            subtitle: 'Список сотрудников и ролей',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _BusinessCard(
                    child: Column(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: _openSettings,
                          child: const _MenuTile(
                            icon: Icons.settings_rounded,
                            iconColor: Color(0xFF64748B),
                            iconTone: Color(0xFFF1F5F9),
                            title: 'Настройки',
                            subtitle: 'Тема, стартовый раздел и навигация',
                          ),
                        ),
                        const Divider(height: 24),
                        InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: _openHelp,
                          child: const _MenuTile(
                            icon: Icons.help_rounded,
                            iconColor: Color(0xFF64748B),
                            iconTone: Color(0xFFF1F5F9),
                            title: 'Помощь',
                            subtitle: 'FAQ и поддержка',
                          ),
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

  Future<void> _showAddMemberDialog() async {
    final companyId = widget.activeCompany?.id;
    if (companyId == null || companyId.isEmpty) return;
    var selectedRole = 'staff';
    final phoneCtrl = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Добавить пользователя'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Телефон',
                    hintText: '+7 777 123 45 67',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  items: _moreMemberRoles
                      .map(
                        (role) => DropdownMenuItem<String>(
                          value: role,
                          child: Text(_moreRoleLabel(role)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => selectedRole = value);
                  },
                  decoration: const InputDecoration(labelText: 'Роль'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Добавить'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true) return;
      final data = await widget.businessGateway.addCompanyMember(
        accessToken: widget.session.accessToken,
        companyId: companyId,
        payload: {
          'phone': phoneCtrl.text.trim(),
          'role': selectedRole,
        },
      );
      if (!mounted) return;
      final next = _MoreCompanyMemberVm.fromJson(data);
      setState(() {
        final index = _members.indexWhere((item) => item.userId == next.userId);
        if (index >= 0) {
          _members = [
            ..._members.sublist(0, index),
            next,
            ..._members.sublist(index + 1),
          ];
        } else {
          _members = [..._members, next];
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      phoneCtrl.dispose();
    }
  }

  Future<void> _changeMemberRole(_MoreCompanyMemberVm member) async {
    final companyId = widget.activeCompany?.id;
    if (companyId == null || companyId.isEmpty) return;
    var selectedRole = member.role;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(
                'Роль: ${member.fullName.isEmpty ? member.phone : member.fullName}'),
            content: DropdownButtonFormField<String>(
              initialValue: selectedRole,
              items: _moreMemberRoles
                  .map(
                    (role) => DropdownMenuItem<String>(
                      value: role,
                      child: Text(_moreRoleLabel(role)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) return;
                setDialogState(() => selectedRole = value);
              },
              decoration: const InputDecoration(labelText: 'Роль'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Сохранить'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true || selectedRole == member.role) return;
      final data = await widget.businessGateway.updateCompanyMemberRole(
        accessToken: widget.session.accessToken,
        companyId: companyId,
        userId: member.userId,
        payload: {'role': selectedRole},
      );
      if (!mounted) return;
      final updated = _MoreCompanyMemberVm.fromJson(data);
      setState(() {
        _members = _members
            .map((item) => item.userId == updated.userId ? updated : item)
            .toList(growable: false);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _removeMember(_MoreCompanyMemberVm member) async {
    final companyId = widget.activeCompany?.id;
    if (companyId == null || companyId.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить пользователя?'),
        content: Text(
          'Пользователь ${member.fullName.isEmpty ? member.phone : member.fullName} потеряет доступ к компании.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.businessGateway.removeCompanyMember(
        accessToken: widget.session.accessToken,
        companyId: companyId,
        userId: member.userId,
      );
      if (!mounted) return;
      setState(() {
        _members = _members
            .where((item) => item.userId != member.userId)
            .toList(growable: false);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
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

  Widget _buildUsersCard({required bool canManageUsers}) {
    return _BusinessCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Пользователи',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              if (canManageUsers)
                TextButton.icon(
                  onPressed: () => _showAddMemberDialog(),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Добавить'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_isUsersLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF00A86B)),
              ),
            )
          else if (_members.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Пользователи пока не добавлены',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            )
          else
            ..._members.map(
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
                        text: member.fullName.isEmpty
                            ? member.phone
                            : member.fullName,
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
                              member.fullName.isEmpty
                                  ? member.phone
                                  : member.fullName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              member.roleLabel,
                              style: const TextStyle(
                                color: Color(0xFF7B8794),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (canManageUsers &&
                          !member.isOwner &&
                          !member.isCurrentUser)
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'role') {
                              _changeMemberRole(member);
                              return;
                            }
                            if (value == 'remove') {
                              _removeMember(member);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem<String>(
                              value: 'role',
                              child: Text('Назначить роль'),
                            ),
                            PopupMenuItem<String>(
                              value: 'remove',
                              child: Text('Удалить'),
                            ),
                          ],
                          icon: const Icon(
                            Icons.more_horiz_rounded,
                            color: Color(0xFF9AA5B1),
                          ),
                        )
                      else
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
    );
  }

  Widget _buildNotificationsPage() {
    final lowStockProducts = _lowStockProducts;
    final unpaidDocuments = _notificationMoneyDocuments;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          TextButton.icon(
            onPressed: _closeSection,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Назад'),
          ),
          const SizedBox(height: 8),
          _BusinessCard(
            background: const LinearGradient(
              colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
            ),
            child: Row(
              children: [
                const _CircleInitials(
                  text: 'Уведомления',
                  size: 80,
                  foregroundColor: Colors.white,
                  backgroundColor: Color(0x33FFFFFF),
                  icon: Icons.notifications_rounded,
                  useIcon: true,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Уведомления',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${lowStockProducts.length + unpaidDocuments.length} активных событий',
                        style: const TextStyle(color: Color(0xCCFFFFFF)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_isNotificationsLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(color: Color(0xFF00A86B)),
              ),
            )
          else ...[
            if (lowStockProducts.isNotEmpty)
              _BusinessCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Низкий остаток',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    ...lowStockProducts.map(
                      (product) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () async {
                            _closeSection();
                            await widget
                                .onOpenBusinessTab(BusinessTab.warehouse);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                const _TileIcon(
                                  icon: Icons.inventory_2_rounded,
                                  color: Color(0xFFD97706),
                                  tone: Color(0xFFFFF3C4),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        'Остаток ${product.quantity} ${product.unitName} · минимум ${product.minQuantity}',
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
                    ),
                  ],
                ),
              ),
            if (lowStockProducts.isNotEmpty && unpaidDocuments.isNotEmpty)
              const SizedBox(height: 16),
            if (unpaidDocuments.isNotEmpty)
              _BusinessCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Неоплаченные документы',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    ...unpaidDocuments.map(
                      (document) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _openDocuments(
                            view: _MoreDocumentsView.money,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                const _TileIcon(
                                  icon: Icons.receipt_long_rounded,
                                  color: Color(0xFF2563EB),
                                  tone: Color(0xFFEFF6FF),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        document.documentNo,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        '${_moneyDocumentTypeLabel(document.documentType)} · остаток ${formatMoney(document.remainingAmount)}',
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
                    ),
                  ],
                ),
              ),
            if (lowStockProducts.isEmpty && unpaidDocuments.isEmpty)
              const _BusinessCard(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      _TileIcon(
                        icon: Icons.check_circle_rounded,
                        color: Color(0xFF16A34A),
                        tone: Color(0x1422C55E),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Активных уведомлений нет',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildDocumentsPage() {
    final isInventory = _documentsView == _MoreDocumentsView.inventory;
    final documents = isInventory ? _inventoryDocuments : _moneyDocuments;
    final typeOptions =
        isInventory ? _inventoryDocumentTypeOptions : _moneyDocumentTypeOptions;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          TextButton.icon(
            onPressed: _closeSection,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Назад'),
          ),
          const SizedBox(height: 8),
          _BusinessCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Документы',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                SegmentedButton<_MoreDocumentsView>(
                  segments: const [
                    ButtonSegment(
                      value: _MoreDocumentsView.inventory,
                      label: Text('Складские'),
                    ),
                    ButtonSegment(
                      value: _MoreDocumentsView.money,
                      label: Text('Денежные'),
                    ),
                  ],
                  selected: {_documentsView},
                  onSelectionChanged: (selection) async {
                    setState(() {
                      _documentsView = selection.first;
                      _documentsType = '';
                    });
                    await _loadDocuments();
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _documentsSearchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _loadDocuments(),
                  decoration: InputDecoration(
                    labelText: 'Поиск по номеру, контрагенту или примечанию',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_documentsSearchController.text.isNotEmpty)
                          IconButton(
                            onPressed: () async {
                              _documentsSearchController.clear();
                              await _loadDocuments();
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                        IconButton(
                          onPressed: () => _loadDocuments(),
                          icon: const Icon(Icons.arrow_forward_rounded),
                        ),
                      ],
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChipButton(
                        label: 'Все',
                        active: _documentsType.isEmpty,
                        activeColor: const Color(0xFF00A86B),
                        onPressed: () async {
                          setState(() => _documentsType = '');
                          await _loadDocuments();
                        },
                      ),
                      ...typeOptions.map(
                        (option) => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: _FilterChipButton(
                            label: option.label,
                            active: _documentsType == option.value,
                            activeColor: option.color,
                            onPressed: () async {
                              setState(() => _documentsType = option.value);
                              await _loadDocuments();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_isDocumentsLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(color: Color(0xFF00A86B)),
              ),
            )
          else if (documents.isEmpty)
            const _BusinessCard(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    _TileIcon(
                      icon: Icons.inbox_rounded,
                      color: Color(0xFF64748B),
                      tone: Color(0xFFF1F5F9),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Документы не найдены',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...documents.map(
              (document) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () async {
                    if (document is _InventoryDocument) {
                      await _openInventoryDocumentDetail(document);
                      return;
                    }
                    if (document is _MoneyDocument) {
                      await _openMoneyDocumentDetail(document);
                    }
                  },
                  child: _BusinessCard(
                    child: document is _InventoryDocument
                        ? _buildInventoryDocumentTile(document)
                        : _buildMoneyDocumentTile(document as _MoneyDocument),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInventoryDocumentTile(_InventoryDocument document) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                document.documentNo,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            _StatusBadge(
              label: _documentTypeLabel(document.documentType),
              kind: _documentStatusKind(document.status),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${document.warehouseName.isEmpty ? 'Без склада' : document.warehouseName} · ${document.documentDate}',
          style: const TextStyle(color: Color(0xFF7B8794), fontSize: 12),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _LabelValue(
                label: 'Количество',
                value: '${document.totalQuantity}',
              ),
            ),
            Expanded(
              child: _LabelValue(
                label: 'Сумма',
                value: formatMoney(document.totalAmount),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMoneyDocumentTile(_MoneyDocument document) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                document.documentNo,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            _StatusBadge(
              label: _moneyDocumentTypeLabel(document.documentType),
              kind: document.remainingAmount > 0
                  ? StatusKind.warning
                  : StatusKind.success,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${document.primaryAccount}${document.secondaryAccount.isEmpty ? '' : ' → ${document.secondaryAccount}'}',
          style: const TextStyle(color: Color(0xFF7B8794), fontSize: 12),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _LabelValue(
                label: 'Сумма',
                value: formatMoney(document.amount),
              ),
            ),
            Expanded(
              child: _LabelValue(
                label: 'Остаток',
                value: formatMoney(document.remainingAmount),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openInventoryDocumentDetail(_InventoryDocument document) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _DocumentDetailScreen(
          accessToken: widget.session.accessToken,
          businessGateway: widget.businessGateway,
          companyId: widget.activeCompany?.id ?? '',
          clients: widget.overview.clients,
          document: document,
          accentColor: const Color(0xFF00A86B),
          counterpartyLabel: 'Контрагент',
        ),
      ),
    );
  }

  Future<void> _openMoneyDocumentDetail(_MoneyDocument document) async {
    try {
      final payload = await widget.businessGateway.fetchMoneyDocumentDetail(
        accessToken: widget.session.accessToken,
        documentId: document.id,
      );
      if (!mounted) {
        return;
      }
      final detail = _moneyDocumentDetailFromJson(payload);
      final wasSettled = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _MoneyDocumentDetailSheet(
          accessToken: widget.session.accessToken,
          businessGateway: widget.businessGateway,
          accounts: widget.overview.finance.accounts,
          detail: detail,
          onSettled: () async {
            await _loadDocuments();
            await _loadNotifications();
          },
        ),
      );
      if (wasSettled == true) {
        await _loadDocuments();
        await _loadNotifications();
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Widget _buildSettingsPage() {
    final tokens = context.appThemeTokens;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          TextButton.icon(
            onPressed: _closeSection,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Назад'),
          ),
          const SizedBox(height: 8),
          _BusinessCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Настройки',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Оформление, стартовый экран и нижняя панель.',
                  style: TextStyle(color: tokens.mutedForeground),
                ),
                const SizedBox(height: 18),
                Text(
                  'Тема приложения',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                ...AppThemePreset.values.map(
                  (preset) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ThemePresetTile(
                      preset: preset,
                      currentPreset: widget.themePreset,
                      onTap: () => widget.onThemeChanged(preset),
                    ),
                  ),
                ),
                const Divider(height: 26),
                DropdownButtonFormField<BusinessTab>(
                  initialValue: widget.startTab,
                  decoration: const InputDecoration(
                    labelText: 'Стартовый раздел',
                  ),
                  items: widget.bottomNavTabs
                      .map(
                        (tab) => DropdownMenuItem<BusinessTab>(
                          value: tab,
                          child: Text(tabLabel(tab)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) async {
                    if (value == null) {
                      return;
                    }
                    await widget.onStartTabChanged(value);
                    if (!mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Стартовый раздел: ${tabLabel(value)}',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: widget.onNavSettingsOpen,
                  child: _MenuTile(
                    icon: Icons.tune_rounded,
                    iconColor: tokens.info,
                    iconTone: tokens.tone(tokens.info),
                    title: 'Настройка навигации',
                    subtitle: 'Разделы в нижней панели',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpPage() {
    final companyId = widget.activeCompany?.id ?? '—';
    final companyName =
        widget.activeCompany?.name ?? widget.overview.companyName;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          TextButton.icon(
            onPressed: _closeSection,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Назад'),
          ),
          const SizedBox(height: 8),
          _BusinessCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Помощь',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                ..._moreFaqItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: ExpansionTile(
                        key: PageStorageKey(item.id),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        collapsedShape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        title: Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        initiallyExpanded: _expandedFaqIds.contains(item.id),
                        onExpansionChanged: (expanded) {
                          setState(() {
                            if (expanded) {
                              _expandedFaqIds.add(item.id);
                            } else {
                              _expandedFaqIds.remove(item.id);
                            }
                          });
                        },
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Text(
                              item.answer,
                              style: const TextStyle(
                                color: Color(0xFF475569),
                                height: 1.4,
                              ),
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
                  'Данные для поддержки',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                _InfoTile(
                  icon: Icons.business_rounded,
                  label: 'Компания',
                  value: companyName,
                ),
                _InfoTile(
                  icon: Icons.tag_rounded,
                  label: 'Company ID',
                  value: companyId,
                ),
                _InfoTile(
                  icon: Icons.phone_rounded,
                  label: 'Телефон',
                  value: widget.session.user.phone,
                ),
                _InfoTile(
                  icon: Icons.link_rounded,
                  label: 'API',
                  value: ApiConfig.baseUrl,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _copySupportData(),
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Скопировать данные для поддержки'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copySupportData() async {
    final data = [
      'Компания: ${widget.activeCompany?.name ?? widget.overview.companyName}',
      'Company ID: ${widget.activeCompany?.id ?? '—'}',
      'Телефон пользователя: ${widget.session.user.phone}',
      'API: ${ApiConfig.baseUrl}',
      'Стартовый раздел: ${tabLabel(widget.startTab)}',
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: data));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Данные скопированы')),
    );
  }

  String _moneyDocumentTypeLabel(String type) {
    switch (type) {
      case 'sale_receivable':
        return 'Дебиторка';
      case 'purchase_payable':
        return 'Кредиторка';
      case 'income':
        return 'Приход денег';
      case 'expense':
        return 'Расход денег';
      case 'transfer':
        return 'Перевод';
      case 'payroll_payout':
        return 'Выплата зарплаты';
      default:
        return type.isEmpty ? 'Документ' : type;
    }
  }

  Widget _buildHiddenTabsCard() {
    if (widget.hiddenTabs.isEmpty) {
      return const _BusinessCard(
        child: Column(
          children: [
            _TileIcon(
              icon: Icons.check_circle_rounded,
              color: Color(0xFF00A86B),
              tone: Color(0x1400A86B),
            ),
            SizedBox(height: 12),
            Text(
              'Все доступные разделы уже вынесены на панель',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Настройте состав вкладок внизу экрана, если захотите поменять разделы местами.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return _BusinessCard(
      child: Column(
        children: [
          for (var index = 0; index < widget.hiddenTabs.length; index++) ...[
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () async {
                await widget.onOpenHiddenTab(widget.hiddenTabs[index]);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _MenuTile(
                  icon: tabIcon(widget.hiddenTabs[index]),
                  iconColor: _hiddenTabIconColor(widget.hiddenTabs[index]),
                  iconTone: _hiddenTabIconTone(widget.hiddenTabs[index]),
                  title: tabLabel(widget.hiddenTabs[index]),
                  subtitle: _hiddenTabSubtitle(widget.hiddenTabs[index]),
                ),
              ),
            ),
            if (index != widget.hiddenTabs.length - 1)
              const Divider(height: 24),
          ],
        ],
      ),
    );
  }

  String _hiddenTabSubtitle(BusinessTab tab) {
    switch (tab) {
      case BusinessTab.crm:
        return 'Клиенты, продажи и долги';
      case BusinessTab.warehouse:
        return 'Остатки, склады и движения';
      case BusinessTab.finance:
        return 'Счета, операции и документы';
      case BusinessTab.production:
        return 'Рецепты и производственные заказы';
      case BusinessTab.sales:
        return 'Заказы, счета и накладные';
      case BusinessTab.purchases:
        return 'Поставщики, закупки и приход';
      case BusinessTab.services:
        return 'Каталог и оказание услуг';
      case BusinessTab.catalog:
        return 'Товары, услуги и цены';
      case BusinessTab.salary:
        return 'Сотрудники, начисления и выплаты';
      case BusinessTab.reports:
        return 'Показатели, сводки и анализ';
      case BusinessTab.taxes:
        return 'Налоги, ставки и обязательства';
      case BusinessTab.dashboard:
      case BusinessTab.more:
        return 'Раздел приложения';
    }
  }

  Color _hiddenTabIconColor(BusinessTab tab) {
    switch (tab) {
      case BusinessTab.crm:
        return const Color(0xFF00A86B);
      case BusinessTab.warehouse:
        return const Color(0xFF2563EB);
      case BusinessTab.finance:
        return const Color(0xFFF59E0B);
      case BusinessTab.production:
        return const Color(0xFF7C3AED);
      case BusinessTab.sales:
        return const Color(0xFF16A34A);
      case BusinessTab.purchases:
        return const Color(0xFF3B82F6);
      case BusinessTab.services:
        return const Color(0xFFF97316);
      case BusinessTab.catalog:
        return const Color(0xFF0891B2);
      case BusinessTab.salary:
        return const Color(0xFF0F766E);
      case BusinessTab.reports:
        return const Color(0xFF22C55E);
      case BusinessTab.taxes:
        return const Color(0xFFEF4444);
      case BusinessTab.dashboard:
      case BusinessTab.more:
        return const Color(0xFF64748B);
    }
  }

  Color _hiddenTabIconTone(BusinessTab tab) {
    switch (tab) {
      case BusinessTab.crm:
        return const Color(0x1400A86B);
      case BusinessTab.warehouse:
        return const Color(0x142563EB);
      case BusinessTab.finance:
        return const Color(0x14F59E0B);
      case BusinessTab.production:
        return const Color(0x147C3AED);
      case BusinessTab.sales:
        return const Color(0x1416A34A);
      case BusinessTab.purchases:
        return const Color(0x143B82F6);
      case BusinessTab.services:
        return const Color(0x14F97316);
      case BusinessTab.catalog:
        return const Color(0x140891B2);
      case BusinessTab.salary:
        return const Color(0x140F766E);
      case BusinessTab.reports:
        return const Color(0x1422C55E);
      case BusinessTab.taxes:
        return const Color(0x14EF4444);
      case BusinessTab.dashboard:
      case BusinessTab.more:
        return const Color(0xFFF1F5F9);
    }
  }
}

const _moreMemberRoles = [
  'admin',
  'manager',
  'accountant',
  'warehouse',
  'sales',
  'staff',
];

String _moreRoleLabel(String role) {
  switch (role) {
    case 'admin':
      return 'Администратор';
    case 'manager':
      return 'Менеджер';
    case 'accountant':
      return 'Бухгалтер';
    case 'warehouse':
      return 'Кладовщик';
    case 'sales':
      return 'Продажи';
    case 'owner':
      return 'Владелец';
    default:
      return 'Сотрудник';
  }
}

class _MoreCompanyMemberVm {
  const _MoreCompanyMemberVm({
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.role,
    required this.roleLabel,
    required this.isOwner,
    required this.isCurrentUser,
  });

  factory _MoreCompanyMemberVm.fromJson(Map<String, dynamic> json) {
    return _MoreCompanyMemberVm(
      userId: json['user_id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? 'staff',
      roleLabel: json['role_label'] as String? ??
          _moreRoleLabel(json['role'] as String? ?? 'staff'),
      isOwner: json['is_owner'] as bool? ?? false,
      isCurrentUser: json['is_current_user'] as bool? ?? false,
    );
  }

  final String userId;
  final String fullName;
  final String phone;
  final String role;
  final String roleLabel;
  final bool isOwner;
  final bool isCurrentUser;
}

enum _MoreSection {
  menu,
  company,
  users,
  notifications,
  documents,
  settings,
  help,
}

enum _MoreDocumentsView { inventory, money }

class _MoreDocumentTypeOption {
  const _MoreDocumentTypeOption({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;
}

class _MoreFaqItem {
  const _MoreFaqItem({
    required this.id,
    required this.title,
    required this.answer,
  });

  final String id;
  final String title;
  final String answer;
}

const _inventoryDocumentTypeOptions = [
  _MoreDocumentTypeOption(
    value: 'sale_issue',
    label: 'Продажа',
    color: Color(0xFF16A34A),
  ),
  _MoreDocumentTypeOption(
    value: 'purchase_receipt',
    label: 'Приход',
    color: Color(0xFF2563EB),
  ),
  _MoreDocumentTypeOption(
    value: 'write_off',
    label: 'Списание',
    color: Color(0xFFDC2626),
  ),
  _MoreDocumentTypeOption(
    value: 'transfer',
    label: 'Перемещение',
    color: Color(0xFF0F766E),
  ),
  _MoreDocumentTypeOption(
    value: 'adjustment',
    label: 'Корректировка',
    color: Color(0xFF7C3AED),
  ),
];

const _moneyDocumentTypeOptions = [
  _MoreDocumentTypeOption(
    value: 'sale_receivable',
    label: 'Дебиторка',
    color: Color(0xFF16A34A),
  ),
  _MoreDocumentTypeOption(
    value: 'purchase_payable',
    label: 'Кредиторка',
    color: Color(0xFFF59E0B),
  ),
  _MoreDocumentTypeOption(
    value: 'income',
    label: 'Приход',
    color: Color(0xFF2563EB),
  ),
  _MoreDocumentTypeOption(
    value: 'expense',
    label: 'Расход',
    color: Color(0xFFDC2626),
  ),
  _MoreDocumentTypeOption(
    value: 'transfer',
    label: 'Перевод',
    color: Color(0xFF0F766E),
  ),
  _MoreDocumentTypeOption(
    value: 'payroll_payout',
    label: 'Зарплата',
    color: Color(0xFF7C3AED),
  ),
];

const _moreFaqItems = [
  _MoreFaqItem(
    id: 'company',
    title: 'Как добавить компанию?',
    answer:
        'На главной странице откройте список компаний и создайте новую компанию. После создания переключитесь на нее, чтобы заполнить реквизиты и начать работу.',
  ),
  _MoreFaqItem(
    id: 'product',
    title: 'Как создать товар?',
    answer:
        'Откройте Справочник или Склад, добавьте товар, заполните название, артикул, цену продажи и закупочную цену. После сохранения товар станет доступен в документах.',
  ),
  _MoreFaqItem(
    id: 'trade',
    title: 'Как оформить закупку или продажу?',
    answer:
        'Создайте документ в разделе Продажи, Закупки или Документы, выберите контрагента, склад и позиции. Цена подставится из справочника, после сохранения обновятся остатки и финансовые движения.',
  ),
  _MoreFaqItem(
    id: 'users',
    title: 'Как пригласить пользователя?',
    answer:
        'Откройте Еще → Пользователи, нажмите Добавить, укажите телефон зарегистрированного пользователя и назначьте роль. Пользователь сразу получит доступ к текущей компании.',
  ),
  _MoreFaqItem(
    id: 'salary',
    title: 'Как начислить зарплату?',
    answer:
        'Перейдите в Зарплата, создайте период, выполните расчет и при необходимости скорректируйте строки. После выплаты создастся денежный документ и обновятся финансы.',
  ),
];
