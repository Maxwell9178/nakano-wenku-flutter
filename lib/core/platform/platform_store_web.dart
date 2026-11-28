import 'dart:convert';
import 'dart:typed_data';

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/idb_browser.dart';

/// 网页版存储实现：浏览器没有文件系统，全部落在 IndexedDB。
///
/// 两个 object store：
/// * `text`  —— 章节 JSON 等文本
/// * `bytes` —— 封面、头像、背景图等二进制
///
/// token 形如 `nwstore://covers/NW-0001.png`，与原生平台保持一致，
/// 上层代码不需要区分运行平台。
class PlatformStore {
  PlatformStore._();

  static const String tokenPrefix = 'nwstore://';
  static const String _dbName = 'nw_store';
  static const String _textStore = 'text';
  static const String _bytesStore = 'bytes';

  static Database? _dbCache;

  static bool get isWeb => true;

  static Future<Database> _open(int version) {
    return idbFactoryBrowser.open(
      _dbName,
      version: version,
      onUpgradeNeeded: (VersionChangeEvent event) {
        final Database database = event.database;
        if (!database.objectStoreNames.contains(_textStore)) {
          database.createObjectStore(_textStore);
        }
        if (!database.objectStoreNames.contains(_bytesStore)) {
          database.createObjectStore(_bytesStore);
        }
      },
    );
  }

  static Future<Database> _db() async {
    final Database? cached = _dbCache;
    if (cached != null) {
      return cached;
    }
    Database db = await _open(1);
    // 自愈：如果浏览器里已经存在一个没有 object store 的同名库
    //（例如旧版本或其它脚本创建过），升级一个版本号把表补上，
    // 否则后续所有读写都会静默失败。
    if (!db.objectStoreNames.contains(_textStore) ||
        !db.objectStoreNames.contains(_bytesStore)) {
      final int nextVersion = db.version + 1;
      db.close();
      db = await _open(nextVersion);
    }
    _dbCache = db;
    return db;
  }

  /// 预热数据库：启动时调用一次，确保 object store 一定存在。
  static Future<void> ensureReady() async {
    await _db();
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
      final Database db = await _db();
      final Object? value = await db
          .transaction(_textStore, idbModeReadOnly)
          .objectStore(_textStore)
          .getObject(key);
      if (value is String) {
        return value;
      }
      if (value is List<int>) {
        return utf8.decode(value);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> writeText(String key, String data) async {
    final Database db = await _db();
    final Transaction txn = db.transaction(_textStore, idbModeReadWrite);
    await txn.objectStore(_textStore).put(data, key);
    await txn.completed;
  }

  static Future<void> deleteKey(String key) async {
    try {
      final Database db = await _db();
      final Transaction txn = db.transaction(_textStore, idbModeReadWrite);
      await txn.objectStore(_textStore).delete(key);
      await txn.completed;
    } catch (_) {
      // 忽略。
    }
  }

  static Future<void> moveKey(String fromKey, String toKey) async {
    final String? data = await readText(fromKey);
    if (data == null) {
      return;
    }
    await writeText(toKey, data);
    await deleteKey(fromKey);
  }

  // ---------------- 字节 ----------------

  static Future<String?> writeBytes(String key, Uint8List bytes) async {
    try {
      if (bytes.isEmpty) {
        return null;
      }
      final Database db = await _db();
      final Transaction txn = db.transaction(_bytesStore, idbModeReadWrite);
      await txn.objectStore(_bytesStore).put(bytes, key);
      await txn.completed;
      return tokenFor(key);
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> readBytes(String token) async {
    try {
      final String? key = keyOf(token);
      if (key == null) {
        // 网页上没有本地文件路径，非 token 一律视为不存在。
        return null;
      }
      final Database db = await _db();
      final Object? value = await db
          .transaction(_bytesStore, idbModeReadOnly)
          .objectStore(_bytesStore)
          .getObject(key);
      if (value is Uint8List) {
        return value;
      }
      if (value is List) {
        return Uint8List.fromList(value.whereType<int>().toList());
      }
      if (value is List<int>) {
        return Uint8List.fromList(value);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> deleteToken(String? token) async {
    if (token == null || token.isEmpty) {
      return;
    }
    final String? key = keyOf(token);
    if (key == null) {
      return;
    }
    try {
      final Database db = await _db();
      final Transaction txn = db.transaction(_bytesStore, idbModeReadWrite);
      await txn.objectStore(_bytesStore).delete(key);
      await txn.completed;
    } catch (_) {
      // 忽略。
    }
  }

  static Future<Uint8List?> readLocalFile(String path) async => null;

  static List<int> encodeUtf8(String data) => utf8.encode(data);
}
