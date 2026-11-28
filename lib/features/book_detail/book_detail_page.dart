import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/book.dart';
import '../../core/models/bookmark.dart';
import '../../core/models/chapter.dart';
import '../../core/routing/app_routes.dart';
import '../../core/services/book_repository.dart';
import '../../core/services/tag_repository.dart';
import '../../core/services/bookmark_repository.dart';
import '../../core/services/chapter_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/feedback.dart';
import '../../core/utils/image_picker_helper.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/ghost_button.dart';
import '../../core/widgets/glass_dialog.dart';
import '../../core/widgets/grid_background.dart';
import '../../core/widgets/liquid_glass.dart';
import '../../core/widgets/page_top_bar.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/text_input_dialog.dart';
import '../../core/widgets/thin_divider.dart';
import '../bookshelf/widgets/book_cover_art.dart';
import '../reader/reader_arguments.dart';
import 'book_detail_controller.dart';
import 'widgets/book_share_card.dart';

/// 书籍详情页：封面 / 元信息 / 章节目录 / 标签管理 / 元数据编辑。
///
/// 第 3 轮实现除「正文阅读」以外的全部详情页业务；
/// 阅读、摘抄、读完标记留给后续轮次。
class BookDetailPage extends StatefulWidget {
  const BookDetailPage({super.key, required this.book});

  final Book book;

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  BookDetailController? _controller;

  /// 目录多选删除模式。
  bool _selecting = false;
  final Set<int> _selected = <int>{};

