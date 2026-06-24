import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:saas_uchet_mobile/app/app_theme.dart';
import 'package:saas_uchet_mobile/core/config/api_config.dart';
import 'package:saas_uchet_mobile/features/auth/domain/auth_gateway.dart';
import 'package:saas_uchet_mobile/features/auth/domain/auth_session.dart';
import 'package:saas_uchet_mobile/features/auth/domain/company_profile.dart';
import 'package:saas_uchet_mobile/features/auth/domain/user_profile.dart';
import 'package:saas_uchet_mobile/features/business/domain/business_gateway.dart';
import 'package:saas_uchet_mobile/features/business/presentation/company_editor_screen.dart';
import 'package:saas_uchet_mobile/features/business/presentation/nav_settings_screen.dart';
import 'package:saas_uchet_mobile/features/business/presentation/profile_editor_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'onboarding_flow.dart';
part 'dashboard_screen.dart';
part 'crm_screen.dart';
part 'warehouse_screen.dart';
part 'finance_screen.dart';
part 'more_screen.dart';
part 'production_screen.dart';
part 'sales_screen.dart';
part 'purchases_screen.dart';
part 'documents_screen.dart';
part 'services_screen.dart';
part 'catalog_screen.dart';
part 'salary_screen.dart';
part 'salary_payroll.dart';
part 'salary_settings.dart';
part 'salary_models.dart';
part 'reports_screen.dart';
part 'taxes_screen.dart';
part 'business_widgets.dart';
part 'business_models.dart';

class BusinessShell extends StatefulWidget {
  const BusinessShell({
    super.key,
    required this.authGateway,
    required this.businessGateway,
    required this.session,
    required this.onLogout,
    required this.onSessionChanged,
    required this.onAccountDeleted,
    required this.themePreset,
    required this.onThemeChanged,
  });

  final AuthGateway authGateway;
  final BusinessGateway businessGateway;
  final AuthSession session;
  final VoidCallback onLogout;
  final ValueChanged<AuthSession> onSessionChanged;
  final VoidCallback onAccountDeleted;
  final AppThemePreset themePreset;
  final ValueChanged<AppThemePreset> onThemeChanged;

  @override
  State<BusinessShell> createState() => _BusinessShellState();
}

class _BusinessShellState extends State<BusinessShell> {
  static const List<_FabMenuAction> _defaultFabActions = [
    _FabMenuAction(
      id: 'sale',
      label: 'Продажа',
      icon: Icons.point_of_sale_rounded,
      color: Color(0xFF00A86B),
    ),
    _FabMenuAction(
      id: 'purchase',
      label: 'Закупка',
      icon: Icons.shopping_cart_checkout_rounded,
      color: Color(0xFF3B82F6),
    ),
    _FabMenuAction(
      id: 'client',
      label: 'Клиент',
      icon: Icons.person_add_alt_1_rounded,
      color: Color(0xFF22C55E),
    ),
    _FabMenuAction(
      id: 'invoice',
      label: 'Счет',
      icon: Icons.receipt_long_rounded,
      color: Color(0xFFF59E0B),
    ),
  ];

  static const List<_FabMenuAction> _warehouseFabActions = [
    _FabMenuAction(
      id: 'warehouse_add',
      label: 'Новый склад',
      icon: Icons.add_business_rounded,
      color: Color(0xFF7C3AED),
    ),
    _FabMenuAction(
      id: 'warehouse_documents',
      label: 'Документы',
      icon: Icons.description_rounded,
      color: Color(0xFF475569),
    ),
    _FabMenuAction(
      id: 'warehouse_operation',
      label: 'Операция',
      icon: Icons.playlist_add_check_circle_rounded,
      color: Color(0xFF0F766E),
    ),
    _FabMenuAction(
      id: 'warehouse_product',
      label: 'Товар',
      icon: Icons.add_box_rounded,
      color: Color(0xFF00A86B),
    ),
  ];

  static const _prefKey = 'nav_tabs';
  static const _activeCompanyKey = 'active_company_id';
  static const _startTabPrefKey = 'start_tab';

  List<_Company> _companies = const [];
  String? _activeCompanyId;

