import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../models/book.dart';
import '../models/chapter.dart';
import 'book_parser.dart';
import 'book_repository.dart';
import 'chapter_repository.dart';

/// 多卷导入策略。
enum VolumeImportMode {
  /// 每一卷单独入库（书名自动追加 | NW-XXXX）。
  separate,

  /// 全部卷合并为一整本书。
  mergeAll,

  /// 用户勾选若干卷合并为一本，其余仍单独入库。
  mergeSelected,
}

/// 单个文件的导入进度，供导入页的进度卡片消费。
class ImportProgress {
  const ImportProgress({
    required this.index,
    required this.total,
    required this.fileName,
    required this.fraction,
    this.done = false,
    this.failed = false,
    this.message,
  });

  /// 文件在本次导入列表中的下标。
  final int index;
  final int total;
  final String fileName;

  /// 该文件整体的进度 0~1。
  final double fraction;

  /// 是否处理完毕（成功）——界面据此打勾。
  final bool done;
  final bool failed;

  /// 进度卡片右侧的短语，例如「已入库 NW-0003」。
  final String? message;
}

/// 解析出来的「一卷」，仍带着它来自哪个源文件，便于进度回填。
class ImportedVolume {
  const ImportedVolume({
    required this.document,
    required this.sourceIndex,
    required this.sourceLabel,
  });

  final ParsedBook document;
  final int sourceIndex;
  final String sourceLabel;
}

/// 解析阶段的产物。
///
/// 先解析、后询问合并策略、最后落盘，这样多卷弹窗出现时
/// 用户已经能看到「共解析出几卷」，不会先写库再后悔。
class ImportPlan {
  const ImportPlan({
    required this.volumes,
    required this.failures,
    required this.totalFiles,
  });

  final List<ImportedVolume> volumes;
  final List<String> failures;
  final int totalFiles;

  bool get hasVolumes => volumes.isNotEmpty;
  int get volumeCount => volumes.length;
}

/// 一次导入的结果。
class ImportOutcome {
  const ImportOutcome({
    required this.books,
    required this.failures,
  });

  /// 本次新入库的书籍（已分配编号）。
  final List<Book> books;

  /// 失败提示，例如「xxx.pdf：PDF 正文解析暂未支持」。
  final List<String> failures;

  bool get isEmpty => books.isEmpty;
}

/// 导入业务编排：解析 → （界面询问策略）→ 分组 → 分配编号 → 落盘。
///
/// 与界面完全解耦：页面只调用 [prepare] / [commit] 并消费
/// [ImportProgress] 回调，不关心 EPUB / DOCX 的具体解析过程。
class BookImportService {
  BookImportService({
    required BookRepository books,
    required ChapterRepository chapters,
    BookParser parser = const BookParser(),
  })  : _books = books,
        _chapters = chapters,
        _parser = parser;

  final BookRepository _books;
  final ChapterRepository _chapters;
  final BookParser _parser;

  /// 第一步：把选中的文件解析成卷（只读文件，不写任何数据）。
  Future<ImportPlan> prepare(
    List<String> paths, {
    void Function(ImportProgress progress)? onProgress,
  }) async {
    final List<ImportedVolume> volumes = <ImportedVolume>[];
    final List<String> failures = <String>[];
    final int total = paths.length;

    for (int index = 0; index < total; index++) {
      final String path = paths[index];
      final String label = p.basename(path);
      onProgress?.call(ImportProgress(
        index: index,
        total: total,
        fileName: label,
        fraction: 0.12,
        message: '解析中',
      ));

      try {
        final List<ParsedBook> parsed = await _parser.parseFile(path);
        for (final ParsedBook document in parsed) {
          volumes.add(ImportedVolume(
            document: document,
            sourceIndex: index,
            sourceLabel: label,
          ));
        }
        onProgress?.call(ImportProgress(
          index: index,
          total: total,
          fileName: label,
          fraction: 0.55,
          message: parsed.length > 1 ? '${parsed.length} 卷' : '解析完成',
        ));
      } catch (error) {
        final String message =
            error is BookParseException ? error.message : '解析失败，文件可能已损坏';
        failures.add('$label：$message');
        onProgress?.call(ImportProgress(
          index: index,
          total: total,
          fileName: label,
          fraction: 1,
          done: true,
          failed: true,
          message: message,
        ));
      }
    }

    return ImportPlan(volumes: volumes, failures: failures, totalFiles: total);
  }

