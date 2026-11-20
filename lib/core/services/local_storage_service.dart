import 'package:shared_preferences/shared_preferences.dart';

/// 本地键值存储的薄封装。
///
/// 项目「纯本地优先」：所有设置、账号资料、阅读进度都以本机存储为准。
/// 这里只做一层语义化封装，方便以后平滑替换底层实现（例如换成
/// 数据库或加密存储）而不用改动业务层。
class LocalStorageService {
  LocalStorageService._(this._prefs);

  final SharedPreferences _prefs;

  /// 应用启动时调用一次，完成 SharedPreferences 的初始化。
  static Future<LocalStorageService> create() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return LocalStorageService._(prefs);
  }

  // ---------------- 读取 ----------------

  bool getBool(String key, {bool fallback = false}) =>
      _prefs.getBool(key) ?? fallback;

  int getInt(String key, {int fallback = 0}) =>
      _prefs.getInt(key) ?? fallback;

  double getDouble(String key, {double fallback = 0}) =>
      _prefs.getDouble(key) ?? fallback;

  String? getString(String key) => _prefs.getString(key);

  // ---------------- 写入 ----------------

  Future<bool> setBool(String key, bool value) => _prefs.setBool(key, value);

  Future<bool> setInt(String key, int value) => _prefs.setInt(key, value);

  Future<bool> setDouble(String key, double value) =>
      _prefs.setDouble(key, value);

  Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);

  // ---------------- 删除 ----------------

  Future<bool> remove(String key) => _prefs.remove(key);

  /// 清空全部本地数据（账号数据删除功能会用到）。
  Future<bool> clear() => _prefs.clear();
}
