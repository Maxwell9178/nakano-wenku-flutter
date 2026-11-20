import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pressable_scale.dart';

/// 书籍列表上方的标签筛选栏。
///
/// 内置 6 类标签由书架控制器提供，自定义标签自动追加；首项固定为「全部」。
class TagFilterBar extends StatelessWidget {
  const TagFilterBar({
    super.key,
    required this.tags,
    required this.activeTag,
    required this.onSelected,
  });

  final List<String> tags;

  /// 当前选中的标签，null 表示「全部」。
  final String? activeTag;

  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: tags.length + 1,
        separatorBuilder: (BuildContext context, int index) {
          return const SizedBox(width: 9);
        },
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) {
            return _TagChip(
              label: '全部',
              selected: activeTag == null,
              onTap: () => onSelected(null),
            );
          }
          final String tag = tags[index - 1];
          return _TagChip(
            label: tag,
            selected: activeTag == tag,
            onTap: () => onSelected(tag),
          );
        },
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final Color accent = AppColors.accent(brightness);

    return PressableScale(
      pressedScale: 0.95,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected
              ? AppColors.alpha(accent, 0.13)
              : AppColors.alpha(AppColors.surface(brightness), 0.32),
          border: Border.all(
            color: selected
                ? AppColors.alpha(accent, 0.52)
                : AppColors.divider(brightness),
            width: 0.9,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            letterSpacing: 0.6,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? accent : AppColors.textSecondary(brightness),
          ),
        ),
      ),
    );
  }
}
