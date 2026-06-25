import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Web-вариант: шарит данные из памяти (скачивание файла через браузер).
Future<void> shareBytesFile(
  List<int> bytes,
  String filename,
  String mimeType,
  String subject,
) async {
  await Share.shareXFiles(
    [
      XFile.fromData(
        Uint8List.fromList(bytes),
        name: filename,
        mimeType: mimeType,
      ),
    ],
    subject: subject,
  );
}
