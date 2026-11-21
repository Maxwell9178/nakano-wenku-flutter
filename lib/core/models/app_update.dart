import 'package:flutter/foundation.dart';

/// 远端版本信息。
///
/// 两个来源共用同一份模型：
/// - 主源：Gitee 仓库里的静态 `version.json`；
/// - 备用源：GitHub Releases 最新发布接口。
///
/// 两者字段不完全一样，所以分别提供解析入口，业务层只依赖本模型。
@immutable
class AppVersionInfo {
  const AppVersionInfo({
    required this.versionName,
    required this.versionCode,
    required this.changelog,
    required this.downloadUrl,
    this.preRelease = false,
  });

  /// 版本名称，例如 `1.0.1`。
  final String versionName;

  /// 版本代号（整数，用于比较新旧）。GitHub 源缺失时为 0。
  final int versionCode;

  /// 更新日志，允许为空。
  final String changelog;

  /// APK 下载地址。
  final String downloadUrl;

  /// 是否测试版（仅用于界面标注，不阻止更新）。
  final bool preRelease;

  bool get hasDownload => downloadUrl.trim().isNotEmpty;

  bool get hasChangelog => changelog.trim().isNotEmpty;

  /// 是否比本机版本更新。
  ///
  /// 优先比较 versionCode；若远端没有 versionCode（GitHub Releases），
  /// 退化为按版本号字符串逐段比较。
  bool isNewerThan({required String localName, required int localCode}) {
    if (versionCode > 0 && localCode > 0) {
      return versionCode > localCode;
    }
    return compareVersionNames(versionName, localName) > 0;
  }

  /// 解析 `version.json`。
  ///
  /// 约定字段：versionName / versionCode / changelog / downloadUrl / preRelease。
  static AppVersionInfo? fromManifest(Map<String, dynamic> json) {
    final String name = (json['versionName'] ?? '').toString().trim();
    final int code = _asInt(json['versionCode']);
    if (name.isEmpty && code <= 0) {
      return null;
    }
    return AppVersionInfo(
      versionName: name.isEmpty ? '未知版本' : name,
      versionCode: code,
      changelog: (json['changelog'] ?? '').toString().trim(),
      downloadUrl: (json['downloadUrl'] ?? '').toString().trim(),
      preRelease: json['preRelease'] == true,
    );
  }

  /// 解析 GitHub Releases 的 `releases/latest` 返回体。
  static AppVersionInfo? fromGitHubRelease(Map<String, dynamic> json) {
    final String tag =
        (json['tag_name'] ?? json['name'] ?? '').toString().trim();
    final String name = tag.replaceFirst(RegExp(r'^[vV]'), '').trim();
    if (name.isEmpty) {
      return null;
    }

    // 优先取 APK 资产，其次取第一个下载资产。
    String apkUrl = '';
    String firstUrl = '';
    final Object? assets = json['assets'];
    if (assets is List<dynamic>) {
      for (final Object? item in assets) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final String url =
            (item['browser_download_url'] ?? '').toString().trim();
        if (url.isEmpty) {
          continue;
        }
        if (firstUrl.isEmpty) {
          firstUrl = url;
        }
        if (url.toLowerCase().split('?').first.endsWith('.apk')) {
          apkUrl = url;
          break;
        }
      }
    }

    return AppVersionInfo(
      versionName: name,
      versionCode: _asInt(json['version_code']),
      changelog: (json['body'] ?? '').toString().trim(),
      downloadUrl: apkUrl.isNotEmpty ? apkUrl : firstUrl,
      preRelease: json['prerelease'] == true,
    );
  }

  /// 逐段比较两个版本号字符串，返回正数表示 [a] 更新。
  ///
  /// 只比较数字段（`1.2.3` vs `1.10.0`），非数字后缀忽略。
  static int compareVersionNames(String a, String b) {
    final List<int> left = _numericParts(a);
    final List<int> right = _numericParts(b);
    final int length = left.length > right.length ? left.length : right.length;
    for (int index = 0; index < length; index++) {
      final int l = index < left.length ? left[index] : 0;
      final int r = index < right.length ? right[index] : 0;
      if (l != r) {
        return l - r;
      }
    }
    return 0;
  }

  static List<int> _numericParts(String value) {
    return RegExp(r'\d+')
        .allMatches(value)
        .map((RegExpMatch match) => int.tryParse(match.group(0) ?? '0') ?? 0)
        .toList(growable: false);
  }

  static int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
