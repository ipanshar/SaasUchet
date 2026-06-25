// Платформозависимый шаринг файла из байтов. На мобильных/десктоп используется
// временный файл (path_provider + dart:io), на web — данные в памяти.
// dart:io изолирован в share_file_io.dart, чтобы не ломать сборку под web.
export 'share_file_io.dart' if (dart.library.html) 'share_file_web.dart';
