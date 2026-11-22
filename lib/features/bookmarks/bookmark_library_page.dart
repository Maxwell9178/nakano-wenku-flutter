import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/book.dart';
import '../../core/models/bookmark.dart';
import '../../core/routing/app_routes.dart';
import '../../core/services/book_repository.dart';
import '../../core/services/bookmark_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/feedback.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/grid_background.dart';
import '../../core/widgets/liquid_glass.dart';
import '../../core/widgets/page_top_bar.dart';
import '../../core/widgets/placeholder_panel.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../core/widgets/thin_divider.dart';
import '../reader/reader_arguments.dart';

/// 总书签库：把全部书籍的书签集中在一个列表里。
///
/// 按「最近添加」倒序展示，点按跳到对应书籍的对应章节，
/// 长按删除（书籍本身的阅读进度不受影响）。
class BookmarkLibraryPage extends StatefulWidget {
  const BookmarkLibraryPage({super.key});

  @override
  State<BookmarkLibraryPage> createState() => _BookmarkLibraryPageState();
}

class _BookmarkLibraryPageState extends State<BookmarkLibraryPage> {
  List<Bookmark> _bookmarks = const <Bookmark>[];
  Map<int, Book> _books = const <int, Book>{};
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final BookmarkRepository repo = context.read<BookmarkRepository>();
    final BookRepository books = context.read<BookRepository>();
    final List<Bookmark> all = await repo.loadAll();
    final List<Book> loaded = await books.loadAll();
    if (!mounted) {
      return;
    }
    setState(() {
      _bookmarks = all;
      _books = <int, Book>{for (final Book book in loaded) book.number: book};
      _loading = false;
    });
  }

  Future<void> _open(Bookmark bookmark) async {
    final Book? book = _books[bookmark.bookNumber];
    if (book == null) {
      showSoftMessage(context, '这本书已经不在了');
      return;
    }
    await Navigator.of(context).pushNamed(
      AppRoutes.reader,
      arguments: ReaderArguments(
        book: book,
        chapterIndex: bookmark.chapterIndex,
        chapterTitle: bookmark.chapterTitle,
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  Future<void> _remove(Bookmark bookmark) async {
    final bool confirmed = await showConfirmDialog(
      context: context,
      title: '删除这条书签？',
      english: 'DELETE BOOKMARK',
      message: '删除后无法恢复，书籍的阅读进度不会受影响。',
      danger: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    await context.read<BookmarkRepository>().remove(bookmark.id);
    if (!mounted) {
      return;
    }
    showSoftMessage(context, '书签已删除');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: AppColors.surface(brightness),
      body: GridBackground(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              const PageTopBar(title: '书签库', english: 'BOOKMARKS'),
              Expanded(child: _buildBody(brightness)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(Brightness brightness) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 1.6));
    }
    if (_bookmarks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: PlaceholderPanel(
            title: '还没有书签',
            english: 'NO BOOKMARKS',
            description: '阅读时在长按菜单里添加书签，这里会汇总全部书籍的书签。',
            icon: Icons.bookmark_border_rounded,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 40),
      itemCount: _bookmarks.length,
      separatorBuilder: (BuildContext context, int index) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ThinDivider(
          thickness: 0.6,
          color: AppColors.alpha(AppColors.divider(brightness), 0.7),
        ),
      ),
      itemBuilder: (BuildContext context, int index) {
        final Bookmark bookmark = _bookmarks[index];
        final Book? book = _books[bookmark.bookNumber];
        return _BookmarkRow(
          bookmark: bookmark,
          bookTitle: book?.title ?? '未知书籍',
          brightness: brightness,
          onTap: () => _open(bookmark),
          onLongPress: () => _remove(bookmark),
        );
      },
    );
  }
}

class _BookmarkRow extends StatelessWidget {
  const _BookmarkRow({
    required this.bookmark,
    required this.bookTitle,
    required this.brightness,
    required this.onTap,
    required this.onLongPress,
  });

  final Bookmark bookmark;
  final String bookTitle;
  final Brightness brightness;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final Color primary = AppColors.textPrimary(brightness);
    final Color tertiary = AppColors.textTertiary(brightness);
    return PressableScale(
      pressedScale: 0.99,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Icon(
                Icons.bookmark_rounded,
                size: 15,
                color: AppColors.alpha(AppColors.accent(brightness), 0.8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    bookTitle,
                    style: TextStyle(
                      fontFamily: AppFonts.serif,
                      fontSize: 14.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    <String>[
                      if (bookmark.chapterTitle.isNotEmpty)
                        bookmark.chapterTitle,
                      '${(bookmark.ratio * 100).round()}%',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      letterSpacing: 0.6,
                      color: tertiary,
                    ),
                  ),
                  if (bookmark.note.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    LiquidGlass(
                      borderRadius: 8,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      child: Text(
                        bookmark.note,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: AppColors.textSecondary(brightness),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              bookmark.timeLabel,
              style: TextStyle(
                fontSize: 8.6,
                letterSpacing: 0.6,
                color: AppColors.alpha(tertiary, 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
