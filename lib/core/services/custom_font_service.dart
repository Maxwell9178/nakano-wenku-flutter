import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../constants/storage_keys.dart';
import 'local_storage_service.dart';

/// 第三方字体包的导入与运行时注册。
///
/// Flutter 只允许在 `pubspec.yaml` 里静态声明字体，因此用户导入的字体
/// 必须在运行时通过 [FontLoader] 注册；注册成功后即可用 [family]
/// 作为 `fontFamily` 使用，不需要重启应用。
class CustomFontService {
  CustomFontService(this._storage);

  /// 运行时字体族名，全局唯一，避免和系统字体重名。
  static const String family = 'NWCustomFont';

  /// 允许导入的字体后缀。
  static const Set<String> fontExtensions = <String>{'ttf', 'otf', 'ttc'};

  final LocalStorageService _storage;

  String? _loadedPath;

  /// 当前是否已有可用字体。
  bool get hasFont => _loadedPath != null;

  /// 当前已注册的字体文件路径。
  String? get loadedPath => _loadedPath;

  /// 启动时把上次导入的字体重新注册（字体注册不跨进程保留）。
  Future<void> restoreSavedFont() async {
    final String? path = _storage.getString(StorageKeys.customFontPath);
    if (path == null || path.isEmpty) {
      return;
    }
    if (!File(path).existsSync()) {
      // 文件被系统清理或用户手动删除：静默失效，不阻塞启动。
      await _storage.remove(StorageKeys.customFontPath);
      return;
    }
    await _loadFromFile(path);
  }

  /// 让用户挑一个字体文件并复制到应用私有目录。
  ///
  /// 返回复制后的绝对路径；用户取消返回 null；格式不支持抛出
  /// [CustomFontException]。
  Future<String?> importFont() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: fontExtensions.toList(growable: false),
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }

    final PlatformFile file = result.files.first;
    final String extension =
        p.extension(file.name).replaceFirst('.', '').toLowerCase();
    if (!fontExtensions.contains(extension)) {
      throw const CustomFontException('只支持 ttf / otf / ttc 字体文件');
    }

    Uint8List? bytes = file.bytes;
    if (bytes == null) {
      final String? rawPath = file.path;
      if (rawPath == null || rawPath.isEmpty) {
        throw const CustomFontException('无法读取所选字体文件');
      }
      bytes = await File(rawPath).readAsBytes();
    }
    if (bytes.isEmpty) {
      throw const CustomFontException('字体文件内容为空');
    }

    final Directory directory = await _fontDirectory();
    final String target =
        '${directory.path}/custom_${DateTime.now().millisecondsSinceEpoch}.'
        '$extension';
    await File(target).writeAsBytes(bytes, flush: true);

    await _loadFromFile(target);
    await _storage.setString(StorageKeys.customFontPath, target);
    return target;
  }

  /// 直接加载一个已存在的字体文件（不复制、不落盘路径）。
  Future<bool> _loadFromFile(String path) async {
    try {
      final Uint8List bytes = await File(path).readAsBytes();
      if (bytes.isEmpty) {
        return false;
      }
      final ByteData data = ByteData.sublistView(bytes);
      final FontLoader loader = FontLoader(family)
        ..addFont(Future<ByteData>.value(data));
      await loader.load();
      _loadedPath = path;
      return true;
    } on Object {
      // 字体损坏 / 格式实际不支持：保持原状，设置页会提示重新导入。
      return false;
    }
  }

  /// 移除已导入的字体（文件 + 记录 + 注册状态）。
  Future<void> clear() async {
    final String? path =
        _loadedPath ?? _storage.getString(StorageKeys.customFontPath);
    if (path != null && path.isNotEmpty) {
      final File file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }
    }
    _loadedPath = null;
    await _storage.remove(StorageKeys.customFontPath);
  }

  Future<Directory> _fontDirectory() async {
    final Directory support = await getApplicationSupportDirectory();
    final Directory directory = Directory('${support.path}/fonts');
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return directory;
  }
}

/// 字体导入失败时抛出的可读异常。
class CustomFontException implements Exception {
  const CustomFontException(this.message);

  final String message;

  @override
  String toString() => message;
}
