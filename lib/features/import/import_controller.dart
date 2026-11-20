import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/import_site.dart';
import '../../core/services/book_import_service.dart';
import '../../core/services/import_site_repository.dart';
import '../../core/services/local_file_scanner.dart';

/// 导入页的状态机：格式筛选 → 扫描 → 勾选 → 解析 → 选择策略 → 入库。
///
/// 页面只负责渲染与转发用户操作，所有耗时逻辑都在这里排队执行，
/// 并通过 [progresses] 把每个文件的进度暴露给进度卡片。
class ImportController extends ChangeNotifier {
  ImportController({
    required LocalFileScanner scanner,
    required BookImportService importService,
    required ImportSiteRepository siteRepository,
  })  : _scanner = scanner,
        _importService = importService,
        _siteRepository = siteRepository;

  final LocalFileScanner _scanner;
  final BookImportService _importService;
  final ImportSiteRepository _siteRepository;

  /// 导入页支持的全部后缀（含暂不支持解析的 PDF / DOC，解析时会给出提示）。
  static const List<String> formatOptions = <String>[
    'epub',
    'txt',
    'md',
    'markdown',
    'docx',
    'zip',
    'pdf',
    'doc',
  ];

  final Set<String> _formats = <String>{
    'epub',
    'txt',
    'md',
    'markdown',
    'docx',
    'zip',
  };

  List<LocalFileEntry> _entries = const <LocalFileEntry>[];
  final Set<String> _selectedPaths = <String>{};
  final Map<int, ImportProgress> _progresses = <int, ImportProgress>{};
  List<ImportSite> _sites = const <ImportSite>[ImportSiteRepository.defaultSite];
  List<String> _failures = const <String>[];

  bool _scanning = false;
  bool _importing = false;
  bool _truncated = false;

  Set<String> get formats => Set<String>.unmodifiable(_formats);
  List<LocalFileEntry> get entries => _entries;
  Set<String> get selectedPaths => Set<String>.unmodifiable(_selectedPaths);
  List<ImportSite> get sites => _sites;
  List<String> get failures => _failures;
  bool get scanning => _scanning;
  bool get importing => _importing;
  bool get truncated => _truncated;
  int get selectedCount => _selectedPaths.length;
  bool get hasEntries => _entries.isNotEmpty;

  /// 进度卡片按文件下标升序展示。
  List<ImportProgress> get progresses {
    final List<ImportProgress> list = _progresses.values.toList()
      ..sort((ImportProgress a, ImportProgress b) => a.index.compareTo(b.index));
    return list;
  }

  /// 可解析的正文本格式（PDF / DOC 仅能扫描与勾选，解析时会给出提示）。
  static const Set<String> parseableExtensions = <String>{
    'epub',
    'txt',
    'md',
    'markdown',
    'docx',
    'zip',
  };

  bool supportedForParsing(String extension) =>
      parseableExtensions.contains(extension.toLowerCase());

  bool get allProgressDone =>
      _progresses.isNotEmpty &&
      _progresses.values.every((ImportProgress p) => p.done);

  void loadSites() {
    _sites = _siteRepository.load();
    notifyListeners();
  }

  bool isFormatEnabled(String extension) => _formats.contains(extension);

  void toggleFormat(String extension) {
    if (_formats.contains(extension)) {
      if (_formats.length == 1) {
        return;
      }
      _formats.remove(extension);
      _entries = _entries
          .where((LocalFileEntry entry) => _formats.contains(entry.extension))
          .toList();
      _selectedPaths.removeWhere((String path) =>
          !_entries.any((LocalFileEntry entry) => entry.path == path));
    } else {
      _formats.add(extension);
    }
    notifyListeners();
  }

  Future<void> scan() async {
    if (_scanning || _importing) {
      return;
    }
    _scanning = true;
    _failures = const <String>[];
    notifyListeners();

    try {
      final FileScanResult result =
          await _scanner.scan(extensions: Set<String>.from(_formats));
      _entries = result.entries;
      _truncated = result.truncated;
      // 扫描完成后默认全选，用户可逐个取消。
      _selectedPaths
        ..clear()
        ..addAll(_entries.map((LocalFileEntry entry) => entry.path));
    } catch (error) {
      _failures = <String>['扫描失败：$error'];
      _entries = const <LocalFileEntry>[];
    } finally {
      _scanning = false;
      notifyListeners();
    }
  }

