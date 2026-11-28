import 'package:flutter/services.dart';

/// 应用内更新的「安装」环节（原生 MethodChannel 封装）。
///
/// 只做一件事：把已经下载到应用缓存目录的 APK 交给系统安装器。
/// 走 FileProvider 生成 content:// Uri，Android 7.0+ 才不会抛
/// FileUriExposedException；Android 8.0+ 还需要「安装未知应用」权限，
/// 未授权时返回 [ApkInstallResult.needPermission]，由界面引导用户去开。
class ApkInstaller {
  const ApkInstaller();

  static const MethodChannel _channel = MethodChannel('nakano_wenku/install');

  /// 是否已获得「安装未知应用」权限。
  Future<bool> canInstall() async {
    try {
      final bool? value = await _channel.invokeMethod<bool>('canInstall');
      return value ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      // 桌面/测试环境下没有原生实现，交给调用方回落到外部打开。
      return false;
    }
  }

  /// 打开系统的「安装未知应用」授权页。
  Future<bool> openInstallSettings() async {
    try {
      final bool? value = await _channel.invokeMethod<bool>(
        'openInstallSettings',
      );
      return value ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 拉起系统安装器。
  Future<ApkInstallResult> install(String path) async {
    try {
      final bool? value = await _channel.invokeMethod<bool>(
        'install',
        <String, Object?>{'path': path},
      );
      return value == true
          ? ApkInstallResult.launched
          : ApkInstallResult.failed;
    } on PlatformException catch (error) {
      if (error.code == 'missing_file') {
        return ApkInstallResult.missingFile;
      }
      return ApkInstallResult.failed;
    } on MissingPluginException {
      return ApkInstallResult.unsupported;
    }
  }
}

/// 安装器返回结果。
enum ApkInstallResult {
  /// 系统安装界面已弹出。
  launched,

  /// 缺少「安装未知应用」权限。
  needPermission,

  /// 安装包文件不存在（被系统清理了缓存）。
  missingFile,

  /// 安装器报错。
  failed,

  /// 当前平台没有原生实现。
  unsupported,
}
