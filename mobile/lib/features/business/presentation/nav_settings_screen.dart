import 'package:flutter/material.dart';
import 'package:saas_uchet_mobile/features/business/presentation/business_shell.dart';

class NavSettingsScreen extends StatefulWidget {
  const NavSettingsScreen({
    super.key,
    required this.currentMiddleTabs,
    required this.onSaved,
  });

  final List<BusinessTab> currentMiddleTabs;
  final Future<void> Function(List<BusinessTab> middleTabs) onSaved;

  @override
  State<NavSettingsScreen> createState() => _NavSettingsScreenState();
}

class _NavSettingsScreenState extends State<NavSettingsScreen> {
  static const _availableTabs = [
    BusinessTab.crm,
    BusinessTab.warehouse,
    BusinessTab.finance,
    BusinessTab.catalog,
    BusinessTab.production,
    BusinessTab.sales,
    BusinessTab.purchases,
    BusinessTab.services,
  ];

  late final Set<BusinessTab> _selectedTabs;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedTabs = widget.currentMiddleTabs.toSet();
    if (_selectedTabs.isEmpty) {
      _selectedTabs.addAll(
        const [
          BusinessTab.crm,
          BusinessTab.warehouse,
          BusinessTab.finance,
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройка вкладок'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Выберите разделы между "Главная" и "Еще".',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          ..._availableTabs.map(
            (tab) => CheckboxListTile(
              value: _selectedTabs.contains(tab),
              title: Text(tabLabel(tab)),
              secondary: Icon(tabIcon(tab)),
              onChanged: _isSaving
                  ? null
                  : (value) {
                      setState(() {
                        if (value == true) {
                          _selectedTabs.add(tab);
                        } else {
                          _selectedTabs.remove(tab);
                        }
                      });
                    },
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_selectedTabs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите хотя бы один раздел')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.onSaved(
        _availableTabs.where(_selectedTabs.contains).toList(growable: false),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
