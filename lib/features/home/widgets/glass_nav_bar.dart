import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/frosted_glass.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/widgets/pressable_scale.dart';

/// 底部导航项的数据描述。
class GlassNavItem {
  const GlassNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// 底部毛玻璃液态导航栏。
///
/// 设计说明：
/// - 整体是一块悬浮的毛玻璃，保证内容可以从它下方透出；
/// - 选中项内部再叠一层液态玻璃胶囊，形成「高亮 + 材质」的双重层次；
/// - 点击采用内缩回弹（PressableScale），不使用 Material 水波纹。
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onChanged,
  });

  final List<GlassNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: FrostedGlass(
        borderRadius: 26,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        shadows: true,
        child: Row(
          children: <Widget>[
            for (int i = 0; i < items.length; i++)
              Expanded(
                child: _NavItem(
                  item: items[i],
                  selected: i == currentIndex,
                  brightness: brightness,
                  onTap: () => onChanged(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.brightness,
    required this.onTap,
  });

  final GlassNavItem item;
  final bool selected;
  final Brightness brightness;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = AppColors.accent(brightness);
    final Color idle = AppColors.textTertiary(brightness);

    final Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      height: 50,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              selected ? item.activeIcon : item.icon,
              key: ValueKey<bool>(selected),
              size: 21,
              color: selected ? accent : idle,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 1.4,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? accent : idle,
            ),
          ),
        ],
      ),
    );

    return PressableScale(
      onTap: onTap,
      pressedScale: 0.94,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: selected
            ? LiquidGlass(
                borderRadius: 20,
                padding: EdgeInsets.zero,
                shadows: false,
                tint: accent,
                opacity: 0.16,
                child: content,
              )
            : content,
      ),
    );
  }
}
