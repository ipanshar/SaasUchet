import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:saas_uchet_mobile/features/auth/domain/auth_gateway.dart';
import 'package:saas_uchet_mobile/features/auth/domain/auth_session.dart';
import 'package:saas_uchet_mobile/features/auth/domain/company_profile.dart';
import 'package:saas_uchet_mobile/features/auth/domain/user_profile.dart';
import 'package:saas_uchet_mobile/features/business/domain/business_gateway.dart';
import 'package:saas_uchet_mobile/features/business/presentation/profile_editor_screen.dart';

part 'onboarding_flow.dart';
part 'dashboard_screen.dart';
part 'crm_screen.dart';
part 'warehouse_screen.dart';
part 'finance_screen.dart';
part 'more_screen.dart';
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

  BusinessTab _activeTab = BusinessTab.dashboard;
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

  List<_FabMenuAction> _fabActionsForCurrentTab() {
    switch (_activeTab) {
      case BusinessTab.warehouse:
        return _warehouseFabActions;
      default:
        return _defaultFabActions;
    }
  }

  Future<void> _handleFabAction(_FabMenuAction action) async {
    setState(() {
      _isFabExpanded = false;
    });

    if (_activeTab == BusinessTab.warehouse) {
      final warehouseState = _warehouseScreenKey.currentState;
      if (warehouseState == null) {
        return;
      }

      switch (action.id) {
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

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Действие "${action.label}" пока в разработке')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showFab = _activeTab != BusinessTab.more;
    final fabActions = _fabActionsForCurrentTab();
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
                _CrmScreen(
                  accessToken: _session.accessToken,
                  clients: overview.clients,
                  businessGateway: widget.businessGateway,
                  onClientsChanged: _loadOverview,
                ),
                _WarehouseScreen(
                  key: _warehouseScreenKey,
                  accessToken: _session.accessToken,
                  products: overview.products,
                  clients: overview.clients,
                  businessGateway: widget.businessGateway,
                  onProductsChanged: _loadOverview,
                ),
                _FinanceScreen(
                  accessToken: _session.accessToken,
                  finance: overview.finance,
                  businessGateway: widget.businessGateway,
                  onFinanceChanged: _loadOverview,
                ),
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
