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

  /// 默认站点：本项目在 GitHub 上的仓库地址，方便第一次使用的人去看更新与源码。
  static const ImportSite defaultSite = ImportSite(
    id: 'default-github',
    name: 'GitHub地址',
    url: 'https://github.com/Maxwell9178/nakano-wenku-flutter',
  );

  /// 官方网站（GitHub Pages 上的项目主页）。
  static const ImportSite officialSite = ImportSite(
    id: 'default-official',
    name: '官方网站',
    url: 'https://maxwell9178.github.io/',
  );

  static const List<ImportSite> bundledSites = <ImportSite>[
    defaultSite,
    officialSite,
  ];

  List<ImportSite> load() {
    final List<ImportSite> sites = _loadRaw();
    // 老版本存过别的默认站点：把内置入口补齐到最前面，但不覆盖用户自己的配置。
    final List<ImportSite> missing = bundledSites
        .where((ImportSite site) =>
            !sites.any((ImportSite item) => item.id == site.id))
        .toList();
    if (missing.isEmpty) {
      return sites;
    }
    return <ImportSite>[...missing, ...sites];
  }

  List<ImportSite> _loadRaw() {
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