  /// 第二步：按策略分组写库，生成书籍与章节目录。
  Future<ImportOutcome> commit(
    ImportPlan plan, {
    VolumeImportMode mode = VolumeImportMode.separate,
    Set<int> mergeSelection = const <int>{},
    String? groupLabel,
    List<int>? mergeOrder,
    List<String> tags = const <String>[],
    void Function(ImportProgress progress)? onProgress,
  }) async {
    if (!plan.hasVolumes) {
      return ImportOutcome(books: const <Book>[], failures: plan.failures);
    }

    final List<Book> existing = _books.loadAll();

    // 用户在界面上调整过的合并顺序：只影响「自选合并」那一组。
    if (mergeOrder != null && mergeOrder.isNotEmpty) {
      final Map<int, ImportedVolume> byIndex = <int, ImportedVolume>{
        for (final ImportedVolume volume in plan.volumes)
          volume.sourceIndex: volume,
      };
      final List<ImportedVolume> ordered = <ImportedVolume>[
        for (final int index in mergeOrder)
          if (byIndex[index] != null) byIndex[index]!,
        for (final ImportedVolume volume in plan.volumes)
          if (!mergeOrder.contains(volume.sourceIndex)) volume,
      ];
      plan = ImportPlan(
        volumes: ordered,
        failures: plan.failures,
        totalFiles: plan.totalFiles,
      );
    }

    final List<List<ImportedVolume>> groups = _buildGroups(
      plan.volumes,
      // 漫画始终一本一文件入库，避免把不同作品合并成一本书。
      plan.volumes.any((ImportedVolume volume) => volume.document.isComic)
          ? VolumeImportMode.separate
          : mode,
      mergeSelection,
    );
    final List<Book> created = <Book>[];

    for (final List<ImportedVolume> group in groups) {
      // 每本书都重新算一次最小空号，避免与已有编号或本批已分配的编号撞号。
      final int number = _books.nextNumber(<Book>[
        ...existing,
        ...created,
      ]);

      final List<Chapter> chapters = <Chapter>[];
      for (final ImportedVolume volume in group) {
        chapters.addAll(volume.document.chapters);
      }

      final int wordCount = chapters.fold<int>(
        0,
        (int sum, Chapter chapter) => sum + chapter.wordCount,
      );
      final String baseTitle = _baseTitleOf(group.first.document.title);
      // 编号只写进 Book.number，绝不拼进书名：书名保持作者写的原样，
      // 编辑书名时也不会看到「| NW-0001」这类后缀。
      final String title = baseTitle;

      // 同一本合并书可能对应多个源文件，进度逐个回填。
      final Set<int> sourceIndexes =
          group.map((ImportedVolume volume) => volume.sourceIndex).toSet();
      for (final int sourceIndex in sourceIndexes) {
        final ImportedVolume source = group.firstWhere(
          (ImportedVolume volume) => volume.sourceIndex == sourceIndex,
          orElse: () => group.first,
        );
        onProgress?.call(ImportProgress(
          index: sourceIndex,
          total: plan.totalFiles,
          fileName: source.sourceLabel,
          fraction: 0.72,
          message: '写入章节',
        ));
      }

      String? coverPath;
      final Uint8List? coverBytes = group.first.document.coverBytes;
      if (coverBytes != null && coverBytes.isNotEmpty) {
        coverPath = await _chapters.saveCoverBytes(
          number,
          coverBytes,
          group.first.document.coverExtension,
        );
      }

      await _chapters.save(number, chapters);

      final Book book = Book(
        number: number,
        title: title,
        author: group.first.document.author,
        coverPath: coverPath,
        wordCount: wordCount,
        chapterCount: chapters.length,
        tags: tags,
        addedAt: DateTime.now(),
        isComic: group.first.document.isComic,
        group: (groupLabel == null || groupLabel.trim().isEmpty)
            ? null
            : groupLabel.trim(),
      );
      created.add(book);

      for (final int sourceIndex in sourceIndexes) {
        final ImportedVolume source = group.firstWhere(
          (ImportedVolume volume) => volume.sourceIndex == sourceIndex,
          orElse: () => group.first,
        );
        onProgress?.call(ImportProgress(
          index: sourceIndex,
          total: plan.totalFiles,
          fileName: source.sourceLabel,
          fraction: 1,
          done: true,
          message: '已入库 ${book.id}',
        ));
      }
    }

    final List<Book> all = <Book>[...existing, ...created]
      ..sort((Book a, Book b) => a.number.compareTo(b.number));
    await _books.saveAll(all);

    return ImportOutcome(books: created, failures: plan.failures);
  }

  /// 便捷方法：解析 + 默认策略直接落盘（后台批处理用）。
  Future<ImportOutcome> importFiles(
    List<String> paths, {
    VolumeImportMode mode = VolumeImportMode.separate,
    Set<int> mergeSelection = const <int>{},
    void Function(ImportProgress progress)? onProgress,
  }) async {
    final ImportPlan plan = await prepare(paths, onProgress: onProgress);
    return commit(
      plan,
      mode: mode,
      mergeSelection: mergeSelection,
      onProgress: onProgress,
    );
  }

  /// 根据导入策略把解析结果分组，每组最终生成一本书。
  List<List<ImportedVolume>> _buildGroups(
    List<ImportedVolume> volumes,
    VolumeImportMode mode,
    Set<int> selection,
  ) {
    switch (mode) {
      case VolumeImportMode.mergeAll:
        return <List<ImportedVolume>>[volumes];

      case VolumeImportMode.mergeSelected:
        final List<ImportedVolume> merged = volumes
            .where((ImportedVolume volume) =>
                selection.contains(volume.sourceIndex))
            .toList();
        if (merged.length < 2) {
          // 选择不足两卷时退化为「分卷单独入库」，避免出现空操作。
          return volumes
              .map((ImportedVolume volume) => <ImportedVolume>[volume])
              .toList();
        }
        final List<ImportedVolume> rest = volumes
            .where((ImportedVolume volume) =>
                !selection.contains(volume.sourceIndex))
            .toList();
        return <List<ImportedVolume>>[
          merged,
          ...rest.map((ImportedVolume volume) => <ImportedVolume>[volume]),
        ];

      case VolumeImportMode.separate:
        return volumes
            .map((ImportedVolume volume) => <ImportedVolume>[volume])
            .toList();
    }
  }

  /// 去掉书名末尾的「第 N 卷 / 卷 N / (上)」等分卷标记，用于合并后的书名。
  String _baseTitleOf(String rawTitle) {
    String title = rawTitle.trim();
    title = title.replaceAll(RegExp(r'\s*[|｜]\s*NW-\d{4}$'), '');
    title = title.replaceAll(
      RegExp(r'[（(【\[]?\s*(第\s*)?[0-9０-９一二三四五六七八九十百]+\s*[卷册部集]\s*[)）】\]]?\s*$'),
      '',
    );
    title = title.trim();
    return title.isEmpty ? rawTitle.trim() : title;
  }
}
