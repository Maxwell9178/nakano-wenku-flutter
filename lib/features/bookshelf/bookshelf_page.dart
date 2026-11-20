import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_routes.dart';
import '../../core/models/book.dart';
import '../../core/services/book_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/grid_background.dart';
import '../../core/widgets/liquid_glass.dart';
import '../../core/widgets/placeholder_panel.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../core/widgets/section_header.dart';
import 'bookshelf_controller.dart';
import 'widgets/book_carousel.dart';
import 'widgets/book_info_panel.dart';
import 'widgets/book_list_item.dart';
import 'widgets/tag_filter_bar.dart';

/// 书架页。
///
/// 结构（自上而下）：
/// 1. 固定顶部栏（软件名 + 署名 + 导入入口）；
/// 2. 3D 立体轮播书架（上半区）；
/// 3. 居中书籍信息区（书名 / 作者 / 连载状态 / 详情箭头）；
/// 4. 标签筛选 + 纯文字书籍列表（下半区，按 NW 编号升序）。
///
/// 顶部栏与导入入口固定不随内容滚动；轮播居中项变化时信息区实时同步。
class BookshelfPage extends StatefulWidget {
  const BookshelfPage({super.key});

  @override
  State<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends State<BookshelfPage> {
  BookshelfController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 依赖注入的仓库来自 AppServices，页面自身不关心存储实现。
    _controller ??= BookshelfController(context.read<BookRepository>())..load();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BookshelfController controller = _controller!;

    return GridBackground(
      child: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: controller,
          builder: (BuildContext context, Widget? child) {
            return Column(
              children: <Widget>[
                AppTopBar(trailing: _buildImportButton(context)),
                Expanded(
                  child: controller.hasBooks
                      ? _buildShelf(context, controller)
                      : _buildEmptyState(context),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------- 有书：轮播 + 信息区 + 列表 ----------------

  Widget _buildShelf(BuildContext context, BookshelfController controller) {
    final double stageHeight = (MediaQuery.of(context).size.height * 0.32)
        .clamp(200.0, 300.0)
        .toDouble();
    final Book? current = controller.currentBook;
    final List<Book> visible = controller.visibleBooks;

    return Column(
      children: <Widget>[
        const SizedBox(height: 2),
        BookCarousel(
          books: controller.books,
          initialIndex: controller.currentIndex,
          stageHeight: stageHeight,
          onCenterChanged: controller.selectIndex,
          onBookTap: _openDetail,
        ),
        const SizedBox(height: 14),
        if (current != null)
          BookInfoPanel(
            book: current,
            onOpenDetail: () => _openDetail(current),
          ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SectionHeader(
            title: '全部藏书',
            english: 'LIBRARY',
            trailing: Text(
              '${visible.length} 本',
              style: TextStyle(
                fontSize: 10.5,
                letterSpacing: 1.0,
                color: AppColors.textTertiary(Theme.of(context).brightness),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TagFilterBar(
          tags: controller.availableTags,
          activeTag: controller.activeTag,
          onSelected: controller.selectTag,
        ),
        const SizedBox(height: 6),
        Expanded(
          child: visible.isEmpty
              ? _buildNoMatchState(context)
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 118),
                  itemCount: visible.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Book book = visible[index];
                    return BookListItem(
                      book: book,
                      onTap: () => _openDetail(book),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ---------------- 空书架 / 筛选无结果 ----------------

  Widget _buildEmptyState(BuildContext context) {
    return const PlaceholderPanel(
      title: '书架还是空的',
      english: 'Empty shelf',
      description: '点击右上角的导入按钮，把第一本书放进你的书架。\n全程离线，数据只保存在这台设备上。',
      icon: Icons.menu_book_outlined,
      footer: '支持 EPUB / TXT / DOCX / Markdown / ZIP',
    );
  }

  Widget _buildNoMatchState(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.filter_alt_off_outlined,
            size: 22,
            color: AppColors.textTertiary(brightness),
          ),
          const SizedBox(height: 10),
          Text(
            '这个标签下还没有书',
            style: TextStyle(
              fontSize: 12.5,
              letterSpacing: 0.5,
              color: AppColors.textSecondary(brightness),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- 右上角导入入口 ----------------

  Widget _buildImportButton(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final Color accent = AppColors.accent(brightness);

    return PressableScale(
      pressedScale: 0.94,
      onTap: _openImport,
      child: LiquidGlass(
        borderRadius: 14,
        borderWidth: 0.9,
        tint: accent,
        opacity: 0.10,
        shadows: false,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.add_rounded, size: 16, color: accent),
            const SizedBox(width: 5),
            Text(
              '导入',
              style: TextStyle(
                fontSize: 11.5,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w500,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- 跳转 ----------------

  /// 轮播与列表统一走同一个详情页。
  ///
  /// 详情页里可能改名、换封面、删章节甚至删整本，返回后必须重新读库，
  /// 否则书架会展示过期数据。
  Future<void> _openDetail(Book book) async {
    await Navigator.of(context)
        .pushNamed(AppRoutes.bookDetail, arguments: book);
    if (!mounted) {
      return;
    }
    _controller?.load();
  }

  Future<void> _openImport() async {
    await Navigator.of(context).pushNamed(AppRoutes.importFiles);
    if (!mounted) {
      return;
    }
    _controller?.load();
  }
}
