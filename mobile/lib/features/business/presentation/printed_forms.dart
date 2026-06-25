part of 'business_shell.dart';

/// Виды печатных форм складского документа: счёт на оплату для продажи,
/// заказ на приобретение для закупки.
enum _PrintedFormKind { invoice, purchaseOrder }

_PrintedFormKind _printedFormKindFor(String documentType) =>
    documentType == 'sale_issue'
        ? _PrintedFormKind.invoice
        : _PrintedFormKind.purchaseOrder;

String _printedFormDate(String isoDate) {
  final date = DateTime.tryParse(isoDate);
  if (date == null) {
    return isoDate;
  }
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

/// Денежная сумма для печатной формы — без знака ₸: шрифт PT Sans,
/// встроенный для кириллицы, не содержит глиф тенге (U+20B8), он рисуется
/// как «битый» прямоугольник. Использует тот же формат разрядов, что и
/// [formatMoney], но с текстовым «тг» вместо символа.
String _formatMoneyForPdf(int value) {
  final sign = value < 0 ? '-' : '';
  return '$sign${_formatMoneyDigits(value.abs())} тг';
}

String _printedLineLabel(_InventoryDocumentLine line) {
  final parts = <String>[line.productName];
  if (line.sku.isNotEmpty) {
    parts.add('SKU: ${line.sku}');
  }
  if (line.barcode.isNotEmpty) {
    parts.add('Штрихкод: ${line.barcode}');
  }
  return parts.join('\n');
}

String? _counterpartyIdLabel(_Client? client) {
  if (client == null) {
    return null;
  }
  final bin = client.bin?.trim() ?? '';
  if (bin.isNotEmpty) {
    return 'БИН: $bin';
  }
  final iin = client.iin?.trim() ?? '';
  if (iin.isNotEmpty) {
    return 'ИИН: $iin';
  }
  return null;
}

/// Строит печатную форму складского документа продажи/закупки: «Счёт на
/// оплату» для `sale_issue` или «Заказ на приобретение» для
/// `purchase_receipt`. Шапка одинакова для обеих форм (логотип компании по
/// центру, реквизиты по бокам), подвал — по виду документа.
Future<Uint8List> _buildInventoryDocumentPrintedForm({
  required _InventoryDocumentDetail detail,
  required _Company company,
  required _Client? client,
  required String counterpartyLabel,
  required String accessToken,
}) async {
  final kind = _printedFormKindFor(detail.summary.documentType);

  final regularFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/PTSans-Regular.ttf'),
  );
  final boldFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/PTSans-Bold.ttf'),
  );
  final regularStyle = pw.TextStyle(font: regularFont, fontSize: 10);
  final boldStyle = pw.TextStyle(font: boldFont, fontSize: 10);

  pw.MemoryImage? logo;
  final logoUrl = company.logoUrl;
  if (logoUrl != null && logoUrl.isNotEmpty) {
    try {
      final response = await http.get(
        ApiConfig.companyLogoUri(company.id),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (response.statusCode == 200) {
        logo = pw.MemoryImage(response.bodyBytes);
      }
    } catch (_) {
      // Логотип не критичен для печатной формы — продолжаем без него.
    }
  }

  final summary = detail.summary;
  final payments = detail.linkedPayments;
  final primaryPayment = payments.isNotEmpty ? payments.first : null;
  final paymentNumbers =
      payments.isEmpty ? '—' : payments.map((p) => p.documentNo).join(', ');
  final paymentStatusLabel = primaryPayment == null
      ? '—'
      : _documentStatusLabel(primaryPayment.status);

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (context) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if ((company.addressLine ?? '').isNotEmpty)
                    pw.Text(company.addressLine!, style: regularStyle),
                  if ((company.city ?? '').isNotEmpty ||
                      (company.region ?? '').isNotEmpty)
                    pw.Text(
                      [company.city, company.region]
                          .where((v) => (v ?? '').isNotEmpty)
                          .join(', '),
                      style: regularStyle,
                    ),
                  if ((company.phone ?? '').isNotEmpty)
                    pw.Text('Тел: ${company.phone}', style: regularStyle),
                  if ((company.email ?? '').isNotEmpty)
                    pw.Text(company.email!, style: regularStyle),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logo != null)
                    pw.Image(logo, width: 64, height: 64, fit: pw.BoxFit.contain)
                  else
                    pw.Container(
                      width: 64,
                      height: 64,
                      alignment: pw.Alignment.center,
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#E2E8F0'),
                        borderRadius: pw.BorderRadius.circular(12),
                      ),
                      child: pw.Text(
                        company.name.isEmpty
                            ? '—'
                            : company.name.substring(0, 1).toUpperCase(),
                        style: pw.TextStyle(font: boldFont, fontSize: 24),
                      ),
                    ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    company.name,
                    textAlign: pw.TextAlign.center,
                    style: boldStyle,
                  ),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  if (company.iin.isNotEmpty)
                    pw.Text(
                      'БИН/ИИН: ${company.iin}',
                      style: regularStyle,
                      textAlign: pw.TextAlign.right,
                    ),
                  if ((company.bankName ?? '').isNotEmpty)
                    pw.Text(
                      company.bankName!,
                      style: regularStyle,
                      textAlign: pw.TextAlign.right,
                    ),
                  if ((company.bankAccount ?? '').isNotEmpty)
                    pw.Text(
                      'ИИК: ${company.bankAccount}',
                      style: regularStyle,
                      textAlign: pw.TextAlign.right,
                    ),
                  if ((company.bankBik ?? '').isNotEmpty)
                    pw.Text(
                      'БИК: ${company.bankBik}',
                      style: regularStyle,
                      textAlign: pw.TextAlign.right,
                    ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Divider(thickness: 1, color: PdfColor.fromHex('#00A86B')),
        pw.SizedBox(height: 14),
        pw.Text(
          '${kind == _PrintedFormKind.invoice ? 'СЧЁТ НА ОПЛАТУ' : 'ЗАКАЗ НА ПРИОБРЕТЕНИЕ'} '
          '№ ${summary.documentNo} от ${_printedFormDate(summary.documentDate)}',
          style: pw.TextStyle(font: boldFont, fontSize: 15),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          '$counterpartyLabel: ${summary.clientName.isEmpty ? '—' : summary.clientName}',
          style: boldStyle,
        ),
        if (_counterpartyIdLabel(client) != null)
          pw.Text(_counterpartyIdLabel(client)!, style: regularStyle),
        if ((client?.phone ?? '').isNotEmpty)
          pw.Text('Тел: ${client!.phone}', style: regularStyle),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          context: context,
          cellStyle: regularStyle,
          headerStyle: boldStyle,
          headerDecoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFF7FAF8),
          ),
          cellAlignments: const {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
          },
          headers: const ['№', 'Наименование', 'Кол-во', 'Цена', 'Сумма'],
          data: List<List<String>>.generate(detail.lines.length, (index) {
            final line = detail.lines[index];
            return [
              '${index + 1}',
              _printedLineLabel(line),
              '${line.quantity}',
              _formatMoneyForPdf(line.unitPrice),
              _formatMoneyForPdf(line.lineTotal),
            ];
          }),
        ),
        pw.SizedBox(height: 10),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Итого: ${_formatMoneyForPdf(summary.totalAmount)}',
            style: pw.TextStyle(font: boldFont, fontSize: 13),
          ),
        ),
        pw.SizedBox(height: 28),
        pw.Divider(thickness: 0.6),
        pw.SizedBox(height: 10),
        if (kind == _PrintedFormKind.purchaseOrder) ...[
          pw.Text('Реквизиты для оплаты поставщику', style: boldStyle),
          pw.SizedBox(height: 4),
          if ((client?.bankName ?? '').isEmpty &&
              (client?.bankAccount ?? '').isEmpty &&
              (client?.bankBik ?? '').isEmpty)
            pw.Text('—', style: regularStyle)
          else ...[
            if ((client?.bankName ?? '').isNotEmpty)
              pw.Text(client!.bankName, style: regularStyle),
            if ((client?.bankAccount ?? '').isNotEmpty)
              pw.Text('ИИК: ${client!.bankAccount}', style: regularStyle),
            if ((client?.bankBik ?? '').isNotEmpty)
              pw.Text('БИК: ${client!.bankBik}', style: regularStyle),
          ],
          pw.SizedBox(height: 10),
          pw.Text('Статус оплаты: $paymentStatusLabel', style: regularStyle),
          pw.Text(
            'Оплачено: ${_formatMoneyForPdf(primaryPayment?.paidAmount ?? 0)}',
            style: regularStyle,
          ),
          pw.Text('Платёжные документы: $paymentNumbers', style: regularStyle),
        ] else ...[
          pw.Text('Статус оплаты: $paymentStatusLabel', style: regularStyle),
          pw.Text('Платёжные документы: $paymentNumbers', style: regularStyle),
        ],
      ],
    ),
  );

  return doc.save();
}

/// Экран предпросмотра печатной формы с готовыми кнопками «Печать» и
/// «Поделиться» (из пакета `printing`).
class _PrintedFormScreen extends StatelessWidget {
  const _PrintedFormScreen({
    required this.documentNo,
    required this.bytes,
  });

  final String documentNo;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7FAF8),
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text('Печатная форма $documentNo'),
      ),
      body: PdfPreview(
        build: (format) async => bytes,
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        pdfFileName: '$documentNo.pdf',
      ),
    );
  }
}
