import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

/// 扫描到（或手动选中）的一个本地文件。
class LocalFileEntry {
  const LocalFileEntry({
    required this.path,
    required this.name,
    required this.size,
    required this.extension,
  });

  final String path;
  final String name;
  final int size;

  /// 小写、不带点，例如 `epub`。
  final String extension;

  /// 列表右侧展示的文件大小。
  String get sizeLabel {
    if (size <= 0) {
      return '大小未知';
    }
    if (size >= 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (size >= 1024) {
      return '${(size / 1024).toStringAsFixed(0)} KB';
    }
    return '$size B';
  }

  LocalFileEntry copyWith({String? path, String? name}) {
    return LocalFileEntry(
      path: path ?? this.path,
      name: name ?? this.name,
      size: size,
      extension: extension,
    );
  }
}

/// 一次扫描的结果。
class FileScanResult {
  const FileScanResult({
    required this.entries,
    this.truncated = false,
    this.scannedRoot,
  });

  final List<LocalFileEntry> entries;

  /// 命中数量达到上限时置位，界面提示「仅展示前 N 个」。
  final bool truncated;

  /// 实际扫描的根目录（为空表示没有可用目录）。
  final String? scannedRoot;
}

/// 本地文件扫描器。
///
/// 说明：Android 10 之后分区存储收紧了直接遍历外部存储的权限，
/// 部分目录会抛 `FileSystemException`，这里全部吞掉并继续扫描；
/// 因此导入页始终保留「手动选择文件」入口（走系统文件选择器），
/// 保证在受限设备上依然可以完成导入。
class LocalFileScanner {
  const LocalFileScanner();

  /// 优先扫描外部存储根目录；不存在时依次尝试其它常见挂载点。
  static const List<String> _candidateRoots = <String>[
    '/storage/emulated/0',
    '/sdcard',
  ];

  /// Android/ 目录下是应用私有数据，遍历既无意义又容易触发权限错误。
  static const Set<String> _skippedDirectoryNames = <String>{
    'Android',
    'obb',
    'data',
  };

  /// 申请读取本机文件的权限。
  ///
  /// * Android 11+：「所有文件访问」（MANAGE_EXTERNAL_STORAGE）；
  /// * 旧版本：普通存储权限。
  ///
  /// 返回 false 也不阻断扫描——能读多少算多少，手动选择文件始终可用。
  Future<bool> ensureStorageAccess() async {
    if (!Platform.isAndroid) {
      return true;
    }
    try {
      if (await Permission.manageExternalStorage.isGranted) {
        return true;
      }
      final PermissionStatus allFiles =
          await Permission.manageExternalStorage.request();
      if (allFiles.isGranted) {
        return true;
      }
      if (await Permission.storage.isGranted) {
        return true;
      }
      return (await Permission.storage.request()).isGranted;
    } catch (_) {
      return false;
    }
  }

  /// 扫描本地文件。
  ///
  /// * [extensions] 勾选的格式集合（小写、不带点）；
  /// * [maxFiles] 结果上限，避免超大目录把内存吃满；
  /// * [isCancelled] 页面退出时返回 true，尽快中断遍历。
  Future<FileScanResult> scan({
    required Set<String> extensions,
    int maxFiles = 3000,
    int maxDepth = 7,
    bool Function()? isCancelled,
  }) async {
    if (extensions.isEmpty) {
      return const FileScanResult(entries: <LocalFileEntry>[]);
    }

    // 权限被拒时继续尝试遍历，失败目录会被静默跳过。
    await ensureStorageAccess();

    for (final String rootPath in _candidateRoots) {
      final Directory root = Directory(rootPath);
      bool exists = false;
      try {
        exists = await root.exists();
      } catch (_) {
        exists = false;
      }
      if (!exists) {
        continue;
      }

      final List<LocalFileEntry> results = <LocalFileEntry>[];
      bool truncated = false;
      await _walk(
        root,
        depth: 0,
        extensions: extensions,
        results: results,
        maxFiles: maxFiles,
        maxDepth: maxDepth,
        isCancelled: isCancelled,
        markTruncated: () => truncated = true,
      );

      if (results.isEmpty && !truncated) {
        // 该挂载点可能被系统拦截，继续尝试下一个。
        continue;
      }

      results.sort((LocalFileEntry a, LocalFileEntry b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      return FileScanResult(
        entries: results,
        truncated: truncated,
        scannedRoot: rootPath,
      );
    }

    return const FileScanResult(entries: <LocalFileEntry>[]);
  }

  Future<void> _walk(
    Directory dir, {
    required int depth,
    required Set<String> extensions,
    required List<LocalFileEntry> results,
    required int maxFiles,
    required int maxDepth,
    required bool Function()? isCancelled,
    required void Function() markTruncated,
  }) async {
    if (depth > maxDepth || results.length >= maxFiles) {
      if (results.length >= maxFiles) {
        markTruncated();
      }
      return;
    }
    if (isCancelled?.call() ?? false) {
      return;
    }

    List<FileSystemEntity> entities;
    try {
      entities = await dir.list(followLinks: false).toList();
    } catch (_) {
      return;
    }

    for (final FileSystemEntity entity in entities) {
      if (isCancelled?.call() ?? false) {
        return;
      }
      if (results.length >= maxFiles) {
        markTruncated();
        return;
      }

      final String name = p.basename(entity.path);
      if (name.isEmpty || name.startsWith('.')) {
        continue;
      }

      if (entity is Directory) {
        if (_skippedDirectoryNames.contains(name)) {
          continue;
        }
        await _walk(
          entity,
          depth: depth + 1,
          extensions: extensions,
          results: results,
          maxFiles: maxFiles,
          maxDepth: maxDepth,
          isCancelled: isCancelled,
          markTruncated: markTruncated,
        );
        continue;
      }

      if (entity is! File) {
        continue;
      }

      final String extension =
          p.extension(entity.path).replaceFirst('.', '').toLowerCase();
      if (!extensions.contains(extension)) {
        continue;
      }

      int size = 0;
      try {
        size = await entity.length();
      } catch (_) {
        size = 0;
      }

      results.add(LocalFileEntry(
        path: entity.path,
        name: name,
        size: size,
        extension: extension,
      ));
    }
  }

  /// 手动选择文件（系统文件选择器），是扫描失败时的兜底路径。
  Future<List<LocalFileEntry>> pickFiles({
    required Set<String> extensions,
  }) async {
    if (extensions.isEmpty) {
      return <LocalFileEntry>[];
    }

    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: extensions.toList(),
      withData: false,
    );
    if (result == null) {
      return <LocalFileEntry>[];
    }

    final List<LocalFileEntry> entries = <LocalFileEntry>[];
    for (final PlatformFile file in result.files) {
      final String? path = file.path;
      if (path == null || path.isEmpty) {
        continue;
      }
      entries.add(LocalFileEntry(
        path: path,
        name: file.name,
        size: file.size,
        extension: p.extension(file.name).replaceFirst('.', '').toLowerCase(),
      ));
    }
    return entries;
  }
}
