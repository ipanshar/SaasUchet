part of 'business_shell.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Payroll settings — recipe payroll amounts (сумма за партию по рецепту)
// ─────────────────────────────────────────────────────────────────────────────

class _PayrollSettingsScreen extends StatefulWidget {
  const _PayrollSettingsScreen({
    required this.accessToken,
    required this.gateway,
  });

  final String accessToken;
  final BusinessGateway gateway;

  @override
  State<_PayrollSettingsScreen> createState() => _PayrollSettingsScreenState();
}

class _PayrollSettingsScreenState extends State<_PayrollSettingsScreen> {
  List<_Recipe> _recipes = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final rows =
          await widget.gateway.fetchRecipes(accessToken: widget.accessToken);
      if (!mounted) return;
      setState(() {
        _recipes = rows.map(_recipeFromJson).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _isLoading = false;
      });
    }
  }

  Future<void> _editRate(_Recipe recipe) async {
    final amount = await showDialog<int>(
      context: context,
      builder: (_) => _RecipeRateDialog(recipe: recipe),
    );
    if (amount == null || !mounted) return;
    try {
      await widget.gateway.setRecipePayrollAmount(
        accessToken: widget.accessToken,
        recipeId: recipe.id,
        amount: amount,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      appBar: AppBar(title: const Text('Настройки начислений')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 48, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const Text('Сдельная за производство',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 4),
        const Text(
          'Сумма начисляется за партию рецепта и делится между участниками производственного заказа по их долям.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
        const SizedBox(height: 16),
        if (_recipes.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.menu_book_outlined,
                      size: 56, color: Color(0xFFCBD5E1)),
                  SizedBox(height: 12),
                  Text('Рецептов пока нет',
                      style:
                          TextStyle(color: Color(0xFF94A3B8), fontSize: 16)),
                  SizedBox(height: 4),
                  Text('Создайте рецепт в разделе «Производство»',
                      style:
                          TextStyle(color: Color(0xFFCBD5E1), fontSize: 13)),
                ],
              ),
            ),
          )
        else
          ..._recipes.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _BusinessCard(
                onTap: () => _editRate(r),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0x1A7C3AED),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.menu_book_rounded,
                          color: Color(0xFF7C3AED), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                          const Text('за партию',
                              style: TextStyle(
                                  color: Color(0xFF94A3B8), fontSize: 12)),
                        ],
                      ),
                    ),
                    Text(formatMoney(r.payrollAmount),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(width: 4),
                    const Icon(Icons.edit_outlined,
                        size: 18, color: Color(0xFF3B82F6)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RecipeRateDialog extends StatefulWidget {
  const _RecipeRateDialog({required this.recipe});

  final _Recipe recipe;

  @override
  State<_RecipeRateDialog> createState() => _RecipeRateDialogState();
}

class _RecipeRateDialogState extends State<_RecipeRateDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.recipe.payrollAmount == 0
            ? ''
            : widget.recipe.payrollAmount.toString());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.recipe.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Сумма к распределению за партию, ₸',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _ctrl,
            autofocus: true,
            decoration: _inputDecoration('0'),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        FilledButton(
          onPressed: () {
            final cleaned = _ctrl.text.replaceAll(RegExp(r'[^0-9]'), '');
            Navigator.pop(context, cleaned.isEmpty ? 0 : int.parse(cleaned));
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
