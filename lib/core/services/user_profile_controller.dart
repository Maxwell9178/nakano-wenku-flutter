import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';
import '../constants/storage_keys.dart';
import 'backup_import_service.dart';
import 'local_storage_service.dart';

/// 账号相关的可展示异常。
class ProfileException implements Exception {
  const ProfileException(this.message);

  final String message;

  @override
  String toString() => 'ProfileException: $message';
}

/// 本地账号资料控制器。
///
/// 项目完全离线：用户名、头像只保存在本机
/// （SharedPreferences + 应用私有目录），不上传任何服务器。
class UserProfileController extends ChangeNotifier {
  UserProfileController(this._storage);

  final LocalStorageService _storage;

  String _userName = '';
  String? _avatarPath;
  DateTime? _createdAt;
  bool _onboardingCompleted = false;

  // ---------------- 只读状态 ----------------

  String get userName => _userName;

  /// 头像文件的绝对路径；null 表示使用默认空白头像。
  String? get avatarPath => _avatarPath;

  /// 账号创建时间，用于统计「入驻天数」。
  DateTime? get createdAt => _createdAt;

  /// 是否已完成首次初始化（true 之后不再弹出初始化页）。
  bool get onboardingCompleted => _onboardingCompleted;

  /// 展示用昵称，未设置时使用兜底文案。
  String get displayName =>
      _userName.trim().isEmpty ? AppConstants.defaultUserName : _userName.trim();

  // ---------------- 初始化 ----------------

  /// 启动阶段从本地存储恢复账号资料。
  void load() {
    _userName = _storage.getString(StorageKeys.userName) ?? '';
    _avatarPath = _storage.getString(StorageKeys.userAvatarPath);
    final int createdAtMs =
        _storage.getInt(StorageKeys.accountCreatedAt, fallback: 0);
    _createdAt = createdAtMs <= 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(createdAtMs);
    _onboardingCompleted =
        _storage.getBool(StorageKeys.onboardingCompleted, fallback: false);
  }

  // ---------------- 路径（新建本地账号） ----------------

  /// 创建本地账号并完成首次初始化。
  ///
  /// [avatarSourcePath] 为用户选择的图片路径，可为空（使用默认头像）。
  /// 头像文件会被拷贝进应用私有目录，避免系统清理缓存后头像丢失。
  Future<void> createLocalAccount({
    required String userName,
    String? avatarSourcePath,
  }) async {
    final String name = userName.trim();
    if (name.isEmpty) {
      throw const ProfileException('昵称不能为空');
    }

    final String? previousAvatar = _avatarPath;

    _userName = name;
    if (avatarSourcePath != null && avatarSourcePath.isNotEmpty) {
      final String? saved = await _persistAvatarFile(avatarSourcePath);
      if (saved != null) {
        _avatarPath = saved;
      }
    }
    _createdAt ??= DateTime.now();
    _onboardingCompleted = true;

    await _persistProfile();
    if (previousAvatar != null && previousAvatar != _avatarPath) {
      await _deleteAvatarQuietly(previousAvatar);
    }
    notifyListeners();
  }

  // ---------------- 路径（导入备份） ----------------

  /// 使用备份包内容恢复账号资料。
  ///
  /// 备份缺失 avatar.png 时使用默认空白头像，绝不抛错。
  Future<void> restoreFromBackup(BackupImportResult backup) async {
    final String? previousAvatar = _avatarPath;

    _userName = backup.userName.trim().isEmpty
        ? AppConstants.defaultUserName
        : backup.userName.trim();

    final Uint8List? avatarBytes = backup.avatarBytes;
    if (backup.hasAvatar && avatarBytes != null) {
      _avatarPath = await _persistAvatarBytes(avatarBytes);
    } else {
      _avatarPath = null;
    }

    _createdAt ??= DateTime.now();
    _onboardingCompleted = true;

    await _persistProfile();
    if (previousAvatar != null && previousAvatar != _avatarPath) {
      await _deleteAvatarQuietly(previousAvatar);
    }
    notifyListeners();
  }

  // ---------------- 资料编辑（我的页面） ----------------

  /// 用 `.wkarchive` 里的账号资料覆盖本地账号。
  ///
  /// 与 [restoreFromBackup] 的区别：这条路径接收已经解析好的字节，
  /// 供数据包导入流程（覆盖 / 合并）复用；[avatarBytes] 为空时
  /// 使用默认空白头像，不抛异常。
  Future<void> applyImportedAccount({
    required String userName,
    Uint8List? avatarBytes,
    DateTime? createdAt,
  }) async {
    final String? previousAvatar = _avatarPath;
    final String trimmed = userName.trim();

    _userName = trimmed.isEmpty ? AppConstants.defaultUserName : trimmed;
    if (avatarBytes != null && avatarBytes.isNotEmpty) {
      final String? saved = await _persistAvatarBytes(avatarBytes);
      _avatarPath = saved;
    } else {
      _avatarPath = null;
    }
    _createdAt = createdAt ?? _createdAt ?? DateTime.now();
    _onboardingCompleted = true;

    await _persistProfile();
    if (previousAvatar != null && previousAvatar != _avatarPath) {
      await _deleteAvatarQuietly(previousAvatar);
    }
    notifyListeners();
  }

