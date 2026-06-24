import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:saas_uchet_mobile/core/config/api_config.dart';
import 'package:saas_uchet_mobile/features/business/domain/business_gateway.dart';

class CompanyEditorScreen extends StatefulWidget {
  const CompanyEditorScreen({
    super.key,
    required this.businessGateway,
    required this.accessToken,
    required this.companyId,
  });

  final BusinessGateway businessGateway;
  final String accessToken;
  final String companyId;

  @override
  State<CompanyEditorScreen> createState() => _CompanyEditorScreenState();
}

class _CompanyEditorScreenState extends State<CompanyEditorScreen> {
  static const _primaryColor = Color(0xFF00A86B);
  static const _bg = Color(0xFFF7FAF8);
  static const _textPrimary = Color(0xFF0F172A);
  static const _maxLogoBytes = 2 * 1024 * 1024;
  static const _allowedLogoExtensions = [
    'ico',
    'png',
    'jpg',
    'jpeg',
    'svg',
    'swg',
  ];

  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _legalFormCtrl = TextEditingController();
  final _iinCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _bankAccountCtrl = TextEditingController();
  final _bankBikCtrl = TextEditingController();
  String _country = 'KZ';

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLogoUploading = false;
  bool _didChange = false;
  String? _error;
  String? _logoError;
  String? _logoUrl;

