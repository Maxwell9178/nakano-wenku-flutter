import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/book.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/services/book_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/grid_background.dart';
import '../../../core/widgets/page_top_bar.dart';
import '../../../core/widgets/placeholder_panel.dart';
import '../../bookshelf/widgets/book_list_item.dart';

/// 书籍列表筛选类型（「我的」页三个统计入口共用同一个页面）。
enum BookListFilter { all, finished, unfinished }

extension BookListFilterX on BookListFilter {
  String get title {
    switch (this) {
      case BookListFilter.all:
        return '全部书籍';
      case BookListFilter.finished:
        return '已读书籍';
      case BookListFilter.unfinished:
        return '未读书籍';
    }
  }

  String get english {
    switch (this) {
      case BookListFilter.all:
        return 'ALL BOOKS';
      case BookListFilter.finished:
        return 'FINISHED BOOKS';
      case BookListFilter.unfinished:
        return 'UNFINISHED BOOKS';
    }
  }

  String get emptyHint {
    switch (this) {
      case BookListFilter.all:
        return '书架还是空的，先去导入一本书吧。';
      case BookListFilter.finished:
        return '还没有标记为已读完的书。';
      case BookListFilter.unfinished:
        return '没有未读完的书，全部读完了。';
    }
  }

  bool matches(Book book) {
    switch (this) {
      case BookListFilter.all:
        return true;
      case BookListFilter.finished:
        return book.isFinished;
      case BookListFilter.unfinished:
        return !book.isFinished;
    }
  }
}

/// 统计入口跳转过来的书籍列表页。
///
/// 只读展示：点条目进入书籍详情，返回后重新读取一次，
/// 保证在详情页标记读完 / 删除后这里立刻同步。
class BookListPage extends StatefulWidget {
  const BookListPage({super.key, required this.filter});

  final BookListFilter filter;

  @override
  State<BookListPage> createState() => _BookListPageState();
}

class _BookListPageState extends State<BookListPage> {
  BookRepository? _books;
  List<Book> _items = const <Book>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_books != null) {
      return;
    }
    _books = context.read<BookRepository>();
    _reload();
  }

  void _reload() {
    final BookRepository? repository = _books;
    if (repository == null) {
      return;
    }
    final List<Book> all = repository.loadAll();
    setState(() {
      _items = all.where(widget.filter.matches).toList(growable: false);
    });
  }

  Future<void> _openDetail(Book book) async {
    await Navigator.of(context)
        .pushNamed(AppRoutes.bookDetail, arguments: book);
    if (mounted) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GridBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              PageTopBar(
                title: widget.filter.title,
                english: widget.filter.english,
                trailing: Text(
                  '${_items.length} 本',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.6,
                    color: AppColors.textTertiary(brightness),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _items.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: PlaceholderPanel(
                          title: '这里还没有书',
                          english: 'EMPTY',
                          description: widget.filter.emptyHint,
                          icon: Icons.auto_stories_outlined,
                          footer: '返回书架可以继续导入',
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 40),
                        itemCount: _items.length,
                        itemBuilder: (BuildContext context, int index) {
                          final Book book = _items[index];
                          return BookListItem(
                            book: book,
                            onTap: () => _openDetail(book),
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