  /// 修改昵称。
  Future<void> updateUserName(String name) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ProfileException('昵称不能为空');
    }
    if (trimmed == _userName) {
      return;
    }
    _userName = trimmed;
    await _storage.setString(StorageKeys.userName, _userName);
    notifyListeners();
  }

  /// 替换头像；传入 null 表示恢复默认空白头像。
  Future<void> updateAvatar(String? sourcePath) async {
    final String? previous = _avatarPath;
    if (sourcePath == null || sourcePath.isEmpty) {
      _avatarPath = null;
    } else {
      final String? saved = await _persistAvatarFile(sourcePath);
      if (saved == null) {
        throw const ProfileException('头像读取失败，请换一张图片试试');
      }
      _avatarPath = saved;
    }

    if (_avatarPath == null) {
      await _storage.remove(StorageKeys.userAvatarPath);
    } else {
      await _storage.setString(StorageKeys.userAvatarPath, _avatarPath!);
    }
    if (previous != null && previous != _avatarPath) {
      await _deleteAvatarQuietly(previous);
    }
    notifyListeners();
  }

  /// 清空账号资料（删除账号时使用）：同时删掉私有目录里的头像文件。
  Future<void> clearAll() async {
    await _deleteAvatarQuietly(_avatarPath);
    _userName = '';
    _avatarPath = null;
    _createdAt = null;
    _onboardingCompleted = false;

    await _storage.remove(StorageKeys.userName);
    await _storage.remove(StorageKeys.userAvatarPath);
    await _storage.remove(StorageKeys.accountCreatedAt);
    await _storage.remove(StorageKeys.onboardingCompleted);
    notifyListeners();
  }

  // ---------------- 内部实现 ----------------

  Future<void> _persistProfile() async {
    await _storage.setString(StorageKeys.userName, _userName);
    await _storage.setBool(StorageKeys.onboardingCompleted, true);

    final DateTime? createdAt = _createdAt;
    if (createdAt != null) {
      await _storage.setInt(
        StorageKeys.accountCreatedAt,
        createdAt.millisecondsSinceEpoch,
      );
    }

    final String? avatarPath = _avatarPath;
    if (avatarPath == null) {
      await _storage.remove(StorageKeys.userAvatarPath);
    } else {
      await _storage.setString(StorageKeys.userAvatarPath, avatarPath);
    }
  }

  /// 账号私有目录（<应用支持目录>/profile）。
  Future<Directory> _profileDirectory() async {
    final Directory base = await getApplicationSupportDirectory();
    final Directory dir = Directory(p.join(base.path, 'profile'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 把用户选择的图片拷贝到私有目录。
  ///
  /// 拷贝失败不阻断账号创建：直接返回 null，界面回退为默认头像。
  Future<String?> _persistAvatarFile(String sourcePath) async {
    try {
      final File source = File(sourcePath);
      if (!await source.exists()) {
        return null;
      }
      final Directory dir = await _profileDirectory();
      final String ext = p.extension(sourcePath).toLowerCase();
      final String safeExt = ext.isEmpty ? '.png' : ext;
      // 文件名带时间戳，避免 Flutter 图片缓存命中旧头像。
      final String fileName =
          'avatar_${DateTime.now().millisecondsSinceEpoch}$safeExt';
      final File target = File(p.join(dir.path, fileName));
      await source.copy(target.path);
      return target.path;
    } catch (_) {
      return null;
    }
  }

  /// 把备份包内的 avatar.png 字节写入私有目录。
  Future<String?> _persistAvatarBytes(Uint8List bytes) async {
    try {
      final Directory dir = await _profileDirectory();
      final String fileName =
          'avatar_${DateTime.now().millisecondsSinceEpoch}.png';
      final File target = File(p.join(dir.path, fileName));
      await target.writeAsBytes(bytes, flush: true);
      return target.path;
    } catch (_) {
      return null;
    }
  }

  /// 静默删除旧头像，失败不影响主流程。
  Future<void> _deleteAvatarQuietly(String? path) async {
    if (path == null || path.isEmpty) {
      return;
    }
    try {
      final File file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // 忽略：残留文件不影响功能。
    }
  }
}