  /// 手动挑选文件（扫描受限或只想导入某个下载目录时使用）。
  Future<void> pickManually() async {
    if (_scanning || _importing) {
      return;
    }
    _scanning = true;
    notifyListeners();
    try {
      final List<LocalFileEntry> picked =
          await _scanner.pickFiles(extensions: Set<String>.from(_formats));
      if (picked.isNotEmpty) {
        final Map<String, LocalFileEntry> merged = <String, LocalFileEntry>{
          for (final LocalFileEntry entry in _entries) entry.path: entry,
          for (final LocalFileEntry entry in picked) entry.path: entry,
        };
        _entries = merged.values.toList()
          ..sort((LocalFileEntry a, LocalFileEntry b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        for (final LocalFileEntry entry in picked) {
          _selectedPaths.add(entry.path);
        }
      }
    } catch (error) {
      _failures = <String>['选择文件失败：$error'];
    } finally {
      _scanning = false;
      notifyListeners();
    }
  }

  void toggleEntry(String path) {
    if (_selectedPaths.contains(path)) {
      _selectedPaths.remove(path);
    } else {
      _selectedPaths.add(path);
    }
    notifyListeners();
  }

  void selectAll() {
    _selectedPaths
      ..clear()
      ..addAll(_entries.map((LocalFileEntry entry) => entry.path));
    notifyListeners();
  }

  void clearSelection() {
    _selectedPaths.clear();
    notifyListeners();
  }

  /// 解析选中文件。返回值交给页面决定是否弹「多卷导入方式」。
  Future<ImportPlan?> prepareSelected() async {
    if (_importing || _selectedPaths.isEmpty) {
      return null;
    }
    _importing = true;
    _progresses.clear();
    _failures = const <String>[];
    notifyListeners();

    final List<String> paths = _entries
        .where((LocalFileEntry entry) => _selectedPaths.contains(entry.path))
        .map((LocalFileEntry entry) => entry.path)
        .toList();

    final ImportPlan plan = await _importService.prepare(
      paths,
      onProgress: _handleProgress,
    );
    _failures = plan.failures;
    notifyListeners();
    return plan;
  }

  /// 按策略写库。
  Future<ImportOutcome?> commitPlan(
    ImportPlan plan, {
    required VolumeImportMode mode,
    Set<int> mergeSelection = const <int>{},
  }) async {
    final ImportOutcome outcome = await _importService.commit(
      plan,
      mode: mode,
      mergeSelection: mergeSelection,
      onProgress: _handleProgress,
    );
    _failures = outcome.failures;
    _importing = false;
    notifyListeners();
    return outcome;
  }

  /// 取消（例如用户在多卷弹窗上点了取消）：只清理忙碌状态，不写库。
  void cancelImport() {
    _importing = false;
    _progresses.clear();
    notifyListeners();
  }

  Future<void> addSite({required String name, required String url}) async {
    final ImportSite site = ImportSite(
      id: 'site-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      url: url,
    );
    _sites = <ImportSite>[..._sites, site];
    await _siteRepository.save(_sites);
    notifyListeners();
  }

  Future<void> removeSite(String id) async {
    _sites = _sites.where((ImportSite site) => site.id != id).toList();
    await _siteRepository.save(_sites);
    notifyListeners();
  }

  void reset() {
    _progresses.clear();
    _importing = false;
    _failures = const <String>[];
    notifyListeners();
  }

  void _handleProgress(ImportProgress progress) {
    _progresses[progress.index] = progress;
    notifyListeners();
  }

  /// 供页面展示的默认站点名（避免空名）。
  String get defaultSiteName => ImportSiteRepository.defaultSite.name;

  /// 判断某个文件是否仍在导入列表中。
  bool containsEntry(String fileName) =>
      _entries.any((LocalFileEntry entry) => entry.name == fileName);

  /// 显示用：当前格式筛选下是否包含可解析格式。
  bool get hasParseableSelection => _selectedPaths.isNotEmpty;

  String get appName => AppConstants.appName;
}
