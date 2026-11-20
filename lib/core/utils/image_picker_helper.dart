import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 让用户选一张本地图片，返回一个可长期读取的文件路径。
///
/// 部分机型（尤其是 Android 11+ 的分区存储）FilePicker 只给 bytes
/// 不给真实路径，这里统一落一份临时文件再返回，调用方无需区分。
Future<String?> pickImagePath({String prefix = 'picked_image'}) async {
  final FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'webp'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) {
    return null;
  }

  final PlatformFile file = result.files.first;
  final String sourcePath = file.path ?? '';
  if (sourcePath.isNotEmpty && File(sourcePath).existsSync()) {
    return sourcePath;
  }

  final Uint8List? bytes = file.bytes;
  if (bytes == null || bytes.isEmpty) {
    return null;
  }

  final Directory directory = await getTemporaryDirectory();
  final String extension = _extensionOf(file.name);
  final String path = p.join(
    directory.path,
    '${prefix}_${DateTime.now().millisecondsSinceEpoch}.$extension',
  );
  await File(path).writeAsBytes(bytes, flush: true);
  return path;
}

String _extensionOf(String name) {
  final String extension =
      p.extension(name).replaceFirst('.', '').toLowerCase();
  return extension.isEmpty ? 'png' : extension;
}
