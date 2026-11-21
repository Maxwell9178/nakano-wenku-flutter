import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/book.dart';
import '../../core/routing/app_routes.dart';
import '../../core/services/book_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/grid_background.dart';
import '../../core/widgets/liquid_glass.dart';
import '../../core/widgets/placeholder_panel.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../core/widgets/thin_divider.dart';
import '../bookshelf/widgets/book_list_item.dart';
import 'search_controller.dart';

/// 搜索页。
///
/// 需求要点：
/// * 搜索框位于上半页偏居中，不贴底；
/// * 进入页面不自动唤起键盘，点击搜索框之后才激活输入；
/// * 框内提示文字固定为「支持联想搜索哦！」；
/// * 搜索框使用液态毛玻璃。
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.active = true});

  /// 是否处于选中的标签页，用于切回来时刷新书籍数据。
  final bool active;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();
  LibrarySearchController? _controller;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_handleFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) {
      return;
    }
    _controller = LibrarySearchController(context.read<BookRepository>())
      ..loadBooks();
  }

  @override
  void didUpdateWidget(covariant SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _controller?.loadBooks();
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_handleFocusChanged);
    _focus.dispose();
    _text.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openBook(Book book) async {
    _focus.unfocus();
    await Navigator.of(context)
        .pushNamed(AppRoutes.bookDetail, arguments: book);
    if (mounted) {
      _controller?.loadBooks();
    }
  }

  void _applyKeyword(String keyword) {
    _text.value = TextEditingValue(
      text: keyword,
      selection: TextSelection.collapsed(offset: keyword.length),
    );
    _controller?.updateQuery(keyword);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final LibrarySearchController? controller = _controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }

    return GridBackground(
      child: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: controller,
          builder: (BuildContext context, Widget? child) {
            final Brightness brightness = Theme.of(context).brightness;
            return LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                // 搜索框落在页面上方约四分之一处：比正中更轻，也比贴顶自然。
                final double topSpace = (constraints.maxHeight * 0.20)
                    .clamp(48.0, 180.0)
                    .toDouble();

                return Column(
                  children: <Widget>[
                    SizedBox(height: topSpace),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: <Widget>[
                          Text(
                            '搜索',
                            style: AppTypography.chineseTitle(
                              brightness,
                              fontSize: 24,
                            ).copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'SEARCH',
                            style: AppTypography.englishLabel(
                              brightness,
                              fontSize: 9,
                              letterSpacing: 3.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ThinDivider(
                            width: 40,
                            gradient: LinearGradient(
                              colors: <Color>[
                                AppColors.alpha(
                                  AppColors.accent(brightness),
                                  0.8,
                                ),
                                AppColors.alpha(
                                  AppColors.accent(brightness),
                                  0.1,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildSearchField(brightness, controller),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: controller.hasQuery
                          ? _buildResults(brightness, controller)
                          : _buildIdle(brightness, controller),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ---------------- 搜索框 ----------------

  Widget _buildSearchField(
    Brightness brightness,
    LibrarySearchController controller,
  ) {
    final bool focused = _focus.hasFocus || controller.hasQuery;
    final Color accent = AppColors.accent(brightness);

    return LiquidGlass(
      borderRadius: 26,
      opacity: focused ? 0.18 : 0.10,
      borderWidth: focused ? 1.1 : 0.8,
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      onTap: _focus.requestFocus,
      child: Row(
        children: <Widget>[
          Icon(
            Icons.search_rounded,
            size: 19,
            color: focused ? accent : AppColors.textTertiary(brightness),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _text,
              focusNode: _focus,
              // 进入页面不自动聚焦：只有用户点搜索框才唤起键盘。
              autofocus: false,
              textInputAction: TextInputAction.search,
              style: TextStyle(
                fontSize: 13.5,
                letterSpacing: 0.4,
                color: AppColors.textPrimary(brightness),
              ),
              cursorColor: accent,
              cursorWidth: 1.4,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: '支持联想搜索哦！',
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  letterSpacing: 0.6,
                  color: AppColors.textTertiary(brightness),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: controller.updateQuery,
            ),
          ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: controller.hasQuery ? 1 : 0,
            child: PressableScale(
              pressedScale: 0.9,
              onTap: controller.hasQuery
                  ? () {
                      _text.clear();
                      controller.clear();
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppColors.textTertiary(brightness),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- 未输入时的提示 + 阅读榜单外壳 ----------------

  Widget _buildIdle(
    Brightness brightness,
    LibrarySearchController controller,
  ) {
    final List<Book> books = controller.allBooks;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 130),
      children: <Widget>[
        Text(
          '输入书名、作者或标签试试',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 0.5,
            color: AppColors.textTertiary(brightness),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: AppConstants.presetTags.map((String tag) {
            return PressableScale(
              pressedScale: 0.95,
              onTap: () => _applyKeyword(tag),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: AppColors.alpha(
                    AppColors.accent(brightness),
                    0.07,
                  ),
                  border: Border.all(
                    color: AppColors.alpha(
                      AppColors.accent(brightness),
                      0.28,
                    ),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 11.5,
                    letterSpacing: 0.6,
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 26),
        _buildRankPanel(brightness, books),
      ],
    );
  }

  /// 阅读榜单：按书籍累计阅读时长降序，无记录时给空状态。
  Widget _buildRankPanel(Brightness brightness, List<Book> books) {
    final Color accent = AppColors.accent(brightness);
    final List<Book> ranked = books
        .where((Book book) => book.totalReadMs > 0)
        .toList()
      ..sort((Book a, Book b) => b.totalReadMs.compareTo(a.totalReadMs));
    final List<Book> preview = ranked.take(3).toList(growable: false);
    final int slots = preview.isEmpty ? 1 : 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              '阅读榜单',
              style: AppTypography.chineseTitle(
                brightness,
                fontSize: 17,
              ).copyWith(fontWeight: FontWeight.w600, letterSpacing: 1.0),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                'READING RANK',
                style: AppTypography.englishLabel(
                  brightness,
                  fontSize: 8.2,
                  letterSpacing: 2.0,
                ).copyWith(color: AppColors.textTertiary(brightness)),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                preview.isEmpty ? '暂无记录' : '按累计时长排序',
                style: TextStyle(
                  fontSize: 9.5,
                  letterSpacing: 0.6,
                  color: AppColors.textTertiary(brightness),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LiquidGlass(
          borderRadius: 24,
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < slots; i++)
                _buildRankRow(
                  brightness: brightness,
                  accent: accent,
                  rank: i + 1,
                  book: i < preview.length ? preview[i] : null,
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _readTimeLabel(Book book) {
    final int minutes = (book.totalReadMs / 60000).ceil();
    if (minutes < 60) {
      return '$minutes 分钟';
    }
    final int hours = minutes ~/ 60;
    final int rest = minutes % 60;
    return rest == 0 ? '$hours 小时' : '$hours 小时 $rest 分';
  }

  Widget _buildRankRow({
    required Brightness brightness,
    required Color accent,
    required int rank,
    required Book? book,
  }) {
    final String number = rank.toString().padLeft(2, '0');
    final bool hasBook = book != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 24,
            child: Text(
              number,
              style: TextStyle(
                fontFamily: AppFonts.serif,
                fontFamilyFallback: AppFonts.serifFallback,
                fontSize: 15,
                fontWeight: rank == 1 ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: 1.0,
                color: hasBook
                    ? (rank == 1 ? accent : AppColors.textTertiary(brightness))
                    : AppColors.alpha(AppColors.textTertiary(brightness), 0.4),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  hasBook ? book.title : '还没有阅读记录',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    letterSpacing: 0.3,
                    color: hasBook
                        ? AppColors.textPrimary(brightness)
                        : AppColors.alpha(
                            AppColors.textTertiary(brightness),
                            0.7,
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        hasBook ? book.author : '开始阅读后这里会出现排行',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          letterSpacing: 0.3,
                          color: AppColors.textTertiary(brightness),
                        ),
                      ),
                    ),
                    Text(
                      hasBook ? _readTimeLabel(book) : '—',
                      style: TextStyle(
                        fontFamily: AppFonts.serif,
                        fontFamilyFallback: AppFonts.serifFallback,
                        fontSize: 9.5,
                        letterSpacing: 0.8,
                        color: AppColors.alpha(
                          AppColors.textTertiary(brightness),
                          0.85,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- 结果列表 ----------------

  Widget _buildResults(
    Brightness brightness,
    LibrarySearchController controller,
  ) {
    final List<Book> results = controller.results;
    if (results.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 130),
        children: <Widget>[
          PlaceholderPanel(
            title: '没有找到相关书籍',
            english: 'NO MATCH',
            description: '换个书名、作者或者标签关键字再试试。',
            icon: Icons.search_off_rounded,
            footer: '关键字「${controller.query.trim()}」',
          ),
        ],
      );
    }

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 6),
          child: Row(
            children: <Widget>[
              Text(
                '联想结果',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.6,
                  color: AppColors.textTertiary(brightness),
                ),
              ),
              const Spacer(),
              Text(
                '${results.length} 项',
                style: TextStyle(
                  fontSize: 9.5,
                  letterSpacing: 0.6,
                  color: AppColors.textTertiary(brightness),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 130),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: results.length,
            itemBuilder: (BuildContext context, int index) {
              final Book book = results[index];
              return BookListItem(
                book: book,
                onTap: () => _openBook(book),
              );
            },
          ),
        ),
      ],
    );
  }
}
