import 'package:flutter/material.dart';

import '../../search/search_page.dart';

/// 底部导航的「搜索」标签：外壳只负责把选中状态传给页面。
class SearchTab extends StatelessWidget {
  const SearchTab({super.key, this.active = true});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return SearchPage(active: active);
  }
}
