import 'package:flutter/material.dart';

import '../../bookshelf/bookshelf_page.dart';

/// 书架标签页。
///
/// 底部导航的「书架」入口只做一层壳，真正的书架页面在
/// features/bookshelf/ 内实现，方便后续详情页、阅读页复用其中的组件。
class BookshelfTab extends StatelessWidget {
  const BookshelfTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const BookshelfPage();
  }
}