  @override
  void initState() {
    super.initState();
    _loadCompany();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _legalFormCtrl.dispose();
    _iinCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _regionCtrl.dispose();
    _postalCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankAccountCtrl.dispose();
    _bankBikCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCompany() async {
    try {
      final data = await widget.businessGateway.fetchCompany(
        accessToken: widget.accessToken,
        companyId: widget.companyId,
      );
      if (!mounted) return;
      setState(() {
        _nameCtrl.text = data['name'] as String? ?? '';
        _legalFormCtrl.text = data['legal_form'] as String? ?? '';
        _iinCtrl.text = data['iin'] as String? ?? '';
        _country = data['country'] as String? ?? 'KZ';
        _emailCtrl.text = data['email'] as String? ?? '';
        _phoneCtrl.text = data['phone'] as String? ?? '';
        _addressCtrl.text = data['address_line'] as String? ?? '';
        _cityCtrl.text = data['city'] as String? ?? '';
        _regionCtrl.text = data['region'] as String? ?? '';
        _postalCtrl.text = data['postal_code'] as String? ?? '';
        _bankNameCtrl.text = data['bank_name'] as String? ?? '';
        _bankAccountCtrl.text = data['bank_account'] as String? ?? '';
        _bankBikCtrl.text = data['bank_bik'] as String? ?? '';
        _logoUrl = data['logo_url'] as String?;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await widget.businessGateway.updateCompany(
        accessToken: widget.accessToken,
        companyId: widget.companyId,
        payload: {
          'name': _nameCtrl.text.trim(),
          'legal_form': _legalFormCtrl.text.trim(),
          'country': _country,
          'iin': _iinCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'address_line': _addressCtrl.text.trim(),
          'city': _cityCtrl.text.trim(),
          'region': _regionCtrl.text.trim(),
          'postal_code': _postalCtrl.text.trim(),
          'bank_name': _bankNameCtrl.text.trim(),
          'bank_account': _bankAccountCtrl.text.trim(),
          'bank_bik': _bankBikCtrl.text.trim(),
          'is_vat_payer': false,
        },
      );
      if (!mounted) return;
      _didChange = true;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _pickAndUploadLogo() async {
    setState(() => _logoError = null);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedLogoExtensions,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      final filename = file.name.trim();
      final extension = _logoExtension(filename);
      if (!_allowedLogoExtensions.contains(extension)) {
        setState(() {
          _logoError = 'Поддерживаются только ICO, PNG, JPG и SVG.';
        });
        return;
      }

      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        setState(() {
          _logoError = 'Не удалось прочитать выбранный файл.';
        });
        return;
      }
      if (bytes.length > _maxLogoBytes) {
        setState(() {
          _logoError = 'Логотип должен быть не больше 2 МБ.';
        });
        return;
      }

      if (extension == 'png' || extension == 'jpg' || extension == 'jpeg') {
        final validationError = await _validateRasterLogo(bytes);
        if (validationError != null) {
          setState(() => _logoError = validationError);
          return;
        }
      }

      setState(() => _isLogoUploading = true);
      final detail = await widget.businessGateway.uploadCompanyLogo(
        accessToken: widget.accessToken,
        companyId: widget.companyId,
        bytes: bytes,
        filename: filename,
      );
      if (!mounted) return;
      setState(() {
        _logoUrl = detail['logo_url'] as String?;
        _logoError = null;
        _isLogoUploading = false;
        _didChange = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Логотип обновлен')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLogoUploading = false;
        _logoError = e.toString();
      });
    }
  }

  Future<String?> _validateRasterLogo(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      try {
        final frame = await codec.getNextFrame();
        final image = frame.image;
        try {
          final width = image.width;
          final height = image.height;
          if (width != height) {
            return 'Логотип должен быть квадратным.';
          }
          if (width < 100 || height < 100) {
            return 'Минимальный размер логотипа 100x100 px.';
          }
          if (width > 600 || height > 600) {
            return 'Максимальный размер логотипа 600x600 px.';
          }
        } finally {
          image.dispose();
        }
      } finally {
        codec.dispose();
      }
      return null;
    } catch (_) {
      return 'Не удалось прочитать размеры изображения.';
    }
  }

  String _logoExtension(String filename) {
    final dot = filename.lastIndexOf('.');
    if (dot < 0 || dot == filename.length - 1) {
      return '';
    }
    return filename.substring(dot + 1).toLowerCase();
  }

  void _closeEditor() {
    Navigator.of(context).pop(_didChange);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _closeEditor();
      },
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: _closeEditor,
          ),
          title: const Text(
            'Реквизиты компании',
            style: TextStyle(
              color: _textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          actions: [
            if (!_isLoading)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: TextButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _primaryColor,
                          ),
                        )
                      : const Text(
                          'Сохранить',
                          style: TextStyle(
                            color: _primaryColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: _primaryColor),
              )
            : _error != null
                ? _ErrorView(
                    message: _error!,
                    onRetry: () {
                      setState(() {
                        _error = null;
                        _isLoading = true;
                      });
                      _loadCompany();
                    },
                  )
                : Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _EditorCard(
                          title: 'Логотип компании',
                          children: [
                            Row(
                              children: [
                                _LogoPreview(
                                  name: _nameCtrl.text.trim().isEmpty
                                      ? 'Компания'
                                      : _nameCtrl.text.trim(),
                                  logoUrl: _logoUrl,
                                  accessToken: widget.accessToken,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      FilledButton.icon(
                                        onPressed: _isLogoUploading
                                            ? null
                                            : _pickAndUploadLogo,
                                        icon: _isLogoUploading
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Icon(Icons.upload_rounded),
                                        label: Text(
                                          _isLogoUploading
                                              ? 'Загрузка...'
                                              : 'Загрузить логотип',
                                        ),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: _primaryColor,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'ICO, PNG, JPG, SVG · до 2 МБ · квадрат 100–600 px',
                                        style: TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 13,
                                          height: 1.4,
                                        ),
                                      ),
                                      if (_logoError != null) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          _logoError!,
                                          style: const TextStyle(
                                            color: Color(0xFFDC2626),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _EditorCard(
                          title: 'Основные данные',
                          children: [
                            _Field(
                              label: 'Название компании',
                              controller: _nameCtrl,
                              required: true,
                            ),
                            _Field(
                              label: 'Организационная форма',
                              hint: 'ТОО, АО, ИП...',
                              controller: _legalFormCtrl,
                            ),
                            _CountryDropdown(
                              value: _country,
                              onChanged: (v) => setState(() => _country = v!),
                            ),
                            _Field(
                              label: 'БИН / ИИН',
                              controller: _iinCtrl,
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _EditorCard(
                          title: 'Контакты',
                          children: [
                            _Field(
                              label: 'Email',
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            _Field(
                              label: 'Телефон',
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _EditorCard(
                          title: 'Адрес',
                          children: [
                            _Field(
                              label: 'Адрес',
                              controller: _addressCtrl,
                            ),
                            _Field(
                              label: 'Город',
                              controller: _cityCtrl,
                            ),
                            _Field(
                              label: 'Область / регион',
                              controller: _regionCtrl,
                            ),
                            _Field(
                              label: 'Почтовый индекс',
                              controller: _postalCtrl,
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _EditorCard(
                          title: 'Банковские реквизиты',
                          children: [
                            _Field(
                              label: 'Название банка',
                              controller: _bankNameCtrl,
                            ),
                            _Field(
                              label: 'ИИК (номер счёта)',
                              controller: _bankAccountCtrl,
                              keyboardType: TextInputType.number,
                            ),
                            _Field(
                              label: 'БИК банка',
                              controller: _bankBikCtrl,
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _LogoPreview extends StatelessWidget {
  const _LogoPreview({
    required this.name,
    required this.accessToken,
    this.logoUrl,
  });

  final String name;
  final String accessToken;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = _resolveLogoUrl(logoUrl);
    final fallback = Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: const Color(0x1400A86B),
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: Text(
        _companyInitials(name),
        style: const TextStyle(
          color: Color(0xFF00A86B),
          fontWeight: FontWeight.w800,
          fontSize: 28,
        ),
      ),
    );
    if (resolvedUrl == null) {
      return fallback;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.network(
        resolvedUrl,
        width: 84,
        height: 84,
        fit: BoxFit.cover,
        headers: {'Authorization': 'Bearer $accessToken'},
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

String? _resolveLogoUrl(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  return '${ApiConfig.baseUrl}$trimmed';
}

String _companyInitials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return 'KZ';
  }
  final initials =
      parts.take(2).map((part) => part.substring(0, 1)).join().toUpperCase();
  return initials.isEmpty ? 'KZ' : initials;
}

class _EditorCard extends StatelessWidget {
  const _EditorCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.required = false,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool required;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF00A86B), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEF4444)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
          ),
          filled: true,
          fillColor: const Color(0xFFF7FAF8),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        validator: required
            ? (v) =>
                (v == null || v.trim().isEmpty) ? 'Обязательное поле' : null
            : null,
      ),
    );
  }
}

class _CountryDropdown extends StatelessWidget {
  const _CountryDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String?> onChanged;

  static const _countries = [
    ('KZ', 'Казахстан'),
    ('RU', 'Россия'),
    ('KG', 'Кыргызстан'),
    ('UZ', 'Узбекистан'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: 'Страна',
          labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF00A86B), width: 1.5),
          ),
          filled: true,
          fillColor: const Color(0xFFF7FAF8),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        items: _countries
            .map(
              (c) => DropdownMenuItem(value: c.$1, child: Text(c.$2)),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A86B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

