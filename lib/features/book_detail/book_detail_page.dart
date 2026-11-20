import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/book.dart';
import '../../core/models/chapter.dart';
import '../../core/routing/app_routes.dart';
import '../../core/services/book_repository.dart';
import '../../core/services/chapter_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/feedback.dart';
import '../../core/utils/image_picker_helper.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/ghost_button.dart';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= BookDetailController(
      books: context.read<BookRepository>(),
      chapters: context.read<ChapterRepository>(),
      book: widget.book,
    )..load();
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
                        const SizedBox(height: 24),
                        _buildMetadataSection(context),
                        const SizedBox(height: 22),
                        _buildTagsSection(context),
                        const SizedBox(height: 22),
                        _buildReadingSection(context),
                        const SizedBox(height: 24),
                        _buildContents(context),
                        const SizedBox(height: 18),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            '第 3 轮 · 章节目录与元数据已可用；正文阅读、摘抄与读完标记将在后续轮次实现。',
                            style: TextStyle(
                              fontSize: 9.5,
                              height: 1.6,
                              color: AppColors.textTertiary(
                                Theme.of(context).brightness,
                              ),
                            ),
                          ),
                        ),
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
            onTap: _changeCover,
            child: Stack(
              children: <Widget>[
                BookCoverArt(book: book, width: 120, height: 168),
                Positioned(
                  right: 6,
                  bottom: 6,
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.chineseTitle(brightness).copyWith(
                    fontSize: 21,
                    letterSpacing: 0.4,
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
              borderRadius: BorderRadius.circular(18),
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
    final List<String> suggestions = AppConstants.presetTags
        .where((String tag) => !tags.contains(tag))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SectionHeader(
            title: '标签',
            english: 'Tags',
            trailing: _LinkText(label: '自定义', onTap: _addCustomTag),
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
            '点击已有标签可移除，点击浅色标签可快速添加。',
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
            onTap: () => _openReader(_c.lastChapterIndex),
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
      validator: (String input) =>
          input.trim().isEmpty ? '书名不能为空' : null,
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
      validator: (String input) =>
          input.trim().isEmpty ? '作者不能为空' : null,
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
        if (number < AppConstants.bookIdMin || number > AppConstants.bookIdMax) {
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

  Future<void> _addTag(String tag) async {
    final String? error = await _c.addTag(tag);
    if (error != null && mounted) {
      showSoftMessage(context, error);
    }
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
        return null;
      },
    );
    if (value == null || !mounted) {
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

  Future<void> _openReader(int chapterIndex) async {
    if (!_c.hasChapters) {
      showSoftMessage(context, '这本书还没有可阅读的章节');
      return;
    }
    final Book updated = await _c.markReadingPosition(chapterIndex);
    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushNamed(
      AppRoutes.reader,
      arguments: ReaderArguments(
        book: updated,
        chapterIndex: chapterIndex,
        chapterTitle: updated.lastChapterTitle,
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
