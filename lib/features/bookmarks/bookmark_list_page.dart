import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/book.dart';
import '../../core/models/bookmark.dart';
import '../../core/routing/app_routes.dart';
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

/// 某本书的书签列表。
///
/// 书签与阅读进度分开存储，这里只读取 [BookmarkRepository]，
/// 点按跳回对应章节，长按删除。
class BookmarkListPage extends StatefulWidget {
  const BookmarkListPage({super.key, required this.book});

  final Book book;

  @override
  State<BookmarkListPage> createState() => _BookmarkListPageState();
}

class _BookmarkListPageState extends State<BookmarkListPage> {
  List<Bookmark> _bookmarks = const <Bookmark>[];
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) {
      _load();
    }
  }

  Future<void> _load() async {
    final BookmarkRepository repo = context.read<BookmarkRepository>();
    final List<Bookmark> items = await repo.loadForBook(widget.book.number);
    if (!mounted) {
      return;
    }
    setState(() {
      _bookmarks = items;
      _loading = false;
    });
  }

  Future<void> _open(Bookmark bookmark) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.reader,
      arguments: ReaderArguments(
        book: widget.book,
        chapterIndex: bookmark.chapterIndex,
        chapterTitle: bookmark.chapterTitle,
      ),
    );
    _load();
  }

  Future<void> _delete(Bookmark bookmark) async {
    final bool ok = await showConfirmDialog(
      context: context,
      title: '删除这条书签？',
      english: 'DELETE BOOKMARK',
      message: '删除后无法恢复，书籍的阅读进度不会受影响。',
      confirmLabel: '删除',
      danger: true,
    );
    if (!ok || !mounted) {
      return;
    }
    await context.read<BookmarkRepository>().remove(bookmark.id);
    if (!mounted) {
      return;
    }
    showSoftMessage(context, '书签已删除');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = AppColors.textPrimary(Theme.of(context).brightness);

    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              PageTopBar(
                title: '书签',
                english: 'BOOKMARKS',
                trailing: Text(
                  '${_bookmarks.length} 条',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.0,
                    color: AppColors.alpha(textColor, 0.6),
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 1.6),
                      )
                    : _bookmarks.isEmpty
                        ? const PlaceholderPanel(
                            title: '还没有书签',
                            english: 'NO BOOKMARKS',
                            description: '阅读时在上方菜单里添加书签，会记录当前章节与进度。',
                            icon: Icons.bookmark_border_rounded,
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                            itemCount: _bookmarks.length,
                            separatorBuilder:
                                (BuildContext context, int index) =>
                                    const SizedBox(height: 10),
                            itemBuilder: (BuildContext context, int index) {
                              final Bookmark item = _bookmarks[index];
                              return LiquidGlass(
                                borderRadius: 16,
                                padding:
                                    const EdgeInsets.fromLTRB(14, 12, 14, 12),
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onLongPress: () => _delete(item),
                                  child: PressableScale(
                                    pressedScale: 0.98,
                                    onTap: () => _open(item),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Row(
                                          children: <Widget>[
                                            Icon(
                                              Icons.bookmark_rounded,
                                              size: 13,
                                              color: AppColors.accent(
                                                  Theme.of(context).brightness),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                item.chapterTitle,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: textColor,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '${(item.ratio * 100).round()}%',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                color: AppColors.alpha(
                                                  textColor,
                                                  0.55,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (item.note.isNotEmpty) ...<Widget>[
                                          const SizedBox(height: 6),
                                          Text(
                                            item.note,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              height: 1.5,
                                              color: AppColors.alpha(
                                                textColor,
                                                0.78,
                                              ),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        ThinDivider(
                                          thickness: 0.6,
                                          color:
                                              AppColors.alpha(textColor, 0.12),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          item.timeLabel,
                                          style: TextStyle(
                                            fontFamily: AppFonts.serif,
                                            fontSize: 9,
                                            letterSpacing: 0.6,
                                            color: AppColors.alpha(
                                                textColor, 0.45),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
