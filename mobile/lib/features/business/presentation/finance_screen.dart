part of 'business_shell.dart';

class _FinanceScreen extends StatefulWidget {
  const _FinanceScreen({
    required this.accessToken,
    required this.finance,
    required this.businessGateway,
    required this.onFinanceChanged,
    this.canWrite = true,
  });

  final String accessToken;
  final _FinanceOverview finance;
  final BusinessGateway businessGateway;
  final Future<void> Function() onFinanceChanged;
  final bool canWrite;

  @override
  State<_FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<_FinanceScreen> {
  FinancePeriod _period = FinancePeriod.month;
  bool _isSubmitting = false;

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
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Счета',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed:
                                  _isSubmitting ? null : _showMoneyDocuments,
                              icon: const Icon(Icons.receipt_long_rounded),
                              label: const Text('Документы'),
                            ),
                            if (widget.canWrite) ...[
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed:
                                    _isSubmitting ? null : _showAccountSheet,
                                icon: const Icon(Icons.add_card_rounded),
                                label: const Text('Счет'),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (widget.finance.accounts.isEmpty)
                          const Text(
                            'Добавьте первый счет, чтобы начать учет денег.',
                            style: TextStyle(color: Color(0xFF7B8794)),
                          )
                        else
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
                  if (widget.canWrite) ...[
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed:
                                _isSubmitting ? null : _showMoneyOperationSheet,
                            child: const Text('Операция'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSubmitting ? null : _showTransferSheet,
                            child: const Text('Перевод'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
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
                        _ExpensesChart(
                          categories: widget.finance.expenseCategories,
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
                        if (widget.finance.transactions.isEmpty)
                          const Text(
                            'Операций пока нет',
                            style: TextStyle(color: Color(0xFF7B8794)),
                          )
                        else
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

  Future<void> _showAccountSheet() async {
    final result = await showModalBottomSheet<_CreateAccountFormData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CreateAccountSheet(),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.businessGateway.createCashAccount(
        accessToken: widget.accessToken,
        payload: {
          'name': result.name,
          'account_type': result.accountType,
          'currency_code': 'KZT',
          'bank_name': result.bankName,
          'iban': result.iban,
          'bik': result.bik,
          'opening_balance': result.openingBalance,
        },
      );
      await widget.onFinanceChanged();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Счет добавлен')),
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

  Future<void> _showMoneyOperationSheet() async {
    if (widget.finance.accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала добавьте счет')),
      );
      return;
    }

    final result = await showModalBottomSheet<_CreateMoneyOperationFormData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateMoneyOperationSheet(
        accounts: widget.finance.accounts,
        transferMode: false,
        incomeCategories: widget.finance.incomeCategories
            .map((category) => category.name)
            .toList(growable: false),
        expenseCategories: widget.finance.expenseCategories
            .map((category) => category.name)
            .toList(growable: false),
      ),
    );

    if (result == null) {
      return;
    }

    await _submitMoneyOperation(result);
  }

  Future<void> _showTransferSheet() async {
    if (widget.finance.accounts.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Для перевода нужно минимум два счета')),
      );
      return;
    }

    final result = await showModalBottomSheet<_CreateMoneyOperationFormData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateMoneyOperationSheet(
        accounts: widget.finance.accounts,
        transferMode: true,
      ),
    );

    if (result == null) {
      return;
    }

    await _submitMoneyOperation(result);
  }

  Future<void> _submitMoneyOperation(
      _CreateMoneyOperationFormData result) async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.businessGateway.createMoneyOperation(
        accessToken: widget.accessToken,
        payload: {
          'account_id': result.accountId,
          'counterparty_account_id': result.counterpartyAccountId,
          'direction': result.direction,
          'amount': result.amount,
          'category': result.category,
          'description': result.description,
        },
      );
      await widget.onFinanceChanged();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Операция сохранена')),
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

  Future<void> _showMoneyDocuments() async {
    try {
      final documents = await widget.businessGateway.fetchMoneyDocuments(
        accessToken: widget.accessToken,
      );
      if (!mounted) {
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _MoneyDocumentsSheet(
          accessToken: widget.accessToken,
          businessGateway: widget.businessGateway,
          accounts: widget.finance.accounts,
          onSettled: widget.onFinanceChanged,
          documents:
              documents.map(_moneyDocumentFromJson).toList(growable: false),
          canWrite: widget.canWrite,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }
}

class _CreateAccountFormData {
  const _CreateAccountFormData({
    required this.name,
    required this.accountType,
    required this.bankName,
    required this.iban,
    required this.bik,
    required this.openingBalance,
  });

  final String name;
  final String accountType;
  final String bankName;
  final String iban;
  final String bik;
  final int openingBalance;
}

class _CreateAccountSheet extends StatefulWidget {
  const _CreateAccountSheet();

  @override
  State<_CreateAccountSheet> createState() => _CreateAccountSheetState();
}

class _CreateAccountSheetState extends State<_CreateAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _ibanController = TextEditingController();
  final _bikController = TextEditingController();
  final _openingBalanceController = TextEditingController(text: '0');
  String _accountType = 'bank';

  @override
  void dispose() {
    _nameController.dispose();
    _bankNameController.dispose();
    _ibanController.dispose();
    _bikController.dispose();
    _openingBalanceController.dispose();
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
                  children: [
                    const Center(
                      child: SizedBox(width: 48, child: Divider(thickness: 4)),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Новый счет',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ClientTextField(
                      controller: _nameController,
                      label: 'Название счета',
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _accountType,
                      items: const [
                        DropdownMenuItem(value: 'bank', child: Text('Банк')),
                        DropdownMenuItem(value: 'cash', child: Text('Касса')),
                        DropdownMenuItem(value: 'card', child: Text('Карта')),
                        DropdownMenuItem(
                          value: 'e_wallet',
                          child: Text('Электронный кошелек'),
                        ),
                      ],
                      decoration: const InputDecoration(labelText: 'Тип счета'),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _accountType = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _ClientTextField(
                      controller: _bankNameController,
                      label: 'Банк',
                    ),
                    const SizedBox(height: 12),
                    _ClientTextField(
                      controller: _ibanController,
                      label: 'IBAN',
                    ),
                    const SizedBox(height: 12),
                    _ClientTextField(
                      controller: _bikController,
                      label: 'БИК',
                    ),
                    const SizedBox(height: 12),
                    _ClientTextField(
                      controller: _openingBalanceController,
                      label: 'Начальный остаток',
                      keyboardType: TextInputType.number,
                      validator: _numberValidator,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submit,
                        child: const Text('Сохранить'),
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
      _CreateAccountFormData(
        name: _nameController.text.trim(),
        accountType: _accountType,
        bankName: _bankNameController.text.trim(),
        iban: _ibanController.text.trim(),
        bik: _bikController.text.trim(),
        openingBalance: int.parse(_openingBalanceController.text.trim()),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Обязательное поле';
    }
    return null;
  }

  String? _numberValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Обязательное поле';
    }
    if (int.tryParse(value.trim()) == null) {
      return 'Введите число';
    }
    return null;
  }
}

class _CreateMoneyOperationFormData {
  const _CreateMoneyOperationFormData({
    required this.accountId,
    required this.counterpartyAccountId,
    required this.direction,
    required this.amount,
    required this.category,
    required this.description,
  });

  final String accountId;
  final String counterpartyAccountId;
  final String direction;
  final int amount;
  final String category;
  final String description;
}

class _CreateMoneyOperationSheet extends StatefulWidget {
  const _CreateMoneyOperationSheet({
    required this.accounts,
    required this.transferMode,
    this.incomeCategories = const [],
    this.expenseCategories = const [],
  });

  final List<_BankAccount> accounts;
  final bool transferMode;
  final List<String> incomeCategories;
  final List<String> expenseCategories;

  @override
  State<_CreateMoneyOperationSheet> createState() =>
      _CreateMoneyOperationSheetState();
}

class _CreateMoneyOperationSheetState
    extends State<_CreateMoneyOperationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  late String _accountId;
  String _counterpartyAccountId = '';
  String _direction = 'income';

  @override
  void initState() {
    super.initState();
    _accountId = widget.accounts.first.id;
    if (widget.transferMode && widget.accounts.length > 1) {
      _direction = 'transfer';
      _counterpartyAccountId = widget.accounts[1].id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
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
                  children: [
                    const Center(
                      child: SizedBox(width: 48, child: Divider(thickness: 4)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.transferMode ? 'Новый перевод' : 'Новая операция',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!widget.transferMode) ...[
                      DropdownButtonFormField<String>(
                        initialValue: _direction,
                        items: const [
                          DropdownMenuItem(
                            value: 'income',
                            child: Text('Приход'),
                          ),
                          DropdownMenuItem(
                            value: 'expense',
                            child: Text('Расход'),
                          ),
                        ],
                        decoration: const InputDecoration(labelText: 'Тип'),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _direction = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    DropdownButtonFormField<String>(
                      initialValue: _accountId,
                      items: widget.accounts
                          .map(
                            (account) => DropdownMenuItem(
                              value: account.id,
                              child: Text(account.name),
                            ),
                          )
                          .toList(growable: false),
                      decoration: InputDecoration(
                        labelText:
                            widget.transferMode ? 'Счет списания' : 'Счет',
                      ),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _accountId = value;
                            if (_counterpartyAccountId == value) {
                              _counterpartyAccountId = '';
                            }
                          });
                        }
                      },
                    ),
                    if (widget.transferMode) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _counterpartyAccountId.isEmpty
                            ? null
                            : _counterpartyAccountId,
                        items: widget.accounts
                            .where((account) => account.id != _accountId)
                            .map(
                              (account) => DropdownMenuItem(
                                value: account.id,
                                child: Text(account.name),
                              ),
                            )
                            .toList(growable: false),
                        decoration: const InputDecoration(
                          labelText: 'Счет зачисления',
                        ),
                        onChanged: (value) {
                          setState(() {
                            _counterpartyAccountId = value ?? '';
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    _ClientTextField(
                      controller: _amountController,
                      label: 'Сумма',
                      keyboardType: TextInputType.number,
                      validator: _numberValidator,
                    ),
                    const SizedBox(height: 12),
                    if (!widget.transferMode) ...[
                      Autocomplete<String>(
                        textEditingController: _categoryController,
                        optionsBuilder: (textValue) {
                          final source = _direction == 'income'
                              ? widget.incomeCategories
                              : widget.expenseCategories;
                          final query = textValue.text.trim().toLowerCase();
                          if (query.isEmpty) {
                            return source;
                          }
                          return source.where(
                            (category) =>
                                category.toLowerCase().contains(query),
                          );
                        },
                        fieldViewBuilder:
                            (context, controller, focusNode, onSubmitted) {
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration:
                                const InputDecoration(labelText: 'Категория'),
                            validator: _requiredValidator,
                            onFieldSubmitted: (_) => onSubmitted(),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    _ClientTextField(
                      controller: _descriptionController,
                      label: 'Описание',
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submit,
                        child: const Text('Сохранить'),
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
    if (widget.transferMode && _counterpartyAccountId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите счет зачисления')),
      );
      return;
    }

    Navigator.of(context).pop(
      _CreateMoneyOperationFormData(
        accountId: _accountId,
        counterpartyAccountId: _counterpartyAccountId,
        direction: widget.transferMode ? 'transfer' : _direction,
        amount: int.parse(_amountController.text.trim()),
        category: widget.transferMode ? '' : _categoryController.text.trim(),
        description: _descriptionController.text.trim(),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Обязательное поле';
    }
    return null;
  }

  String? _numberValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Обязательное поле';
    }
    if (int.tryParse(value.trim()) == null) {
      return 'Введите число';
    }
    return null;
  }
}

class _MoneyDocumentsSheet extends StatefulWidget {
  const _MoneyDocumentsSheet({
    required this.accessToken,
    required this.businessGateway,
    required this.accounts,
    required this.onSettled,
    required this.documents,
    this.canWrite = true,
  });

  final String accessToken;
  final BusinessGateway businessGateway;
  final List<_BankAccount> accounts;
  final Future<void> Function() onSettled;
  final List<_MoneyDocument> documents;
  final bool canWrite;

  @override
  State<_MoneyDocumentsSheet> createState() => _MoneyDocumentsSheetState();
}

class _MoneyDocumentsSheetState extends State<_MoneyDocumentsSheet> {
  String _query = '';
  String _type = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.documents.where((document) {
      final matchesType = _type.isEmpty || document.documentType == _type;
      final query = _query.toLowerCase();
      final matchesQuery = query.isEmpty ||
          document.documentNo.toLowerCase().contains(query) ||
          document.description.toLowerCase().contains(query) ||
          document.primaryAccount.toLowerCase().contains(query) ||
          document.secondaryAccount.toLowerCase().contains(query);
      return matchesType && matchesQuery;
    }).toList(growable: false);

    final documentTypes = widget.documents
        .map((item) => item.documentType)
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);

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
            children: [
              const SizedBox(width: 48, child: Divider(thickness: 4)),
              const SizedBox(height: 12),
              const Text(
                'Денежные документы',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              _SearchField(
                hintText: 'Поиск по номеру, описанию, счету...',
                icon: Icons.search_rounded,
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChipButton(
                      label: 'Все',
                      active: _type.isEmpty,
                      activeColor: const Color(0xFF00A86B),
                      onPressed: () => setState(() => _type = ''),
                    ),
                    ...documentTypes.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _FilterChipButton(
                          label: item,
                          active: _type == item,
                          activeColor: const Color(0xFF2563EB),
                          onPressed: () => setState(() => _type = item),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'Документы не найдены',
                          style: TextStyle(color: Color(0xFF7B8794)),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final document = filtered[index];
                          return _BusinessCard(
                            onTap: () => _openDocumentDetail(document),
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
                                    Text(
                                      formatMoney(document.amount),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${document.documentType} • ${document.operationDate}',
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
                                        label: 'Основной счет',
                                        value: document.primaryAccount,
                                      ),
                                    ),
                                    if (document.secondaryAccount.isNotEmpty)
                                      Expanded(
                                        child: _LabelValue(
                                          label: 'Второй счет',
                                          value: document.secondaryAccount,
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                  ],
                                ),
                                if (document.documentType ==
                                        'sale_receivable' ||
                                    document.documentType ==
                                        'purchase_payable') ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _LabelValue(
                                          label: 'Оплачено',
                                          value:
                                              formatMoney(document.paidAmount),
                                        ),
                                      ),
                                      _LabelValue(
                                        label: 'Остаток',
                                        value: formatMoney(
                                          document.remainingAmount,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ],
                                  ),
                                ],
                                if (document.description.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    document.description,
                                    style: const TextStyle(
                                      color: Color(0xFF475569),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
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

  Future<void> _openDocumentDetail(_MoneyDocument document) async {
    try {
      final payload = await widget.businessGateway.fetchMoneyDocumentDetail(
        accessToken: widget.accessToken,
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
          accessToken: widget.accessToken,
          businessGateway: widget.businessGateway,
          accounts: widget.accounts,
          detail: detail,
          onSettled: widget.onSettled,
          canWrite: widget.canWrite,
        ),
      );
      if (wasSettled == true && mounted) {
        Navigator.of(context).pop();
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
}

class _MoneyDocumentDetailSheet extends StatefulWidget {
  const _MoneyDocumentDetailSheet({
    required this.accessToken,
    required this.businessGateway,
    required this.accounts,
    required this.detail,
    required this.onSettled,
    this.openSettleOnOpen = false,
    this.canWrite = true,
  });

  final String accessToken;
  final BusinessGateway businessGateway;
  final List<_BankAccount> accounts;
  final _MoneyDocumentDetail detail;
  final Future<void> Function() onSettled;
  final bool openSettleOnOpen;
  final bool canWrite;

  @override
  State<_MoneyDocumentDetailSheet> createState() =>
      _MoneyDocumentDetailSheetState();
}

class _MoneyDocumentDetailSheetState extends State<_MoneyDocumentDetailSheet> {
  bool _isSubmitting = false;
  bool _didAutoOpenSettle = false;

  bool get _canSettle =>
      widget.canWrite &&
      (widget.detail.summary.status == 'draft' ||
          widget.detail.summary.status == 'partial') &&
      (widget.detail.summary.documentType == 'sale_receivable' ||
          widget.detail.summary.documentType == 'purchase_payable') &&
      widget.accounts.isNotEmpty &&
      widget.detail.summary.remainingAmount > 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !widget.openSettleOnOpen ||
          !_canSettle ||
          _didAutoOpenSettle) {
        return;
      }
      _didAutoOpenSettle = true;
      _settleDocument();
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
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
            children: [
              const SizedBox(width: 48, child: Divider(thickness: 4)),
              const SizedBox(height: 12),
              Text(
                detail.summary.documentNo,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                '${detail.summary.documentType} • ${detail.summary.operationDate}',
                style: const TextStyle(color: Color(0xFF7B8794)),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _BusinessCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: _LabelValue(
                              label: 'Основной счет',
                              value: detail.summary.primaryAccount.isEmpty
                                  ? 'Не выбран'
                                  : detail.summary.primaryAccount,
                            ),
                          ),
                          _LabelValue(
                            label: 'Сумма',
                            value: formatMoney(detail.summary.amount),
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ),
                    ),
                    if (detail.summary.documentType == 'sale_receivable' ||
                        detail.summary.documentType == 'purchase_payable') ...[
                      const SizedBox(height: 12),
                      _BusinessCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: _LabelValue(
                                label: 'Оплачено',
                                value: formatMoney(detail.summary.paidAmount),
                              ),
                            ),
                            _LabelValue(
                              label: 'Остаток',
                              value: formatMoney(
                                detail.summary.remainingAmount,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (detail.summary.description.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _BusinessCard(
                        child: Text(
                          detail.summary.description,
                          style: const TextStyle(color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    ...detail.lines.map(
                      (line) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _BusinessCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      line.category.isEmpty
                                          ? 'Без категории'
                                          : line.category,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (line.note.isNotEmpty)
                                      Text(
                                        line.note,
                                        style: const TextStyle(
                                          color: Color(0xFF7B8794),
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                formatMoney(line.amount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_canSettle) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isSubmitting ? null : _settleDocument,
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Провести оплату'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _settleDocument() async {
    final result = await showModalBottomSheet<_SettleMoneyDocumentFormData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SettleMoneyDocumentSheet(
        accounts: widget.accounts,
        maxAmount: widget.detail.summary.remainingAmount,
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.businessGateway.settleMoneyDocument(
        accessToken: widget.accessToken,
        documentId: widget.detail.summary.id,
        payload: {
          'account_id': result.accountId,
          'amount': result.amount,
          'operation_date': result.operationDate,
          'description': result.description,
        },
      );
      await widget.onSettled();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Оплата проведена')),
      );
      Navigator.of(context).pop(true);
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

class _SettleMoneyDocumentFormData {
  const _SettleMoneyDocumentFormData({
    required this.accountId,
    required this.amount,
    required this.operationDate,
    required this.description,
  });

  final String accountId;
  final int amount;
  final String operationDate;
  final String description;
}

class _SettleMoneyDocumentSheet extends StatefulWidget {
  const _SettleMoneyDocumentSheet({
    required this.accounts,
    required this.maxAmount,
  });

  final List<_BankAccount> accounts;
  final int maxAmount;

  @override
  State<_SettleMoneyDocumentSheet> createState() =>
      _SettleMoneyDocumentSheetState();
}

class _SettleMoneyDocumentSheetState extends State<_SettleMoneyDocumentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _operationDateController;
  final _descriptionController = TextEditingController();
  late String _accountId;

  @override
  void initState() {
    super.initState();
    _accountId = widget.accounts.first.id;
    _amountController = TextEditingController(text: '${widget.maxAmount}');
    final now = DateTime.now();
    _operationDateController = TextEditingController(
      text:
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _operationDateController.dispose();
    _descriptionController.dispose();
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
                  children: [
                    const Center(
                      child: SizedBox(width: 48, child: Divider(thickness: 4)),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Провести оплату',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _accountId,
                      items: widget.accounts
                          .map(
                            (account) => DropdownMenuItem<String>(
                              value: account.id,
                              child: Text(account.name),
                            ),
                          )
                          .toList(growable: false),
                      decoration: const InputDecoration(labelText: 'Счет'),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _accountId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _ClientTextField(
                      controller: _amountController,
                      label: 'Сумма оплаты',
                      keyboardType: TextInputType.number,
                      validator: _amountValidator,
                    ),
                    const SizedBox(height: 12),
                    _ClientTextField(
                      controller: _operationDateController,
                      label: 'Дата операции',
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 12),
                    _ClientTextField(
                      controller: _descriptionController,
                      label: 'Комментарий',
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submit,
                        child: const Text('Провести'),
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
      _SettleMoneyDocumentFormData(
        accountId: _accountId,
        amount: int.parse(_amountController.text.trim()),
        operationDate: _operationDateController.text.trim(),
        description: _descriptionController.text.trim(),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Обязательное поле';
    }
    return null;
  }

  String? _amountValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Обязательное поле';
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return 'Введите число';
    }
    if (parsed <= 0) {
      return 'Сумма должна быть больше нуля';
    }
    if (parsed > widget.maxAmount) {
      return 'Сумма не должна превышать остаток';
    }
    return null;
  }
}
