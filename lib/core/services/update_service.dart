import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';
import '../constants/storage_keys.dart';
import '../models/app_update.dart';
import 'local_storage_service.dart';

/// 一次更新检测的结果状态。
enum UpdateStatus {
  /// 已经是最新版本。
  upToDate,

  /// 发现可更新版本。
  available,

  /// 两个源都失败（离线、超时、返回格式错误等）。
  failed,
}

/// 更新检测结果。
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.status,
    this.info,
    this.sourceLabel,
    this.message,
  });

  final UpdateStatus status;

  /// 远端版本信息（[UpdateStatus.failed] 时为空）。
  final AppVersionInfo? info;

  /// 命中的源名称，便于界面标注「来自 Gitee / GitHub」。
  final String? sourceLabel;

  /// 失败原因（仅用于日志，界面统一显示友好文案）。
  final String? message;

  bool get hasUpdate => status == UpdateStatus.available && info != null;
}

/// 版本更新服务（全局唯一，唯一允许发起网络请求的业务模块）。
///
/// 设计约束：
/// - 不引入额外网络依赖，直接用 `dart:io` 的 [HttpClient] 请求两个静态源；
/// - 主源 Gitee `version.json`，失败后切 GitHub Releases，两者都失败静默；
/// - 冷启动自动检测有 7 天冷却，手动检测不受冷却限制；
/// - 下载交给系统（浏览器 / 系统下载管理器），完成后由系统安装器接管。
class UpdateService {
  UpdateService(
    this._storage, {
    Future<String> Function(Uri uri)? fetcher,
    Future<bool> Function(Uri uri)? launcher,
  })  : _fetcher = fetcher,
        _launcher = launcher;

  final LocalStorageService _storage;

  /// 可注入的请求实现（测试或离线场景使用）。
  final Future<String> Function(Uri uri)? _fetcher;

  /// 可注入的打开链接实现（测试使用）。
  final Future<bool> Function(Uri uri)? _launcher;

  /// 单次请求超时。
  static const Duration _requestTimeout = Duration(seconds: 8);

  /// 自动检测冷却：7 天。
  static const Duration _cooldown =
      Duration(days: AppConstants.updateCheckCooldownDays);

  Uri get _manifestUri => Uri.parse(AppConstants.updateManifestUrl);

  Uri get _apiUri => Uri.parse(AppConstants.updateApiUrl);

  /// 冷启动自动检测是否已过冷却期。
  bool shouldAutoCheck() {
    final int last = _storage.getInt(StorageKeys.lastAutoUpdateCheckAt);
    if (last <= 0) {
      return true;
    }
    final DateTime lastTime = DateTime.fromMillisecondsSinceEpoch(last);
    return DateTime.now().difference(lastTime) >= _cooldown;
  }

  /// 上一次成功检测的时间，界面可用来显示「上次检测」。
  DateTime? get lastCheckTime {
    final int last = _storage.getInt(StorageKeys.lastAutoUpdateCheckAt);
    if (last <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(last);
  }

  /// 该版本是否已经被「稍后提醒」忽略。
  ///
  /// 忽略按版本记录：同一个版本不再自动弹窗，直到用户手动检测
  /// 或发布更高版本。
  bool isDismissed(AppVersionInfo info) {
    final int skipped = _storage.getInt(StorageKeys.updateSkippedVersionCode);
    return skipped > 0 && skipped == _dismissKey(info);
  }

  /// 记录「稍后提醒」，避免下一次冷启动重复弹窗。
  Future<void> dismiss(AppVersionInfo info) {
    return _storage.setInt(StorageKeys.updateSkippedVersionCode, _dismissKey(info));
  }

  /// 检测更新：Gitee 优先，失败后切换 GitHub，两个都失败返回 [UpdateStatus.failed]。
  ///
  /// 只有检测成功才写入冷却时间，离线时下次冷启动仍会重试。
  Future<UpdateCheckResult> check() async {
    final List<_UpdateSource> sources = <_UpdateSource>[
      _UpdateSource(
        label: 'Gitee',
        uri: _manifestUri,
        parser: AppVersionInfo.fromManifest,
      ),
      _UpdateSource(
        label: 'GitHub',
        uri: _apiUri,
        parser: AppVersionInfo.fromGitHubRelease,
      ),
    ];

    String? lastError;
    for (final _UpdateSource source in sources) {
      try {
        final String raw = await _fetch(source.uri);
        final Object? decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('返回内容不是 JSON 对象');
        }
        final AppVersionInfo? info = source.parser(decoded);
        if (info == null) {
          throw const FormatException('版本字段缺失');
        }

        await _storage.setInt(
          StorageKeys.lastAutoUpdateCheckAt,
          DateTime.now().millisecondsSinceEpoch,
        );

        final bool newer = info.isNewerThan(
          localName: AppConstants.versionName,
          localCode: AppConstants.versionCode,
        );
        return UpdateCheckResult(
          status: newer ? UpdateStatus.available : UpdateStatus.upToDate,
          info: info,
          sourceLabel: source.label,
        );
      } on Object catch (error) {
        lastError = '$error';
      }
    }

    return UpdateCheckResult(
      status: UpdateStatus.failed,
      message: lastError ?? '网络不可用',
    );
  }

  /// 打开下载地址。
  ///
  /// 使用外部应用打开：Android 会交给浏览器 / 系统下载管理器，
  /// 下载完成后点击通知即可进入系统安装器，全程不申请安装权限。
  Future<bool> openDownload(AppVersionInfo info) async {
    if (!info.hasDownload) {
      return false;
    }
    final Uri uri = Uri.parse(info.downloadUrl);
    final Future<bool> Function(Uri uri)? launcher = _launcher;
    if (launcher != null) {
      try {
        return await launcher(uri);
      } on Object {
        return false;
      }
    }
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }

  // ---------------- 内部实现 ----------------

  int _dismissKey(AppVersionInfo info) {
    // GitHub 源没有 versionCode，用版本名哈希兜底，保证同一版本稳定。
    return info.versionCode > 0
        ? info.versionCode
        : info.versionName.hashCode.abs();
  }

  Future<String> _fetch(Uri uri) async {
    final Future<String> Function(Uri uri)? fetcher = _fetcher;
    if (fetcher != null) {
      return fetcher(uri).timeout(_requestTimeout);
    }

    final HttpClient client = HttpClient()..connectionTimeout = _requestTimeout;
    try {
      final HttpClientRequest request =
          await client.getUrl(uri).timeout(_requestTimeout);
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/json, text/plain, */*',
      );
      request.headers.set(
        HttpHeaders.userAgentHeader,
        '${AppConstants.appName}/${AppConstants.versionName}',
      );

      final HttpClientResponse response =
          await request.close().timeout(_requestTimeout);
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      return await response
          .transform(utf8.decoder)
          .join()
          .timeout(_requestTimeout);
    } finally {
      client.close(force: true);
    }
  }
}

/// 更新源描述：名称 + 地址 + 解析函数。
class _UpdateSource {
  const _UpdateSource({
    required this.label,
    required this.uri,
    required this.parser,
  });

  final String label;
  final Uri uri;
  final AppVersionInfo? Function(Map<String, dynamic> json) parser;
}