  BusinessTab _activeTab = BusinessTab.dashboard;
  BusinessTab _preferredStartTab = BusinessTab.dashboard;
  List<BusinessTab> _activeTabs = const [
    BusinessTab.dashboard,
    BusinessTab.crm,
    BusinessTab.warehouse,
    BusinessTab.catalog,
    BusinessTab.more,
  ];
  bool _isFabExpanded = false;
  late AuthSession _session;
  final GlobalKey<_WarehouseScreenState> _warehouseScreenKey =
      GlobalKey<_WarehouseScreenState>();
  _OverviewData? _overview;
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _activeCompanyId = prefs.getString(_activeCompanyKey);
      if (_activeCompanyId != null && _activeCompanyId!.isNotEmpty) {
        widget.businessGateway.activeCompanyId = _activeCompanyId;
      }
    } catch (_) {
      // Preferences unavailable (e.g. in tests) — fall back to default company.
    }
    // Companies must load first so tab filtering by role is correct before the
    // UI is shown. Tab prefs are applied next (while companies are available),
    // then overview data loads and the spinner clears.
    await _loadCompanies();
    await _loadTabPrefs();
    await _loadStartTabPref();
    await _loadOverview();
  }

  Future<void> _loadCompanies() async {
    try {
      final raw = await widget.businessGateway.fetchCompanies(
        accessToken: _session.accessToken,
      );
      final companies = raw
          .map(_companyFromJson)
          .where((company) => company.id.isNotEmpty)
          .toList(growable: false);

      // Validate the stored active company; otherwise fall back to default.
      var active = _activeCompanyId;
      if (active == null || !companies.any((c) => c.id == active)) {
        final defaults = companies.where((c) => c.isDefault).toList();
        active = defaults.isNotEmpty
            ? defaults.first.id
            : (companies.isNotEmpty ? companies.first.id : null);
        widget.businessGateway.activeCompanyId = active;
        _activeCompanyId = active;
      }

      if (!mounted) return;
      setState(() {
        _companies = companies;
        _activeTabs = _normalizeTabsForRole(_activeTabs);
        _activeTab = _resolvePreferredStartTab(
          preferredTab: _activeTab,
          tabs: _activeTabs,
        );
      });
    } catch (_) {
      // Non-fatal: switcher just stays empty/unchanged.
    }
  }

  Future<void> _switchCompany(String companyId) async {
    if (companyId == _activeCompanyId) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeCompanyKey, companyId);
    widget.businessGateway.activeCompanyId = companyId;
    setState(() {
      _activeCompanyId = companyId;
      _activeTabs = _normalizeTabsForRole(_activeTabs);
      _activeTab = _resolvePreferredStartTab(tabs: _activeTabs);
      _isFabExpanded = false;
    });
    await _loadOverview();
  }

  Future<void> _setDefaultCompany(String companyId) async {
    try {
      await widget.businessGateway.setDefaultCompany(
        accessToken: _session.accessToken,
        companyId: companyId,
      );
      await _loadCompanies();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Компания по умолчанию обновлена')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _createCompany(Map<String, dynamic> payload) async {
    final created = await widget.businessGateway.createCompany(
      accessToken: _session.accessToken,
      payload: payload,
    );
    await _loadCompanies();
    final id = created['id'] as String?;
    if (id != null && id.isNotEmpty) {
      await _switchCompany(id);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Компания создана')),
    );
  }

  Future<void> _addCompanyMember(
    String companyId,
    Map<String, dynamic> payload,
  ) async {
    await widget.businessGateway.addCompanyMember(
      accessToken: _session.accessToken,
      companyId: companyId,
      payload: payload,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Сотрудник добавлен')),
    );
  }

  Future<void> _loadTabPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefKey);
    if (stored == null || stored.isEmpty) return;
    final names = stored.split(',');
    final middle = names
        .map(
          (n) => BusinessTab.values.where((t) => t.name == n).firstOrNull,
        )
        .whereType<BusinessTab>()
        .where((t) => t != BusinessTab.dashboard && t != BusinessTab.more)
        .toList();
    if (middle.isEmpty || !mounted) return;
    setState(() {
      _activeTabs = _normalizeTabsForRole([
        BusinessTab.dashboard,
        ...middle,
        BusinessTab.more,
      ]);
      _activeTab = _resolvePreferredStartTab(tabs: _activeTabs);
    });
  }

  Future<void> _saveAndApplyTabs(List<BusinessTab> middleTabs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, middleTabs.map((t) => t.name).join(','));
    if (!mounted) return;
    setState(() {
      _activeTabs = _normalizeTabsForRole([
        BusinessTab.dashboard,
        ...middleTabs,
        BusinessTab.more,
      ]);
      _activeTab = _resolvePreferredStartTab(tabs: _activeTabs);
      _isFabExpanded = false;
    });
  }

  Future<void> _loadStartTabPref() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_startTabPrefKey);
    if (stored == null || stored.isEmpty) {
      if (!mounted) return;
      setState(() {
        _activeTab = _resolvePreferredStartTab(tabs: _activeTabs);
      });
      return;
    }
    final preferred =
        BusinessTab.values.where((tab) => tab.name == stored).firstOrNull;
    if (preferred == null || !mounted) {
      return;
    }
    setState(() {
      _preferredStartTab = preferred;
      _activeTab = _resolvePreferredStartTab(tabs: _activeTabs);
    });
  }

  Future<void> _saveStartTab(BusinessTab tab) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_startTabPrefKey, tab.name);
    if (!mounted) {
      return;
    }
    setState(() {
      _preferredStartTab = tab;
      _activeTab = _resolvePreferredStartTab(tabs: _activeTabs);
    });
  }

  void _openNavSettings() {
    final middleTabs = _activeTabs
        .where((t) => t != BusinessTab.dashboard && t != BusinessTab.more)
        .toList();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => NavSettingsScreen(
          currentMiddleTabs: middleTabs,
          allowedTabs: _allowedMiddleTabsForRole(_currentCompanyRole()),
          onSaved: _saveAndApplyTabs,
        ),
      ),
    );
  }

  BusinessTab _resolvePreferredStartTab({
    BusinessTab? preferredTab,
    List<BusinessTab>? tabs,
  }) {
    final currentTabs = tabs ?? _activeTabs;
    final candidate = preferredTab ?? _preferredStartTab;
    if (currentTabs.contains(candidate)) {
      return candidate;
    }
    return BusinessTab.dashboard;
  }

  Future<_OverviewData> _fetchOverviewData() async {
    final payload = await widget.businessGateway.fetchOverview(
      accessToken: _session.accessToken,
    );
    return _OverviewData.fromJson(payload, _session.user);
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
      final overview = await _fetchOverviewData();
      if (!mounted) {
        return;
      }
      setState(() {
        _overview = overview;
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

  Future<_OverviewData> _refreshOverviewSnapshot() async {
    final overview = await _fetchOverviewData();
    if (!mounted) {
      return overview;
    }
    setState(() {
      _overview = overview;
      _loadError = null;
      _isLoading = false;
    });
    return overview;
  }

  Future<void> _openProfileEditor() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProfileEditorScreen(
          authGateway: widget.authGateway,
          businessGateway: widget.businessGateway,
          session: _session,
          onLogout: widget.onLogout,
          onSessionChanged: _handleSessionChanged,
          onAccountDeleted: widget.onAccountDeleted,
        ),
      ),
    );
    _loadOverview();
  }

  Future<void> _openCompanyEditor() async {
    final id = _activeCompanyId;
    if (id == null) return;
    if (!_canAccessCompanySettings()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('У вас нет доступа к настройкам компании')),
      );
      return;
    }
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CompanyEditorScreen(
          businessGateway: widget.businessGateway,
          accessToken: _session.accessToken,
          companyId: id,
        ),
      ),
    );
    if (changed == true) {
      await _loadCompanies();
      await _loadOverview();
    }
  }

  List<_FabMenuAction> _fabActionsForCurrentTab() {
    switch (_activeTab) {
      case BusinessTab.warehouse:
        return _warehouseFabActions;
      default:
        return _defaultFabActions;
    }
  }

  String _currentCompanyRole() {
    final active = _activeCompanyId;
    if (active == null || active.isEmpty) {
      final company = _companies.where((c) => c.isDefault).firstOrNull ??
          _companies.firstOrNull;
      return company?.role ?? 'owner';
    }
    return _companies.where((c) => c.id == active).firstOrNull?.role ?? 'owner';
  }

  bool _canAccessCompanySettings() {
    final role = _currentCompanyRole();
    return role == 'owner' || role == 'admin';
  }

  List<BusinessTab> _allowedMiddleTabsForRole(String role) {
    switch (role) {
      case 'owner':
      case 'admin':
        return const [
          BusinessTab.crm,
          BusinessTab.warehouse,
          BusinessTab.finance,
          BusinessTab.catalog,
          BusinessTab.production,
          BusinessTab.sales,
          BusinessTab.purchases,
          BusinessTab.salary,
          BusinessTab.reports,
        ];
      case 'manager':
        return const [
          BusinessTab.crm,
          BusinessTab.warehouse,
          BusinessTab.finance,
          BusinessTab.catalog,
          BusinessTab.production,
          BusinessTab.reports,
        ];
      case 'accountant':
        return const [
          BusinessTab.crm,
          BusinessTab.finance,
          BusinessTab.salary,
          BusinessTab.reports,
        ];
      case 'warehouse':
        return const [
          BusinessTab.warehouse,
          BusinessTab.catalog,
        ];
      case 'sales':
        return const [
          BusinessTab.crm,
          BusinessTab.warehouse,
          BusinessTab.catalog,
        ];
      default:
        return const [];
    }
  }

  List<BusinessTab> _normalizeTabsForRole(List<BusinessTab> tabs) {
    final allowed = _allowedMiddleTabsForRole(_currentCompanyRole()).toSet();
    final middle = tabs
        .where((tab) => tab != BusinessTab.dashboard && tab != BusinessTab.more)
        .where(allowed.contains)
        .toList(growable: false);
    return [BusinessTab.dashboard, ...middle, BusinessTab.more];
  }

  List<BusinessTab> _hiddenTabsForRole() {
    final activeMiddleTabs = _activeTabs
        .where((tab) => tab != BusinessTab.dashboard && tab != BusinessTab.more)
        .toSet();
    return _allowedMiddleTabsForRole(
      _currentCompanyRole(),
    ).where((tab) => !activeMiddleTabs.contains(tab)).toList(growable: false);
  }

  Future<void> _handleWarehouseFabAction(
    _FabMenuAction action,
    _WarehouseScreenState? warehouseState,
  ) async {
    if (warehouseState == null) {
      return;
    }

    switch (action.id) {
      case 'warehouse_add':
        await warehouseState.openCreateWarehouse();
        return;
      case 'warehouse_documents':
        await warehouseState.openInventoryDocuments();
        return;
      case 'warehouse_operation':
        await warehouseState.openCreateInventoryDocument();
        return;
      case 'warehouse_product':
        await warehouseState.openCreateProduct();
        return;
    }
  }

  Future<void> _openHiddenTab(BusinessTab tab) async {
    final overview = _overview;
    if (overview == null) {
      return;
    }

    final warehouseScreenKey = tab == BusinessTab.warehouse
        ? GlobalKey<_WarehouseScreenState>()
        : null;

    final selectedTab = await Navigator.of(context).push<BusinessTab?>(
      MaterialPageRoute<BusinessTab?>(
        builder: (context) => _HiddenTabRouteScreen(
          tab: tab,
          title: tabLabel(tab),
          initialOverview: overview,
          reloadOverview: _refreshOverviewSnapshot,
          bottomNavTabs: _activeTabs,
          screenBuilder: (overview, onOverviewChanged, routeWarehouseKey) =>
              _buildScreen(
            tab,
            overview,
            onOverviewChanged: onOverviewChanged,
            warehouseScreenKey: routeWarehouseKey,
          ),
          fabActions:
              tab == BusinessTab.warehouse ? _warehouseFabActions : const [],
          onFabActionSelected: tab == BusinessTab.warehouse
              ? (action, warehouseState) async {
                  await _handleWarehouseFabAction(action, warehouseState);
                }
              : null,
          warehouseScreenKey: warehouseScreenKey,
        ),
      ),
    );

    if (!mounted) {
      return;
    }
    if (selectedTab != null && _activeTabs.contains(selectedTab)) {
      setState(() {
        _activeTab = selectedTab;
        _isFabExpanded = false;
      });
    }
    await _loadOverview();
  }

  Future<void> _openBusinessTab(BusinessTab tab) async {
    if (_activeTabs.contains(tab)) {
      if (!mounted) {
        return;
      }
      setState(() {
        _activeTab = tab;
        _isFabExpanded = false;
      });
      return;
    }
    await _openHiddenTab(tab);
  }

  Future<void> _handleFabAction(_FabMenuAction action) async {
    setState(() {
      _isFabExpanded = false;
    });

    if (_activeTab == BusinessTab.warehouse) {
      await _handleWarehouseFabAction(action, _warehouseScreenKey.currentState);
      return;
    }

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Действие "${action.label}" пока в разработке')),
    );
  }

  Widget _buildScreen(
    BusinessTab tab,
    _OverviewData overview, {
    Future<void> Function()? onOverviewChanged,
    GlobalKey<_WarehouseScreenState>? warehouseScreenKey,
  }) {
    final refreshOverview = onOverviewChanged ?? _loadOverview;
    switch (tab) {
      case BusinessTab.dashboard:
        return _DashboardScreen(
          session: _session,
          overview: overview,
          companies: _companies,
          activeCompanyId: _activeCompanyId,
          onSwitchCompany: _switchCompany,
          onSetDefaultCompany: _setDefaultCompany,
          onCreateCompany: _createCompany,
          onAddCompanyMember: _addCompanyMember,
          onRefresh: refreshOverview,
          onOpenBusinessTab: _openBusinessTab,
        );
      case BusinessTab.crm:
        return _CrmScreen(
          accessToken: _session.accessToken,
          clients: overview.clients,
          products: overview.products,
          accounts: overview.finance.accounts,
          businessGateway: widget.businessGateway,
          onClientsChanged: refreshOverview,
        );
      case BusinessTab.warehouse:
        return _WarehouseScreen(
          key: warehouseScreenKey ?? _warehouseScreenKey,
          accessToken: _session.accessToken,
          products: overview.products,
          clients: overview.clients,
          businessGateway: widget.businessGateway,
          onProductsChanged: refreshOverview,
        );
      case BusinessTab.finance:
        return _FinanceScreen(
          accessToken: _session.accessToken,
          finance: overview.finance,
          businessGateway: widget.businessGateway,
          onFinanceChanged: refreshOverview,
        );
      case BusinessTab.more:
        return _MoreScreen(
          session: _session,
          overview: overview,
          onLogout: widget.onLogout,
          onOpenProfile: _openProfileEditor,
          onNavSettingsOpen: _openNavSettings,
          businessGateway: widget.businessGateway,
          onOpenCompanyEditor: _openCompanyEditor,
          hiddenTabs: _hiddenTabsForRole(),
          onOpenHiddenTab: _openHiddenTab,
          onOpenBusinessTab: _openBusinessTab,
          activeCompany: _activeCompanyId != null
              ? _companies.where((c) => c.id == _activeCompanyId).firstOrNull
              : null,
          themePreset: widget.themePreset,
          onThemeChanged: widget.onThemeChanged,
          startTab: _resolvePreferredStartTab(tabs: _activeTabs),
          onStartTabChanged: _saveStartTab,
          bottomNavTabs: _activeTabs,
        );
      case BusinessTab.production:
        return _ProductionScreen(
          accessToken: _session.accessToken,
          products: overview.products,
          businessGateway: widget.businessGateway,
        );
      case BusinessTab.sales:
        return _SalesScreen(
          accessToken: _session.accessToken,
          businessGateway: widget.businessGateway,
          products: overview.products,
          clients: overview.clients,
        );
      case BusinessTab.purchases:
        return _PurchasesScreen(
          accessToken: _session.accessToken,
          businessGateway: widget.businessGateway,
          products: overview.products,
          clients: overview.clients,
        );
      case BusinessTab.services:
        return const _ServicesScreen();
      case BusinessTab.catalog:
        return _CatalogScreen(
          accessToken: _session.accessToken,
          products: overview.products,
          businessGateway: widget.businessGateway,
          onProductsChanged: refreshOverview,
        );
      case BusinessTab.salary:
        return _SalaryScreen(
          accessToken: _session.accessToken,
          businessGateway: widget.businessGateway,
          accounts: overview.finance.accounts,
        );
      case BusinessTab.reports:
        return _ReportsScreen(
          accessToken: widget.session.accessToken,
          businessGateway: widget.businessGateway,
          overview: overview,
        );
      case BusinessTab.taxes:
        return const _TaxesScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final showFab = _activeTab != BusinessTab.more &&
        _activeTab != BusinessTab.catalog &&
        _activeTab != BusinessTab.crm &&
        _activeTab != BusinessTab.production &&
        _activeTab != BusinessTab.sales &&
        _activeTab != BusinessTab.purchases &&
        _activeTab != BusinessTab.salary &&
        _activeTab != BusinessTab.reports &&
        _activeTab != BusinessTab.taxes;
    final fabActions = _fabActionsForCurrentTab();
    final overview = _overview;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 52,
                      color: context.appThemeTokens.mutedForeground,
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
                      style: TextStyle(
                        color: context.appThemeTokens.mutedForeground,
                      ),
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
              index: _activeTabs.indexOf(_activeTab),
              children: _activeTabs
                  .map((tab) => _buildScreen(tab, overview))
                  .toList(),
            ),
          if (showFab)
            Positioned(
              right: 16,
              bottom: 90,
              child: _FabMenu(
                expanded: _isFabExpanded,
                actions: fabActions,
                onToggle: () {
                  setState(() {
                    _isFabExpanded = !_isFabExpanded;
                  });
                },
                onActionSelected: _handleFabAction,
              ),
            ),
        ],
      ),
      bottomNavigationBar: _BottomNavBar(
        activeTab: _activeTab,
        tabs: _activeTabs,
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

class _HiddenTabRouteScreen extends StatefulWidget {
  const _HiddenTabRouteScreen({
    required this.tab,
    required this.title,
    required this.initialOverview,
    required this.reloadOverview,
    required this.bottomNavTabs,
    required this.screenBuilder,
    this.fabActions = const [],
    this.onFabActionSelected,
    this.warehouseScreenKey,
  });

  final BusinessTab tab;
  final String title;
  final _OverviewData initialOverview;
  final Future<_OverviewData> Function() reloadOverview;
  final List<BusinessTab> bottomNavTabs;
  final Widget Function(
    _OverviewData overview,
    Future<void> Function() onOverviewChanged,
    GlobalKey<_WarehouseScreenState>? warehouseScreenKey,
  ) screenBuilder;
  final List<_FabMenuAction> fabActions;
  final Future<void> Function(
    _FabMenuAction action,
    _WarehouseScreenState? warehouseState,
  )? onFabActionSelected;
  final GlobalKey<_WarehouseScreenState>? warehouseScreenKey;

  @override
  State<_HiddenTabRouteScreen> createState() => _HiddenTabRouteScreenState();
}

class _HiddenTabRouteScreenState extends State<_HiddenTabRouteScreen> {
  late _OverviewData _overview;
  bool _isFabExpanded = false;

  @override
  void initState() {
    super.initState();
    _overview = widget.initialOverview;
  }

  Future<void> _refreshOverview() async {
    final overview = await widget.reloadOverview();
    if (!mounted) {
      return;
    }
    setState(() {
      _overview = overview;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          widget.screenBuilder(
            _overview,
            _refreshOverview,
            widget.warehouseScreenKey,
          ),
          Positioned(
            left: 16,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Material(
                color: context.appThemeTokens.card.withValues(alpha: 0.92),
                shape: const CircleBorder(),
                elevation: 6,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Назад',
                ),
              ),
            ),
          ),
          if (widget.fabActions.isNotEmpty &&
              widget.onFabActionSelected != null)
            Positioned(
              right: 16,
              bottom: 90,
              child: _FabMenu(
                expanded: _isFabExpanded,
                actions: widget.fabActions,
                onToggle: () {
                  setState(() {
                    _isFabExpanded = !_isFabExpanded;
                  });
                },
                onActionSelected: (action) async {
                  setState(() {
                    _isFabExpanded = false;
                  });
                  await widget.onFabActionSelected!(
                    action,
                    widget.warehouseScreenKey?.currentState,
                  );
                },
              ),
            ),
        ],
      ),
      bottomNavigationBar: _BottomNavBar(
        activeTab: BusinessTab.more,
        tabs: widget.bottomNavTabs,
        onTabSelected: (tab) {
          Navigator.of(context).pop(tab);
        },
      ),
    );
  }
}
