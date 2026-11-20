import 'dart:convert';

import '../constants/storage_keys.dart';
import '../models/import_site.dart';
import 'local_storage_service.dart';

/// 导入页「网站快捷访问小球」的本地存储。
///
/// 初始内置一个站点，用户可继续添加；网址只存在本地 JSON 里，
/// 界面上不展示（需求：网址配置信息隐藏存储，不会被随意改动）。
class ImportSiteRepository {
  const ImportSiteRepository(this._storage);

  final LocalStorageService _storage;

  /// 默认站点：成为小说家吧（轻小说资源站）。
  static const ImportSite defaultSite = ImportSite(
    id: 'default-syosetu',
    name: '小说家',
    url: 'https://syosetu.com/',
  );

  List<ImportSite> load() {
    final String? raw = _storage.getString(StorageKeys.importSites);
    if (raw == null || raw.isEmpty) {
      return <ImportSite>[defaultSite];
    }

    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <ImportSite>[defaultSite];
      }
      final List<ImportSite> sites = decoded
          .whereType<Map>()
          .map((Map<dynamic, dynamic> item) =>
              ImportSite.fromJson(Map<String, dynamic>.from(item)))
          .where((ImportSite site) => site.url.isNotEmpty)
          .toList();
      return sites.isEmpty ? <ImportSite>[defaultSite] : sites;
    } catch (_) {
      return <ImportSite>[defaultSite];
    }
  }

  Future<void> save(List<ImportSite> sites) async {
    final List<Map<String, dynamic>> payload =
        sites.map((ImportSite site) => site.toJson()).toList();
    await _storage.setString(StorageKeys.importSites, jsonEncode(payload));
  }
}
