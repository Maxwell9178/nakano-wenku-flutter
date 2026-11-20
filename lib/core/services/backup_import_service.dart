import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';

import '../constants/app_constants.dart';

/// 备份导入过程中可以直接展示给用户的异常。
///
/// 所有文案都是「人话」，禁止把底层异常直接抛给界面造成崩溃或英文报错。
class BackupImportException implements Exception {
  const BackupImportException(this.message);

  final String message;

  @override
  String toString() => 'BackupImportException: $message';
}

/// 备份读取结果。
///
/// 负责解压 .wkarchive 并读出 info.json 与 avatar.png；
/// 真正的数据落盘由 WkArchiveService.apply 完成，这里只做读取与预校验。
class BackupImportResult {
  const BackupImportResult({
    required this.userName,
    required this.rawInfo,
    this.avatarBytes,
  });

  /// 备份包中解析出的用户名（缺失时使用兜底昵称）。
  final String userName;

  /// info.json 的原始结构，供后续轮次复用。
  final Map<String, dynamic> rawInfo;

  /// avatar.png 的原始字节；备份包未携带头像时为 null（不报错）。
  final Uint8List? avatarBytes;

  bool get hasAvatar => avatarBytes != null && avatarBytes!.isNotEmpty;
}

/// .wkarchive 备份包读取服务。
///
/// 备份包本质是 zip 改名，内部结构：
/// - info.json：文本类数据
/// - avatar.png：头像原图（非必选，缺失时使用默认空白头像）
///
/// 约束：全程离线解析，不发起任何网络请求。
class BackupImportService {
  const BackupImportService();

  /// 单个备份包大小上限（防御性限制，避免误选超大文件导致内存爆炸）。
  static const int _maxArchiveBytes = 1024 * 1024 * 1024;

  /// 唤起系统文件选择器并读取备份；用户取消时返回 null。
  Future<BackupImportResult?> pickAndRead() async {
    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>[AppConstants.backupExtension],
        allowMultiple: false,
        withData: false,
      );
    } catch (_) {
      throw const BackupImportException('无法打开文件选择器，请检查系统文件权限');
    }

    if (picked == null || picked.files.isEmpty) {
      return null; // 用户主动取消，不算错误
    }

    final String? path = picked.files.first.path;
    if (path == null || path.isEmpty) {
      throw const BackupImportException('无法读取所选文件，请重新选择');
    }

    return readFromFile(File(path));
  }

  /// 解析指定路径的备份包。
  Future<BackupImportResult> readFromFile(File file) async {
    if (!await file.exists()) {
      throw const BackupImportException('备份文件不存在或已被移动');
    }

    final int length = await file.length();
    if (length <= 0) {
      throw const BackupImportException('备份文件为空');
    }
    if (length > _maxArchiveBytes) {
      throw const BackupImportException('备份文件过大，暂不支持导入');
    }

    final Uint8List bytes = await file.readAsBytes();

    Archive archive;
    try {
      // verify: true 会校验 CRC，能拦下被截断的压缩包。
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } catch (_) {
      throw const BackupImportException('备份包已损坏或格式不正确');
    }

    ArchiveFile? infoEntry;
    ArchiveFile? avatarEntry;
    for (final ArchiveFile entry in archive.files) {
      if (!entry.isFile) {
        continue;
      }
      final String name =
          entry.name.replaceAll('\\', '/').split('/').last.toLowerCase();
      if (name == 'info.json') {
        infoEntry = entry;
      } else if (name == 'avatar.png') {
        avatarEntry = entry;
      }
    }

    if (infoEntry == null) {
      throw const BackupImportException('备份包内缺少 info.json，无法恢复数据');
    }

    final Uint8List? infoBytes = _readEntryBytes(infoEntry);
    if (infoBytes == null) {
      throw const BackupImportException('备份包内的 info.json 无法读取');
    }

    Map<String, dynamic> rawInfo;
    try {
      final dynamic decoded = jsonDecode(utf8.decode(infoBytes));
      rawInfo = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      throw const BackupImportException('info.json 内容格式不正确');
    }

    final Uint8List? avatarBytes =
        avatarEntry == null ? null : _readEntryBytes(avatarEntry);

    return BackupImportResult(
      userName: _extractUserName(rawInfo),
      rawInfo: rawInfo,
      avatarBytes: avatarBytes,
    );
  }

  /// 兼容不同版本 archive 包的内容读取方式。
  Uint8List? _readEntryBytes(ArchiveFile entry) {
    try {
      final dynamic content = entry.content;
      if (content is Uint8List) {
        return content;
      }
      if (content is List<int>) {
        return Uint8List.fromList(content);
      }
      if (content is List) {
        return Uint8List.fromList(content.cast<int>());
      }
    } catch (_) {
      // 读取失败按「缺失」处理，交由调用方决定是否兜底。
    }
    return null;
  }

  /// 从 info.json 中尽可能宽松地提取用户名。
  ///
  /// 备份结构会随着版本演进而扩展，这里允许 userName / username / name
  /// 以及 account.name、user.name 等常见嵌套写法。
  String _extractUserName(Map<String, dynamic> info) {
    final List<Object?> candidates = <Object?>[
      info['userName'],
      info['username'],
      info['name'],
      info['account'] is Map ? (info['account'] as Map)['name'] : null,
      info['user'] is Map ? (info['user'] as Map)['name'] : null,
    ];

    for (final Object? candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return AppConstants.defaultUserName;
  }
}
