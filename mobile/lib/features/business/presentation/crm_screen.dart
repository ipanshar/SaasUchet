part of 'business_shell.dart';

class _CrmScreen extends StatefulWidget {
  const _CrmScreen({
    required this.accessToken,
    required this.clients,
    required this.businessGateway,
    required this.onClientsChanged,
  });

  final String accessToken;
  final List<_Client> clients;
  final BusinessGateway businessGateway;
  final Future<void> Function() onClientsChanged;

  @override
  State<_CrmScreen> createState() => _CrmScreenState();
}

class _CrmScreenState extends State<_CrmScreen> {
  String _query = '';
  _Client? _selectedClient;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final clients = widget.clients.where((client) {
      final query = _query.toLowerCase();
      return client.name.toLowerCase().contains(query) ||
          client.contact.toLowerCase().contains(query);
    }).toList();

    final vipCount =
        widget.clients.where((client) => client.segment == 'VIP').length;
    final debtorCount =
        widget.clients.where((client) => client.debt > 0).length;

    if (_selectedClient != null) {
      final client = _selectedClient!;
      return SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _selectedClient = null),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Назад'),
            ),
            const SizedBox(height: 8),
            _BusinessCard(
              background: const LinearGradient(
                colors: [Color(0xFF00A86B), Color(0xFF008F5B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
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
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              client.binOrIinLabel,
                              style: const TextStyle(color: Color(0xCCFFFFFF)),
                            ),
                          ],
                        ),
                      ),
                      _StatusBadge(
                        label: client.segment,
                        kind: client.segment == 'VIP'
                            ? StatusKind.warning
                            : StatusKind.neutral,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _HeroStat(
                        label: 'Общие продажи',
                        value: formatMoney(client.totalSales),
                      ),
                      const SizedBox(width: 16),
                      _HeroStat(
                        label: 'Задолженность',
                        value: formatMoney(client.debt),
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
                    'История взаимодействий',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      item.date,
                                      style: const TextStyle(
                                        color: Color(0xFF7B8794),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.note,
                                  style: const TextStyle(
                                    color: Color(0xFF7B8794),
                                    fontSize: 13,
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
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => _showClientSheet(initialClient: client),
                    child: const Text('Редактировать'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _isSubmitting ? null : () => _deleteClient(client),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                    ),
                    child: const Text('Удалить'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {},
                    child: const Text('Создать сделку'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Text('Позвонить'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'CRM',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
              ),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : () => _showClientSheet(),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Клиент'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SearchField(
                  hintText: 'Поиск клиентов...',
                  icon: Icons.search_rounded,
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              const SizedBox(width: 10),
              _SquareIconButton(icon: Icons.tune_rounded, onPressed: () {}),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Всего клиентов',
                  value: '${widget.clients.length}',
                  tone: const Color(0x1400A86B),
                  accent: const Color(0xFF00A86B),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  title: 'VIP клиенты',
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
          const SizedBox(height: 16),
          ...clients.map(
            (client) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _BusinessCard(
                onTap: () => setState(() => _selectedClient = client),
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
                          label: client.segment,
                          kind: client.debt > 0
                              ? StatusKind.warning
                              : StatusKind.success,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_rounded,
                          size: 14,
                          color: Color(0xFF7B8794),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          client.phone,
                          style: const TextStyle(
                            color: Color(0xFF7B8794),
                            fontSize: 12,
                          ),
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
                        if (client.debt > 0)
                          _LabelValue(
                            label: 'Долг',
                            value: formatMoney(client.debt),
                            valueColor: const Color(0xFFD97706),
                            textAlign: TextAlign.right,
                          ),
                      ],
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
