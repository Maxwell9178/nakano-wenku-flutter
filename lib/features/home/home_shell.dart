import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/grid_background.dart';
import 'tabs/bookshelf_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/search_tab.dart';
import 'widgets/glass_nav_bar.dart';

/// 主框架：底部导航 + 三个标签页。
///
/// - 使用 IndexedStack 保留每个标签页的状态，切换标签不会丢失书架滚动位置；
/// - 导航栏悬浮在内容之上（extendBody），配合毛玻璃透出下层网格。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const List<GlassNavItem> _items = <GlassNavItem>[
    GlassNavItem(
      label: '书架',
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book_rounded,
    ),
    GlassNavItem(
      label: '搜索',
      icon: Icons.search_rounded,
      activeIcon: Icons.manage_search_rounded,
    ),
    GlassNavItem(
      label: '我的',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  late int _index = widget.initialIndex.clamp(0, _items.length - 1).toInt();

  void _onNavChanged(int next) {
    if (next == _index) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _index = next);
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        extendBody: true,
        body: GridBackground(
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: IndexedStack(
                  index: _index,
                  children: <Widget>[
                    const BookshelfTab(),
                    // 搜索 / 我的 需要知道自己是否被选中，切回来时刷新一次数据。
                    SearchTab(active: _index == 1),
                    ProfileTab(active: _index == 2),
                  ],
                ),
              ),
              // 导航栏贴在底部安全区之上。
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: GlassNavBar(
                    items: _items,
                    currentIndex: _index,
                    onChanged: _onNavChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
