part of 'business_shell.dart';

class _CrmScreen extends StatefulWidget {
  const _CrmScreen({
    required this.accessToken,
    required this.clients,
    required this.products,
    required this.accounts,
    required this.businessGateway,
    required this.onClientsChanged,
  });

  final String accessToken;
  final List<_Client> clients;
  final List<_Product> products;
  final List<_BankAccount> accounts;
  final BusinessGateway businessGateway;
  final Future<void> Function() onClientsChanged;

  @override
  State<_CrmScreen> createState() => _CrmScreenState();
}

class _CrmScreenState extends State<_CrmScreen> {
  String _query = '';
  _Client? _selectedClient;
  bool _isSubmitting = false;
  bool _showOnlyOverdue = false;
  _CrmSortMode _sortMode = _CrmSortMode.defaultOrder;
  bool _isCrmFabExpanded = false;

  @override
  void didUpdateWidget(covariant _CrmScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedClient == null) {
      return;
    }

    _Client? updatedClient;
    for (final client in widget.clients) {
      if (client.id == _selectedClient!.id) {
        updatedClient = client;
        break;
      }
    }

    _selectedClient = updatedClient;
  }

  @override
  Widget build(BuildContext context) {
    final clients = widget.clients.where((client) {
      final query = _query.toLowerCase();
      final matchesQuery = client.name.toLowerCase().contains(query) ||
          client.contact.toLowerCase().contains(query);
      final matchesOverdue = !_showOnlyOverdue || client.overdueAmount > 0;
      return matchesQuery && matchesOverdue;
    }).toList()
      ..sort((left, right) {
        switch (_sortMode) {
          case _CrmSortMode.overdueDesc:
            final overdueCompare =
                right.overdueAmount.compareTo(left.overdueAmount);
            if (overdueCompare != 0) return overdueCompare;
            return right.receivable.compareTo(left.receivable);
          case _CrmSortMode.receivableDesc:
            final receivableCompare =
                right.receivable.compareTo(left.receivable);
            if (receivableCompare != 0) return receivableCompare;
            return right.overdueAmount.compareTo(left.overdueAmount);
          case _CrmSortMode.defaultOrder:
            return 0;
        }
      });

    final vipCount =
        widget.clients.where((c) => c.segment == 'VIP').length;
    final debtorCount =
        widget.clients.where((c) => c.debt > 0).length;
    final selectedClient = _selectedClient;

    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: selectedClient != null
              ? _buildClientDetail(selectedClient)
              : _buildClientList(clients, vipCount, debtorCount),
        ),
        Positioned(
          right: 16,
          bottom: 90,
          child: selectedClient != null
              ? _FabMenu(
                  expanded: _isCrmFabExpanded,
                  actions: _clientFabActions,
                  onToggle: () => setState(
                    () => _isCrmFabExpanded = !_isCrmFabExpanded,
                  ),
                  onActionSelected: _handleClientFabAction,
                )
              : FloatingActionButton(
                  heroTag: 'crm_add_client',
                  backgroundColor: const Color(0xFF00A86B),
                  onPressed: _isSubmitting ? null : () => _showClientSheet(),
                  child: const Icon(Icons.person_add_alt_1_rounded,
                      color: Colors.white),
                ),
        ),
      ],
    );
  }

  // ── List view ────────────────────────────────────────────────────────────────

  Widget _buildClientList(
      List<_Client> clients, int vipCount, int debtorCount) {
    return Column(
      children: [
        _GradientHeader(
          title: 'CRM',
          subtitle: _clientCountLabel(widget.clients.length),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Клиентов',
                  value: '${widget.clients.length}',
                  tone: const Color(0x1400A86B),
                  accent: const Color(0xFF00A86B),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  title: 'VIP',
                  value: '$vipCount',
                  tone: const Color(0x1422C55E),
                  accent: const Color(0xFF22C55E),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  title: 'Должники',
                  value: '$debtorCount',
                  tone: const Color(0x14F59E0B),
                  accent: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 0, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChipButton(
                  label: 'Все',
                  active: !_showOnlyOverdue,
                  activeColor: const Color(0xFF00A86B),
                  onPressed: () =>
                      setState(() => _showOnlyOverdue = false),
                ),
                const SizedBox(width: 8),
                _FilterChipButton(
                  label: 'Просрочка',
                  active: _showOnlyOverdue,
                  activeColor: const Color(0xFFDC2626),
                  onPressed: () =>
                      setState(() => _showOnlyOverdue = true),
                ),
                const SizedBox(width: 8),
                _FilterChipButton(
                  label: 'По просрочке ↓',
                  active: _sortMode == _CrmSortMode.overdueDesc,
                  activeColor: const Color(0xFFB91C1C),
                  onPressed: () =>
                      setState(() => _sortMode = _CrmSortMode.overdueDesc),
                ),
                const SizedBox(width: 8),
                _FilterChipButton(
                  label: 'По дебиторке ↓',
                  active: _sortMode == _CrmSortMode.receivableDesc,
                  activeColor: const Color(0xFFD97706),
                  onPressed: () => setState(
                      () => _sortMode = _CrmSortMode.receivableDesc),
                ),
                const SizedBox(width: 8),
                _FilterChipButton(
                  label: 'По умолчанию',
                  active: _sortMode == _CrmSortMode.defaultOrder,
                  activeColor: const Color(0xFF64748B),
                  onPressed: () =>
                      setState(() => _sortMode = _CrmSortMode.defaultOrder),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: _SearchField(
            hintText: 'Поиск клиентов...',
            icon: Icons.search_rounded,
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: clients.isEmpty
              ? const Center(
                  child: Text(
                    'Клиентов пока нет',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  itemCount: clients.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _buildClientTile(clients[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildClientTile(_Client client) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: client.overdueAmount > 0
            ? Border.all(color: const Color(0x33DC2626), width: 1.2)
            : null,
      ),
      child: _BusinessCard(
        onTap: () => setState(() {
          _selectedClient = client;
          _isCrmFabExpanded = false;
        }),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        client.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        client.contact,
                        style: const TextStyle(
                          color: Color(0xFF7B8794),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(
                  label: client.overdueAmount > 0 ? 'Просрочка' : client.segment,
                  kind: client.overdueAmount > 0
                      ? StatusKind.error
                      : client.debt > 0
                          ? StatusKind.warning
                          : StatusKind.success,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.phone_rounded,
                    size: 14, color: Color(0xFF7B8794)),
                const SizedBox(width: 6),
                Text(
                  client.phone,
                  style:
                      const TextStyle(color: Color(0xFF7B8794), fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _LabelValue(
                    label: 'Продажи',
                    value: formatMoney(client.totalSales),
                  ),
                ),
                if (client.receivable > 0 || client.payable > 0)
                  _LabelValue(
                    label:
                        client.receivable > 0 ? 'Дебиторка' : 'Кредиторка',
                    value: formatMoney(
                      client.receivable > 0
                          ? client.receivable
                          : client.payable,
                    ),
                    valueColor: client.receivable > 0
                        ? const Color(0xFFD97706)
                        : const Color(0xFF2563EB),
                    textAlign: TextAlign.right,
                  ),
              ],
            ),
            if (client.overdueAmount > 0) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFDC2626), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Просрочено: ${formatMoney(client.overdueAmount)}',
                        style: const TextStyle(
                          color: Color(0xFF991B1B),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Detail view ──────────────────────────────────────────────────────────────

  Widget _buildClientDetail(_Client client) {
    return Column(
      children: [
        _GradientHeader(
          title: client.name,
          subtitle: client.binOrIinLabel.isEmpty ? null : client.binOrIinLabel,
          trailing: IconButton(
            onPressed: () => setState(() {
              _selectedClient = null;
              _isCrmFabExpanded = false;
            }),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            tooltip: 'Назад',
          ),
          child: Row(
            children: [
              Expanded(
                child: _HeroStat(
                  label: 'Общие продажи',
                  value: formatMoney(client.totalSales),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _HeroStat(
                  label: 'Дебиторка',
                  value: formatMoney(client.receivable),
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(
                label: client.segment,
                kind: client.segment == 'VIP'
                    ? StatusKind.warning
                    : StatusKind.neutral,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _BusinessCard(
                      child: _LabelValue(
                        label: 'Дебиторская задолженность',
                        value: formatMoney(client.receivable),
                        valueColor: const Color(0xFFD97706),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BusinessCard(
                      child: _LabelValue(
                        label: 'Кредиторская задолженность',
                        value: formatMoney(client.payable),
                        valueColor: const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _BusinessCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Взаиморасчеты',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _LabelValue(
                            label: 'Поступило',
                            value: formatMoney(client.paymentsIn),
                            valueColor: const Color(0xFF16A34A),
                          ),
                        ),
                        Expanded(
                          child: _LabelValue(
                            label: 'Оплачено',
                            value: formatMoney(client.paymentsOut),
                            valueColor: const Color(0xFF2563EB),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        _LabelValue(
                          label: 'Средний чек',
                          value: formatMoney(client.averageSale),
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _LabelValue(
                            label: 'Продаж',
                            value: '${client.salesCount}',
                          ),
                        ),
                        _LabelValue(
                          label: 'Просрочка',
                          value: formatMoney(client.overdueAmount),
                          valueColor: client.overdueAmount > 0
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF16A34A),
                          textAlign: TextAlign.right,
                        ),
                      ],
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
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    _InfoTile(
                      icon: Icons.person_rounded,
                      label: 'Контактное лицо',
                      value: client.contact,
                    ),
                    _InfoTile(
                      icon: Icons.phone_rounded,
                      label: 'Телефон',
                      value: client.phone,
                    ),
                    _InfoTile(
                      icon: Icons.mail_rounded,
                      label: 'Email',
                      value: client.email,
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
                      'Открытые документы',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    if (client.openDocuments.isEmpty)
                      const Text(
                        'Открытых документов нет',
                        style: TextStyle(color: Color(0xFF7B8794)),
                      )
                    else
                      ...client.openDocuments.map(
                        (document) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: _isSubmitting
                                  ? null
                                  : () => _openDebtDocument(document),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            document.documentNo,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                        _StatusBadge(
                                          label: document.status,
                                          kind: document.status == 'posted'
                                              ? StatusKind.success
                                              : StatusKind.warning,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${document.documentType} · ${document.operationDate}',
                                      style: const TextStyle(
                                          color: Color(0xFF7B8794),
                                          fontSize: 12),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _LabelValue(
                                            label: 'Сумма',
                                            value:
                                                formatMoney(document.amount),
                                          ),
                                        ),
                                        Expanded(
                                          child: _LabelValue(
                                            label: 'Оплачено',
                                            value: formatMoney(
                                                document.paidAmount),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        _LabelValue(
                                          label: 'Остаток',
                                          value: formatMoney(
                                              document.remainingAmount),
                                          valueColor:
                                              const Color(0xFFD97706),
                                          textAlign: TextAlign.right,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
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
                      'Продажи и оплаты',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    if (client.timeline.isEmpty)
                      const Text(
                        'Событий по клиенту пока нет',
                        style: TextStyle(color: Color(0xFF7B8794)),
                      )
                    else
                      ...client.timeline.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _BusinessCard(
                            onTap: _isSubmitting
                                ? null
                                : () => _openTimelineEvent(item),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: toneColor(item.tone)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    _iconForTimeline(item.eventType),
                                    color: toneColor(item.tone),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${item.subtitle} · ${item.eventDate}',
                                        style: const TextStyle(
                                            color: Color(0xFF7B8794),
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  formatMoney(item.amount),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: toneColor(item.tone),
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
                      'История взаимодействий',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    ...client.interactions.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(top: 6),
                              decoration: const BoxDecoration(
                                color: Color(0xFF00A86B),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      Text(
                                        item.date,
                                        style: const TextStyle(
                                            color: Color(0xFF7B8794),
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.note,
                                    style: const TextStyle(
                                        color: Color(0xFF7B8794),
                                        fontSize: 13),
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
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── FAB helpers ──────────────────────────────────────────────────────────────

  static const _clientFabActions = [
    _FabMenuAction(
      id: 'client_edit',
      label: 'Редактировать',
      icon: Icons.edit_outlined,
      color: Color(0xFF3B82F6),
    ),
    _FabMenuAction(
      id: 'client_sale',
      label: 'Продажа',
      icon: Icons.point_of_sale_rounded,
      color: Color(0xFF00A86B),
    ),
    _FabMenuAction(
      id: 'client_purchase',
      label: 'Закуп',
      icon: Icons.shopping_cart_checkout_rounded,
      color: Color(0xFF0F766E),
    ),
    _FabMenuAction(
      id: 'client_invoice',
      label: 'Счет на оплату',
      icon: Icons.receipt_long_rounded,
      color: Color(0xFFF59E0B),
    ),
    _FabMenuAction(
      id: 'client_settle',
      label: 'Принять оплату',
      icon: Icons.payments_rounded,
      color: Color(0xFF16A34A),
    ),
    _FabMenuAction(
      id: 'client_delete',
      label: 'Удалить',
      icon: Icons.delete_outline_rounded,
      color: Color(0xFFEF4444),
    ),
  ];

  Future<void> _handleClientFabAction(_FabMenuAction action) async {
    setState(() => _isCrmFabExpanded = false);
    final client = _selectedClient;
    if (client == null) return;
    switch (action.id) {
      case 'client_edit':
        await _showClientSheet(initialClient: client);
      case 'client_sale':
        await _showInventoryDocumentSheet(
            client: client, documentType: 'sale_issue');
      case 'client_purchase':
        await _showInventoryDocumentSheet(
            client: client, documentType: 'purchase_receipt');
      case 'client_invoice':
        await _openReceivableDocument(client);
      case 'client_settle':
        await _settleReceivableDocument(client);
      case 'client_delete':
        await _deleteClient(client);
    }
  }

  String _clientCountLabel(int count) {
    if (count % 100 >= 11 && count % 100 <= 19) return '$count клиентов';
    switch (count % 10) {
      case 1:
        return '$count клиент';
      case 2:
      case 3:
      case 4:
        return '$count клиента';
      default:
        return '$count клиентов';
    }
  }

  Future<void> _showClientSheet({_Client? initialClient}) async {
    final result = await showModalBottomSheet<_CreateClientFormData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateClientSheet(initialClient: initialClient),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final payload = {
        'name': result.name,
        'contact': result.contact,
        'phone': result.phone,
        'email': result.email,
        'segment': result.segment,
        'bin': result.bin,
        'iin': result.iin,
      };
      if (initialClient == null) {
        await widget.businessGateway.createClient(
          accessToken: widget.accessToken,
          payload: payload,
        );
      } else {
        await widget.businessGateway.updateClient(
          accessToken: widget.accessToken,
          clientId: initialClient.id,
          payload: payload,
        );
      }
      await widget.onClientsChanged();
      if (!mounted) {
        return;
      }
      if (initialClient != null) {
        setState(() {
          _selectedClient = null;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            initialClient == null ? 'Клиент добавлен' : 'Клиент обновлен',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _deleteClient(_Client client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить клиента?'),
        content: Text('Клиент "${client.name}" будет удален из CRM.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.businessGateway.deleteClient(
        accessToken: widget.accessToken,
        clientId: client.id,
      );
      await widget.onClientsChanged();
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedClient = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Клиент удален')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _openDebtDocument(
    _ClientDebtDocument document, {
    bool openSettleOnOpen = false,
  }) async {
    try {
      final payload = await widget.businessGateway.fetchMoneyDocumentDetail(
        accessToken: widget.accessToken,
        documentId: document.documentId,
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
          accessToken: widget.accessToken,
          businessGateway: widget.businessGateway,
          accounts: widget.accounts,
          detail: detail,
          onSettled: widget.onClientsChanged,
          openSettleOnOpen: openSettleOnOpen,
        ),
      );

      if (wasSettled == true) {
        await widget.onClientsChanged();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _openReceivableDocument(_Client client) async {
    final document = await _pickReceivableDocument(client);
    if (document == null) {
      return;
    }
    await _openDebtDocument(document);
  }

  Future<void> _settleReceivableDocument(_Client client) async {
    if (widget.accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Сначала добавьте счет в разделе Финансы')),
      );
      return;
    }

    final document = await _pickReceivableDocument(client);
    if (document == null) {
      return;
    }
    await _openDebtDocument(document, openSettleOnOpen: true);
  }

  Future<_ClientDebtDocument?> _pickReceivableDocument(_Client client) async {
    final documents = client.openDocuments
        .where(
          (document) =>
              document.documentType == 'sale_receivable' &&
              document.remainingAmount > 0,
        )
        .toList(growable: false);

    if (documents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Сначала создайте продажу с задолженностью для клиента'),
        ),
      );
      return null;
    }

    if (documents.length == 1) {
      return documents.first;
    }

    return showModalBottomSheet<_ClientDebtDocument>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ClientReceivableDocumentsSheet(
        clientName: client.name,
        documents: documents,
      ),
    );
  }

  Future<void> _showInventoryDocumentSheet({
    required _Client client,
    required String documentType,
  }) async {
    final result = await showModalBottomSheet<_CreateInventoryDocumentFormData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateInventoryDocumentSheet(
        accessToken: widget.accessToken,
        businessGateway: widget.businessGateway,
        products: widget.products,
        clients: widget.clients,
        initialDocumentType: documentType,
        initialClientId: client.id,
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.businessGateway.createInventoryDocument(
        accessToken: widget.accessToken,
        payload: {
          'document_type': result.documentType,
          'client_id': result.clientId,
          'warehouse_name': result.warehouseName,
          'related_warehouse_name': result.relatedWarehouseName,
          'note': result.note,
          'lines': result.lines
              .map(
                (line) => {
                  'product_id': line.productId,
                  'service_id': line.serviceId,
                  'quantity': line.quantity,
                  'unit_price': line.unitPrice,
                  'unit_cost': line.unitCost,
                  'note': line.note,
                },
              )
              .toList(growable: false),
        },
      );
      await widget.onClientsChanged();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.documentType == 'sale_issue'
                ? 'Продажа создана'
                : 'Закуп создан',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _openTimelineEvent(_ClientTimelineItem item) async {
    try {
      if (item.documentType == 'sale_issue' ||
          item.documentType == 'purchase_receipt') {
        final payload =
            await widget.businessGateway.fetchInventoryDocumentDetail(
          accessToken: widget.accessToken,
          documentId: item.documentId,
        );
        if (!mounted) {
          return;
        }
        final detail = _inventoryDocumentDetailFromJson(payload);
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => _InventoryDocumentDetailSheet(detail: detail),
        );
        return;
      }

      if (item.documentType == 'sale_receivable' ||
          item.documentType == 'purchase_payable') {
        final payload = await widget.businessGateway.fetchMoneyDocumentDetail(
          accessToken: widget.accessToken,
          documentId: item.documentId,
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
            accessToken: widget.accessToken,
            businessGateway: widget.businessGateway,
            accounts: widget.accounts,
            detail: detail,
            onSettled: widget.onClientsChanged,
          ),
        );
        if (wasSettled == true) {
          await widget.onClientsChanged();
        }
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  IconData _iconForTimeline(String eventType) {
    switch (eventType) {
      case 'sale_issue':
        return Icons.point_of_sale_rounded;
      case 'purchase_receipt':
        return Icons.shopping_cart_checkout_rounded;
      case 'payment_in':
        return Icons.arrow_downward_rounded;
      case 'payment_out':
        return Icons.arrow_upward_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }
}

enum _CrmSortMode {
  defaultOrder,
  overdueDesc,
  receivableDesc,
}

class _CreateClientFormData {
  const _CreateClientFormData({
    required this.name,
    required this.contact,
    required this.phone,
    required this.email,
    required this.segment,
    required this.bin,
    required this.iin,
  });

  final String name;
  final String contact;
  final String phone;
  final String email;
  final String segment;
  final String bin;
  final String iin;
}

class _ClientReceivableDocumentsSheet extends StatelessWidget {
  const _ClientReceivableDocumentsSheet({
    required this.clientName,
    required this.documents,
  });

  final String clientName;
  final List<_ClientDebtDocument> documents;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7FAF8),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: SizedBox(width: 48, child: Divider(thickness: 4)),
              ),
              const SizedBox(height: 12),
              const Text(
                'Выберите счет',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                clientName,
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: documents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final document = documents[index];
                    return _BusinessCard(
                      onTap: () => Navigator.of(context).pop(document),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  document.documentNo,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              _StatusBadge(
                                label: document.status,
                                kind: document.status == 'partial'
                                    ? StatusKind.warning
                                    : StatusKind.success,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            document.operationDate,
                            style: const TextStyle(
                              color: Color(0xFF7B8794),
                              fontSize: 12,
                            ),
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
                                  label: 'Оплачено',
                                  value: formatMoney(document.paidAmount),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              _LabelValue(
                                label: 'Остаток',
                                value: formatMoney(document.remainingAmount),
                                valueColor: const Color(0xFFD97706),
                                textAlign: TextAlign.right,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateClientSheet extends StatefulWidget {
  const _CreateClientSheet({this.initialClient});

  final _Client? initialClient;

  @override
  State<_CreateClientSheet> createState() => _CreateClientSheetState();
}

class _CreateClientSheetState extends State<_CreateClientSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _binController = TextEditingController();
  final _iinController = TextEditingController();
  String _segment = 'Regular';

  @override
  void initState() {
    super.initState();
    final client = widget.initialClient;
    if (client == null) {
      return;
    }

    _nameController.text = client.name;
    _contactController.text = client.contact;
    _phoneController.text = client.phone;
    _emailController.text = client.email;
    _binController.text = client.bin ?? '';
    _iinController.text = client.iin ?? '';
    _segment = client.segment;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _binController.dispose();
    _iinController.dispose();
    super.dispose();
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Center(
                      child: SizedBox(
                        width: 48,
                        child: Divider(thickness: 4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.initialClient == null
                          ? 'Новый клиент'
                          : 'Редактировать клиента',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ClientTextField(
                      controller: _nameController,
                      label: 'Название / ФИО',
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 12),
                    _ClientTextField(
                      controller: _contactController,
                      label: 'Контактное лицо',
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 12),
                    _ClientTextField(
                      controller: _phoneController,
                      label: 'Телефон',
                      keyboardType: TextInputType.phone,
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 12),
                    _ClientTextField(
                      controller: _emailController,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _segment,
                      items: const [
                        DropdownMenuItem(
                            value: 'Regular', child: Text('Regular')),
                        DropdownMenuItem(value: 'VIP', child: Text('VIP')),
                      ],
                      decoration: const InputDecoration(labelText: 'Сегмент'),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _segment = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _ClientTextField(
                      controller: _binController,
                      label: 'БИН',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    _ClientTextField(
                      controller: _iinController,
                      label: 'ИИН',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submit,
                        child: Text(
                          widget.initialClient == null
                              ? 'Сохранить'
                              : 'Обновить',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _CreateClientFormData(
        name: _nameController.text.trim(),
        contact: _contactController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        segment: _segment,
        bin: _binController.text.trim(),
        iin: _iinController.text.trim(),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Обязательное поле';
    }
    return null;
  }
}

class _ClientTextField extends StatelessWidget {
  const _ClientTextField({
    required this.controller,
    required this.label,
    this.validator,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
    );
  }
}
