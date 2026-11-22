import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 让用户从**系统相册**里选一张图片，返回一个可长期读取的文件路径。
///
/// 之前用 file_picker 会打开文件目录（Download/Documents），
/// 需求要求图片类内容统一走系统相册选择器，因此这里改用 image_picker。
/// 相册返回的通常是缓存目录里的临时文件，这里再复制一份到临时目录，
/// 保证调用方拿到路径后不会因为系统清理缓存而失效。
Future<String?> pickImagePath({String prefix = 'picked_image'}) async {
  final XFile? picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 2400,
    maxHeight: 2400,
    imageQuality: 92,
  );
  if (picked == null) {
    return null;
  }

  final String extension =
      _extensionOf(picked.name.isEmpty ? picked.path : picked.name);
  final Directory directory = await getTemporaryDirectory();
  final String path = p.join(
    directory.path,
    '${prefix}_${DateTime.now().millisecondsSinceEpoch}.$extension',
  );
  await File(picked.path).copy(path);
  if (await File(path).exists()) {
    return path;
  }
  return picked.path;
}

String _extensionOf(String name) {
  final String extension =
      p.extension(name).replaceFirst('.', '').toLowerCase();
  if (extension.isEmpty) {
    return 'jpg';
  }
  if (extension == 'jpeg') {
    return 'jpg';
  }
  return extension;
}
