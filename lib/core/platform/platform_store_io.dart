import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 原生平台（Android）的存储实现：直接写应用私有目录。
///
/// token 形如 `nwstore://covers/NW-0001.png`，实际文件在
/// `<应用支持目录>/nwstore/covers/NW-0001.png`。
class PlatformStore {
  PlatformStore._();

  static const String tokenPrefix = 'nwstore://';

  static Directory? _rootCache;

  static bool get isWeb => false;

  static Future<Directory> _root() async {
    final Directory? cached = _rootCache;
    if (cached != null) {
      return cached;
    }
    final Directory support = await getApplicationSupportDirectory();
    final Directory root = Directory(p.join(support.path, 'nwstore'));
    if (!root.existsSync()) {
      await root.create(recursive: true);
    }
    _rootCache = root;
    return root;
  }

  static Future<File> _file(String key) async {
    final Directory root = await _root();
    final String relative = key.replaceAll('\\', '/');
    return File(p.join(root.path, relative));
  }

  static String tokenFor(String key) => '$tokenPrefix$key';

  static String? keyOf(String token) {
    if (!token.startsWith(tokenPrefix)) {
      return null;
    }
    return token.substring(tokenPrefix.length);
  }

  // ---------------- 文本 ----------------

  static Future<String?> readText(String key) async {
    try {
      final File file = await _file(key);
      if (!await file.exists()) {
        return null;
      }
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  static Future<void> writeText(String key, String data) async {
    final File file = await _file(key);
    await file.parent.create(recursive: true);
    await file.writeAsString(data, flush: true);
  }

  static Future<void> deleteKey(String key) async {
    try {
      final File file = await _file(key);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // 删除失败不阻断主流程。
    }
  }

  static Future<void> moveKey(String fromKey, String toKey) async {
    try {
      final File source = await _file(fromKey);
      if (!await source.exists()) {
        return;
      }
      final File target = await _file(toKey);
      await target.parent.create(recursive: true);
      await source.copy(target.path);
      await source.delete();
    } catch (_) {
      // 迁移失败时保留原文件。
    }
  }

  // ---------------- 字节（封面 / 头像 / 背景图） ----------------

  static Future<String?> writeBytes(String key, Uint8List bytes) async {
    try {
      if (bytes.isEmpty) {
        return null;
      }
      final File file = await _file(key);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      return tokenFor(key);
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> readBytes(String token) async {
    try {
      final String? key = keyOf(token);
      final File file = key != null ? await _file(key) : File(token);
      if (!await file.exists()) {
        return null;
      }
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  static Future<void> deleteToken(String? token) async {
    if (token == null || token.isEmpty) {
      return;
    }
    final String? key = keyOf(token);
    if (key != null) {
      await deleteKey(key);
      return;
    }
    try {
      final File file = File(token);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // 忽略。
    }
  }

  /// 供调试：把任意本地文件读成字节。
  static Future<Uint8List?> readLocalFile(String path) async {
    try {
      final File file = File(path);
      if (!await file.exists()) {
        return null;
      }
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  static List<int> encodeUtf8(String data) => utf8.encode(data);
}