  /// 本书书签 / 批注条数，用于详情页入口角标。
  int _bookmarkCount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= BookDetailController(
      books: context.read<BookRepository>(),
      chapters: context.read<ChapterRepository>(),
      book: widget.book,
    )..load();
    _loadExtras();
  }

  Future<void> _loadExtras() async {
    try {
      final List<Bookmark> bookmarks = await context
          .read<BookmarkRepository>()
          .loadForBook(widget.book.number);
      if (!mounted) {
        return;
      }
      setState(() {
        _bookmarkCount = bookmarks.length;
      });
    } catch (_) {
      // 读不到就保持 0，不影响详情页其它内容。
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  BookDetailController get _c => _controller!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GridBackground(
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _c,
            builder: (BuildContext context, Widget? child) {
              return Column(
                children: <Widget>[
                  PageTopBar(
                    title: '书籍详情',
                    english: 'Book detail',
                    trailing: PressableScale(
                      pressedScale: 0.92,
                      onTap: _confirmDeleteBook,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 19,
                          color: AppColors.alpha(
                            AppColors.danger,
                            0.85,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(0, 18, 0, 40),
                      children: <Widget>[
                        _buildHeader(context),
                        const SizedBox(height: 28),
                        _buildMetadataSection(context),
                        const SizedBox(height: 26),
                        _buildTagsSection(context),
                        const SizedBox(height: 26),
                        _buildReadingSection(context),
                        const SizedBox(height: 26),
                        _buildStatsSection(context),
                        const SizedBox(height: 28),
                        _buildContents(context),
                        const SizedBox(height: 22),
                      ],
                    ),
                  ),
                  if (_selecting) _buildSelectionBar(context),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- 头部

  Widget _buildHeader(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final Book book = _c.book;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PressableScale(
            pressedScale: 0.96,
            // 点按查看封面大图（可保存），长按更换封面。
            onTap: _viewCover,
            onLongPress: _changeCover,
            child: Stack(
              children: <Widget>[
                BookCoverArt(book: book, width: 120, height: 168),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: GestureDetector(
                    onTap: _changeCover,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.alpha(Colors.black, 0.55),
                        border: Border.all(
                          color: AppColors.alpha(Colors.white, 0.35),
                          width: 0.7,
                        ),
                      ),
                      child: const Icon(
                        Icons.photo_camera_outlined,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  book.title,
                  // 长书名换行展示，禁用省略号截断。
                  softWrap: true,
                  style: AppTypography.chineseTitle(brightness).copyWith(
                    fontSize: 21,
                    letterSpacing: 0.4,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  book.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
                const SizedBox(height: 10),
                ThinDivider(
                  width: 44,
                  thickness: 1.0,
                  gradient: LinearGradient(
                    colors: <Color>[
                      AppColors.alpha(AppColors.accent(brightness), 0.85),
                      AppColors.alpha(AppColors.accent(brightness), 0.10),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _MetaRow(label: '编号', value: book.id),
                _MetaRow(label: '总字数', value: _c.totalWordsLabel),
                _MetaRow(label: '章节', value: '${_c.chapterCount} 章'),
                _MetaRow(
                  label: '状态',
                  value: book.seriesStatus.label,
                  highlight: book.seriesStatus == BookSeriesStatus.completed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- 元数据编辑

  Widget _buildMetadataSection(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: SectionHeader(title: '书籍信息', english: 'Metadata'),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.alpha(AppColors.divider(brightness), 0.9),
                width: 0.8,
              ),
              color: AppColors.alpha(AppColors.surface(brightness), 0.22),
            ),
            child: Column(
              children: <Widget>[
                _InfoEditRow(
                  label: '书名',
                  english: 'Title',
                  value: _c.book.title,
                  onTap: _editTitle,
                ),
                _RowDivider(brightness: brightness),
                _InfoEditRow(
                  label: '作者',
                  english: 'Author',
                  value: _c.book.author,
                  onTap: _editAuthor,
                ),
                _RowDivider(brightness: brightness),
                _InfoEditRow(
                  label: '编号',
                  english: 'Number',
                  value: _c.book.id,
                  onTap: _editNumber,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- 标签

  Widget _buildTagsSection(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final List<String> tags = _c.book.tags;
    final TagRepository tagRepo = context.read<TagRepository>();
    final List<String> pool = tagRepo.effectiveTags;
    final List<String> suggestions =
        pool.where((String tag) => !tags.contains(tag)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SectionHeader(
            title: '标签',
            english: 'Tags',
            trailing: _LinkText(
              label: '管理',
              onTap: () => _manageTags(tagRepo),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String tag in tags)
                _TagChip(
                  label: tag,
                  filled: true,
                  onTap: () => _confirmRemoveTag(tag),
                ),
              for (final String tag in suggestions)
                _TagChip(
                  label: tag,
                  filled: false,
                  onTap: () => _addTag(tag),
                ),
              if (tags.isEmpty && suggestions.isEmpty)
                Text(
                  '还没有标签',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary(brightness),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '每本最多 ${TagRepository.maxTagsPerBook} 个标签；点击已有标签可移除，浅色标签可添加。',
            style: TextStyle(
              fontSize: 9.5,
              color: AppColors.textTertiary(brightness),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- 阅读入口

  Widget _buildReadingSection(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LiquidGlass(
            borderRadius: 22,
            onTap: () => _openReader(_c.lastChapterIndex, resume: true),
            child: SizedBox(
              height: 56,
              child: Row(
                children: <Widget>[
                  const SizedBox(width: 20),
                  Icon(
                    Icons.play_arrow_rounded,
                    size: 22,
                    color: AppColors.accent(brightness),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '开始阅读',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: AppColors.textPrimary(brightness),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'CONTINUE READING',
                          style: AppTypography.englishLabel(brightness,
                                  fontSize: 7.8, letterSpacing: 2.0)
                              .copyWith(
                                  color: AppColors.textTertiary(brightness)),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: AppColors.textSecondary(brightness),
                  ),
                  const SizedBox(width: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Icon(
                Icons.bookmark_border_rounded,
                size: 13,
                color: AppColors.textTertiary(brightness),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '上次读到：${_c.lastChapterLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- 本书数据

  Widget _buildStatsSection(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SectionHeader(
            title: '本书数据',
            english: 'Statistics',
            trailing: _LinkText(label: '分享图', onTap: _showShareCard),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: LiquidGlass(
            borderRadius: 16,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: <Widget>[
                _StatRow(
                  icon: Icons.schedule_rounded,
                  label: '累计阅读',
                  english: 'READ TIME',
                  value: _c.book.totalReadLabel,
                  brightness: brightness,
                ),
                _RowDivider(brightness: brightness),
                _StatRow(
                  icon: Icons.bookmark_border_rounded,
                  label: '书签',
                  english: 'BOOKMARKS',
                  value: '$_bookmarkCount 条',
                  brightness: brightness,
                  onTap: () => _openList(AppRoutes.bookmarks),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openList(String route) async {
    await Navigator.of(context).pushNamed(route, arguments: _c.book);
    _loadExtras();
  }

  Future<void> _showShareCard() async {
    await showBookShareDialog(context, book: _c.book);
  }

  // ---------------------------------------------------------------- 目录

  Widget _buildContents(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final List<Chapter> chapters = _c.chapters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SectionHeader(
            title: '章节目录',
            english: 'Contents',
            trailing: chapters.isEmpty
                ? null
                : _LinkText(
                    label: _selecting ? '完成' : '多选',
                    onTap: _toggleSelecting,
                  ),
          ),
        ),
        const SizedBox(height: 6),
        if (_c.loading && chapters.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 26),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 1.6),
              ),
            ),
          )
        else if (chapters.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
            child: Text(
              '这本书还没有章节目录，可重新导入，或检查源文件是否为纯图片 PDF。',
              style: TextStyle(
                fontSize: 11,
                height: 1.6,
                color: AppColors.textTertiary(brightness),
              ),
            ),
          )
        else
          for (int index = 0; index < chapters.length; index++)
            _ChapterRow(
              index: index,
              chapter: chapters[index],
              selecting: _selecting,
              selected: _selected.contains(index),
              onTap: () {
                if (_selecting) {
                  setState(() {
                    if (!_selected.add(index)) {
                      _selected.remove(index);
                    }
                  });
                } else {
                  _openReader(index);
                }
              },
              onDelete: () => _confirmDeleteChapter(index),
            ),
      ],
    );
  }

  Widget _buildSelectionBar(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: GhostButton(
              label: _selected.length == _c.chapters.length ? '取消全选' : '全选',
              onTap: () {
                setState(() {
                  if (_selected.length == _c.chapters.length) {
                    _selected.clear();
                  } else {
                    _selected
                      ..clear()
                      ..addAll(
                        List<int>.generate(_c.chapters.length, (int i) => i),
                      );
                  }
                });
              },
              expand: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: LiquidGlass(
              borderRadius: 18,
              tint: AppColors.danger,
              onTap: _selected.isEmpty
                  ? null
                  : () => _confirmDeleteSelected(_selected.length),
              child: SizedBox(
                height: 46,
                child: Center(
                  child: Text(
                    '删除所选（${_selected.length}）',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _selected.isEmpty
                          ? AppColors.textTertiary(brightness)
                          : AppColors.danger,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- 交互

  void _toggleSelecting() {
    setState(() {
      _selecting = !_selecting;
      if (!_selecting) {
        _selected.clear();
      }
    });
  }

  Future<void> _editTitle() async {
    final String? value = await showTextInputDialog(
      context: context,
      title: '修改书名',
      english: 'Book title',
      initialValue: _c.book.title,
      maxLength: 60,
      validator: (String input) => input.trim().isEmpty ? '书名不能为空' : null,
    );
    if (value == null || !mounted) {
      return;
    }
    await _c.rename(value);
  }

  Future<void> _editAuthor() async {
    final String? value = await showTextInputDialog(
      context: context,
      title: '修改作者',
      english: 'Author',
      initialValue: _c.book.author,
      maxLength: 40,
      validator: (String input) => input.trim().isEmpty ? '作者不能为空' : null,
    );
    if (value == null || !mounted) {
      return;
    }
    await _c.changeAuthor(value);
  }

  Future<void> _editNumber() async {
    final String? value = await showTextInputDialog(
      context: context,
      title: '修改编号',
      english: 'Book number',
      message: '编号范围 0001 ~ 9999，且不能与书架上的其他书重复。',
      initialValue: _c.book.number.toString(),
      maxLength: 4,
      keyboardType: TextInputType.number,
      validator: (String input) {
        final int? number = int.tryParse(input.trim());
        if (number == null) {
          return '请输入 1 ~ 9999 的数字';
        }
        if (number < AppConstants.bookIdMin ||
            number > AppConstants.bookIdMax) {
          return '编号范围 0001 ~ 9999';
        }
        if (_c.isNumberTaken(number)) {
          return '编号 ${AppConstants.formatBookId(number)} 已被其他书籍使用';
        }
        return null;
      },
    );
    if (value == null || !mounted) {
      return;
    }
    final String? error = await _c.changeNumber(int.parse(value.trim()));
    if (error != null && mounted) {
      showSoftMessage(context, error);
    }
  }

  Future<void> _changeCover() async {
    final String? path = await pickImagePath(prefix: 'book_cover');
    if (path == null || !mounted) {
      return;
    }
    final bool saved = await _c.changeCover(path);
    if (!saved && mounted) {
      showSoftMessage(context, '封面读取失败，请换一张图片试试');
    }
  }

  /// 查看封面大图，并可保存到系统相册。
  Future<void> _viewCover() async {
    final Book book = _c.book;
    final String? path = book.coverPath;
    final File? file = (path == null || path.isEmpty) ? null : File(path);
    if (file == null || !file.existsSync()) {
      showSoftMessage(context, '这本书还没有封面图片');
      return;
    }
    final Brightness brightness = Theme.of(context).brightness;
    await showDialog<void>(
      context: context,
      barrierColor: AppColors.alpha(Colors.black, 0.72),
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: GestureDetector(
                  onTap: () => Navigator.of(dialogContext).pop(),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      file,
                      fit: BoxFit.contain,
                      errorBuilder: (BuildContext context, Object error,
                          StackTrace? stack) {
                        return Text(
                          '封面图片读取失败',
                          style: TextStyle(
                            color: AppColors.alpha(Colors.white, 0.85),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  GhostButton(
                    label: '保存到相册',
                    english: 'SAVE',
                    icon: Icons.download_rounded,
                    onTap: () => _saveCover(file),
                  ),
                  const SizedBox(width: 12),
                  GhostButton(
                    label: '关闭',
                    english: 'CLOSE',
                    onTap: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '点封面也可以关闭',
                style: TextStyle(
                  fontSize: 8.6,
                  letterSpacing: 0.8,
                  color: AppColors.alpha(
                    brightness == Brightness.dark ? Colors.white : Colors.black,
                    0.45,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveCover(File file) async {
    try {
      final Uint8List bytes = await file.readAsBytes();
      await Gal.putImageBytes(bytes, album: 'NakanoWenku');
      if (mounted) {
        showSoftMessage(context, '封面已保存到相册');
      }
    } on Object {
      if (mounted) {
        showSoftMessage(context, '保存失败，请检查相册权限');
      }
    }
  }

  Future<void> _addTag(String tag) async {
    final String? error = await _c.addTag(tag);
    if (error != null && mounted) {
      showSoftMessage(context, error);
    }
  }

  /// 标签管理：新增自定义标签 / 删除任意标签（含系统预设）。
  Future<void> _manageTags(TagRepository repo) async {
    final Brightness brightness = Theme.of(context).brightness;
    final List<String> pool = repo.effectiveTags;
    await showGlassDialog<void>(
      context: context,
      builder: (BuildContext context) => GlassDialogCard(
        title: '管理标签',
        english: 'TAGS',
        message: '最多 ${TagRepository.maxTags} 个标签，实时同步到兴趣雷达。',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final String tag in pool)
                  GestureDetector(
                    onTap: () async {
                      await repo.remove(tag);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        _manageTags(repo);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.divider(brightness),
                          width: 0.9,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            tag,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textPrimary(brightness),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Icon(
                            Icons.close_rounded,
                            size: 12,
                            color: AppColors.textTertiary(brightness),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '点击标签可删除（系统标签也能删，删完可重新加回）。',
              style: TextStyle(
                fontSize: 9.5,
                color: AppColors.textTertiary(brightness),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          GlassDialogButton(
            label: '新增标签',
            primary: true,
            onTap: () async {
              Navigator.of(context).pop();
              await _addCustomTag();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _addCustomTag() async {
    final String? value = await showTextInputDialog(
      context: context,
      title: '新增标签',
      english: 'New tag',
      hintText: '例如：治愈',
      maxLength: 8,
      validator: (String input) {
        final String tag = input.trim();
        if (tag.isEmpty) {
          return '标签不能为空';
        }
        if (_c.book.tags.contains(tag)) {
          return '这本已经有「$tag」标签了';
        }
        final TagRepository repo = context.read<TagRepository>();
        if (!repo.effectiveTags.contains(tag) && repo.isFull) {
          return '标签最多 ${TagRepository.maxTags} 个，先去管理里删掉一个';
        }
        return null;
      },
    );
    if (value == null || !mounted) {
      return;
    }
    // 自定义标签同时进入标签池，避免下次还要重新输入。
    final TagRepository repo = context.read<TagRepository>();
    if (!repo.effectiveTags.contains(value)) {
      final bool ok = await repo.add(value);
      if (!ok && mounted) {
        showSoftMessage(context, '标签池已满（最多 ${TagRepository.maxTags} 个）');
        return;
      }
    }
    if (!mounted) {
      return;
    }
    await _addTag(value);
  }

  Future<void> _confirmRemoveTag(String tag) async {
    final bool confirmed = await showConfirmDialog(
      context: context,
      title: '移除标签',
      english: 'Remove tag',
      message: '将从本书移除「$tag」，不影响其他书籍。',
      confirmLabel: '移除',
      danger: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    await _c.removeTag(tag);
  }

  Future<void> _confirmDeleteChapter(int index) async {
    final Chapter chapter = _c.chapters[index];
    final bool confirmed = await showConfirmDialog(
      context: context,
      title: '删除章节',
      english: 'Delete chapter',
      message: '将删除「${chapter.title}」，删除后无法恢复。',
      confirmLabel: '删除',
      danger: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    await _c.deleteChapters(<int>{index});
    if (mounted) {
      setState(() => _selected.remove(index));
    }
  }

  Future<void> _confirmDeleteSelected(int count) async {
    final bool confirmed = await showConfirmDialog(
      context: context,
      title: '删除 $count 个章节',
      english: 'Delete chapters',
      message: '所选章节将从本书永久移除，删除后无法恢复。',
      confirmLabel: '删除',
      danger: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    await _c.deleteChapters(Set<int>.from(_selected));
    if (mounted) {
      setState(() {
        _selected.clear();
        _selecting = false;
      });
    }
  }

  Future<void> _confirmDeleteBook() async {
    final bool confirmed = await showConfirmDialog(
      context: context,
      title: '移除整本书',
      english: 'Remove book',
      message: '《${_c.book.title}》的元数据、章节目录与封面都会从本机删除，此操作不可恢复。',
      confirmLabel: '移除',
      danger: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    await _c.deleteBook();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openReader(int chapterIndex, {bool resume = false}) async {
    if (!_c.hasChapters) {
      showSoftMessage(context, '这本书还没有可阅读的章节');
      return;
    }
    // resume=true 表示「继续阅读」：沿用书籍保存的进度，不当作明确指定章节。
    final Book updated =
        resume ? _c.book : await _c.markReadingPosition(chapterIndex);
    if (!mounted) {
      return;
    }
    // 漫画包走独立的漫画阅读页，不进入文字阅读器。
    if (updated.isComic) {
      await Navigator.of(context).pushNamed(
        AppRoutes.comic,
        arguments: updated,
      );
      return;
    }
    // 传入真实的章节标题：阅读页据此判定「明确指定章节进入」，
    // 从而直接定位到该章开头，而不是跳回上次读到的位置。
    if (resume) {
      await Navigator.of(context).pushNamed(
        AppRoutes.reader,
        arguments: ReaderArguments(book: updated),
      );
      return;
    }
    final String chapterTitle =
        (chapterIndex >= 0 && chapterIndex < _c.chapters.length)
            ? _c.chapters[chapterIndex].title
            : '';
    await Navigator.of(context).pushNamed(
      AppRoutes.reader,
      arguments: ReaderArguments(
        book: updated,
        chapterIndex: chapterIndex,
        chapterTitle: chapterTitle.isEmpty ? null : chapterTitle,
      ),
    );
  }
}

// ------------------------------------------------------------------ 小组件

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 46,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 0.4,
                color: AppColors.textTertiary(brightness),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.2,
                fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
                color: highlight
                    ? AppColors.accent(brightness)
                    : AppColors.textSecondary(brightness),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoEditRow extends StatelessWidget {
  const _InfoEditRow({
    required this.label,
    required this.english,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String english;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    return PressableScale(
      pressedScale: 0.99,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 40,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary(brightness),
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textPrimary(brightness),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              english.toUpperCase(),
              style: AppTypography.englishLabel(brightness, fontSize: 7.6)
                  .copyWith(color: AppColors.textTertiary(brightness)),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.edit_outlined,
              size: 14,
              color: AppColors.textTertiary(brightness),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider({required this.brightness});

  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return ThinDivider(
      thickness: 0.7,
      color: AppColors.alpha(AppColors.divider(brightness), 0.75),
      margin: const EdgeInsets.only(left: 16, right: 16),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    return PressableScale(
      pressedScale: 0.94,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: filled
              ? AppColors.alpha(AppColors.accent(brightness), 0.13)
              : Colors.transparent,
          border: Border.all(
            color: filled
                ? AppColors.alpha(AppColors.accent(brightness), 0.55)
                : AppColors.alpha(AppColors.divider(brightness), 0.9),
            width: 0.85,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.3,
                fontWeight: filled ? FontWeight.w600 : FontWeight.w400,
                color: filled
                    ? AppColors.accent(brightness)
                    : AppColors.textSecondary(brightness),
              ),
            ),
            if (filled) ...<Widget>[
              const SizedBox(width: 5),
              Icon(
                Icons.close_rounded,
                size: 11,
                color: AppColors.accent(brightness),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChapterRow extends StatelessWidget {
  const _ChapterRow({
    required this.index,
    required this.chapter,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });

  final int index;
  final Chapter chapter;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    return Column(
      children: <Widget>[
        PressableScale(
          pressedScale: 0.99,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 16, 10),
            child: Row(
              children: <Widget>[
                if (selecting) ...<Widget>[
                  Icon(
                    selected
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 18,
                    color: selected
                        ? AppColors.accent(brightness)
                        : AppColors.textTertiary(brightness),
                  ),
                  const SizedBox(width: 10),
                ] else ...<Widget>[
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${index + 1}'.padLeft(2, '0'),
                      style: AppTypography.englishLabel(
                        brightness,
                        fontSize: 9.5,
                        letterSpacing: 0.4,
                      ).copyWith(color: AppColors.textTertiary(brightness)),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        chapter.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textPrimary(brightness),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${chapter.wordCount} 字',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: AppColors.textTertiary(brightness),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!selecting)
                  PressableScale(
                    pressedScale: 0.9,
                    onTap: onDelete,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 16,
                        color: AppColors.textTertiary(brightness),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        ThinDivider(
          thickness: 0.7,
          color: AppColors.alpha(AppColors.divider(brightness), 0.6),
          margin: const EdgeInsets.only(left: 24, right: 24),
        ),
      ],
    );
  }
}

class _LinkText extends StatelessWidget {
  const _LinkText({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: 0.92,
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: AppColors.accent(Theme.of(context).brightness),
        ),
      ),
    );
  }
}

/// 详情页「本书数据」单行：图标 + 中文标签 + 英文小字 + 右侧数值。
class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.english,
    required this.value,
    required this.brightness,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String english;
  final String value;
  final Brightness brightness;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: <Widget>[
          Icon(
            icon,
            size: 15,
            color: AppColors.alpha(AppColors.textSecondary(brightness), 0.9),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  english,
                  style: AppTypography.englishLabel(
                    brightness,
                    fontSize: 7.4,
                    letterSpacing: 1.8,
                  ).copyWith(color: AppColors.textTertiary(brightness)),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppFonts.serif,
              fontSize: 11.5,
              color: AppColors.textSecondary(brightness),
            ),
          ),
          if (onTap != null) ...<Widget>[
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 15,
              color: AppColors.textTertiary(brightness),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }
    return PressableScale(
      pressedScale: 0.98,
      onTap: onTap,
      child: content,
    );
  }
}
