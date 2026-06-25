import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Сохраняет байты во временный файл и открывает системный диалог «Поделиться».
Future<void> shareBytesFile(
  List<int> bytes,
  String filename,
  String mimeType,
  String subject,
) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: mimeType, name: filename)],
    subject: subject,
  );
}
